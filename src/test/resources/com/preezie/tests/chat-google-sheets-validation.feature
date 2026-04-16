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
  * def baseUrl = 'https://dev-greenback-app-chat.azurewebsites.net'
  * def cmsBase = 'https://dev-greenback-app-cms-gateway.azurewebsites.net'
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def sheetsReader = read('classpath:com/preezie/services/utils/google-sheets-reader.js')
  * def spreadsheetId = karate.get('googleSheetsId') || '1FV7pekpUKZ34VjDXuoslernJuGnx3jsjxJI5WkYsHVM'
  * def authToken = karate.get('cmsIdToken')

Scenario: Run all enabled tests from Google Sheets
  # Validate CMS authentication token is available
  * if (!authToken) karate.fail('CMS authentication token (cmsIdToken) is not configured. Please set FIREBASE_API_KEY, FIREBASE_EMAIL, and FIREBASE_PASSWORD environment variables.')

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
      var sessionId = testCase.sessionId || null;
      var visitorId = testCase.visitorId || null;
      var results = karate.get('results');

      karate.log('');
      karate.log('========================================');
      karate.log('Testing:', content);
      karate.log('Tenant:', tenantName, '(' + tenantId + ')');
      karate.log('Expected Safe:', expectedSafe);
      karate.log('SessionId:', sessionId);
      karate.log('VisitorId:', visitorId);
      karate.log('========================================');

      var traceId = null;

      // Track validation failures for this test case (soft validation)
      var testHasFailures = false;

      try {
        // 1) Get TraceId from Chat API
        karate.log('Step 1: Getting TraceId from Chat API...');
        var chat = karate.call('classpath:com/preezie/services/chat/get-trace-id.feature', {
          content: content,
          tenantId: tenantId,
          sessionId: sessionId,
          visitorId: visitorId
        });

        if (!chat.traceId) {
          testHasFailures = true;
          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: 'N/A',
            stage: 'Chat API',
            error: 'No traceId returned'
          });
          karate.log('[FAILED] No traceId returned');
          // Cannot continue without traceId - this is a hard failure
          results.failed++;
          return;
        }
        traceId = chat.traceId;
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
        if (traceData && traceData.length > 0) {
          var agentNames = karate.map(traceData, function(x){ return x.agentName });
          karate.log('All agent names in trace:', JSON.stringify(agentNames));
        }

        // 3) Validate promptGlobalFilter.Safe (HARD validation - stops if failed)
        karate.log('Step 3: Validating promptGlobalFilter.Safe...');
        var pgf = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', {
          data: traceData,
          agentName: 'promptGlobalFilter',
          key: 'Safe'
        });
        karate.log('promptGlobalFilter.Safe - Expected:', expectedSafe, 'Actual:', pgf.value);

        if (pgf.value !== expectedSafe) {
          testHasFailures = true;
          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: traceId,
            stage: 'promptGlobalFilter',
            expected: expectedSafe,
            actual: pgf.value
          });
          karate.log('[FAILED] promptGlobalFilter - Expected:', expectedSafe, 'Actual:', pgf.value);
          // promptGlobalFilter is a hard validation - if Safe doesn't match, stop
          results.failed++;
          return;
        }

        // ======================================================================
        // AI JUDGE SOFT VALIDATIONS - Continue even on failure
        // ======================================================================

        // 4) Validate getIntentSummary with LLM evaluator (SOFT validation)
        karate.log('Step 4: Validating getIntentSummary with LLM evaluator...');
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
            if (validation.scores) {
              errorDetails += 'Scores: relevance=' + (validation.scores.relevance || 'N/A') +
                ', faithfulness=' + (validation.scores.faithfulness || 'N/A') +
                ', instructionCompliance=' + (validation.scores.instructionCompliance || 'N/A') +
                ', semanticCloseness=' + (validation.scores.semanticCloseness || 'N/A') + '. ';
            }
            if (validation.issues && validation.issues.length > 0) {
              errorDetails += 'Issues: ' + validation.issues.join('; ') + '. ';
            }
            if (validation.summary) {
              errorDetails += 'Summary: ' + validation.summary;
            }
          } else {
            errorDetails = 'LLM evaluation failed or returned no validation';
          }

          results.errors.push({
            tenant: tenantName,
            tenantId: tenantId,
            content: content,
            traceId: traceId,
            stage: 'getIntentSummary',
            error: errorDetails,
            responseLLM: llmResponseText ? (llmResponseText.length > 300 ? llmResponseText.substring(0, 300) + '...' : llmResponseText) : ''
          });
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
            if (intentValidation) {
              if (intentValidation.scores) {
                intentErrorDetails += 'Scores: relevance=' + (intentValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (intentValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (intentValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (intentValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include classified intent info from AI
              var parsedContent = intentEvalResult.intentEvaluatorResultOut ? intentEvalResult.intentEvaluatorResultOut.parsedContent : null;
              if (parsedContent) {
                if (parsedContent.classifiedIntent) {
                  intentErrorDetails += 'Classified Intent: ' + parsedContent.classifiedIntent + '. ';
                }
                if (parsedContent.expectedIntentCategory) {
                  intentErrorDetails += 'Expected Category: ' + parsedContent.expectedIntentCategory + '. ';
                }
              }
              if (intentValidation.issues && intentValidation.issues.length > 0) {
                intentErrorDetails += 'Issues: ' + intentValidation.issues.join('; ') + '. ';
              }
              if (intentValidation.summary) {
                intentErrorDetails += 'Summary: ' + intentValidation.summary;
              }
            } else {
              intentErrorDetails = 'Intent LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'getIntent',
              error: intentErrorDetails,
              responseLLM: intentLlmResponseText ? (intentLlmResponseText.length > 300 ? intentLlmResponseText.substring(0, 300) + '...' : intentLlmResponseText) : ''
            });
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
            if (categoriesValidation) {
              if (categoriesValidation.scores) {
                categoriesErrorDetails += 'Scores: relevance=' + (categoriesValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (categoriesValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (categoriesValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (categoriesValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include classified categories info from AI
              var parsedCategoriesContent = categoriesEvalResult.categoriesEvaluatorResultOut ? categoriesEvalResult.categoriesEvaluatorResultOut.parsedContent : null;
              if (parsedCategoriesContent) {
                if (parsedCategoriesContent.classifiedCategories) {
                  categoriesErrorDetails += 'Classified Categories: ' + parsedCategoriesContent.classifiedCategories + '. ';
                }
                if (parsedCategoriesContent.expectedCategories) {
                  categoriesErrorDetails += 'Expected Categories: ' + parsedCategoriesContent.expectedCategories + '. ';
                }
              }
              if (categoriesValidation.issues && categoriesValidation.issues.length > 0) {
                categoriesErrorDetails += 'Issues: ' + categoriesValidation.issues.join('; ') + '. ';
              }
              if (categoriesValidation.summary) {
                categoriesErrorDetails += 'Summary: ' + categoriesValidation.summary;
              }
            } else {
              categoriesErrorDetails = 'Categories LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'getCategories',
              error: categoriesErrorDetails,
              responseLLM: categoriesLlmResponseText ? (categoriesLlmResponseText.length > 300 ? categoriesLlmResponseText.substring(0, 300) + '...' : categoriesLlmResponseText) : ''
            });
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
            if (findProductValidation) {
              if (findProductValidation.scores) {
                findProductErrorDetails += 'Scores: relevance=' + (findProductValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (findProductValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (findProductValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (findProductValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include extracted query info from AI
              var parsedFindProductContent = findProductEvalResult.findProductEvaluatorResultOut ? findProductEvalResult.findProductEvaluatorResultOut.parsedContent : null;
              if (parsedFindProductContent) {
                if (parsedFindProductContent.extractedQuery) {
                  findProductErrorDetails += 'Extracted Query: ' + parsedFindProductContent.extractedQuery + '. ';
                }
                if (parsedFindProductContent.expectedQuery) {
                  findProductErrorDetails += 'Expected Query: ' + parsedFindProductContent.expectedQuery + '. ';
                }
              }
              if (findProductValidation.issues && findProductValidation.issues.length > 0) {
                findProductErrorDetails += 'Issues: ' + findProductValidation.issues.join('; ') + '. ';
              }
              if (findProductValidation.summary) {
                findProductErrorDetails += 'Summary: ' + findProductValidation.summary;
              }
            } else {
              findProductErrorDetails = 'FindProduct LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'findProductFromPrompt',
              error: findProductErrorDetails,
              responseLLM: findProductLlmResponseText ? (findProductLlmResponseText.length > 300 ? findProductLlmResponseText.substring(0, 300) + '...' : findProductLlmResponseText) : ''
            });
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
            if (smartResponseValidation) {
              if (smartResponseValidation.scores) {
                smartResponseErrorDetails += 'Scores: relevance=' + (smartResponseValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (smartResponseValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (smartResponseValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (smartResponseValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include response type and products referenced from AI
              var parsedSmartResponseContent = smartResponseEvalResult.smartResponseEvaluatorResultOut ? smartResponseEvalResult.smartResponseEvaluatorResultOut.parsedContent : null;
              if (parsedSmartResponseContent) {
                if (parsedSmartResponseContent.responseType) {
                  smartResponseErrorDetails += 'Response Type: ' + parsedSmartResponseContent.responseType + '. ';
                }
                if (parsedSmartResponseContent.productsReferenced) {
                  smartResponseErrorDetails += 'Products Referenced: ' + parsedSmartResponseContent.productsReferenced + '. ';
                }
              }
              if (smartResponseValidation.issues && smartResponseValidation.issues.length > 0) {
                smartResponseErrorDetails += 'Issues: ' + smartResponseValidation.issues.join('; ') + '. ';
              }
              if (smartResponseValidation.summary) {
                smartResponseErrorDetails += 'Summary: ' + smartResponseValidation.summary;
              }
            } else {
              smartResponseErrorDetails = 'SmartResponse LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'smartResponse',
              error: smartResponseErrorDetails,
              responseLLM: smartResponseLlmResponseText ? (smartResponseLlmResponseText.length > 300 ? smartResponseLlmResponseText.substring(0, 300) + '...' : smartResponseLlmResponseText) : ''
            });
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
            if (getUserInformationValidation) {
              if (getUserInformationValidation.scores) {
                getUserInformationErrorDetails += 'Scores: relevance=' + (getUserInformationValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (getUserInformationValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (getUserInformationValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (getUserInformationValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include extracted info from AI
              var parsedGetUserInformationContent = getUserInformationEvalResult.getUserInformationEvaluatorResultOut ? getUserInformationEvalResult.getUserInformationEvaluatorResultOut.parsedContent : null;
              if (parsedGetUserInformationContent) {
                if (parsedGetUserInformationContent.extractedInfo) {
                  getUserInformationErrorDetails += 'Extracted Info: ' + parsedGetUserInformationContent.extractedInfo + '. ';
                }
                if (parsedGetUserInformationContent.expectedInfo) {
                  getUserInformationErrorDetails += 'Expected Info: ' + parsedGetUserInformationContent.expectedInfo + '. ';
                }
              }
              if (getUserInformationValidation.issues && getUserInformationValidation.issues.length > 0) {
                getUserInformationErrorDetails += 'Issues: ' + getUserInformationValidation.issues.join('; ') + '. ';
              }
              if (getUserInformationValidation.summary) {
                getUserInformationErrorDetails += 'Summary: ' + getUserInformationValidation.summary;
              }
            } else {
              getUserInformationErrorDetails = 'GetUserInformation LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'getUserInformation',
              error: getUserInformationErrorDetails,
              responseLLM: getUserInformationLlmResponseText ? (getUserInformationLlmResponseText.length > 300 ? getUserInformationLlmResponseText.substring(0, 300) + '...' : getUserInformationLlmResponseText) : ''
            });
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
            if (specificQuestionSubIntentValidation) {
              if (specificQuestionSubIntentValidation.scores) {
                specificQuestionSubIntentErrorDetails += 'Scores: relevance=' + (specificQuestionSubIntentValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (specificQuestionSubIntentValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (specificQuestionSubIntentValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (specificQuestionSubIntentValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include classified sub-intent info from AI
              var parsedSpecificQuestionSubIntentContent = specificQuestionSubIntentEvalResult.specificQuestionSubIntentEvaluatorResultOut ? specificQuestionSubIntentEvalResult.specificQuestionSubIntentEvaluatorResultOut.parsedContent : null;
              if (parsedSpecificQuestionSubIntentContent) {
                if (parsedSpecificQuestionSubIntentContent.classifiedSubIntent) {
                  specificQuestionSubIntentErrorDetails += 'Classified SubIntent: ' + parsedSpecificQuestionSubIntentContent.classifiedSubIntent + '. ';
                }
                if (parsedSpecificQuestionSubIntentContent.expectedSubIntentCategory) {
                  specificQuestionSubIntentErrorDetails += 'Expected SubIntent Category: ' + parsedSpecificQuestionSubIntentContent.expectedSubIntentCategory + '. ';
                }
              }
              if (specificQuestionSubIntentValidation.issues && specificQuestionSubIntentValidation.issues.length > 0) {
                specificQuestionSubIntentErrorDetails += 'Issues: ' + specificQuestionSubIntentValidation.issues.join('; ') + '. ';
              }
              if (specificQuestionSubIntentValidation.summary) {
                specificQuestionSubIntentErrorDetails += 'Summary: ' + specificQuestionSubIntentValidation.summary;
              }
            } else {
              specificQuestionSubIntentErrorDetails = 'SpecificQuestionSubIntent LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'getSpecificQuestionSubIntent',
              error: specificQuestionSubIntentErrorDetails,
              responseLLM: specificQuestionSubIntentLlmResponseText ? (specificQuestionSubIntentLlmResponseText.length > 300 ? specificQuestionSubIntentLlmResponseText.substring(0, 300) + '...' : specificQuestionSubIntentLlmResponseText) : ''
            });
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
            if (multiProductQuestionSubIntentValidation) {
              if (multiProductQuestionSubIntentValidation.scores) {
                multiProductQuestionSubIntentErrorDetails += 'Scores: relevance=' + (multiProductQuestionSubIntentValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (multiProductQuestionSubIntentValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (multiProductQuestionSubIntentValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (multiProductQuestionSubIntentValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include classified sub-intent info from AI
              var parsedMultiProductQuestionSubIntentContent = multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentEvaluatorResultOut ? multiProductQuestionSubIntentEvalResult.multiProductQuestionSubIntentEvaluatorResultOut.parsedContent : null;
              if (parsedMultiProductQuestionSubIntentContent) {
                if (parsedMultiProductQuestionSubIntentContent.classifiedSubIntent) {
                  multiProductQuestionSubIntentErrorDetails += 'Classified SubIntent: ' + parsedMultiProductQuestionSubIntentContent.classifiedSubIntent + '. ';
                }
                if (parsedMultiProductQuestionSubIntentContent.expectedSubIntentCategory) {
                  multiProductQuestionSubIntentErrorDetails += 'Expected SubIntent Category: ' + parsedMultiProductQuestionSubIntentContent.expectedSubIntentCategory + '. ';
                }
              }
              if (multiProductQuestionSubIntentValidation.issues && multiProductQuestionSubIntentValidation.issues.length > 0) {
                multiProductQuestionSubIntentErrorDetails += 'Issues: ' + multiProductQuestionSubIntentValidation.issues.join('; ') + '. ';
              }
              if (multiProductQuestionSubIntentValidation.summary) {
                multiProductQuestionSubIntentErrorDetails += 'Summary: ' + multiProductQuestionSubIntentValidation.summary;
              }
            } else {
              multiProductQuestionSubIntentErrorDetails = 'MultiProductQuestionSubIntent LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'getMultiProductQuestionSubIntent',
              error: multiProductQuestionSubIntentErrorDetails,
              responseLLM: multiProductQuestionSubIntentLlmResponseText ? (multiProductQuestionSubIntentLlmResponseText.length > 300 ? multiProductQuestionSubIntentLlmResponseText.substring(0, 300) + '...' : multiProductQuestionSubIntentLlmResponseText) : ''
            });
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
            if (specificProductQuestionValidation) {
              if (specificProductQuestionValidation.scores) {
                specificProductQuestionErrorDetails += 'Scores: relevance=' + (specificProductQuestionValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (specificProductQuestionValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (specificProductQuestionValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (specificProductQuestionValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include response analysis from AI
              var parsedSpecificProductQuestionContent = specificProductQuestionEvalResult.specificProductQuestionEvaluatorResultOut ? specificProductQuestionEvalResult.specificProductQuestionEvaluatorResultOut.parsedContent : null;
              if (parsedSpecificProductQuestionContent) {
                if (parsedSpecificProductQuestionContent.responseAnalysis) {
                  specificProductQuestionErrorDetails += 'Response Analysis: ' + parsedSpecificProductQuestionContent.responseAnalysis + '. ';
                }
                if (parsedSpecificProductQuestionContent.expectedBehavior) {
                  specificProductQuestionErrorDetails += 'Expected Behavior: ' + parsedSpecificProductQuestionContent.expectedBehavior + '. ';
                }
              }
              if (specificProductQuestionValidation.issues && specificProductQuestionValidation.issues.length > 0) {
                specificProductQuestionErrorDetails += 'Issues: ' + specificProductQuestionValidation.issues.join('; ') + '. ';
              }
              if (specificProductQuestionValidation.summary) {
                specificProductQuestionErrorDetails += 'Summary: ' + specificProductQuestionValidation.summary;
              }
            } else {
              specificProductQuestionErrorDetails = 'SpecificProductQuestion LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'specificProductQuestion',
              error: specificProductQuestionErrorDetails,
              responseLLM: specificProductQuestionLlmResponseText ? (specificProductQuestionLlmResponseText.length > 300 ? specificProductQuestionLlmResponseText.substring(0, 300) + '...' : specificProductQuestionLlmResponseText) : ''
            });
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
            if (searchingByTitleValidation) {
              if (searchingByTitleValidation.scores) {
                searchingByTitleErrorDetails += 'Scores: relevance=' + (searchingByTitleValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (searchingByTitleValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (searchingByTitleValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (searchingByTitleValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include extracted terms from AI
              var parsedSearchingByTitleContent = searchingByTitleEvalResult.searchingByTitleEvaluatorResultOut ? searchingByTitleEvalResult.searchingByTitleEvaluatorResultOut.parsedContent : null;
              if (parsedSearchingByTitleContent) {
                if (parsedSearchingByTitleContent.extractedTerms) {
                  searchingByTitleErrorDetails += 'Extracted Terms: ' + parsedSearchingByTitleContent.extractedTerms + '. ';
                }
              }
              if (searchingByTitleValidation.issues && searchingByTitleValidation.issues.length > 0) {
                searchingByTitleErrorDetails += 'Issues: ' + searchingByTitleValidation.issues.join('; ') + '. ';
              }
              if (searchingByTitleValidation.summary) {
                searchingByTitleErrorDetails += 'Summary: ' + searchingByTitleValidation.summary;
              }
            } else {
              searchingByTitleErrorDetails = 'SearchingByTitle LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'searchingByTitle',
              error: searchingByTitleErrorDetails,
              responseLLM: searchingByTitleLlmResponseText ? (searchingByTitleLlmResponseText.length > 300 ? searchingByTitleLlmResponseText.substring(0, 300) + '...' : searchingByTitleLlmResponseText) : ''
            });
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
            if (specificProductQuestionResponseValidation) {
              if (specificProductQuestionResponseValidation.scores) {
                specificProductQuestionResponseErrorDetails += 'Scores: relevance=' + (specificProductQuestionResponseValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (specificProductQuestionResponseValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (specificProductQuestionResponseValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (specificProductQuestionResponseValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include response analysis from AI
              var parsedSpecificProductQuestionResponseContent = specificProductQuestionResponseEvalResult.specificProductQuestionResponseEvaluatorResultOut ? specificProductQuestionResponseEvalResult.specificProductQuestionResponseEvaluatorResultOut.parsedContent : null;
              if (parsedSpecificProductQuestionResponseContent) {
                if (parsedSpecificProductQuestionResponseContent.responseAnalysis) {
                  specificProductQuestionResponseErrorDetails += 'Response Analysis: ' + parsedSpecificProductQuestionResponseContent.responseAnalysis + '. ';
                }
                if (parsedSpecificProductQuestionResponseContent.expectedBehavior) {
                  specificProductQuestionResponseErrorDetails += 'Expected Behavior: ' + parsedSpecificProductQuestionResponseContent.expectedBehavior + '. ';
                }
              }
              if (specificProductQuestionResponseValidation.issues && specificProductQuestionResponseValidation.issues.length > 0) {
                specificProductQuestionResponseErrorDetails += 'Issues: ' + specificProductQuestionResponseValidation.issues.join('; ') + '. ';
              }
              if (specificProductQuestionResponseValidation.summary) {
                specificProductQuestionResponseErrorDetails += 'Summary: ' + specificProductQuestionResponseValidation.summary;
              }
            } else {
              specificProductQuestionResponseErrorDetails = 'SpecificProductQuestionResponse LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'specificProductQuestionResponse',
              error: specificProductQuestionResponseErrorDetails,
              responseLLM: specificProductQuestionResponseLlmResponseText ? (specificProductQuestionResponseLlmResponseText.length > 300 ? specificProductQuestionResponseLlmResponseText.substring(0, 300) + '...' : specificProductQuestionResponseLlmResponseText) : ''
            });
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
            if (specificProductSizeRecommendationValidation) {
              if (specificProductSizeRecommendationValidation.scores) {
                specificProductSizeRecommendationErrorDetails += 'Scores: relevance=' + (specificProductSizeRecommendationValidation.scores.relevance || 'N/A') +
                  ', faithfulness=' + (specificProductSizeRecommendationValidation.scores.faithfulness || 'N/A') +
                  ', instructionCompliance=' + (specificProductSizeRecommendationValidation.scores.instructionCompliance || 'N/A') +
                  ', semanticCloseness=' + (specificProductSizeRecommendationValidation.scores.semanticCloseness || 'N/A') + '. ';
              }
              // Include response analysis from AI
              var parsedSpecificProductSizeRecommendationContent = specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationEvaluatorResultOut ? specificProductSizeRecommendationEvalResult.specificProductSizeRecommendationEvaluatorResultOut.parsedContent : null;
              if (parsedSpecificProductSizeRecommendationContent) {
                if (parsedSpecificProductSizeRecommendationContent.responseAnalysis) {
                  specificProductSizeRecommendationErrorDetails += 'Response Analysis: ' + parsedSpecificProductSizeRecommendationContent.responseAnalysis + '. ';
                }
                if (parsedSpecificProductSizeRecommendationContent.expectedBehavior) {
                  specificProductSizeRecommendationErrorDetails += 'Expected Behavior: ' + parsedSpecificProductSizeRecommendationContent.expectedBehavior + '. ';
                }
              }
              if (specificProductSizeRecommendationValidation.issues && specificProductSizeRecommendationValidation.issues.length > 0) {
                specificProductSizeRecommendationErrorDetails += 'Issues: ' + specificProductSizeRecommendationValidation.issues.join('; ') + '. ';
              }
              if (specificProductSizeRecommendationValidation.summary) {
                specificProductSizeRecommendationErrorDetails += 'Summary: ' + specificProductSizeRecommendationValidation.summary;
              }
            } else {
              specificProductSizeRecommendationErrorDetails = 'SpecificProductSizeRecommendation LLM evaluation failed or returned no validation';
            }

            results.errors.push({
              tenant: tenantName,
              tenantId: tenantId,
              content: content,
              traceId: traceId,
              stage: 'specificProductSizeRecommendation',
              error: specificProductSizeRecommendationErrorDetails,
              responseLLM: specificProductSizeRecommendationLlmResponseText ? (specificProductSizeRecommendationLlmResponseText.length > 300 ? specificProductSizeRecommendationLlmResponseText.substring(0, 300) + '...' : specificProductSizeRecommendationLlmResponseText) : ''
            });
            karate.log('[SOFT FAIL] specificProductSizeRecommendation validation:', specificProductSizeRecommendationErrorDetails);
            // Continue (soft validation mode)
          }
        } else {
          karate.log('Skipping specificProductSizeRecommendation validation (not present in trace data)');
        }

        // ======================================================================
        // END OF VALIDATIONS - Determine final pass/fail status
        // ======================================================================

        if (testHasFailures) {
          results.failed++;
          karate.log('[FAILED] Test had one or more validation failures for:', content);
        } else {
          results.passed++;
          karate.log('[PASSED] All validations passed for:', content);
        }

      } catch (e) {
        results.failed++;
        results.errors.push({
          tenant: tenantName,
          tenantId: tenantId,
          content: content,
          traceId: traceId || 'N/A',
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
  * karate.log('Pass Rate:', Math.round((results.passed / allTestData.length) + '%'))
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
        karate.log('  TraceId: ' + (err.traceId || 'N/A'));
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
      }
      karate.log('');
      karate.log('===========================================================');
    }
    """

  # Store results for external access (by test runner for Google Sheets export)
  * def testResults = { totalTests: allTestData.length, passed: results.passed, failed: results.failed, errors: results.errors, spreadsheetId: spreadsheetId }
  * karate.set('testResultsForExport', testResults)

  # Write results to JSON file for the test runner to read
  * eval
    """
    try {
      var FileWriter = Java.type('java.io.FileWriter');
      var projectDir = java.lang.System.getProperty('user.dir');
      var filePath = projectDir + '/target/test-results.json';

      var jsonResults = {
        totalTests: allTestData.length,
        passed: results.passed,
        failed: results.failed,
        passRate: allTestData.length > 0 ? Math.round((results.passed / allTestData.length) * 100) : 0,
        errors: results.errors.map(function(err) {
          return {
            tenantId: err.tenantId || '',
            tenantName: err.tenant || 'Unknown',
            content: err.content || '',
            traceId: err.traceId || 'N/A',
            failedStage: err.stage || '',
            expected: err.expected !== undefined ? String(err.expected) : '',
            actual: err.actual !== undefined ? String(err.actual) : '',
            errorMessage: err.error || '',
            responseLLM: err.responseLLM || ''
          };
        })
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
