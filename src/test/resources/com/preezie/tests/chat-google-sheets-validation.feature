Feature: Chat API validation selector (Google Sheets data driven)

Background:
  * def sheetsReader = read('classpath:com/preezie/services/utils/google-sheets-reader.js')
  * def pgfUtils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def analyserParser = read('classpath:com/preezie/services/utils/analyser-parser.js')
  * def visitorRotation = read('classpath:com/preezie/services/utils/visitor-rotation.js')
  * def spreadsheetId = karate.get('googleSheetsId') || '1FV7pekpUKZ34VjDXuoslernJuGnx3jsjxJI5WkYsHVM'
  * def environment = sheetsReader.getEnvironmentFromConfig(spreadsheetId)
  * def envConfig = karate.get('getEnvironmentUrls')(environment)
  * def baseUrl = envConfig.chatBaseUrl
  * def cmsBase = envConfig.cmsBaseUrl
  * def validationMode = sheetsReader.getValidationFromConfig(spreadsheetId)
  * def validationModeName = validationMode == '1' ? 'ai-judge' : 'analyser'
  * def firebaseApiKeyConfig = envConfig.firebaseApiKey
  * def firebaseEmailConfig = karate.get('firebaseEmail')
  * def firebasePasswordConfig = karate.get('firebasePassword')
  * configure readTimeout = 30000

Scenario: Run all enabled tests from Google Sheets
  * def allTestData = sheetsReader.getAllEnabledTestData(spreadsheetId)
  * karate.log('Loaded', allTestData.length, 'enabled test cases from Google Sheets')
  * karate.log('Validation mode:', validationModeName)

  * def baseVisitorId = allTestData.length > 0 && allTestData[0].visitorId ? allTestData[0].visitorId : 'test_visitor_' + java.lang.System.currentTimeMillis()
  * def messageLimit = 10
  * def initialVisitorId = visitorRotation.initialize(baseVisitorId, messageLimit)
  * karate.log('Visitor rotation initialized - Base ID:', baseVisitorId, '| Limit:', messageLimit)

  * def results =
    """
    {
      "validationMode": "#(validationMode)",
      "validationModeName": "#(validationModeName)",
      "passed": 0,
      "warnings": 0,
      "failed": 0,
      "testFailures": {},
      "testWarnings": {},
      "allTestResults": {}
    }
    """

  * def agentValidators =
    """
    [
      {
        "agentName": "getIntentSummary",
        "feature": "classpath:com/preezie/llm/helpers/run-evaluator.feature",
        "promptArgsFn": "getFirstIntentSummaryPromptArguments",
        "validationKey": "validationOut",
        "resultKey": "evaluatorResultOut",
        "callSucceededKey": "llmCallSucceededOut"
      },
      {
        "agentName": "getIntent",
        "feature": "classpath:com/preezie/llm/helpers/run-intent-evaluator.feature",
        "promptArgsFn": "getFirstIntentPromptArguments",
        "validationKey": "intentValidationOut",
        "resultKey": "intentEvaluatorResultOut",
        "callSucceededKey": "intentLlmCallSucceededOut"
      },
      {
        "agentName": "getCategories",
        "feature": "classpath:com/preezie/llm/helpers/run-categories-evaluator.feature",
        "promptArgsFn": "getFirstCategoriesPromptArguments",
        "validationKey": "categoriesValidationOut",
        "resultKey": "categoriesEvaluatorResultOut",
        "callSucceededKey": "categoriesLlmCallSucceededOut"
      },
      {
        "agentName": "findProductFromPrompt",
        "feature": "classpath:com/preezie/llm/helpers/run-findproduct-evaluator.feature",
        "promptArgsFn": "getFirstFindProductPromptArguments",
        "validationKey": "findProductValidationOut",
        "resultKey": "findProductEvaluatorResultOut",
        "callSucceededKey": "findProductLlmCallSucceededOut"
      },
      {
        "agentName": "smartResponse",
        "feature": "classpath:com/preezie/llm/helpers/run-smartresponse-evaluator.feature",
        "promptArgsFn": "getFirstSmartResponsePromptArguments",
        "validationKey": "smartResponseValidationOut",
        "resultKey": "smartResponseEvaluatorResultOut",
        "callSucceededKey": "smartResponseLlmCallSucceededOut"
      },
      {
        "agentName": "getUserInformation",
        "feature": "classpath:com/preezie/llm/helpers/run-getuserinformation-evaluator.feature",
        "promptArgsFn": "getFirstUserInformationPromptArguments",
        "validationKey": "getUserInformationValidationOut",
        "resultKey": "getUserInformationEvaluatorResultOut",
        "callSucceededKey": "getUserInformationLlmCallSucceededOut"
      },
      {
        "agentName": "specificQuestionSubIntent",
        "feature": "classpath:com/preezie/llm/helpers/run-specificquestionsubintent-evaluator.feature",
        "promptArgsFn": "getFirstSpecificQuestionSubIntentPromptArguments",
        "validationKey": "specificQuestionSubIntentValidationOut",
        "resultKey": "specificQuestionSubIntentEvaluatorResultOut",
        "callSucceededKey": "specificQuestionSubIntentLlmCallSucceededOut"
      },
      {
        "agentName": "multiProductQuestionSubIntent",
        "feature": "classpath:com/preezie/llm/helpers/run-multiproductquestionsubintent-evaluator.feature",
        "promptArgsFn": "getFirstMultiProductQuestionSubIntentPromptArguments",
        "validationKey": "multiProductQuestionSubIntentValidationOut",
        "resultKey": "multiProductQuestionSubIntentEvaluatorResultOut",
        "callSucceededKey": "multiProductQuestionSubIntentLlmCallSucceededOut"
      },
      {
        "agentName": "specificProductQuestion",
        "feature": "classpath:com/preezie/llm/helpers/run-specificproductquestion-evaluator.feature",
        "promptArgsFn": "getFirstSpecificProductQuestionPromptArguments",
        "validationKey": "specificProductQuestionValidationOut",
        "resultKey": "specificProductQuestionEvaluatorResultOut",
        "callSucceededKey": "specificProductQuestionLlmCallSucceededOut"
      },
      {
        "agentName": "searchingByTitle",
        "feature": "classpath:com/preezie/llm/helpers/run-searchingbytitle-evaluator.feature",
        "promptArgsFn": "getFirstSearchingByTitlePromptArguments",
        "validationKey": "searchingByTitleValidationOut",
        "resultKey": "searchingByTitleEvaluatorResultOut",
        "callSucceededKey": "searchingByTitleLlmCallSucceededOut"
      },
      {
        "agentName": "specificProductQuestionResponse",
        "feature": "classpath:com/preezie/llm/helpers/run-specificproductquestionresponse-evaluator.feature",
        "promptArgsFn": "getFirstSpecificProductQuestionResponsePromptArguments",
        "validationKey": "specificProductQuestionResponseValidationOut",
        "resultKey": "specificProductQuestionResponseEvaluatorResultOut",
        "callSucceededKey": "specificProductQuestionResponseLlmCallSucceededOut"
      },
      {
        "agentName": "specificProductSizeRecommendation",
        "feature": "classpath:com/preezie/llm/helpers/run-specificproductsizerecommendation-evaluator.feature",
        "promptArgsFn": "getFirstSpecificProductSizeRecommendationPromptArguments",
        "validationKey": "specificProductSizeRecommendationValidationOut",
        "resultKey": "specificProductSizeRecommendationEvaluatorResultOut",
        "callSucceededKey": "specificProductSizeRecommendationLlmCallSucceededOut"
      },
      {
        "agentName": "similarBaseProduct",
        "feature": "classpath:com/preezie/llm/helpers/run-similarbaseproduct-evaluator.feature",
        "promptArgsFn": "getFirstSimilarBaseProductPromptArguments",
        "validationKey": "similarBaseProductValidationOut",
        "resultKey": "similarBaseProductEvaluatorResultOut",
        "callSucceededKey": "similarBaseProductLlmCallSucceededOut"
      },
      {
        "agentName": "productCompareResponse",
        "feature": "classpath:com/preezie/llm/helpers/run-productcompareresponse-evaluator.feature",
        "promptArgsFn": "getFirstProductCompareResponsePromptArguments",
        "validationKey": "productCompareResponseValidationOut",
        "resultKey": "productCompareResponseEvaluatorResultOut",
        "callSucceededKey": "productCompareResponseLlmCallSucceededOut"
      },
      {
        "agentName": "findBaseProduct",
        "feature": "classpath:com/preezie/llm/helpers/run-findbaseproduct-evaluator.feature",
        "promptArgsFn": "getFirstFindBaseProductPromptArguments",
        "validationKey": "findBaseProductValidationOut",
        "resultKey": "findBaseProductEvaluatorResultOut",
        "callSucceededKey": "findBaseProductLlmCallSucceededOut"
      },
      {
        "agentName": "findProductsToBundle",
        "feature": "classpath:com/preezie/llm/helpers/run-findproductstobundle-evaluator.feature",
        "promptArgsFn": "getFirstFindProductsToBundlePromptArguments",
        "validationKey": "findProductsToBundleValidationOut",
        "resultKey": "findProductsToBundleEvaluatorResultOut",
        "callSucceededKey": "findProductsToBundleLlmCallSucceededOut"
      },
      {
        "agentName": "generalConversation",
        "feature": "classpath:com/preezie/llm/helpers/run-generalconversation-evaluator.feature",
        "promptArgsFn": "getFirstGeneralConversationPromptArguments",
        "validationKey": "generalConversationValidationOut",
        "resultKey": "generalConversationEvaluatorResultOut",
        "callSucceededKey": "generalConversationLlmCallSucceededOut"
      }
    ]
    """

  * def runTest =
    """
    function(testCase) {
      var pgfUtils = karate.get('pgfUtils');
      var analyserParser = karate.get('analyserParser');
      var validationMode = karate.get('validationMode');
      var validationModeName = karate.get('validationModeName');
      var baseUrl = karate.get('baseUrl');
      var cmsBase = karate.get('cmsBase');
      var firebaseApiKey = karate.get('firebaseApiKeyConfig');
      var firebaseEmail = karate.get('firebaseEmailConfig');
      var firebasePassword = karate.get('firebasePasswordConfig');
      var visitorRotation = karate.get('visitorRotation');
      var agentValidators = karate.get('agentValidators');
      var results = karate.get('results');
      var content = testCase.content;
      var tenantId = testCase.tenantId;
      var tenantName = testCase.tenantName;
      var sessionId = testCase.sessionId || null;
      var expectedSafe = ('' + (testCase.expectedSafe !== undefined ? testCase.expectedSafe : 'true')).toLowerCase() === 'true';
      var traceId = null;
      var testKey = null;
      var cmsToken = karate.get('cmsIdToken');

      function normalizeBoolean(value) {
        return ('' + value).toLowerCase() === 'true';
      }

      function ensureFailureBucket(key) {
        if (!results.testFailures[key]) {
          results.testFailures[key] = {
            validationMode: validationModeName,
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: key.split('||')[1] || 'N/A',
            failures: []
          };
        }
      }

      function recordFailure(key, failure) {
        ensureFailureBucket(key);
        results.testFailures[key].failures.push(failure);
      }

      function ensureWarningBucket(key) {
        if (!results.testWarnings[key]) {
          results.testWarnings[key] = {
            validationMode: validationModeName,
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: key.split('||')[1] || 'N/A',
            warnings: []
          };
        }
      }

      function recordWarning(key, warning) {
        ensureWarningBucket(key);
        results.testWarnings[key].warnings.push(warning);
      }

      function setAllResult(key, value) {
        results.allTestResults[key] = value;
      }

      function getCmsToken() {
        if (cmsToken) {
          karate.log('🔐 Reusing Firebase CMS token from cache:', cmsToken.substring(0, 20) + '...');
          return cmsToken;
        }

        if (!firebaseApiKey || !firebaseEmail || !firebasePassword) {
          karate.log('⚠️ Firebase login skipped: missing api key/email/password');
          return null;
        }

        karate.log('🔐 Logging in to Firebase for CMS bearer token...');
        var loginResult = karate.call('classpath:com/preezie/services/auth/firebase-login.feature', {
          firebaseApiKey: firebaseApiKey,
          firebaseEmail: firebaseEmail,
          firebasePassword: firebasePassword
        });
        cmsToken = loginResult && loginResult.idToken ? loginResult.idToken : null;
        karate.log(
          '🔐 Firebase login result:',
          loginResult && loginResult.expiresIn ? ('expiresIn=' + loginResult.expiresIn) : 'no expiresIn',
          '| idToken=',
          cmsToken ? cmsToken.substring(0, 20) + '...' : 'null'
        );
        return cmsToken;
      }

      function buildAiJudgeFailure(agentName, validation, parsedContent, responseText) {
        var report = pgfUtils.buildReport(validation, parsedContent, agentName);
        var severity = validation && validation.severity ? validation.severity : (validation && validation.pass === true ? 'pass' : 'fail');
        var warnings = [];
        if (validation && validation.warnings) {
          warnings = Array.isArray(validation.warnings) ? validation.warnings : [validation.warnings];
        }
        var resultLabel = severity === 'warning' ? 'PASS WITH WARNING' : (validation && validation.pass === true ? 'PASS' : 'FAIL');
        return {
          stage: agentName,
          agentName: agentName,
          error: report,
          validationMode: validationModeName,
          result: resultLabel,
          severity: severity,
          intent: agentName,
          pipelineValidation: validation && validation.scores ? JSON.stringify(validation.scores) : '',
          anomalies: severity === 'warning'
            ? (warnings && warnings.length > 0 ? warnings.join(' | ') : '')
            : (validation && validation.issues ? validation.issues.join(' | ') : ''),
          warnings: warnings && warnings.length > 0 ? warnings.join(' | ') : '',
          qualityAssessment: validation && validation.summary ? validation.summary : '',
          responseLLM: responseText || '',
          validationReport: report,
          scores: validation && validation.scores ? validation.scores : null,
          summary: validation && validation.summary ? validation.summary : ''
        };
      }

      function buildAnalyserFailure(stage, errorMessage, analysisData, parsedAnalysis) {
        return {
          stage: stage,
          agentName: stage,
          error: errorMessage,
          validationMode: validationModeName,
          analysis: analysisData || '',
          parsedAnalysis: parsedAnalysis || null,
          result: parsedAnalysis && parsedAnalysis.result ? parsedAnalysis.result : '',
          intent: parsedAnalysis && parsedAnalysis.intent ? parsedAnalysis.intent : '',
          pipelineValidation: parsedAnalysis && parsedAnalysis.pipelineValidation ? parsedAnalysis.pipelineValidation : '',
          anomalies: parsedAnalysis && parsedAnalysis.anomalies ? parsedAnalysis.anomalies : '',
          qualityAssessment: parsedAnalysis && parsedAnalysis.qualityAssessment ? parsedAnalysis.qualityAssessment : ''
        };
      }

      function validatePromptGlobalFilter(traceData, expectedSafeValue) {
        var matches = Array.isArray(traceData) ? traceData.filter(function(item) {
          return item && item.agentName === 'promptGlobalFilter';
        }) : [];

        if (!matches.length) {
          return { pass: false, severity: 'fail', message: 'No promptGlobalFilter trace data found' };
        }

        var pgf = pgfUtils.findFirstValidPGF(matches, 'Safe');
        if (!pgf || !pgf.parsed) {
          return { pass: false, severity: 'fail', message: 'No valid promptGlobalFilter payload found' };
        }

        var actual = pgf.parsed.Safe;
        if (normalizeBoolean(actual) !== normalizeBoolean(expectedSafeValue)) {
          return {
            pass: true,
            severity: 'warning',
            message: 'Expected Safe: ' + expectedSafeValue + ' | Actual Safe: ' + actual,
            actual: actual
          };
        }

        return { pass: true, severity: 'pass', actual: actual };
      }

      function runAiJudge(traceData) {
        var validations = [];
        var failures = [];
        var warnings = [];
        var failed = false;
        var traceAgentMap = {};
        var presentValidators = [];
        var traceCount = Array.isArray(traceData) ? traceData.length : 0;
        var agentCount = 0;
        var i;

        var safeCheck = validatePromptGlobalFilter(traceData, expectedSafe);
        if (!safeCheck.pass) {
          failed = true;
          var safeFailure = {
            stage: 'promptGlobalFilter',
            agentName: 'promptGlobalFilter',
            error: safeCheck.message,
            validationMode: validationModeName,
            result: 'FAIL',
            intent: 'promptGlobalFilter',
            pipelineValidation: '',
            anomalies: safeCheck.message,
            qualityAssessment: '',
            responseLLM: '',
            validationReport: safeCheck.message
          };
          validations.push(safeFailure);
          failures.push(safeFailure);
        } else if (safeCheck.severity === 'warning') {
          var safeWarning = {
            stage: 'promptGlobalFilter',
            agentName: 'promptGlobalFilter',
            error: safeCheck.message,
            validationMode: validationModeName,
            result: 'PASS WITH WARNING',
            severity: 'warning',
            intent: 'promptGlobalFilter',
            pipelineValidation: '',
            anomalies: safeCheck.message,
            warnings: [safeCheck.message],
            qualityAssessment: '',
            responseLLM: '',
            validationReport: safeCheck.message,
          };
          validations.push(safeWarning);
          warnings.push(safeWarning);
        }

        if (Array.isArray(traceData)) {
          for (i = 0; i < traceData.length; i++) {
            if (traceData[i] && traceData[i].agentName && traceData[i].agentName !== 'promptGlobalFilter') {
              traceAgentMap[traceData[i].agentName] = true;
            }
          }
        }

        for (i = 0; i < agentValidators.length; i++) {
          if (traceAgentMap[agentValidators[i].agentName]) {
            presentValidators.push(agentValidators[i]);
          }
        }

        karate.log('🔎 AI judge trace agents:', Object.keys(traceAgentMap).join(', ') || 'none');
        karate.log('🔎 AI judge validating', presentValidators.length, 'of', agentValidators.length, 'known validators');

        for (i = 0; i < presentValidators.length; i++) {
          var config = presentValidators[i];
          agentCount++;
          var items = Array.isArray(traceData) ? traceData.filter(function(item) {
            return item && item.agentName === config.agentName;
          }) : [];

          if (!items.length) {
            failed = true;
            var missingTraceFailure = {
              stage: config.agentName,
              agentName: config.agentName,
              error: 'No trace items found for agent ' + config.agentName,
              validationMode: validationModeName,
              result: 'FAIL',
              intent: config.agentName,
              pipelineValidation: '',
              anomalies: 'No trace items found',
              qualityAssessment: '',
              responseLLM: '',
              validationReport: 'No trace items found for agent ' + config.agentName
            };
            validations.push(missingTraceFailure);
            failures.push(missingTraceFailure);
            continue;
          }

          var promptArgsFn = pgfUtils[config.promptArgsFn];
          var promptArgs = promptArgsFn ? promptArgsFn.call(pgfUtils, items) : null;
          var promptArgumentsText = promptArgs ? JSON.stringify(promptArgs, null, 2) : '';
          var llmRequestText = pgfUtils.getFirstLLMRequestFormatedText(items) || '';
          var responseText = pgfUtils.getFirstLLMResponseText(items) || '';
          var userMessage = promptArgs && promptArgs.userPrompt ? promptArgs.userPrompt : content;

          if (!promptArgumentsText || !llmRequestText || !responseText) {
            failed = true;
            var missingInputsFailure = {
              stage: config.agentName,
              agentName: config.agentName,
              error: 'Missing trace data for AI judge inputs',
              validationMode: validationModeName,
              result: 'FAIL',
              intent: config.agentName,
              pipelineValidation: '',
              anomalies: 'Missing prompt arguments, request text, or response text',
              qualityAssessment: '',
              responseLLM: responseText || '',
              validationReport: 'Missing trace data for AI judge inputs'
            };
            validations.push(missingInputsFailure);
            failures.push(missingInputsFailure);
            continue;
          }

          var evaluatorArgs = {
            PromptArguments: promptArgumentsText,
            LLMRequestFormattedPrompt: llmRequestText,
            UserMessage: userMessage,
            ResponseLLM: responseText,
            tenantId: tenantId,
            content: content
          };

          var evalResult = karate.call(config.feature, evaluatorArgs);
          var validation = evalResult[config.validationKey];
          var evaluatorResult = evalResult[config.resultKey];
          var parsedContent = evaluatorResult && evaluatorResult.parsedContent ? evaluatorResult.parsedContent : null;
          var passed = validation && validation.pass === true;

          var agentResult = buildAiJudgeFailure(config.agentName, validation, parsedContent, responseText);
          validations.push(agentResult);

          if (!passed) {
            failed = true;
            failures.push(agentResult);
          } else if (validation && validation.severity === 'warning') {
            warnings.push(agentResult);
          }
        }

        return {
          pass: !failed,
          validations: validations,
          warnings: warnings,
          failures: failures,
          traceAgentCount: Object.keys(traceAgentMap).length,
          validatedAgentCount: agentCount
        };
      }

      function runAnalyser(traceIdValue, cmsTokenValue) {
        var analyserResponse = karate.call('classpath:com/preezie/services/cms/get-analyser-result.feature', {
          cmsBase: cmsBase,
          traceId: traceIdValue,
          cmsIdToken: cmsTokenValue
        });

        if (!analyserResponse || analyserResponse.statusCode !== 'OK') {
          return {
            pass: false,
            failures: [
              buildAnalyserFailure(
                'CMS Analyser',
                analyserResponse && analyserResponse.errorMessage ? analyserResponse.errorMessage : 'Analyser returned non-OK status',
                '',
                null
              )
            ]
          };
        }

        var analysisData = analyserResponse.data;
        if (!analysisData || !analysisData.analysis) {
          return {
            pass: false,
            failures: [
              buildAnalyserFailure(
                'CMS Analyser',
                'No analysis data returned',
                analysisData || '',
                null
              )
            ]
          };
        }

        var parsed = analyserParser.parseAnalysis(analysisData.analysis);
        if (!parsed || parsed.result === 'Unknown') {
          return {
            pass: false,
            failures: [
              buildAnalyserFailure(
                'CMS Analyser',
                'Analyser returned Unknown',
                analysisData.analysis,
                parsed
              )
            ]
          };
        }

        var passed = analyserParser.isPassingResult(parsed);
        return {
          pass: passed,
          parsed: parsed,
          analysisData: analysisData
        };
      }

      karate.log('');
      karate.log('========================================');
      karate.log('Testing:', content);
      karate.log('Tenant:', tenantName, '(' + tenantId + ')');
      karate.log('SessionId:', sessionId);
      karate.log('Validation mode:', validationModeName);
      karate.log('Using baseUrl:', baseUrl);
      karate.log('========================================');

      try {
        var chatToken = getCmsToken();
        if (!chatToken) {
          testKey = content + '||NO_TOKEN';
          recordFailure(testKey, {
            stage: 'CMS Auth',
            agentName: 'CMS Auth',
            error: 'Missing Firebase auth config or CMS token',
            validationMode: validationModeName,
            result: 'FAIL',
            intent: 'CMS Auth',
            pipelineValidation: '',
            anomalies: 'Missing Firebase auth config or CMS token',
            qualityAssessment: '',
            responseLLM: '',
            validationReport: 'Missing Firebase auth config or CMS token'
          });
          setAllResult(testKey, {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: 'NO_TOKEN',
            validationMode: validationModeName,
            status: 'FAILED'
          });
          results.failed++;
          return;
        }

        karate.log('Step 1: Getting TraceId from Chat API...');
        var chat = karate.call('classpath:com/preezie/services/chat/get-trace-id.feature', {
          baseUrl: baseUrl,
          content: content,
          tenantId: tenantId,
          sessionId: sessionId,
          visitorId: visitorRotation.getNextVisitorId(),
          cmsIdToken: chatToken
        });

        visitorRotation.recordMessageSent();

        if (!chat.traceId) {
          testKey = content + '||NO_TRACE';
          recordFailure(testKey, {
            stage: 'Chat API',
            agentName: 'Chat API',
            error: 'No traceId returned',
            validationMode: validationModeName,
            result: 'FAIL',
            intent: 'Chat API',
            pipelineValidation: '',
            anomalies: 'No traceId returned',
            qualityAssessment: '',
            responseLLM: '',
            validationReport: 'No traceId returned'
          });
          setAllResult(testKey, {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: 'NO_TRACE',
            validationMode: validationModeName,
            status: 'FAILED'
          });
          results.failed++;
          return;
        }

        traceId = chat.traceId;
        testKey = content + '||' + traceId;
        karate.log('TraceId:', traceId);

        if (validationMode === '1') {
          karate.log('Step 2: Loading CMS trace data for AI judge...');
          var traceResponse = karate.call('classpath:com/preezie/services/cms/get-trace-data.feature', {
            cmsBase: cmsBase,
            traceId: traceId,
            cmsIdToken: chatToken
          });
          var traceData = traceResponse && traceResponse.data ? traceResponse.data : [];

          karate.log('Step 3: Running AI judge validations...');
          var aiJudgeResult = runAiJudge(traceData);
          var aiJudgeStatus = aiJudgeResult.warnings && aiJudgeResult.warnings.length > 0 ? 'PASSED_WITH_WARNING' : 'PASSED';
          setAllResult(testKey, {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: traceId,
            validationMode: validationModeName,
            status: aiJudgeStatus,
            validations: aiJudgeResult.validations,
            warnings: aiJudgeResult.warnings
          });

          if (!aiJudgeResult.pass) {
            for (var ai = 0; ai < aiJudgeResult.failures.length; ai++) {
              recordFailure(testKey, aiJudgeResult.failures[ai]);
            }
            results.failed++;
            karate.log('[FAILED] AI judge validation failed');
          } else {
            results.passed++;
            if (aiJudgeResult.warnings && aiJudgeResult.warnings.length > 0) {
              results.warnings = results.warnings + aiJudgeResult.warnings.length;
              for (var aw = 0; aw < aiJudgeResult.warnings.length; aw++) {
                recordWarning(testKey, aiJudgeResult.warnings[aw]);
              }
              karate.log('[PASSED WITH WARNING] AI judge validation passed with warnings');
            } else {
              karate.log('[PASSED] AI judge validation passed');
            }
          }
        } else {
          karate.log('Step 2: Logging in to CMS auth...');
          karate.log('Step 3: Calling CMS Analyser for validation...');
          var analyserResult = runAnalyser(traceId, chatToken);
          setAllResult(testKey, {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: traceId,
            validationMode: validationModeName,
            status: analyserResult.pass ? 'PASSED' : 'FAILED',
            parsedAnalysis: analyserResult.parsed || null
          });

          if (!analyserResult.pass) {
            recordFailure(testKey, analyserResult.failures[0]);
            results.failed++;
            karate.log('[FAILED] Analyser validation failed');
          } else {
            results.passed++;
            karate.log('[PASSED] Analyser validation passed');
          }
        }
      } catch (e) {
        results.failed++;
        var exceptionKey = content + '||' + (traceId || 'EXCEPTION');
        recordFailure(exceptionKey, {
          stage: 'Exception',
          agentName: 'Exception',
          error: e.message || String(e),
          validationMode: validationModeName,
          result: 'FAIL',
          intent: 'Exception',
          pipelineValidation: '',
          anomalies: e.message || String(e),
          qualityAssessment: '',
          responseLLM: '',
          validationReport: e.message || String(e)
        });
        karate.log('[ERROR]', e.message || e);
      }
    }
    """

  * karate.forEach(allTestData, runTest)

  * karate.log('\n============================================')
  * karate.log('           TEST RESULTS SUMMARY              ')
  * karate.log('============================================')
  * karate.log('Validation mode:', validationModeName)
  * karate.log('Total Tests:', allTestData.length)
  * karate.log('Passed:', results.passed)
  * karate.log('Warnings:', results.warnings)
  * karate.log('Failed:', results.failed)
  * def passRate = allTestData.length > 0 ? Math.round((results.passed / allTestData.length) * 100) : 0
  * karate.log('Pass Rate:', passRate + '%')
  * karate.log('============================================')

  * eval
    """
    var warningKeys = Object.keys(results.testWarnings);
    if (warningKeys.length > 0) {
      karate.log('');
      karate.log('================== PASS WITH WARNINGS ==================');
      for (var w = 0; w < warningKeys.length; w++) {
        var testWarning = results.testWarnings[warningKeys[w]];
        karate.log('');
        karate.log('══════════════════════════════════════════════════════════');
        karate.log('[WARNED TEST ' + (w + 1) + ' of ' + warningKeys.length + ']');
        karate.log('Mode:     ' + testWarning.validationMode);
        karate.log('Message:  ' + testWarning.content);
        karate.log('Trace ID: ' + testWarning.traceId);
        karate.log('Tenant:   ' + testWarning.tenant + ' (' + testWarning.tenantId + ')');
        karate.log('Warnings: ' + testWarning.warnings.length);
        karate.log('──────────────────────────────────────────────────────────');
        for (var wy = 0; wy < testWarning.warnings.length; wy++) {
          var warning = testWarning.warnings[wy];
          karate.log('');
          karate.log('  ' + (wy + 1) + '. ' + warning.stage + ':');
          karate.log('     ' + warning.error);
          if (warning.validationReport && warning.validationReport !== warning.error) {
            karate.log('     ── Validation Report ─────────────────────────');
            karate.log('     ' + warning.validationReport);
          }
        }
      }
      karate.log('');
      karate.log('═══════════════════════════════════════════════════════════════');
    }

    var failureKeys = Object.keys(results.testFailures);
    if (failureKeys.length > 0) {
      karate.log('');
      karate.log('================== FAILED TESTS DETAILS ==================');
      for (var i = 0; i < failureKeys.length; i++) {
        var testFailure = results.testFailures[failureKeys[i]];
        karate.log('');
        karate.log('══════════════════════════════════════════════════════════');
        karate.log('[FAILED TEST ' + (i + 1) + ' of ' + failureKeys.length + ']');
        karate.log('Mode:     ' + testFailure.validationMode);
        karate.log('Message:  ' + testFailure.content);
        karate.log('Trace ID: ' + testFailure.traceId);
        karate.log('Tenant:   ' + testFailure.tenant + ' (' + testFailure.tenantId + ')');
        karate.log('Failures: ' + testFailure.failures.length);
        karate.log('──────────────────────────────────────────────────────────');

        for (var j = 0; j < testFailure.failures.length; j++) {
          var failure = testFailure.failures[j];
          karate.log('');
          karate.log('  ' + (j + 1) + '. ' + failure.stage + ':');
          karate.log('     ' + failure.error);
          if (failure.validationReport && failure.validationReport !== failure.error) {
            karate.log('     ── Validation Report ─────────────────────────');
            karate.log('     ' + failure.validationReport);
          }
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
          }
        }
      }
      karate.log('');
      karate.log('═══════════════════════════════════════════════════════════════');
    }
    """

  * def failureArray = []
  * eval
    """
    var failureKeys = Object.keys(results.testFailures);
    for (var i = 0; i < failureKeys.length; i++) {
      failureArray.push(results.testFailures[failureKeys[i]]);
    }
    """

  * def warningArray = []
  * eval
    """
    var warningKeys = Object.keys(results.testWarnings);
    for (var i = 0; i < warningKeys.length; i++) {
      warningArray.push(results.testWarnings[warningKeys[i]]);
    }
    """

  * eval
    """
    try {
      var FileWriter = Java.type('java.io.FileWriter');
      var projectDir = java.lang.System.getProperty('user.dir');
      var modeSuffix = validationModeName;
      var timestamp = new java.text.SimpleDateFormat('yyyy-MM-dd HH:mm:ss').format(new java.util.Date());

      function escapeCsv(field) {
        if (field === undefined || field === null) return '';
        var str = String(field);
        if (str.indexOf(',') > -1 || str.indexOf('"') > -1 || str.indexOf('\\n') > -1) {
          return '"' + str.replace(/"/g, '""') + '"';
        }
        return str;
      }

      function writeFile(path, content) {
        var writer = new FileWriter(path);
        writer.write(content);
        writer.close();
      }

      var payload = {
        validationMode: validationMode,
        validationModeName: validationModeName,
        totalTests: allTestData.length,
        passed: results.passed,
        warnings: results.warnings,
        failed: results.failed,
        passRate: passRate,
        warningResults: warningArray,
        failures: failureArray
      };

      var genericJsonPath = projectDir + '/target/test-results.json';
      var modeJsonPath = projectDir + '/target/test-results-' + modeSuffix + '.json';
      writeFile(genericJsonPath, JSON.stringify(payload, null, 2));
      writeFile(modeJsonPath, JSON.stringify(payload, null, 2));

      var csvPath = projectDir + '/target/test-results-' + modeSuffix + '.csv';
      var csvLines = [];

      if (validationModeName === 'ai-judge') {
        csvLines.push(['Timestamp','Tenant','TenantId','Message','TraceId','Validation Mode','Stage','Status','Result','Intent','Pipeline Validation','Anomalies & Issues','Response Quality Assessment','Error Details'].join(','));
        for (var wi = 0; wi < warningArray.length; wi++) {
          var testWarning = warningArray[wi];
          for (var wj = 0; wj < testWarning.warnings.length; wj++) {
            var warningItem = testWarning.warnings[wj];
            csvLines.push([
              escapeCsv(timestamp),
              escapeCsv(testWarning.tenant || ''),
              escapeCsv(testWarning.tenantId || ''),
              escapeCsv(testWarning.content || ''),
              escapeCsv(testWarning.traceId || 'N/A'),
              escapeCsv(validationModeName),
              escapeCsv(warningItem.stage || ''),
              escapeCsv('WARNING'),
              escapeCsv(warningItem.result || 'PASS WITH WARNING'),
              escapeCsv(warningItem.intent || ''),
              escapeCsv(warningItem.pipelineValidation || ''),
              escapeCsv(warningItem.warnings || warningItem.anomalies || ''),
              escapeCsv(warningItem.qualityAssessment || ''),
              escapeCsv(warningItem.validationReport || warningItem.error || '')
            ].join(','));
          }
        }
        for (var i = 0; i < failureArray.length; i++) {
          var testFailure = failureArray[i];
          for (var j = 0; j < testFailure.failures.length; j++) {
            var failure = testFailure.failures[j];
            csvLines.push([
              escapeCsv(timestamp),
              escapeCsv(testFailure.tenant || ''),
              escapeCsv(testFailure.tenantId || ''),
              escapeCsv(testFailure.content || ''),
              escapeCsv(testFailure.traceId || 'N/A'),
              escapeCsv(validationModeName),
              escapeCsv(failure.stage || ''),
              escapeCsv(failure.result || 'UNKNOWN'),
              escapeCsv(failure.result || ''),
              escapeCsv(failure.intent || ''),
              escapeCsv(failure.pipelineValidation || ''),
              escapeCsv(failure.anomalies || ''),
              escapeCsv(failure.qualityAssessment || ''),
              escapeCsv(failure.validationReport || failure.error || '')
            ].join(','));
          }
        }
      } else {
        csvLines.push(['Timestamp','Tenant','TenantId','Message','TraceId','Validation Mode','Status','Result','Intent','Pipeline Validation','Anomalies & Issues','Response Quality Assessment','Error Details'].join(','));
        for (var k = 0; k < failureArray.length; k++) {
          var analyserFailure = failureArray[k];
          for (var m = 0; m < analyserFailure.failures.length; m++) {
            var af = analyserFailure.failures[m];
            csvLines.push([
              escapeCsv(timestamp),
              escapeCsv(analyserFailure.tenant || ''),
              escapeCsv(analyserFailure.tenantId || ''),
              escapeCsv(analyserFailure.content || ''),
              escapeCsv(analyserFailure.traceId || 'N/A'),
              escapeCsv(validationModeName),
              escapeCsv('FAILED'),
              escapeCsv(af.result || ''),
              escapeCsv(af.intent || ''),
              escapeCsv(af.pipelineValidation || ''),
              escapeCsv(af.anomalies || ''),
              escapeCsv(af.qualityAssessment || ''),
              escapeCsv(af.error || '')
            ].join(','));
          }
        }
      }

      writeFile(genericJsonPath.replace('.json', '.csv'), csvLines.join('\\n'));
      writeFile(csvPath, csvLines.join('\\n'));
      karate.log('✅ Test results JSON written to:', genericJsonPath);
      karate.log('✅ Test results JSON written to:', modeJsonPath);
      karate.log('✅ Test results CSV written to:', csvPath);
    } catch (e) {
      karate.log('Warning: Could not write test results files:', e.message || e);
    }
    """
