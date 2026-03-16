Feature: Chat API - TraceId + CMS validation (Google Sheets Data Driven)
  # ============================================================================
  # TEST DATA IS NOW IN GOOGLE SPREADSHEET!
  # ============================================================================
  # Spreadsheet: https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
  #
  # Sheets Required:
  #   - tenantConfig: columns [tenantName, tenantId, dataFile, enabled]
  #   - Blue_Bungalow: columns [content, expectedSafe, intent, enabled]
  #   - JB_HIFI: columns [content, expectedSafe, intent, enabled]
  #   - PUMA: columns [content, expectedSafe, intent, enabled]
  #
  # IMPORTANT: The Google Sheet must be published to web:
  #   File > Share > Publish to web > Entire Document > CSV
  # ============================================================================

Background:
  * def baseUrl = 'https://dev-greenback-app-chat.azurewebsites.net'
  * def cmsBase = 'https://dev-greenback-app-cms-gateway.azurewebsites.net'
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def sheetsReader = read('classpath:com/preezie/services/utils/google-sheets-reader.js')
  * def spreadsheetId = karate.get('googleSheetsId') || '1FV7pekpUKZ34VjDXuoslernJuGnx3jsjxJI5WkYsHVM'
  * def authToken = karate.get('cmsIdToken')

Scenario: Run all enabled tests from Google Sheets
  # Load all enabled test data from Google Sheets
  * def allTestData = sheetsReader.getAllEnabledTestData(spreadsheetId)
  * karate.log('Loaded', allTestData.length, 'enabled test cases from Google Sheets')

  # Track results
  * def results = { passed: 0, failed: 0, errors: [] }

  # Store references for use in function
  * def cmsBaseUrl = cmsBase
  * def token = authToken

  # Process each test case
  * def runTest =
    """
    function(testCase) {
      var utils = karate.get('utils');
      var tenantId = testCase.tenantId;
      var tenantName = testCase.tenantName;
      var content = testCase.content;
      var expectedSafe = testCase.expectedSafe === true || testCase.expectedSafe === 'true' || testCase.expectedSafe === 'TRUE';
      var expectedIntent = testCase.intent;
      var results = karate.get('results');

      karate.log('');
      karate.log('========================================');
      karate.log('Testing:', content);
      karate.log('Tenant:', tenantName, '(' + tenantId + ')');
      karate.log('Expected Safe:', expectedSafe, '| Expected Intent:', expectedIntent);
      karate.log('========================================');

      try {
        // 1) Get TraceId from Chat API
        karate.log('Step 1: Getting TraceId from Chat API...');
        var chat = karate.call('classpath:com/preezie/services/chat/get-trace-id.feature', { content: content, tenantId: tenantId });

        if (!chat.traceId) {
          results.failed++;
          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            stage: 'Chat API',
            error: 'No traceId returned'
          });
          karate.log('[FAILED] No traceId returned');
          return;
        }
        karate.log('TraceId:', chat.traceId);

        // 2) CMS trace lookup
        karate.log('Step 2: CMS trace lookup...');
        var cmsResponse = karate.call('classpath:com/preezie/services/cms/get-trace-data.feature', {
          cmsBase: karate.get('cmsBaseUrl'),
          traceId: chat.traceId,
          cmsIdToken: karate.get('token')
        });

        var traceData = cmsResponse.data;
        karate.log('Trace data retrieved, items:', traceData ? traceData.length : 0);

        // 3) Validate promptGlobalFilter.Safe
        karate.log('Step 3: Validating promptGlobalFilter.Safe...');
        var pgf = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', {
          data: traceData,
          agentName: 'promptGlobalFilter',
          key: 'Safe'
        });
        karate.log('promptGlobalFilter.Safe - Expected:', expectedSafe, 'Actual:', pgf.value);

        if (pgf.value !== expectedSafe) {
          results.failed++;
          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            stage: 'promptGlobalFilter',
            expected: expectedSafe,
            actual: pgf.value
          });
          karate.log('[FAILED] promptGlobalFilter - Expected:', expectedSafe, 'Actual:', pgf.value);
          return;
        }

        // 4) Validate getIntent.Intent (if present)
        karate.log('Step 4: Validating getIntent.Intent...');
        var getIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntent' });
        karate.log('getIntent items found:', getIntentItems.length);

        if (getIntentItems.length > 0 && expectedIntent) {
          var intent = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', {
            data: traceData,
            agentName: 'getIntent',
            key: 'Intent'
          });
          karate.log('getIntent.Intent - Expected:', expectedIntent, 'Actual:', intent.value);

          if (intent.value !== expectedIntent) {
            results.failed++;
            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              stage: 'getIntent',
              expected: expectedIntent,
              actual: intent.value
            });
            karate.log('[FAILED] getIntent - Expected:', expectedIntent, 'Actual:', intent.value);
            return;
          }
        } else {
          karate.log('Skipping getIntent validation (not present or no expected value)');
        }

        // 5) Validate getIntentSummary with LLM evaluator
        karate.log('Step 5: Validating getIntentSummary with LLM evaluator...');
        var intentSummaryItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntentSummary' });
        karate.log('getIntentSummary items found:', intentSummaryItems.length);

        var llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems);
        var promptArgumentsText = utils.getFirstLLMPromptArgumentsText(intentSummaryItems);
        var llmRequestFormatedText = utils.getFirstLLMRequestFormatedText(intentSummaryItems);

        karate.log('LLM Response Text:', llmResponseText ? llmResponseText.substring(0, 100) + '...' : 'null');

        var evalArgs = {
          PromptArguments: promptArgumentsText,
          LLMRequestFormattedPrompt: llmRequestFormatedText,
          UserMessage: content,
          ResponseLLM: llmResponseText,
          tenantId: tenantId,
          content: content
        };

        var evalResult = karate.call('classpath:com/preezie/llm/helpers/run-evaluator.feature', evalArgs);
        karate.log('Evaluator result - pass:', evalResult && evalResult.validation ? evalResult.validation.pass : 'undefined');

        var passed = evalResult && evalResult.validation && evalResult.validation.pass === true;
        if (!passed) {
          results.failed++;
          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            stage: 'getIntentSummary',
            responseLLM: llmResponseText,
            validation: evalResult && evalResult.validation ? evalResult.validation : 'no validation'
          });
          karate.log('[FAILED] getIntentSummary validation');
          return;
        }

        // All validations passed
        results.passed++;
        karate.log('[PASSED] All validations passed for:', content);

      } catch (e) {
        results.failed++;
        results.errors.push({
          tenant: tenantName,
          tenantId: tenantId,
          content: content,
          stage: 'Exception',
          error: e.message || String(e)
        });
        karate.log('[ERROR]', e.message || e);
      }
    }
    """

  # Run all tests
  * karate.forEach(allTestData, runTest)

  # Print summary
  * karate.log('\\n============================================')
  * karate.log('           TEST RESULTS SUMMARY              ')
  * karate.log('============================================')
  * karate.log('Total Tests:', allTestData.length)
  * karate.log('Passed:', results.passed)
  * karate.log('Failed:', results.failed)
  * karate.log('Pass Rate:', Math.round((results.passed / allTestData.length) * 100) + '%')
  * karate.log('============================================')

  # Print failed tests details
  * eval
    """
    if (results.errors.length > 0) {
      karate.log('');
      karate.log('================== FAILED TESTS DETAILS ==================');
      for (var i = 0; i < results.errors.length; i++) {
        var err = results.errors[i];
        karate.log('');
        karate.log('[FAILURE ' + (i + 1) + ' of ' + results.errors.length + ']');
        karate.log('  Tenant: ' + err.tenant + ' (' + err.tenantId + ')');
        karate.log('  Content: ' + err.content);
        karate.log('  Failed At: ' + err.stage);
        if (err.expected !== undefined) {
          karate.log('  Expected: ' + err.expected);
          karate.log('  Actual: ' + err.actual);
        }
        if (err.error) {
          karate.log('  Error: ' + err.error);
        }
        if (err.responseLLM) {
          karate.log('  ResponseLLM: ' + err.responseLLM);
        }
        if (err.validation && typeof err.validation === 'object') {
          karate.log('  Validation: ' + JSON.stringify(err.validation, null, 2));
        }
      }
      karate.log('');
      karate.log('===========================================================');
    }
    """

  # Build failure message for assertion
  * def failureMessage = results.failed > 0 ? results.failed + ' test(s) failed. Check logs above for details.' : 'All tests passed'
  * print failureMessage

  # Fail the scenario if any tests failed
  * if (results.failed > 0) karate.fail(failureMessage)
