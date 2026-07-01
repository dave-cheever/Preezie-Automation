Feature: Chat API - TraceId + CMS Analyser validation (Google Sheets Data Driven)
  # ============================================================================
  # VALIDATION VIA CMS ANALYSER ENDPOINT
  # ============================================================================
  # All validation is now handled by the CMS Analyser endpoint which provides
  # comprehensive analysis of the chat trace including pass/fail determination.
  #
  # Flow:
  #   1. Send message to Chat API → get traceId
  #   2. Login to CMS (Firebase) → get bearer token
  #   3. Call CMS Analyser endpoint with traceId → get analysis
  #   4. Parse analysis result to determine pass/fail
  #
  # The analyser returns:
  #   - statusCode: "OK" or error
  #   - data.analysis: HTML-formatted analysis with Result (Pass/Fail)
  #   - data.traceId, data.tenantId
  # ============================================================================

Background:
  # 🌍 Dynamic Environment Configuration (from Google Sheets)
  * def sheetsReader = read('classpath:com/preezie/services/utils/google-sheets-reader.js')
  * def spreadsheetId = karate.get('googleSheetsId') || '1FV7pekpUKZ34VjDXuoslernJuGnx3jsjxJI5WkYsHVM'

  # Read environment name from Google Sheets config (defaults to 'dev')
  * def environment = sheetsReader.getEnvironmentFromConfig(spreadsheetId)

  # Get environment-specific URLs and Firebase key using karate-config helper
  * def envConfig = karate.get('getEnvironmentUrls')(environment)
  * def baseUrl = envConfig.chatBaseUrl
  * def cmsBase = envConfig.cmsBaseUrl
  * karate.log('🚀 Testing on:', environment.toUpperCase(), 'environment')

  # Utilities and helpers
  * def visitorRotation = read('classpath:com/preezie/services/utils/visitor-rotation.js')
  * def analyserParser = read('classpath:com/preezie/services/utils/analyser-parser.js')
  * def firebaseApiKeyConfig = envConfig.firebaseApiKey
  * def firebaseEmailConfig = karate.get('firebaseEmail')
  * def firebasePasswordConfig = karate.get('firebasePassword')
  * karate.log('🔑 Using Firebase API Key:', firebaseApiKeyConfig ? firebaseApiKeyConfig.substring(0, 20) + '...' : 'null')
  
  # Configure longer timeout for all HTTP requests (30 seconds)
  * configure readTimeout = 30000

Scenario: Run all enabled tests from Google Sheets
  # Load all enabled test data from Google Sheets
  * def allTestData = sheetsReader.getAllEnabledTestData(spreadsheetId)
  * karate.log('Loaded', allTestData.length, 'enabled test cases from Google Sheets')

  # Initialize visitor rotation (25 messages per visitor by default)
  * def baseVisitorId = 'test_visitor_' + java.lang.System.currentTimeMillis()
  * def messageLimit = 9
  * def initialVisitorId = visitorRotation.initialize(baseVisitorId, messageLimit)
  * karate.log('Visitor rotation initialized - Base ID:', baseVisitorId, '| Limit:', messageLimit)

  # Track results - grouped by test message/traceId
  * def results = { passed: 0, failed: 0, testFailures: {}, allTestResults: {} }

  # Store references for use in function
  * def cmsBaseUrl = cmsBase

  # Process each test case
  * def runTest =
    """
    function(testCase) {
      var visitorRotation = karate.get('visitorRotation');
      var analyserParser = karate.get('analyserParser');
      var baseUrl = karate.get('baseUrl');
      var cmsBaseUrl = karate.get('cmsBaseUrl');
      var tenantId = testCase.tenantId;
      var tenantName = testCase.tenantName;
      var content = testCase.content;
      var sessionId = testCase.sessionId || null;

      // Get current visitorId (automatically rotates when limit is reached)
      var visitorId = visitorRotation.getNextVisitorId();

      var results = karate.get('results');

      // Helper function to record failure
      function recordFailure(testKey, stage, errorDetails, analysisData, parsedAnalysis) {
        if (!results.testFailures[testKey]) {
          results.testFailures[testKey] = {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: testKey.split('||')[1] || 'N/A',
            failures: []
          };
        }
        results.testFailures[testKey].failures.push({
          stage: stage,
          error: errorDetails,
          analysis: analysisData || '',
          parsedAnalysis: parsedAnalysis || null
        });
      }

      karate.log('');
      karate.log('========================================');
      karate.log('Testing:', content);
      karate.log('Tenant:', tenantName, '(' + tenantId + ')');
      karate.log('SessionId:', sessionId);
      karate.log('VisitorId:', visitorId);
      karate.log('Using baseUrl:', baseUrl);
      karate.log('========================================');

      var traceId = null;
      var testKey = null;

      try {
        // 1) Get TraceId from Chat API
        karate.log('Step 1: Getting TraceId from Chat API...');
        var chat = karate.call('classpath:com/preezie/services/chat/get-trace-id.feature', {
          baseUrl: baseUrl,
          content: content,
          tenantId: tenantId,
          sessionId: sessionId,
          visitorId: visitorId
        });

        // Record that a message was sent (increments rotation counter)
        visitorRotation.recordMessageSent();

        if (!chat.traceId) {
          testKey = content + '||NO_TRACE';
          recordFailure(testKey, 'Chat API', 'No traceId returned', '');
          karate.log('[FAILED] No traceId returned');
          results.failed++;
          return;
        }
        traceId = chat.traceId;
        testKey = content + '||' + traceId;
        karate.log('TraceId:', traceId);

        // 2) Login to CMS (Firebase) to obtain bearer token
        karate.log('Step 2: Logging in to CMS auth...');
        var firebaseApiKey = karate.get('firebaseApiKeyConfig');
        var firebaseEmail = karate.get('firebaseEmailConfig');
        var firebasePassword = karate.get('firebasePasswordConfig');

        if (!firebaseApiKey || !firebaseEmail || !firebasePassword) {
          recordFailure(
            testKey,
            'CMS Auth',
            'Missing Firebase auth config. Set FIREBASE_API_KEY, FIREBASE_EMAIL, and FIREBASE_PASSWORD.',
            ''
          );
          karate.log('[FAILED] Missing Firebase auth config');
          results.failed++;
          return;
        }

        var loginResult = karate.call('classpath:com/preezie/services/auth/firebase-login.feature', {
          firebaseApiKey: firebaseApiKey,
          firebaseEmail: firebaseEmail,
          firebasePassword: firebasePassword
        });
        var cmsToken = loginResult ? loginResult.idToken : null;
        if (!cmsToken) {
          recordFailure(testKey, 'CMS Auth', 'Firebase login did not return idToken', '');
          karate.log('[FAILED] CMS auth returned no idToken');
          results.failed++;
          return;
        }

        // 3) Call CMS Analyser endpoint for validation with retry logic
        karate.log('Step 3: Calling CMS Analyser for validation...');
        
        var maxRetries = 5;
        var retryDelayMs = 5000; // 5 seconds between retries
        var parsed = null;
        var analyserResponse = null;
        var analysisData = null;
        
        for (var attempt = 1; attempt <= maxRetries; attempt++) {
          if (attempt > 1) {
            karate.log('⏳ Retry attempt', attempt, 'of', maxRetries, '- waiting', retryDelayMs / 1000, 'seconds...');
            java.lang.Thread.sleep(retryDelayMs);
          }
          
          analyserResponse = karate.call('classpath:com/preezie/services/cms/get-analyser-result.feature', {
            cmsBase: cmsBaseUrl,
            traceId: traceId,
            cmsIdToken: cmsToken
          });

          if (!analyserResponse || analyserResponse.statusCode !== 'OK') {
            var errorMsg = analyserResponse && analyserResponse.errorMessage ? analyserResponse.errorMessage : 'Analyser returned non-OK status';
            if (attempt === maxRetries) {
              recordFailure(testKey, 'CMS Analyser', errorMsg, '');
              karate.log('[FAILED] Analyser call failed after', maxRetries, 'attempts:', errorMsg);
              results.failed++;
              return;
            }
            karate.log('⚠️  Attempt', attempt, 'failed:', errorMsg);
            continue;
          }

          analysisData = analyserResponse.data;
          if (!analysisData || !analysisData.analysis) {
            if (attempt === maxRetries) {
              recordFailure(testKey, 'CMS Analyser', 'No analysis data returned after ' + maxRetries + ' attempts', '');
              karate.log('[FAILED] No analysis data in response after', maxRetries, 'attempts');
              results.failed++;
              return;
            }
            karate.log('⚠️  Attempt', attempt, '- No analysis data yet');
            continue;
          }

          // Log raw analysis for debugging
          if (attempt === 1) {
            karate.log('📄 Raw analysis (first 300 chars):', analysisData.analysis.substring(0, Math.min(300, analysisData.analysis.length)));
          }

          // Parse the analysis HTML to extract result
          parsed = analyserParser.parseAnalysis(analysisData.analysis);
          
          // Check if we got a valid result (not Unknown)
          if (parsed.result !== 'Unknown') {
            if (attempt > 1) {
              karate.log('✅ Got valid result on attempt', attempt);
            }
            break; // Success - exit retry loop
          }
          
          // Result is Unknown - log and retry
          if (attempt < maxRetries) {
            karate.log('⚠️  Attempt', attempt, '- Result is Unknown, will retry...');
          } else {
            karate.log('⚠️  All', maxRetries, 'attempts returned Unknown');
            karate.log('⚠️  Raw analysis:', analysisData.analysis);
          }
        }
        
        // Check if we exhausted all retries with Unknown result
        if (!parsed || parsed.result === 'Unknown') {
          recordFailure(testKey, 'CMS Analyser', 'Analyser returned Unknown after ' + maxRetries + ' attempts', '');
          karate.log('[FAILED] Result still Unknown after', maxRetries, 'attempts');
          results.failed++;
          return;
        }
        
        // Log complete analyser details for ALL tests
        karate.log('');
        karate.log('═══════════════════════════════════════════════════════════');
        karate.log('📊 ANALYSER DETAILS');
        karate.log('═══════════════════════════════════════════════════════════');
        karate.log('Result:', parsed.result || 'N/A');
        karate.log('───────────────────────────────────────────────────────────');
        if (parsed.intent) {
          karate.log('Intent:', parsed.intent);
          karate.log('───────────────────────────────────────────────────────────');
        }
        if (parsed.pipelineValidation) {
          karate.log('Pipeline Validation:', parsed.pipelineValidation);
          karate.log('───────────────────────────────────────────────────────────');
        }
        if (parsed.anomalies) {
          karate.log('Anomalies & Issues:', parsed.anomalies);
          karate.log('───────────────────────────────────────────────────────────');
        }
        if (parsed.qualityAssessment) {
          karate.log('Response Quality Assessment:', parsed.qualityAssessment);
          karate.log('───────────────────────────────────────────────────────────');
        }
        if (parsed.parseError) {
          karate.log('⚠️  Parse Error:', parsed.parseError);
          karate.log('───────────────────────────────────────────────────────────');
        }
        karate.log('═══════════════════════════════════════════════════════════');

        // Store analysis data for ALL tests (pass or fail)
        results.allTestResults[testKey] = {
          tenant: tenantName,
          tenantId: tenantId,
          content: content,
          traceId: traceId,
          status: null, // Will be set below
          parsedAnalysis: parsed
        };

        // Check if test passed
        var testPassed = analyserParser.isPassingResult(parsed);

        if (!testPassed) {
          var failureDetails = analyserParser.getAnalysisSummary(parsed);
          recordFailure(testKey, 'Analyser Validation', failureDetails, analysisData.analysis, parsed);
          results.allTestResults[testKey].status = 'FAILED';
          karate.log('[FAILED] Analyser determined: ' + parsed.result);
          results.failed++;
        } else {
          results.allTestResults[testKey].status = 'PASSED';
          karate.log('[PASSED] Analyser validation passed');
          results.passed++;
        }

      } catch (e) {
        results.failed++;
        var exceptionKey = content + '||' + (traceId || 'EXCEPTION');
        recordFailure(exceptionKey, 'Exception', e.message || String(e), '');
        karate.log('[ERROR]', e.message || e);
      }
    }
    """

  # Run all tests
  * karate.forEach(allTestData, runTest)

  # Print summary
  * karate.log('\n============================================')
  * karate.log('           TEST RESULTS SUMMARY              ')
  * karate.log('============================================')
  * karate.log('Total Tests:', allTestData.length)
  * karate.log('Passed:', results.passed)
  * karate.log('Failed:', results.failed)
  * def passRate = allTestData.length > 0 ? Math.round((results.passed / allTestData.length) * 100) : 0
  * karate.log('Pass Rate:', passRate + '%')
  * karate.log('============================================')

  # Print failed tests details
  * eval
    """
    var failureKeys = Object.keys(results.testFailures);
    if (failureKeys.length > 0) {
      karate.log('');
      karate.log('================== FAILED TESTS DETAILS ==================');

      for (var i = 0; i < failureKeys.length; i++) {
        var testFailure = results.testFailures[failureKeys[i]];

        karate.log('');
        karate.log('══════════════════════════════════════════════════════════');
        karate.log('[FAILED TEST ' + (i + 1) + ' of ' + failureKeys.length + ']');
        karate.log('══════════════════════════════════════════════════════════');
        karate.log('Message:   ' + testFailure.content);
        karate.log('Trace ID:  ' + testFailure.traceId);
        karate.log('Tenant:    ' + testFailure.tenant + ' (' + testFailure.tenantId + ')');
        karate.log('');
        karate.log('Failures: ' + testFailure.failures.length);
        karate.log('──────────────────────────────────────────────────────────');

        for (var j = 0; j < testFailure.failures.length; j++) {
          var failure = testFailure.failures[j];
          karate.log('');
          karate.log('  ' + (j + 1) + '. ' + failure.stage + ':');
          karate.log('     ' + failure.error);
          
          if (failure.parsedAnalysis) {
            karate.log('     ── Analyser Details ──────────────────────────');
            karate.log('     Result: ' + failure.parsedAnalysis.result);
            if (failure.parsedAnalysis.intent) {
              karate.log('     Intent: ' + failure.parsedAnalysis.intent);
            }
            if (failure.parsedAnalysis.pipelineValidation) {
              karate.log('     Pipeline Validation: ' + failure.parsedAnalysis.pipelineValidation);
            }
            if (failure.parsedAnalysis.anomalies) {
              karate.log('     Anomalies & Issues: ' + failure.parsedAnalysis.anomalies);
            }
            if (failure.parsedAnalysis.qualityAssessment) {
              karate.log('     Response Quality Assessment: ' + failure.parsedAnalysis.qualityAssessment);
            }
            karate.log('     ──────────────────────────────────────────');
          } else if (failure.analysis && failure.analysis.length > 0) {
            karate.log('     ── Full Analysis ──────────────────────────');
            var analysisLines = failure.analysis.split('\\n');
            for (var k = 0; k < analysisLines.length; k++) {
              karate.log('     ' + analysisLines[k]);
            }
            karate.log('     ──────────────────────────────────────────');
          }
        }
      }
      karate.log('');
      karate.log('═══════════════════════════════════════════════════════════════');
    }
    """

  # Store results for external access
  * def testResults = { totalTests: allTestData.length, passed: results.passed, failed: results.failed, testFailures: results.testFailures, spreadsheetId: spreadsheetId }
  * karate.set('testResultsForExport', testResults)

  # Write results to JSON and CSV files
  * eval
    """
    try {
      var FileWriter = Java.type('java.io.FileWriter');
      var projectDir = java.lang.System.getProperty('user.dir');
      var SimpleDateFormat = Java.type('java.text.SimpleDateFormat');
      var Date = Java.type('java.util.Date');
      
      var timestamp = new SimpleDateFormat('yyyy-MM-dd HH:mm:ss').format(new Date());
      
      var failuresArray = [];
      var failureKeys = Object.keys(results.testFailures);
      for (var i = 0; i < failureKeys.length; i++) {
        var testFailure = results.testFailures[failureKeys[i]];
        failuresArray.push({
          tenantId: testFailure.tenantId || '',
          tenantName: testFailure.tenant || 'Unknown',
          content: testFailure.content || '',
          traceId: testFailure.traceId || 'N/A',
          failures: testFailure.failures.map(function(f) {
            return {
              stage: f.stage,
              error: f.error || '',
              analysis: f.analysis || '',
              result: f.parsedAnalysis ? f.parsedAnalysis.result : null,
              intent: f.parsedAnalysis ? f.parsedAnalysis.intent : null,
              pipelineValidation: f.parsedAnalysis ? f.parsedAnalysis.pipelineValidation : null,
              anomalies: f.parsedAnalysis ? f.parsedAnalysis.anomalies : null,
              qualityAssessment: f.parsedAnalysis ? f.parsedAnalysis.qualityAssessment : null
            };
          })
        });
      }

      var jsonResults = {
        totalTests: allTestData.length,
        passed: results.passed,
        failed: results.failed,
        passRate: allTestData.length > 0 ? Math.round((results.passed / allTestData.length) * 100) : 0,
        failures: failuresArray
      };

      // Write JSON file
      var jsonPath = projectDir + '/target/test-results.json';
      var jsonWriter = new FileWriter(jsonPath);
      jsonWriter.write(JSON.stringify(jsonResults, null, 2));
      jsonWriter.close();
      karate.log('✅ Test results JSON written to:', jsonPath);
      
      // Write CSV file for Google Sheets import
      var csvPath = projectDir + '/target/test-results.csv';
      var csvWriter = new FileWriter(csvPath);
      
      // CSV Header
      csvWriter.write('Timestamp,Tenant,TenantId,Message,TraceId,Status,Result,Intent,Pipeline Validation,Anomalies & Issues,Response Quality Assessment,Error Details\\n');
      
      // Write each test result (both passed and failed)
      var resultKeys = Object.keys(results.allTestResults);
      for (var i = 0; i < resultKeys.length; i++) {
        var testKey = resultKeys[i];
        var testResult = results.allTestResults[testKey];
        var testFailure = results.testFailures[testKey];
        
        var status = testResult.status || 'UNKNOWN';
        var result = '';
        var intent = '';
        var pipelineValidation = '';
        var anomalies = '';
        var qualityAssessment = '';
        var errorDetails = '';
        
        // Get analysis data from the stored result
        if (testResult.parsedAnalysis) {
          result = testResult.parsedAnalysis.result || '';
          intent = testResult.parsedAnalysis.intent || '';
          pipelineValidation = testResult.parsedAnalysis.pipelineValidation || '';
          anomalies = testResult.parsedAnalysis.anomalies || '';
          qualityAssessment = testResult.parsedAnalysis.qualityAssessment || '';
        }
        
        // Add error details if it's a failure
        if (testFailure && testFailure.failures && testFailure.failures.length > 0) {
          for (var j = 0; j < testFailure.failures.length; j++) {
            var failure = testFailure.failures[j];
            if (failure.error) {
              errorDetails += (errorDetails ? ' | ' : '') + failure.stage + ': ' + failure.error;
            }
          }
        }
        
        // Escape CSV fields (wrap in quotes if they contain comma, quote, or newline)
        function escapeCsv(field) {
          if (!field) return '';
          var str = String(field);
          if (str.indexOf(',') > -1 || str.indexOf('"') > -1 || str.indexOf('\\n') > -1) {
            return '"' + str.replace(/"/g, '""') + '"';
          }
          return str;
        }
        
        var row = [
          escapeCsv(timestamp),
          escapeCsv(testResult.tenant || ''),
          escapeCsv(testResult.tenantId || ''),
          escapeCsv(testResult.content || ''),
          escapeCsv(testResult.traceId || 'N/A'),
          escapeCsv(status),
          escapeCsv(result),
          escapeCsv(intent),
          escapeCsv(pipelineValidation),
          escapeCsv(anomalies),
          escapeCsv(qualityAssessment),
          escapeCsv(errorDetails)
        ];
        
        csvWriter.write(row.join(',') + '\\n');
      }
      
      csvWriter.close();
      karate.log('✅ Test results CSV written to:', csvPath);
      karate.log('');
      karate.log('═══════════════════════════════════════════════════════════════════════════');
      karate.log('📋 TO IMPORT RESULTS TO GOOGLE SHEETS:');
      karate.log('   1. Open your Google Sheet: https://docs.google.com/spreadsheets/d/' + spreadsheetId);
      karate.log('   2. Go to the "results" tab (create it if it doesn\'t exist)');
      karate.log('   3. Click File → Import → Upload');
      karate.log('   4. Upload: ' + csvPath);
      karate.log('   5. Choose "Append to current sheet" or "Replace data at selected cell"');
      karate.log('═══════════════════════════════════════════════════════════════════════════');
      karate.log('');
      
    } catch (e) {
      karate.log('Warning: Could not write test results files:', e.message || e);
    }
    """

  # Fail the scenario if any tests failed
  * def failureMessage = results.failed > 0 ? results.failed + ' test(s) failed. Check logs above for details.' : 'All tests passed'
  * print failureMessage
  * if (results.failed > 0) karate.fail(failureMessage)
