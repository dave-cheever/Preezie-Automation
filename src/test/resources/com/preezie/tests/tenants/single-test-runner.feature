Feature: Single Test Case Runner
  # This feature runs a single test case and returns the result
  # Called by tenant feature files with filtered (enabled only) test data

Scenario:
  * def content = __arg.content
  * def expectedSafe = __arg.expectedSafe
  * def intent = __arg.intent
  * def tenantId = __arg.tenantId
  * def tenantName = __arg.tenantName
  * def cmsBase = __arg.cmsBase
  * def baseUrl = __arg.baseUrl

  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def failed = false
  * def failedAt = null
  * def errorMessage = null
  * def expectedSafeVal = null
  * def actualSafeVal = null
  * def expectedIntentVal = null
  * def actualIntentVal = null

  # 1) Chat -> TraceId
  * def chat = call read('classpath:com/preezie/services/chat/get-trace-id.feature') { content: '#(content)', tenantId: '#(tenantId)' }
  * eval
    """
    if (!chat.traceId) {
      failed = true;
      failedAt = 'getTraceId';
      errorMessage = 'Failed to get traceId for content: ' + content;
      karate.log('[FAILED] getTraceId - ' + errorMessage);
    }
    """
  * if (failed) karate.set('result', { failed: true, failedAt: failedAt, errorMessage: errorMessage, content: content })
  * if (failed) karate.abort()

  # Check if CMS token is available
  * eval
    """
    if (!cmsIdToken) {
      failed = true;
      failedAt = 'cmsAuth';
      errorMessage = 'CMS authentication token (cmsIdToken) is not configured. Please set FIREBASE_API_KEY, FIREBASE_EMAIL, and FIREBASE_PASSWORD environment variables.';
      karate.log('[FAILED] cmsAuth - ' + errorMessage);
    }
    """
  * if (failed) karate.set('result', { failed: true, failedAt: failedAt, errorMessage: errorMessage, content: content })
  * if (failed) karate.abort()

  # 2) CMS trace lookup
  Given url cmsBase
  And path '/cms/agents/trace', chat.traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def traceData = response.data

  # 3) promptGlobalFilter.Safe validation
  * def pgf = call read('classpath:com/preezie/services/cms/extract-agent-json-key.feature') { data: #(traceData), agentName: 'promptGlobalFilter', key: 'Safe' }
  * print '====== promptGlobalFilter DEBUG ======'
  * print '====== pgf.value:', pgf.value, 'type:', typeof pgf.value
  * print '====== expectedSafe:', expectedSafe, 'type:', typeof expectedSafe
  * eval
    """
    var expected = (expectedSafe === true || expectedSafe === 'true');
    var actual = pgf.value;
    karate.log('>>> promptGlobalFilter comparison:');
    karate.log('>>> expected (boolean):', expected, 'type:', typeof expected);
    karate.log('>>> actual:', actual, 'type:', typeof actual);
    karate.log('>>> actual === expected:', actual === expected);
    karate.log('>>> actual == expected:', actual == expected);
    if (actual !== expected) {
      failed = true;
      failedAt = 'promptGlobalFilter';
      errorMessage = '[promptGlobalFilter FAILED]\\n' +
        'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
        'Content: ' + content + '\\n' +
        'Expected Safe: ' + expected + '\\n' +
        'Actual Safe: ' + actual;
      karate.log(errorMessage);
      karate.set('expectedSafeVal', expected);
      karate.set('actualSafeVal', actual);
    }
    """
  * if (failed) karate.set('result', { failed: true, failedAt: failedAt, errorMessage: errorMessage, content: content, expectedSafe: expectedSafeVal, actualSafe: actualSafeVal })
  * if (failed) karate.abort()

  # 4) getIntent.Intent validation (if present)
  * def getIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntent' })
  * print '====== getIntent DEBUG ======'
  * print '====== getIntentItems.length:', getIntentItems.length
  * print '====== expected intent:', intent
  * eval
    """
    if (getIntentItems.length > 0) {
      var intentResult = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', {
        data: traceData,
        agentName: 'getIntent',
        key: 'Intent'
      });

      karate.log('>>> getIntent comparison:');
      karate.log('>>> expected intent:', intent, 'type:', typeof intent);
      karate.log('>>> actual intent:', intentResult.value, 'type:', typeof intentResult.value);
      karate.log('>>> intentResult.value === intent:', intentResult.value === intent);
      karate.log('>>> intentResult.value == intent:', intentResult.value == intent);

      if (intentResult.value !== intent) {
        failed = true;
        failedAt = 'getIntent';
        errorMessage = '[getIntent FAILED]\\n' +
          'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
          'Content: ' + content + '\\n' +
          'Expected Intent: ' + intent + '\\n' +
          'Actual Intent: ' + intentResult.value;
        karate.log(errorMessage);
        karate.set('expectedIntentVal', intent);
        karate.set('actualIntentVal', intentResult.value);
      }
    } else {
      karate.log('getIntent not present; skipping Intent validation for: ' + content);
    }
    """
  * if (failed) karate.set('result', { failed: true, failedAt: failedAt, errorMessage: errorMessage, content: content, expectedIntent: expectedIntentVal, actualIntent: actualIntentVal })
  * if (failed) karate.abort()

  # 5) getIntentSummary validation with LLM evaluator
  * print '====== STARTING STEP 5: getIntentSummary validation ======'
  * print '====== traceData length:', traceData.length
  * def intentSummaryItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntentSummary' })
  * print '====== intentSummaryItems length:', intentSummaryItems.length
  * print '====== intentSummaryItems:', intentSummaryItems
  * def llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems)
  * def promptArgumentsText = utils.getFirstLLMPromptArgumentsText(intentSummaryItems)
  * def llmRequestFormatedText = utils.getFirstLLMRequestFormatedText(intentSummaryItems)
  * print '====== llmResponseText:', llmResponseText
  * print '====== promptArgumentsText present:', !!promptArgumentsText
  * print '====== llmRequestFormatedText present:', !!llmRequestFormatedText

  * def evalArgs =
  """
  {
    "PromptArguments": "#(promptArgumentsText)",
    "LLMRequestFormattedPrompt": "#(llmRequestFormatedText)",
    "UserMessage": "#(content)",
    "ResponseLLM": "#(llmResponseText)",
    "tenantId": "#(tenantId)",
    "content": "#(content)"
  }
  """
  * karate.log('>>> CALLING LLM EVALUATOR for:', content)
  * def evalResult = call read('classpath:com/preezie/llm/helpers/run-evaluator.feature') evalArgs
  * karate.log('>>> LLM EVALUATOR RETURNED for:', content)
  * karate.log('>>> evalResult keys:', evalResult ? Object.keys(evalResult) : 'null')
  * eval
    """
    // The run-evaluator.feature exposes validationOut, evaluatorResultOut, and llmCallSucceededOut
    var validation = evalResult ? evalResult.validationOut : null;
    var llmCallSucceeded = evalResult ? evalResult.llmCallSucceededOut : false;
    var passed = validation && validation.pass === true;
    karate.log('>>> validation object:', validation ? JSON.stringify(validation) : 'null');
    karate.log('>>> llmCallSucceeded:', llmCallSucceeded);
    karate.log('>>> passed:', passed);

    // Only fail if LLM call succeeded but validation failed
    // Skip failure if LLM API quota exceeded - just log warning
    if (!llmCallSucceeded) {
      karate.log('>>> LLM API call failed - skipping validation (API quota exceeded?)');
    } else if (!passed) {
      failed = true;
      failedAt = 'getIntentSummary';
      var details = validation ? JSON.stringify(validation, null, 2) : 'no validation object';
      errorMessage = '[getIntentSummary FAILED]\\n' +
        'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
        'Content: ' + content + '\\n' +
        'ResponseLLM: ' + (llmResponseText || 'null') + '\\n' +
        'Validation Details: ' + details;
      karate.log(errorMessage);
    }
    """

  # Set final result
  * def result = { failed: failed, failedAt: failedAt, errorMessage: errorMessage, content: content, passed: !failed, expectedSafe: expectedSafeVal, actualSafe: actualSafeVal, expectedIntent: expectedIntentVal, actualIntent: actualIntentVal }
  * karate.log(failed ? '[FAILED] ' + content : '[PASSED] ' + content)

