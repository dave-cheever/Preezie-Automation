Feature: Chat API - TraceId + CMS validation (Google Sheets Data Driven)
  # ============================================================================
  # TEST DATA IS NOW IN GOOGLE SPREADSHEET!
  # ============================================================================
  # Spreadsheet: https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
  #
  # Sheets Required:
  #   - tenantConfig: columns [tenantName, tenantId, dataFile, enabled]
  #   - Blue_Bungalow: columns [content, expectedSafe, enabled]
  #   - JB_HIFI: columns [content, expectedSafe, enabled]
  #   - PUMA: columns [content, expectedSafe, enabled]
  #
  # NOTE: The 'intent' column is no longer required in test data!
  # getIntent is now validated using AI judge similar to getIntentSummary.
  #
  # SOFT VALIDATION MODE: AI Judge validations continue even on failure
  # to collect all validation results for a complete report.
  #
  # IMPORTANT: The Google Sheet must be published to web:
  #   File > Share > Publish to web > Entire Document > CSV
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
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def visitorRotation = read('classpath:com/preezie/services/utils/visitor-rotation.js')
  * def firebaseApiKeyConfig = envConfig.firebaseApiKey
  * def firebaseEmailConfig = karate.get('firebaseEmail')
  * def firebasePasswordConfig = karate.get('firebasePassword')
  * karate.log('🔑 Using Firebase API Key:', firebaseApiKeyConfig ? firebaseApiKeyConfig.substring(0, 20) + '...' : 'null')

Scenario: Run all enabled tests from Google Sheets
  # Load all enabled test data from Google Sheets
  * def allTestData = sheetsReader.getAllEnabledTestData(spreadsheetId)
  * karate.log('Loaded', allTestData.length, 'enabled test cases from Google Sheets')

  # Initialize visitor rotation (25 messages per visitor by default)
  * def baseVisitorId = 'test_visitor_' + java.lang.System.currentTimeMillis()
  * def messageLimit = 25
  * def initialVisitorId = visitorRotation.initialize(baseVisitorId, messageLimit)
  * karate.log('Visitor rotation initialized - Base ID:', baseVisitorId, '| Limit:', messageLimit)

  # Track results - grouped by test message/traceId
  * def results = { passed: 0, failed: 0, testFailures: {} }

  # Store references for use in function
  * def cmsBaseUrl = cmsBase

  # Process each test case
  * def runTest =
    """
    function(testCase) {
      var utils = karate.get('utils');
      var visitorRotation = karate.get('visitorRotation');
      var baseUrl = karate.get('baseUrl');
      var tenantId = testCase.tenantId;
      var tenantName = testCase.tenantName;
      var content = testCase.content;
      var expectedSafe = testCase.expectedSafe === true || testCase.expectedSafe === 'true' || testCase.expectedSafe === 'TRUE';
      var sessionId = testCase.sessionId || null;

      // Get current visitorId (automatically rotates when limit is reached)
      var visitorId = visitorRotation.getNextVisitorId();

      var results = karate.get('results');

      // Helper function to record agent failure
      function recordAgentFailure(testKey, agentName, errorDetails, responseLLM, expected, actual) {
        if (!results.testFailures[testKey]) {
          results.testFailures[testKey] = {
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: testKey.split('||')[1] || 'N/A',
            agentFailures: []
          };
        }
        var failureEntry = {
          agent: agentName,
          error: errorDetails,
          responseLLM: responseLLM || ''
        };
        if (expected !== undefined) failureEntry.expected = expected;
        if (actual !== undefined) failureEntry.actual = actual;
        results.testFailures[testKey].agentFailures.push(failureEntry);
      }

      karate.log('');
      karate.log('========================================');
      karate.log('Testing:', content);
      karate.log('Tenant:', tenantName, '(' + tenantId + ')');
      karate.log('Expected Safe:', expectedSafe);
      karate.log('SessionId:', sessionId);
      karate.log('VisitorId:', visitorId);
      karate.log('Using baseUrl:', baseUrl);
      karate.log('========================================');

      var traceId = null;

      // Track validation failures for this test case (soft validation)
      var testHasFailures = false;

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
          testHasFailures = true;
          // Create failure entry for this test
          testKey = content + '||NO_TRACE';
          recordAgentFailure(testKey, 'Chat API', 'No traceId returned', '');
          karate.log('[FAILED] No traceId returned');
          // Cannot continue without traceId - this is a hard failure
          results.failed++;
          return;
        }
        traceId = chat.traceId;
        testKey = content + '||' + traceId;  // Unique key for this test
        karate.log('TraceId:', chat.traceId);

        // 2) Login to CMS (Firebase) to obtain bearer token
        karate.log('Step 2: Logging in to CMS auth...');
        var firebaseApiKey = karate.get('firebaseApiKeyConfig');
        var firebaseEmail = karate.get('firebaseEmailConfig');
        var firebasePassword = karate.get('firebasePasswordConfig');

        if (!firebaseApiKey || !firebaseEmail || !firebasePassword) {
          testHasFailures = true;
          recordAgentFailure(
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
          testHasFailures = true;
          recordAgentFailure(testKey, 'CMS Auth', 'Firebase login did not return idToken', '');
          karate.log('[FAILED] CMS auth returned no idToken');
          results.failed++;
          return;
        }

        // 3) CMS trace lookup using bearer token
        karate.log('Step 3: CMS trace lookup...');
        var cmsResponse = karate.call('classpath:com/preezie/services/cms/get-trace-data.feature', {
          cmsBase: karate.get('cmsBaseUrl'),
          traceId: chat.traceId,
          cmsIdToken: cmsToken
        });

        var traceData = cmsResponse.data;
        karate.log('Trace data retrieved, items:', traceData ? traceData.length : 0);
        if (traceData && traceData.length > 0) {
          var agentNames = karate.map(traceData, function(x){ return x.agentName });
          karate.log('All agent names in trace:', JSON.stringify(agentNames));
        }

        // 4) Validate promptGlobalFilter.Safe (HARD validation - stops if failed)
        karate.log('Step 4: Validating promptGlobalFilter.Safe...');
        var pgf = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', {
          data: traceData,
          agentName: 'promptGlobalFilter',
          key: 'Safe'
        });
        karate.log('promptGlobalFilter.Safe - Expected:', expectedSafe, 'Actual:', pgf.value);

        if (pgf.value !== expectedSafe) {
          testHasFailures = true;
          recordAgentFailure(
            testKey,
            'promptGlobalFilter',
            'Expected: ' + expectedSafe + ', Actual: ' + pgf.value,
            '',
            expectedSafe,
            pgf.value
          );
          karate.log('[FAILED] promptGlobalFilter - Expected:', expectedSafe, 'Actual:', pgf.value);
          // promptGlobalFilter is a hard validation - if Safe doesn't match, stop
          results.failed++;
          return;
        }

        // ======================================================================
        // AI JUDGE SOFT VALIDATIONS - Continue even on failure
        // ======================================================================

        // 5) Validate getIntentSummary with LLM evaluator (SOFT validation)
        karate.log('Step 5: Validating getIntentSummary with LLM evaluator...');
        var intentSummaryItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntentSummary' });
        karate.log('getIntentSummary items found:', intentSummaryItems.length);

        var llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems);
        var promptArgumentsObj = utils.getFirstIntentSummaryPromptArguments(intentSummaryItems);
        var llmRequestFormatedText = utils.getFirstLLMRequestFormatedText(intentSummaryItems);

        karate.log('LLM Response Text:', llmResponseText ? llmResponseText.substring(0, 100) + '...' : 'null');

        var evalArgs = {
          PromptArguments: promptArgumentsObj,
          LLMRequestFormattedPrompt: llmRequestFormatedText,
          UserMessage: content,
          ResponseLLM: llmResponseText,
          tenantId: tenantId,
          content: content
        };

        var evalResult = karate.call('classpath:com/preezie/llm/helpers/run-evaluator.feature', evalArgs);
        karate.log('Evaluator result - pass:', evalResult && evalResult.validationOut ? evalResult.validationOut.pass : 'undefined');

        var validation = evalResult ? evalResult.validationOut : null;
        var passed = validation && validation.pass === true;
        if (!passed) {
          testHasFailures = true;

          // Build detailed error message for getIntentSummary
          var errorDetails = '';
          if (validation) {
            var parsedIntentSummaryContent = evalResult.evaluatorResultOut ? evalResult.evaluatorResultOut.parsedContent : null;
            errorDetails = utils.buildReport(validation, parsedIntentSummaryContent, 'getIntentSummary');
          } else {
            errorDetails = utils.buildReport(null, null, 'getIntentSummary');
          }

          recordAgentFailure(
            testKey,
            'getIntentSummary',
            errorDetails,
            llmResponseText ? (llmResponseText.length > 300 ? llmResponseText.substring(0, 300) + '...' : llmResponseText) : ''
          );
          karate.log('[SOFT FAIL] getIntentSummary validation:', errorDetails);
          // Continue to next validation (soft validation mode)
        }

        // 5) Validate getIntent with AI Judge (SOFT validation)
        karate.log('Step 5: Validating getIntent with AI Judge...');
        var getIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntent' });
        karate.log('getIntent items found:', getIntentItems.length);

        if (getIntentItems.length > 0) {
          var intentLlmResponseText = utils.getFirstLLMResponseText(getIntentItems);
          var intentPromptArgumentsObj = utils.getFirstIntentPromptArguments(getIntentItems);
          var intentLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getIntentItems);

          // Use the actual UserMessage from getIntent's prompt arguments, not the test content
          var intentUserMessage = utils.getFirstUserPromptOnly(getIntentItems);
          karate.log('getIntent UserMessage from trace:', intentUserMessage ? intentUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('getIntent LLM Response:', intentLlmResponseText ? intentLlmResponseText.substring(0, 100) + '...' : 'null');

          var intentEvalArgs = {
            PromptArguments: intentPromptArgumentsObj,
            LLMRequestFormattedPrompt: intentLlmRequestFormatedText,
            UserMessage: intentUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: intentLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var intentEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-intent-evaluator.feature', intentEvalArgs);
          karate.log('Intent Evaluator result - pass:', intentEvalResult && intentEvalResult.intentValidationOut ? intentEvalResult.intentValidationOut.pass : 'undefined');

          var intentValidation = intentEvalResult ? intentEvalResult.intentValidationOut : null;
          var intentPassed = intentValidation && intentValidation.pass === true;

          if (!intentPassed) {
            testHasFailures = true;

            var intentErrorDetails = '';
            {
              var parsedIntentContent = intentEvalResult.intentEvaluatorResultOut ? intentEvalResult.intentEvaluatorResultOut.parsedContent : null;
              intentErrorDetails = utils.buildReport(intentValidation, parsedIntentContent, 'getIntent');
            }

            recordAgentFailure(
              testKey,
              'getIntent',
              intentErrorDetails,
              intentLlmResponseText ? (intentLlmResponseText.length > 300 ? intentLlmResponseText.substring(0, 300) + '...' : intentLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] getIntent validation:', intentErrorDetails);
            // Continue to next validation (soft validation mode)
          }
        } else {
          karate.log('Skipping getIntent validation (not present in trace data)');
        }

        // 6) Validate getCategories with AI Judge (SOFT validation)
        karate.log('Step 6: Validating getCategories with AI Judge...');
        var getCategoriesItems = karate.filter(traceData, function(x){ return x.agentName == 'getCategories' });
        karate.log('getCategories items found:', getCategoriesItems.length);

        if (getCategoriesItems.length > 0) {
          var categoriesLlmResponseText = utils.getFirstLLMResponseText(getCategoriesItems);
          var categoriesPromptArgumentsObj = utils.getFirstCategoriesPromptArguments(getCategoriesItems);
          var categoriesLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getCategoriesItems);

          // Use the actual UserMessage from getCategories's prompt arguments
          var categoriesUserMessage = utils.getFirstUserPromptOnly(getCategoriesItems);
          karate.log('getCategories UserMessage from trace:', categoriesUserMessage ? categoriesUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('getCategories LLM Response:', categoriesLlmResponseText ? categoriesLlmResponseText.substring(0, 100) + '...' : 'null');

          var categoriesEvalArgs = {
            PromptArguments: categoriesPromptArgumentsObj,
            LLMRequestFormattedPrompt: categoriesLlmRequestFormatedText,
            UserMessage: categoriesUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: categoriesLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var categoriesEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-categories-evaluator.feature', categoriesEvalArgs);
          karate.log('Categories Evaluator result - pass:', categoriesEvalResult && categoriesEvalResult.categoriesValidationOut ? categoriesEvalResult.categoriesValidationOut.pass : 'undefined');

          var categoriesValidation = categoriesEvalResult ? categoriesEvalResult.categoriesValidationOut : null;
          var categoriesPassed = categoriesValidation && categoriesValidation.pass === true;

          if (!categoriesPassed) {
            testHasFailures = true;

            var categoriesErrorDetails = '';
            {
              var parsedCategoriesContent = categoriesEvalResult.categoriesEvaluatorResultOut ? categoriesEvalResult.categoriesEvaluatorResultOut.parsedContent : null;
              categoriesErrorDetails = utils.buildReport(categoriesValidation, parsedCategoriesContent, 'getCategories');
            }

            recordAgentFailure(
              testKey,
              'getCategories',
              categoriesErrorDetails,
              categoriesLlmResponseText ? (categoriesLlmResponseText.length > 300 ? categoriesLlmResponseText.substring(0, 300) + '...' : categoriesLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] getCategories validation:', categoriesErrorDetails);
            // Continue to next validation (soft validation mode)
          }
        } else {
          karate.log('Skipping getCategories validation (not present in trace data)');
        }

        // 7) Validate findProductFromPrompt with AI Judge (SOFT validation)
        karate.log('Step 7: Validating findProductFromPrompt with AI Judge...');
        var findProductItems = karate.filter(traceData, function(x){ return x.agentName == 'findProductFromPrompt' });
        karate.log('findProductFromPrompt items found:', findProductItems.length);

        if (findProductItems.length > 0) {
          var findProductLlmResponseText = utils.getFirstLLMResponseText(findProductItems);
          var findProductPromptArgumentsObj = utils.getFirstFindProductPromptArguments(findProductItems);
          var findProductLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(findProductItems);

          // Use the actual UserMessage from findProductFromPrompt's prompt arguments
          var findProductUserMessage = utils.getFirstUserPromptOnly(findProductItems);
          karate.log('findProductFromPrompt UserMessage from trace:', findProductUserMessage ? findProductUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('findProductFromPrompt LLM Response:', findProductLlmResponseText ? findProductLlmResponseText.substring(0, 100) + '...' : 'null');

          var findProductEvalArgs = {
            PromptArguments: findProductPromptArgumentsObj,
            LLMRequestFormattedPrompt: findProductLlmRequestFormatedText,
            UserMessage: findProductUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: findProductLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var findProductEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-findproduct-evaluator.feature', findProductEvalArgs);
          karate.log('FindProduct Evaluator result - pass:', findProductEvalResult && findProductEvalResult.findProductValidationOut ? findProductEvalResult.findProductValidationOut.pass : 'undefined');

          var findProductValidation = findProductEvalResult ? findProductEvalResult.findProductValidationOut : null;
          var findProductPassed = findProductValidation && findProductValidation.pass === true;

          if (!findProductPassed) {
            testHasFailures = true;

            var findProductErrorDetails = '';
            {
              var parsedFindProductContent = findProductEvalResult.findProductEvaluatorResultOut ? findProductEvalResult.findProductEvaluatorResultOut.parsedContent : null;
              findProductErrorDetails = utils.buildReport(findProductValidation, parsedFindProductContent, 'findProductFromPrompt');
            }

            recordAgentFailure(
              testKey,
              'findProductFromPrompt',
              findProductErrorDetails,
              findProductLlmResponseText ? (findProductLlmResponseText.length > 300 ? findProductLlmResponseText.substring(0, 300) + '...' : findProductLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] findProductFromPrompt validation:', findProductErrorDetails);
            // Continue to next validation (soft validation mode)
          }
        } else {
          karate.log('Skipping findProductFromPrompt validation (not present in trace data)');
        }

        // 8) Validate smartResponse with AI Judge (SOFT validation)
        karate.log('Step 8: Validating smartResponse with AI Judge...');
        var smartResponseItems = karate.filter(traceData, function(x){ return x.agentName == 'smartResponse' });
        karate.log('smartResponse items found:', smartResponseItems.length);

        if (smartResponseItems.length > 0) {
          var smartResponseLlmResponseText = utils.getFirstLLMResponseText(smartResponseItems);
          var smartResponsePromptArgumentsObj = utils.getFirstSmartResponsePromptArguments(smartResponseItems);
          var smartResponseLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(smartResponseItems);

          // Use the actual UserMessage from smartResponse's prompt arguments
          var smartResponseUserMessage = utils.getFirstUserPromptOnly(smartResponseItems);
          karate.log('smartResponse UserMessage from trace:', smartResponseUserMessage ? smartResponseUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('smartResponse LLM Response:', smartResponseLlmResponseText ? smartResponseLlmResponseText.substring(0, 100) + '...' : 'null');

          var smartResponseEvalArgs = {
            PromptArguments: smartResponsePromptArgumentsObj,
            LLMRequestFormattedPrompt: smartResponseLlmRequestFormatedText,
            UserMessage: smartResponseUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: smartResponseLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var smartResponseEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-smartresponse-evaluator.feature', smartResponseEvalArgs);
          karate.log('SmartResponse Evaluator result - pass:', smartResponseEvalResult && smartResponseEvalResult.smartResponseValidationOut ? smartResponseEvalResult.smartResponseValidationOut.pass : 'undefined');

          var smartResponseValidation = smartResponseEvalResult ? smartResponseEvalResult.smartResponseValidationOut : null;
          var smartResponsePassed = smartResponseValidation && smartResponseValidation.pass === true;

          if (!smartResponsePassed) {
            testHasFailures = true;

            var smartResponseErrorDetails = '';
            {
              var parsedSmartResponseContent = smartResponseEvalResult.smartResponseEvaluatorResultOut ? smartResponseEvalResult.smartResponseEvaluatorResultOut.parsedContent : null;
              smartResponseErrorDetails = utils.buildReport(smartResponseValidation, parsedSmartResponseContent, 'smartResponse');
            }

            recordAgentFailure(
              testKey,
              'smartResponse',
              smartResponseErrorDetails,
              smartResponseLlmResponseText ? (smartResponseLlmResponseText.length > 300 ? smartResponseLlmResponseText.substring(0, 300) + '...' : smartResponseLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] smartResponse validation:', smartResponseErrorDetails);
            // Continue to next validation (soft validation mode)
          }
        } else {
          karate.log('Skipping smartResponse validation (not present in trace data)');
        }

        // 9) Validate getUserInformation with AI Judge (SOFT validation)
        karate.log('Step 9: Validating getUserInformation with AI Judge...');
        var getUserInformationItems = karate.filter(traceData, function(x){ return x.agentName == 'getUserInformation' });
        karate.log('getUserInformation items found:', getUserInformationItems.length);

        if (getUserInformationItems.length > 0) {
          var getUserInformationLlmResponseText = utils.getFirstLLMResponseText(getUserInformationItems);
          var getUserInformationPromptArgumentsObj = utils.getFirstUserInformationPromptArguments(getUserInformationItems);
          var getUserInformationLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getUserInformationItems);

          // Use the actual UserMessage from getUserInformation's prompt arguments
          var getUserInformationUserMessage = utils.getFirstUserPromptOnly(getUserInformationItems);
          karate.log('getUserInformation UserMessage from trace:', getUserInformationUserMessage ? getUserInformationUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('getUserInformation LLM Response:', getUserInformationLlmResponseText ? getUserInformationLlmResponseText.substring(0, 100) + '...' : 'null');

          var getUserInformationEvalArgs = {
            PromptArguments: getUserInformationPromptArgumentsObj,
            LLMRequestFormattedPrompt: getUserInformationLlmRequestFormatedText,
            UserMessage: getUserInformationUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: getUserInformationLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var getUserInformationEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-getuserinformation-evaluator.feature', getUserInformationEvalArgs);
          karate.log('GetUserInformation Evaluator result - pass:', getUserInformationEvalResult && getUserInformationEvalResult.getUserInformationValidationOut ? getUserInformationEvalResult.getUserInformationValidationOut.pass : 'undefined');

          var getUserInformationValidation = getUserInformationEvalResult ? getUserInformationEvalResult.getUserInformationValidationOut : null;
          var getUserInformationPassed = getUserInformationValidation && getUserInformationValidation.pass === true;

          if (!getUserInformationPassed) {
            testHasFailures = true;

            var getUserInformationErrorDetails = '';
            {
              var parsedGetUserInformationContent = getUserInformationEvalResult.getUserInformationEvaluatorResultOut ? getUserInformationEvalResult.getUserInformationEvaluatorResultOut.parsedContent : null;
              getUserInformationErrorDetails = utils.buildReport(getUserInformationValidation, parsedGetUserInformationContent, 'getUserInformation');
            }

            recordAgentFailure(
              testKey,
              'getUserInformation',
              getUserInformationErrorDetails,
              getUserInformationLlmResponseText ? (getUserInformationLlmResponseText.length > 300 ? getUserInformationLlmResponseText.substring(0, 300) + '...' : getUserInformationLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] getUserInformation validation:', getUserInformationErrorDetails);
            // Continue to next validation (soft validation mode)
          }
        } else {
          karate.log('Skipping getUserInformation validation (not present in trace data)');
        }

        // 10) Validate getSpecificQuestionSubIntent with AI Judge (SOFT validation)
        karate.log('Step 10: Validating getSpecificQuestionSubIntent with AI Judge...');
        var getSpecificQuestionSubIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getSpecificQuestionSubIntent' });
        karate.log('getSpecificQuestionSubIntent items found:', getSpecificQuestionSubIntentItems.length);

        if (getSpecificQuestionSubIntentItems.length > 0) {
          var specificQuestionSubIntentLlmResponseText = utils.getFirstLLMResponseText(getSpecificQuestionSubIntentItems);
          var specificQuestionSubIntentPromptArgumentsObj = utils.getFirstSpecificQuestionSubIntentPromptArguments(getSpecificQuestionSubIntentItems);
          var specificQuestionSubIntentLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSpecificQuestionSubIntentItems);

          // Use the actual UserMessage from getSpecificQuestionSubIntent's prompt arguments
          var specificQuestionSubIntentUserMessage = utils.getFirstUserPromptOnly(getSpecificQuestionSubIntentItems);
          karate.log('getSpecificQuestionSubIntent UserMessage from trace:', specificQuestionSubIntentUserMessage ? specificQuestionSubIntentUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('getSpecificQuestionSubIntent LLM Response:', specificQuestionSubIntentLlmResponseText ? specificQuestionSubIntentLlmResponseText.substring(0, 100) + '...' : 'null');

          var specificQuestionSubIntentEvalArgs = {
            PromptArguments: specificQuestionSubIntentPromptArgumentsObj,
            LLMRequestFormattedPrompt: specificQuestionSubIntentLlmRequestFormatedText,
            UserMessage: specificQuestionSubIntentUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: specificQuestionSubIntentLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var specificQuestionSubIntentEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-specificquestionsubintent-evaluator.feature', specificQuestionSubIntentEvalArgs);
          karate.log('SpecificQuestionSubIntent Evaluator result - pass:', specificQuestionSubIntentEvalResult && specificQuestionSubIntentEvalResult.specificQuestionSubIntentValidationOut ? specificQuestionSubIntentEvalResult.specificQuestionSubIntentValidationOut.pass : 'undefined');

          var specificQuestionSubIntentValidation = specificQuestionSubIntentEvalResult ? specificQuestionSubIntentEvalResult.specificQuestionSubIntentValidationOut : null;
          var specificQuestionSubIntentPassed = specificQuestionSubIntentValidation && specificQuestionSubIntentValidation.pass === true;

          if (!specificQuestionSubIntentPassed) {
            testHasFailures = true;

            var specificQuestionSubIntentErrorDetails = '';
            {
              var parsedSpecificQuestionSubIntentContent = specificQuestionSubIntentEvalResult.specificQuestionSubIntentEvaluatorResultOut ? specificQuestionSubIntentEvalResult.specificQuestionSubIntentEvaluatorResultOut.parsedContent : null;
              specificQuestionSubIntentErrorDetails = utils.buildReport(specificQuestionSubIntentValidation, parsedSpecificQuestionSubIntentContent, 'getSpecificQuestionSubIntent');
            }

            recordAgentFailure(
              testKey,
              'getSpecificQuestionSubIntent',
              specificQuestionSubIntentErrorDetails,
              specificQuestionSubIntentLlmResponseText ? (specificQuestionSubIntentLlmResponseText.length > 300 ? specificQuestionSubIntentLlmResponseText.substring(0, 300) + '...' : specificQuestionSubIntentLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] getSpecificQuestionSubIntent validation:', specificQuestionSubIntentErrorDetails);
            // Continue (soft validation mode) - this is the last validation anyway
          }
        } else {
          karate.log('Skipping getSpecificQuestionSubIntent validation (not present in trace data)');
        }

        // 11) Validate getMultiProductQuestionSubIntent with AI Judge (SOFT validation)
        karate.log('Step 11: Validating getMultiProductQuestionSubIntent with AI Judge...');
        var getMultiProductQuestionSubIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getMultiProductQuestionSubIntent' });
        karate.log('getMultiProductQuestionSubIntent items found:', getMultiProductQuestionSubIntentItems.length);

        if (getMultiProductQuestionSubIntentItems.length > 0) {
          var multiProductQuestionSubIntentLlmResponseText = utils.getFirstLLMResponseText(getMultiProductQuestionSubIntentItems);
          var multiProductQuestionSubIntentPromptArgumentsObj = utils.getFirstMultiProductQuestionSubIntentPromptArguments(getMultiProductQuestionSubIntentItems);
          var multiProductQuestionSubIntentLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getMultiProductQuestionSubIntentItems);

          // Use the actual UserMessage from getMultiProductQuestionSubIntent's prompt arguments
          var multiProductQuestionSubIntentUserMessage = utils.getFirstUserPromptOnly(getMultiProductQuestionSubIntentItems);
          karate.log('getMultiProductQuestionSubIntent UserMessage from trace:', multiProductQuestionSubIntentUserMessage ? multiProductQuestionSubIntentUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('getMultiProductQuestionSubIntent LLM Response:', multiProductQuestionSubIntentLlmResponseText ? multiProductQuestionSubIntentLlmResponseText.substring(0, 100) + '...' : 'null');

          var multiProductQuestionSubIntentEvalArgs = {
            PromptArguments: multiProductQuestionSubIntentPromptArgumentsObj,
            LLMRequestFormattedPrompt: multiProductQuestionSubIntentLlmRequestFormatedText,
            UserMessage: multiProductQuestionSubIntentUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: multiProductQuestionSubIntentLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var multiProductQuestionSubIntentEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-multiproductquestionsubintent-evaluator.feature', multiProductQuestionSubIntentEvalArgs);
          karate.log('MultiProductQuestionSubIntent Evaluator result - pass:', multiProductQuestionSubIntentEvalResult && multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentValidationOut ? multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentValidationOut.pass : 'undefined');

          var multiProductQuestionSubIntentValidation = multiProductQuestionSubIntentEvalResult ? multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentValidationOut : null;
          var multiProductQuestionSubIntentPassed = multiProductQuestionSubIntentValidation && multiProductQuestionSubIntentValidation.pass === true;

          if (!multiProductQuestionSubIntentPassed) {
            testHasFailures = true;

            var multiProductQuestionSubIntentErrorDetails = '';
            {
              var parsedMultiProductQuestionSubIntentContent = multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentEvaluatorResultOut ? multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentEvaluatorResultOut.parsedContent : null;
              multiProductQuestionSubIntentErrorDetails = utils.buildReport(multiProductQuestionSubIntentValidation, parsedMultiProductQuestionSubIntentContent, 'getMultiProductQuestionSubIntent');
            }

            recordAgentFailure(
              testKey,
              'getMultiProductQuestionSubIntent',
              multiProductQuestionSubIntentErrorDetails,
              multiProductQuestionSubIntentLlmResponseText ? (multiProductQuestionSubIntentLlmResponseText.length > 300 ? multiProductQuestionSubIntentLlmResponseText.substring(0, 300) + '...' : multiProductQuestionSubIntentLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] getMultiProductQuestionSubIntent validation:', multiProductQuestionSubIntentErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping getMultiProductQuestionSubIntent validation (not present in trace data)');
        }

        // 12) Validate specificProductQuestion with AI Judge (SOFT validation)
        karate.log('Step 12: Validating specificProductQuestion with AI Judge...');
        var getSpecificProductQuestionItems = karate.filter(traceData, function(x){ return x.agentName == 'specificProductQuestion' });
        karate.log('specificProductQuestion items found:', getSpecificProductQuestionItems.length);

        if (getSpecificProductQuestionItems.length > 0) {
          var specificProductQuestionLlmResponseText = utils.getFirstLLMResponseText(getSpecificProductQuestionItems);
          var specificProductQuestionPromptArgumentsObj = utils.getFirstSpecificProductQuestionPromptArguments(getSpecificProductQuestionItems);
          var specificProductQuestionLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSpecificProductQuestionItems);

          // Use the actual UserMessage from specificProductQuestion's prompt arguments
          var specificProductQuestionUserMessage = utils.getFirstUserPromptOnly(getSpecificProductQuestionItems);
          karate.log('specificProductQuestion UserMessage from trace:', specificProductQuestionUserMessage ? specificProductQuestionUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('specificProductQuestion LLM Response:', specificProductQuestionLlmResponseText ? specificProductQuestionLlmResponseText.substring(0, 100) + '...' : 'null');

          var specificProductQuestionEvalArgs = {
            PromptArguments: specificProductQuestionPromptArgumentsObj,
            LLMRequestFormattedPrompt: specificProductQuestionLlmRequestFormatedText,
            UserMessage: specificProductQuestionUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: specificProductQuestionLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var specificProductQuestionEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-specificproductquestion-evaluator.feature', specificProductQuestionEvalArgs);
          karate.log('SpecificProductQuestion Evaluator result - pass:', specificProductQuestionEvalResult && specificProductQuestionEvalResult.specificProductQuestionValidationOut ? specificProductQuestionEvalResult.specificProductQuestionValidationOut.pass : 'undefined');

          var specificProductQuestionValidation = specificProductQuestionEvalResult ? specificProductQuestionEvalResult.specificProductQuestionValidationOut : null;
          var specificProductQuestionPassed = specificProductQuestionValidation && specificProductQuestionValidation.pass === true;

          if (!specificProductQuestionPassed) {
            testHasFailures = true;

            var specificProductQuestionErrorDetails = '';
            {
              var parsedSpecificProductQuestionContent = specificProductQuestionEvalResult.specificProductQuestionEvaluatorResultOut ? specificProductQuestionEvalResult.specificProductQuestionEvaluatorResultOut.parsedContent : null;
              specificProductQuestionErrorDetails = utils.buildReport(specificProductQuestionValidation, parsedSpecificProductQuestionContent, 'specificProductQuestion');
            }

            recordAgentFailure(
              testKey,
              'specificProductQuestion',
              specificProductQuestionErrorDetails,
              specificProductQuestionLlmResponseText ? (specificProductQuestionLlmResponseText.length > 300 ? specificProductQuestionLlmResponseText.substring(0, 300) + '...' : specificProductQuestionLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] specificProductQuestion validation:', specificProductQuestionErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping specificProductQuestion validation (not present in trace data)');
        }

        // 13) Validate searchingByTitle with AI Judge (SOFT validation)
        karate.log('Step 13: Validating searchingByTitle with AI Judge...');
        var getSearchingByTitleItems = karate.filter(traceData, function(x){ return x.agentName == 'searchingByTitle' });
        karate.log('searchingByTitle items found:', getSearchingByTitleItems.length);

        if (getSearchingByTitleItems.length > 0) {
          var searchingByTitleLlmResponseText = utils.getFirstLLMResponseText(getSearchingByTitleItems);
          var searchingByTitlePromptArgumentsObj = utils.getFirstSearchingByTitlePromptArguments(getSearchingByTitleItems);
          var searchingByTitleLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSearchingByTitleItems);

          // Use the actual UserMessage from searchingByTitle's prompt arguments
          var searchingByTitleUserMessage = utils.getFirstUserPromptOnly(getSearchingByTitleItems);
          karate.log('searchingByTitle UserMessage from trace:', searchingByTitleUserMessage ? searchingByTitleUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('searchingByTitle LLM Response:', searchingByTitleLlmResponseText ? searchingByTitleLlmResponseText.substring(0, 100) + '...' : 'null');

          var searchingByTitleEvalArgs = {
            PromptArguments: searchingByTitlePromptArgumentsObj,
            LLMRequestFormattedPrompt: searchingByTitleLlmRequestFormatedText,
            UserMessage: searchingByTitleUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: searchingByTitleLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var searchingByTitleEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-searchingbytitle-evaluator.feature', searchingByTitleEvalArgs);
          karate.log('SearchingByTitle Evaluator result - pass:', searchingByTitleEvalResult && searchingByTitleEvalResult.searchingByTitleValidationOut ? searchingByTitleEvalResult.searchingByTitleValidationOut.pass : 'undefined');

          var searchingByTitleValidation = searchingByTitleEvalResult ? searchingByTitleEvalResult.searchingByTitleValidationOut : null;
          var searchingByTitlePassed = searchingByTitleValidation && searchingByTitleValidation.pass === true;

          if (!searchingByTitlePassed) {
            testHasFailures = true;

            var searchingByTitleErrorDetails = '';
            {
              var parsedSearchingByTitleContent = searchingByTitleEvalResult.searchingByTitleEvaluatorResultOut ? searchingByTitleEvalResult.searchingByTitleEvaluatorResultOut.parsedContent : null;
              searchingByTitleErrorDetails = utils.buildReport(searchingByTitleValidation, parsedSearchingByTitleContent, 'searchingByTitle');
            }

            recordAgentFailure(
              testKey,
              'searchingByTitle',
              searchingByTitleErrorDetails,
              searchingByTitleLlmResponseText ? (searchingByTitleLlmResponseText.length > 300 ? searchingByTitleLlmResponseText.substring(0, 300) + '...' : searchingByTitleLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] searchingByTitle validation:', searchingByTitleErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping searchingByTitle validation (not present in trace data)');
        }

        // 14) Validate specificProductQuestionResponse with AI Judge (SOFT validation)
        karate.log('Step 14: Validating specificProductQuestionResponse with AI Judge...');
        var getSpecificProductQuestionResponseItems = karate.filter(traceData, function(x){ return x.agentName == 'specificProductQuestionResponse' });
        karate.log('specificProductQuestionResponse items found:', getSpecificProductQuestionResponseItems.length);

        if (getSpecificProductQuestionResponseItems.length > 0) {
          var specificProductQuestionResponseLlmResponseText = utils.getFirstLLMResponseText(getSpecificProductQuestionResponseItems);
          var specificProductQuestionResponsePromptArgumentsObj = utils.getFirstSpecificProductQuestionResponsePromptArguments(getSpecificProductQuestionResponseItems);
          var specificProductQuestionResponseLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSpecificProductQuestionResponseItems);

          // Use the actual UserMessage from specificProductQuestionResponse's prompt arguments
          var specificProductQuestionResponseUserMessage = utils.getFirstUserPromptOnly(getSpecificProductQuestionResponseItems);
          karate.log('specificProductQuestionResponse UserMessage from trace:', specificProductQuestionResponseUserMessage ? specificProductQuestionResponseUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('specificProductQuestionResponse LLM Response:', specificProductQuestionResponseLlmResponseText ? specificProductQuestionResponseLlmResponseText.substring(0, 100) + '...' : 'null');

          var specificProductQuestionResponseEvalArgs = {
            PromptArguments: specificProductQuestionResponsePromptArgumentsObj,
            LLMRequestFormattedPrompt: specificProductQuestionResponseLlmRequestFormatedText,
            UserMessage: specificProductQuestionResponseUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: specificProductQuestionResponseLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var specificProductQuestionResponseEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-specificproductquestionresponse-evaluator.feature', specificProductQuestionResponseEvalArgs);
          karate.log('SpecificProductQuestionResponse Evaluator result - pass:', specificProductQuestionResponseEvalResult && specificProductQuestionResponseEvalResult.specificProductQuestionResponseValidationOut ? specificProductQuestionResponseEvalResult.specificProductQuestionResponseValidationOut.pass : 'undefined');

          var specificProductQuestionResponseValidation = specificProductQuestionResponseEvalResult ? specificProductQuestionResponseEvalResult.specificProductQuestionResponseValidationOut : null;
          var specificProductQuestionResponsePassed = specificProductQuestionResponseValidation && specificProductQuestionResponseValidation.pass === true;

          if (!specificProductQuestionResponsePassed) {
            testHasFailures = true;

            var specificProductQuestionResponseErrorDetails = '';
            {
              var parsedSpecificProductQuestionResponseContent = specificProductQuestionResponseEvalResult.specificProductQuestionResponseEvaluatorResultOut ? specificProductQuestionResponseEvalResult.specificProductQuestionResponseEvaluatorResultOut.parsedContent : null;
              specificProductQuestionResponseErrorDetails = utils.buildReport(specificProductQuestionResponseValidation, parsedSpecificProductQuestionResponseContent, 'specificProductQuestionResponse');
            }

            recordAgentFailure(
              testKey,
              'specificProductQuestionResponse',
              specificProductQuestionResponseErrorDetails,
              specificProductQuestionResponseLlmResponseText ? (specificProductQuestionResponseLlmResponseText.length > 300 ? specificProductQuestionResponseLlmResponseText.substring(0, 300) + '...' : specificProductQuestionResponseLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] specificProductQuestionResponse validation:', specificProductQuestionResponseErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping specificProductQuestionResponse validation (not present in trace data)');
        }

        // 15) Validate specificProductSizeRecommendation with AI Judge (SOFT validation)
        karate.log('Step 15: Validating specificProductSizeRecommendation with AI Judge...');
        // Debug: log all agent names to help identify the correct name
        if (traceData && traceData.length > 0) {
          var allAgentNames = [];
          for (var i = 0; i < traceData.length; i++) {
            var name = traceData[i].agentName || 'undefined';
            if (allAgentNames.indexOf(name) === -1) allAgentNames.push(name);
          }
          karate.log('DEBUG Step 15 - All unique agent names in trace data:', JSON.stringify(allAgentNames));
          // Also check for partial matches
          var sizeRelated = karate.filter(traceData, function(x){
            return x.agentName && (x.agentName.toLowerCase().indexOf('size') >= 0 || x.agentName.toLowerCase().indexOf('recommendation') >= 0);
          });
          karate.log('DEBUG Step 15 - Agents containing "size" or "recommendation":', sizeRelated.length);
          if (sizeRelated.length > 0) {
            for (var j = 0; j < sizeRelated.length; j++) {
              karate.log('DEBUG Step 15 - Size-related agent found: "' + sizeRelated[j].agentName + '"');
            }
          }
        }
        var getSpecificProductSizeRecommendationItems = karate.filter(traceData, function(x){ return x.agentName == 'specificProductSizeRecommendation' });
        karate.log('specificProductSizeRecommendation items found:', getSpecificProductSizeRecommendationItems.length);

        if (getSpecificProductSizeRecommendationItems.length > 0) {
          var specificProductSizeRecommendationLlmResponseText = utils.getFirstLLMResponseText(getSpecificProductSizeRecommendationItems);
          var specificProductSizeRecommendationPromptArgumentsObj = utils.getFirstSpecificProductSizeRecommendationPromptArguments(getSpecificProductSizeRecommendationItems);
          var specificProductSizeRecommendationLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSpecificProductSizeRecommendationItems);

          // Use the actual UserMessage from specificProductSizeRecommendation's prompt arguments
          var specificProductSizeRecommendationUserMessage = utils.getFirstUserPromptOnly(getSpecificProductSizeRecommendationItems);
          karate.log('specificProductSizeRecommendation UserMessage from trace:', specificProductSizeRecommendationUserMessage ? specificProductSizeRecommendationUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('specificProductSizeRecommendation LLM Response:', specificProductSizeRecommendationLlmResponseText ? specificProductSizeRecommendationLlmResponseText.substring(0, 100) + '...' : 'null');

          var specificProductSizeRecommendationEvalArgs = {
            PromptArguments: specificProductSizeRecommendationPromptArgumentsObj,
            LLMRequestFormattedPrompt: specificProductSizeRecommendationLlmRequestFormatedText,
            UserMessage: specificProductSizeRecommendationUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: specificProductSizeRecommendationLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var specificProductSizeRecommendationEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-specificproductsizerecommendation-evaluator.feature', specificProductSizeRecommendationEvalArgs);
          karate.log('SpecificProductSizeRecommendation Evaluator result - pass:', specificProductSizeRecommendationEvalResult && specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationValidationOut ? specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationValidationOut.pass : 'undefined');

          var specificProductSizeRecommendationValidation = specificProductSizeRecommendationEvalResult ? specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationValidationOut : null;
          var specificProductSizeRecommendationPassed = specificProductSizeRecommendationValidation && specificProductSizeRecommendationValidation.pass === true;

          if (!specificProductSizeRecommendationPassed) {
            testHasFailures = true;

            var specificProductSizeRecommendationErrorDetails = '';
            {
              var parsedSpecificProductSizeRecommendationContent = specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationEvaluatorResultOut ? specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationEvaluatorResultOut.parsedContent : null;
              specificProductSizeRecommendationErrorDetails = utils.buildReport(specificProductSizeRecommendationValidation, parsedSpecificProductSizeRecommendationContent, 'specificProductSizeRecommendation');
            }

            recordAgentFailure(
              testKey,
              'specificProductSizeRecommendation',
              specificProductSizeRecommendationErrorDetails,
              specificProductSizeRecommendationLlmResponseText ? (specificProductSizeRecommendationLlmResponseText.length > 300 ? specificProductSizeRecommendationLlmResponseText.substring(0, 300) + '...' : specificProductSizeRecommendationLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] specificProductSizeRecommendation validation:', specificProductSizeRecommendationErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping specificProductSizeRecommendation validation (not present in trace data)');
        }

        // 16) Validate similarBaseProduct with AI Judge (SOFT validation)
        karate.log('Step 16: Validating similarBaseProduct with AI Judge...');
        var getSimilarBaseProductItems = karate.filter(traceData, function(x){ return x.agentName == 'similarBaseProduct' });
        karate.log('similarBaseProduct items found:', getSimilarBaseProductItems.length);

        if (getSimilarBaseProductItems.length > 0) {
          var similarBaseProductLlmResponseText = utils.getFirstLLMResponseText(getSimilarBaseProductItems);
          var similarBaseProductPromptArgumentsObj = utils.getFirstSimilarBaseProductPromptArguments(getSimilarBaseProductItems);
          var similarBaseProductLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getSimilarBaseProductItems);

          // Use the actual UserMessage from similarBaseProduct's prompt arguments
          var similarBaseProductUserMessage = utils.getFirstUserPromptOnly(getSimilarBaseProductItems);
          karate.log('similarBaseProduct UserMessage from trace:', similarBaseProductUserMessage ? similarBaseProductUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('similarBaseProduct LLM Response:', similarBaseProductLlmResponseText ? similarBaseProductLlmResponseText.substring(0, 100) + '...' : 'null');

          var similarBaseProductEvalArgs = {
            PromptArguments: similarBaseProductPromptArgumentsObj,
            LLMRequestFormattedPrompt: similarBaseProductLlmRequestFormatedText,
            UserMessage: similarBaseProductUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: similarBaseProductLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var similarBaseProductEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-similarbaseproduct-evaluator.feature', similarBaseProductEvalArgs);
          karate.log('SimilarBaseProduct Evaluator result - pass:', similarBaseProductEvalResult && similarBaseProductEvalResult.similarBaseProductValidationOut ? similarBaseProductEvalResult.similarBaseProductValidationOut.pass : 'undefined');

          var similarBaseProductValidation = similarBaseProductEvalResult ? similarBaseProductEvalResult.similarBaseProductValidationOut : null;
          var similarBaseProductPassed = similarBaseProductValidation && similarBaseProductValidation.pass === true;

          if (!similarBaseProductPassed) {
            testHasFailures = true;

            var similarBaseProductErrorDetails = '';
            {
              var parsedSimilarBaseProductContent = similarBaseProductEvalResult.similarBaseProductEvaluatorResultOut ? similarBaseProductEvalResult.similarBaseProductEvaluatorResultOut.parsedContent : null;
              similarBaseProductErrorDetails = utils.buildReport(similarBaseProductValidation, parsedSimilarBaseProductContent, 'similarBaseProduct');
            }

            recordAgentFailure(
              testKey,
              'similarBaseProduct',
              similarBaseProductErrorDetails,
              similarBaseProductLlmResponseText ? (similarBaseProductLlmResponseText.length > 300 ? similarBaseProductLlmResponseText.substring(0, 300) + '...' : similarBaseProductLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] similarBaseProduct validation:', similarBaseProductErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping similarBaseProduct validation (not present in trace data)');
        }

        // 17) Validate productCompareResponse with AI Judge (SOFT validation)
        karate.log('Step 17: Validating productCompareResponse with AI Judge...');
        var getProductCompareResponseItems = karate.filter(traceData, function(x){ return x.agentName == 'productCompareResponse' });
        karate.log('productCompareResponse items found:', getProductCompareResponseItems.length);

        if (getProductCompareResponseItems.length > 0) {
          var productCompareResponseLlmResponseText = utils.getFirstLLMResponseText(getProductCompareResponseItems);
          var productCompareResponsePromptArgumentsObj = utils.getFirstProductCompareResponsePromptArguments(getProductCompareResponseItems);
          var productCompareResponseLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getProductCompareResponseItems);

          // Use the actual UserMessage from productCompareResponse's prompt arguments
          var productCompareResponseUserMessage = utils.getFirstUserPromptOnly(getProductCompareResponseItems);
          karate.log('productCompareResponse UserMessage from trace:', productCompareResponseUserMessage ? productCompareResponseUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('productCompareResponse LLM Response:', productCompareResponseLlmResponseText ? productCompareResponseLlmResponseText.substring(0, 100) + '...' : 'null');

          var productCompareResponseEvalArgs = {
            PromptArguments: productCompareResponsePromptArgumentsObj,
            LLMRequestFormattedPrompt: productCompareResponseLlmRequestFormatedText,
            UserMessage: productCompareResponseUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: productCompareResponseLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var productCompareResponseEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-productcompareresponse-evaluator.feature', productCompareResponseEvalArgs);
          karate.log('ProductCompareResponse Evaluator result - pass:', productCompareResponseEvalResult && productCompareResponseEvalResult.productCompareResponseValidationOut ? productCompareResponseEvalResult.productCompareResponseValidationOut.pass : 'undefined');

          var productCompareResponseValidation = productCompareResponseEvalResult ? productCompareResponseEvalResult.productCompareResponseValidationOut : null;
          var productCompareResponsePassed = productCompareResponseValidation && productCompareResponseValidation.pass === true;

          if (!productCompareResponsePassed) {
            testHasFailures = true;

            var productCompareResponseErrorDetails = '';
            {
              var parsedProductCompareResponseContent = productCompareResponseEvalResult.productCompareResponseEvaluatorResultOut ? productCompareResponseEvalResult.productCompareResponseEvaluatorResultOut.parsedContent : null;
              productCompareResponseErrorDetails = utils.buildReport(productCompareResponseValidation, parsedProductCompareResponseContent, 'productCompareResponse');
            }

            recordAgentFailure(
              testKey,
              'productCompareResponse',
              productCompareResponseErrorDetails,
              productCompareResponseLlmResponseText ? (productCompareResponseLlmResponseText.length > 300 ? productCompareResponseLlmResponseText.substring(0, 300) + '...' : productCompareResponseLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] productCompareResponse validation:', productCompareResponseErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping productCompareResponse validation (not present in trace data)');
        }

        // 18) Validate findBaseProduct with AI Judge (SOFT validation)
        karate.log('Step 18: Validating findBaseProduct with AI Judge...');
        var getFindBaseProductItems = karate.filter(traceData, function(x){ return x.agentName == 'findBaseProduct' });
        karate.log('findBaseProduct items found:', getFindBaseProductItems.length);

        if (getFindBaseProductItems.length > 0) {
          var findBaseProductLlmResponseText = utils.getFirstLLMResponseText(getFindBaseProductItems);
          var findBaseProductPromptArgumentsObj = utils.getFirstFindBaseProductPromptArguments(getFindBaseProductItems);
          var findBaseProductLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getFindBaseProductItems);

          // Use the actual UserMessage from findBaseProduct's prompt arguments
          var findBaseProductUserMessage = utils.getFirstUserPromptOnly(getFindBaseProductItems);
          karate.log('findBaseProduct UserMessage from trace:', findBaseProductUserMessage ? findBaseProductUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('findBaseProduct LLM Response:', findBaseProductLlmResponseText ? findBaseProductLlmResponseText.substring(0, 100) + '...' : 'null');

          var findBaseProductEvalArgs = {
            PromptArguments: findBaseProductPromptArgumentsObj,
            LLMRequestFormattedPrompt: findBaseProductLlmRequestFormatedText,
            UserMessage: findBaseProductUserMessage || content,  // Fallback to content if userPrompt not found
            ResponseLLM: findBaseProductLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var findBaseProductEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-findbaseproduct-evaluator.feature', findBaseProductEvalArgs);
          karate.log('FindBaseProduct Evaluator result - pass:', findBaseProductEvalResult && findBaseProductEvalResult.findBaseProductValidationOut ? findBaseProductEvalResult.findBaseProductValidationOut.pass : 'undefined');

          var findBaseProductValidation = findBaseProductEvalResult ? findBaseProductEvalResult.findBaseProductValidationOut : null;
          var findBaseProductPassed = findBaseProductValidation && findBaseProductValidation.pass === true;

          if (!findBaseProductPassed) {
            testHasFailures = true;

            var findBaseProductErrorDetails = '';
            {
              var parsedFindBaseProductContent = findBaseProductEvalResult.findBaseProductEvaluatorResultOut ? findBaseProductEvalResult.findBaseProductEvaluatorResultOut.parsedContent : null;
              findBaseProductErrorDetails = utils.buildReport(findBaseProductValidation, parsedFindBaseProductContent, 'findBaseProduct');
            }

            recordAgentFailure(
              testKey,
              'findBaseProduct',
              findBaseProductErrorDetails,
              findBaseProductLlmResponseText ? (findBaseProductLlmResponseText.length > 300 ? findBaseProductLlmResponseText.substring(0, 300) + '...' : findBaseProductLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] findBaseProduct validation:', findBaseProductErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping findBaseProduct validation (not present in trace data)');
        }

        // 19) Validate findProductsToBundle with AI Judge (SOFT validation)
        karate.log('Step 19: Validating findProductsToBundle with AI Judge...');
        var getFindProductsToBundleItems = karate.filter(traceData, function(x){ return x.agentName == 'findProductsToBundle' });
        karate.log('findProductsToBundle items found:', getFindProductsToBundleItems.length);

        if (getFindProductsToBundleItems.length > 0) {
          var findProductsToBundleLlmResponseText = utils.getFirstLLMResponseText(getFindProductsToBundleItems);
          var findProductsToBundlePromptArgumentsObj = utils.getFirstFindProductsToBundlePromptArguments(getFindProductsToBundleItems);
          var findProductsToBundleLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getFindProductsToBundleItems);

          var findProductsToBundleUserMessage = utils.getFirstUserPromptOnly(getFindProductsToBundleItems);
          karate.log('findProductsToBundle UserMessage from trace:', findProductsToBundleUserMessage ? findProductsToBundleUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('findProductsToBundle LLM Response:', findProductsToBundleLlmResponseText ? findProductsToBundleLlmResponseText.substring(0, 100) + '...' : 'null');

          var findProductsToBundleEvalArgs = {
            PromptArguments: findProductsToBundlePromptArgumentsObj,
            LLMRequestFormattedPrompt: findProductsToBundleLlmRequestFormatedText,
            UserMessage: findProductsToBundleUserMessage || content,
            ResponseLLM: findProductsToBundleLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var findProductsToBundleEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-findproductstobundle-evaluator.feature', findProductsToBundleEvalArgs);
          karate.log('FindProductsToBundle Evaluator result - pass:', findProductsToBundleEvalResult && findProductsToBundleEvalResult.findProductsToBundleValidationOut ? findProductsToBundleEvalResult.findProductsToBundleValidationOut.pass : 'undefined');

          var findProductsToBundleValidation = findProductsToBundleEvalResult ? findProductsToBundleEvalResult.findProductsToBundleValidationOut : null;
          var findProductsToBundlePassed = findProductsToBundleValidation && findProductsToBundleValidation.pass === true;

          if (!findProductsToBundlePassed) {
            testHasFailures = true;

            var findProductsToBundleErrorDetails = '';
            {
              var parsedFindProductsToBundleContent = findProductsToBundleEvalResult.findProductsToBundleEvaluatorResultOut ? findProductsToBundleEvalResult.findProductsToBundleEvaluatorResultOut.parsedContent : null;
              findProductsToBundleErrorDetails = utils.buildReport(findProductsToBundleValidation, parsedFindProductsToBundleContent, 'findProductsToBundle');
            }

            recordAgentFailure(
              testKey,
              'findProductsToBundle',
              findProductsToBundleErrorDetails,
              findProductsToBundleLlmResponseText ? (findProductsToBundleLlmResponseText.length > 300 ? findProductsToBundleLlmResponseText.substring(0, 300) + '...' : findProductsToBundleLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] findProductsToBundle validation:', findProductsToBundleErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping findProductsToBundle validation (not present in trace data)');
        }

        // 20) Validate generalConversation with AI Judge (SOFT validation)
        karate.log('Step 20: Validating generalConversation with AI Judge...');
        var getGeneralConversationItems = karate.filter(traceData, function(x){ return x.agentName == 'generalConversation' });
        karate.log('generalConversation items found:', getGeneralConversationItems.length);

        if (getGeneralConversationItems.length > 0) {
          var generalConversationLlmResponseText = utils.getFirstLLMResponseText(getGeneralConversationItems);
          var generalConversationPromptArgumentsObj = utils.getFirstGeneralConversationPromptArguments(getGeneralConversationItems);
          var generalConversationLlmRequestFormatedText = utils.getFirstLLMRequestFormatedText(getGeneralConversationItems);

          var generalConversationUserMessage = utils.getFirstUserPromptOnly(getGeneralConversationItems);
          karate.log('generalConversation UserMessage from trace:', generalConversationUserMessage ? generalConversationUserMessage.substring(0, 100) + '...' : 'null');
          karate.log('generalConversation LLM Response:', generalConversationLlmResponseText ? generalConversationLlmResponseText.substring(0, 100) + '...' : 'null');

          var generalConversationEvalArgs = {
            PromptArguments: generalConversationPromptArgumentsObj,
            LLMRequestFormattedPrompt: generalConversationLlmRequestFormatedText,
            UserMessage: generalConversationUserMessage || content,
            ResponseLLM: generalConversationLlmResponseText,
            tenantId: tenantId,
            content: content
          };

          var generalConversationEvalResult = karate.call('classpath:com/preezie/llm/helpers/run-generalconversation-evaluator.feature', generalConversationEvalArgs);
          karate.log('GeneralConversation Evaluator result - pass:', generalConversationEvalResult && generalConversationEvalResult.generalConversationValidationOut ? generalConversationEvalResult.generalConversationValidationOut.pass : 'undefined');

          var generalConversationValidation = generalConversationEvalResult ? generalConversationEvalResult.generalConversationValidationOut : null;
          var generalConversationPassed = generalConversationValidation && generalConversationValidation.pass === true;

          if (!generalConversationPassed) {
            testHasFailures = true;

            var generalConversationErrorDetails = '';
            {
              var parsedGeneralConversationContent = generalConversationEvalResult.generalConversationEvaluatorResultOut ? generalConversationEvalResult.generalConversationEvaluatorResultOut.parsedContent : null;
              generalConversationErrorDetails = utils.buildReport(generalConversationValidation, parsedGeneralConversationContent, 'generalConversation');
            }

            recordAgentFailure(
              testKey,
              'generalConversation',
              generalConversationErrorDetails,
              generalConversationLlmResponseText ? (generalConversationLlmResponseText.length > 300 ? generalConversationLlmResponseText.substring(0, 300) + '...' : generalConversationLlmResponseText) : ''
            );
            karate.log('[SOFT FAIL] generalConversation validation:', generalConversationErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping generalConversation validation (not present in trace data)');
        }

        if (testHasFailures) {
          results.failed++;
          karate.log('[FAILED] Test had one or more validation failures for:', content);
        } else {
          results.passed++;
          karate.log('[PASSED] All validations passed for:', content);
        }

      } catch (e) {
        results.failed++;
        var exceptionKey = content + '||' + (traceId || 'EXCEPTION');
        recordAgentFailure(exceptionKey, 'Exception', e.message || String(e), '');
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
  * karate.log('Pass Rate:', Math.round((results.passed / allTestData.length) + '%'))
  * karate.log('============================================')

  # Print failed tests details - GROUPED BY MESSAGE/TRACEID
  * eval
    """
    var failureKeys = Object.keys(results.testFailures);
    if (failureKeys.length > 0) {
      karate.log('');
      karate.log('================== FAILED TESTS DETAILS (GROUPED) ==================');

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
        karate.log('List of agents failed: ' + testFailure.agentFailures.length);
        karate.log('──────────────────────────────────────────────────────────');

        for (var j = 0; j < testFailure.agentFailures.length; j++) {
          var agentFailure = testFailure.agentFailures[j];
          karate.log('');
          karate.log('  ' + (j + 1) + '. ' + agentFailure.agent + ':');

          if (agentFailure.expected !== undefined) {
            karate.log('     Expected: ' + agentFailure.expected);
            karate.log('     Actual:   ' + agentFailure.actual);
          }

          if (agentFailure.error) {
            karate.log('     ── Details ──────────────────────────────');
            var errorLines = agentFailure.error.split('\\n');
            for (var k = 0; k < errorLines.length; k++) {
              karate.log('     ' + errorLines[k]);
            }
            karate.log('     ─────────────────────────────────────────');
          }

          if (agentFailure.responseLLM && agentFailure.responseLLM.length > 0) {
            karate.log('     LLM Response: ' + agentFailure.responseLLM);
          }
        }
      }
      karate.log('');
      karate.log('═══════════════════════════════════════════════════════════════════');
    }
    """

  # Store results for external access (by test runner for Google Sheets export)
  * def testResults = { totalTests: allTestData.length, passed: results.passed, failed: results.failed, testFailures: results.testFailures, spreadsheetId: spreadsheetId }
  * karate.set('testResultsForExport', testResults)

  # Write results to JSON file for the test runner to read
  * eval
    """
    try {
      var FileWriter = Java.type('java.io.FileWriter');
      var projectDir = java.lang.System.getProperty('user.dir');
      var filePath = projectDir + '/target/test-results.json';

      // Convert testFailures object to array of failures
      var failuresArray = [];
      var failureKeys = Object.keys(results.testFailures);
      for (var i = 0; i < failureKeys.length; i++) {
        var testFailure = results.testFailures[failureKeys[i]];
        failuresArray.push({
          tenantId: testFailure.tenantId || '',
          tenantName: testFailure.tenant || 'Unknown',
          content: testFailure.content || '',
          traceId: testFailure.traceId || 'N/A',
          agentsFailed: testFailure.agentFailures.map(function(af) {
            return {
              agent: af.agent,
              error: af.error || '',
              expected: af.expected !== undefined ? String(af.expected) : '',
              actual: af.actual !== undefined ? String(af.actual) : '',
              responseLLM: af.responseLLM || ''
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


      var writer = new FileWriter(filePath);
      writer.write(JSON.stringify(jsonResults, null, 2));
      writer.close();
      karate.log('Test results written to:', filePath);
    } catch (e) {
      karate.log('Warning: Could not write test results file:', e.message || e);
    }
    """

  # Build failure message for assertion
  * def failureMessage = results.failed > 0 ? results.failed + ' test(s) failed. Check logs above for details.' : 'All tests passed'
  * print failureMessage

  # Fail the scenario if any tests failed
  * if (results.failed > 0) karate.fail(failureMessage)
