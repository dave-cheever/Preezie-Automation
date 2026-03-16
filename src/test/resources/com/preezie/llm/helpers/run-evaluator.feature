Feature: Run evaluator against provided context

Scenario:
  * karate.log('=== RUN-EVALUATOR.FEATURE STARTED ===')
  * def evaluatorContext =
    """
    {
      "PromptArguments": "#(__arg.PromptArguments)",
      "LLMRequestFormattedPrompt": "#(__arg.LLMRequestFormattedPrompt)",
      "UserMessage": "#(__arg.UserMessage)",
      "ResponseLLM": "#(__arg.ResponseLLM)"
    }
    """
  * def evaluatorContextText = karate.pretty(evaluatorContext)

  * def evaluatorSystem = read('classpath:com/preezie/llm/validators/prompts/evaluator-system.prompt.txt')
  * def evaluatorUser = read('classpath:com/preezie/llm/validators/prompts/evaluator-user.prompt.txt')
  * def evaluatorUserWithContext = evaluatorUser + '\n\nContext to evaluate (JSON):\n' + evaluatorContextText

  * def evaluatorPayload =
    """
    {
      "model": "gpt-4.1",
      "messages": [
        { "role": "system", "content": "#(evaluatorSystem)" },
        { "role": "user", "content": "#(evaluatorUserWithContext)" }
      ],
      "temperature": 0
    }
    """

  * karate.log('=== CALLING LLM-CLIENT.FEATURE ===')
  * def llmResult = call read('classpath:com/preezie/llm/helpers/llm-client.feature')
  * karate.log('=== LLM-CLIENT.FEATURE RETURNED ===')
  * karate.log('=== llmResult:', llmResult)
  * karate.log('=== llmResult keys:', llmResult ? Object.keys(llmResult) : 'null')

  # Check if LLM call succeeded
  * def llmCallSucceeded = llmResult.llmCallSucceeded == true
  * karate.log('=== LLM call succeeded:', llmCallSucceeded)

  * def evaluatorResult = llmResult.evaluatorResponse
  * karate.log('=== evaluatorResponse received, has usage:', evaluatorResult && evaluatorResult.usage ? 'yes' : 'no')

  # If LLM call failed, create a dummy validation result
  * eval
    """
    if (!llmCallSucceeded) {
      karate.log('=== LLM CALL FAILED - Creating fallback result ===');
      evaluatorResult = evaluatorResult || {};
      evaluatorResult.parsedContent = {
        pass: false,
        scores: { relevance: 0, faithfulness: 0, instructionCompliance: 0, semanticCloseness: 0 },
        issues: ['LLM API call failed: ' + (evaluatorResult.error ? evaluatorResult.error.message : 'Unknown error')],
        summary: 'LLM evaluation could not be performed due to API error'
      };
    } else {
      if (typeof evaluatorResult === 'string') {
        try { evaluatorResult = JSON.parse(evaluatorResult); } catch(e) {}
      }
      if (evaluatorResult && evaluatorResult.choices && evaluatorResult.choices.length > 0) {
        var content = evaluatorResult.choices[0].message && evaluatorResult.choices[0].message.content;
        if (content) {
          var text = content.replace(/```/g, '');
          try { evaluatorResult.parsedContent = JSON.parse(text); } catch(e) { evaluatorResult.parsedContent = text; }
        }
      }
    }
    """

  # Record usage - directly write to CSV using Java
  * print '=== BEFORE USAGE RECORDING - evaluatorResult type:', typeof evaluatorResult
  * print '=== evaluatorResult:', evaluatorResult
  * eval
    """
    karate.log('=== INSIDE USAGE RECORDING EVAL ===');
    karate.log('evaluatorResult exists:', !!evaluatorResult);
    karate.log('evaluatorResult type:', typeof evaluatorResult);
    if (evaluatorResult) {
      karate.log('evaluatorResult.usage exists:', !!evaluatorResult.usage);
      karate.log('evaluatorResult keys:', Object.keys(evaluatorResult));
    }

    if (evaluatorResult && evaluatorResult.usage) {
      try {
        var UsageData = Java.type('com.preezie.llm.cost.UsageData');
        var UsageCsvWriter = Java.type('com.preezie.llm.cost.UsageCsvWriter');
        var csvFilePath = java.lang.System.getProperty('user.dir') + '/target/usage.csv';

        var tenantId = (__arg.tenantId || '').toString().replace(/'/g, '').replace(/"/g, '').trim();
        var content = (__arg.content || '').toString().replace(/'/g, '').replace(/"/g, '').trim();

        // Ensure numeric values are integers
        var promptTokens = parseInt(evaluatorResult.usage.prompt_tokens) || 0;
        var completionTokens = parseInt(evaluatorResult.usage.completion_tokens) || 0;
        var totalTokens = parseInt(evaluatorResult.usage.total_tokens) || 0;
        var cachedTokens = evaluatorResult.usage.prompt_tokens_details ? (parseInt(evaluatorResult.usage.prompt_tokens_details.cached_tokens) || 0) : 0;
        var audioTokens = evaluatorResult.usage.prompt_tokens_details ? (parseInt(evaluatorResult.usage.prompt_tokens_details.audio_tokens) || 0) : 0;

        karate.log('=== RECORDING USAGE ===');
        karate.log('TenantId:', tenantId);
        karate.log('Content:', content.substring(0, Math.min(50, content.length)));
        karate.log('Prompt Tokens:', promptTokens);
        karate.log('Completion Tokens:', completionTokens);
        karate.log('Total Tokens:', totalTokens);
        karate.log('CSV Path:', csvFilePath);

        var builder = new UsageData.Builder();
        builder.tenantId(tenantId);
        builder.content(content);
        builder.modelName('gpt-4.1');
        builder.promptTokens(promptTokens);
        builder.completionTokens(completionTokens);
        builder.totalTokens(totalTokens);
        builder.cachedTokens(cachedTokens);
        builder.audioTokens(audioTokens);
        var usageDataObj = builder.build();

        karate.log('=== UsageData object created ===');
        var writer = new UsageCsvWriter(csvFilePath);
        karate.log('=== UsageCsvWriter created ===');
        writer.writeUsage(usageDataObj);
        karate.log('=== USAGE RECORDED SUCCESSFULLY to:', csvFilePath, '===');
      } catch (e) {
        karate.log('ERROR recording usage:', e);
        karate.log('ERROR message:', e.message);
        karate.log('ERROR stack:', e.stack);
      }
    } else {
      karate.log('WARNING: No usage data found in evaluatorResult');
      if (evaluatorResult) {
        karate.log('evaluatorResult keys:', Object.keys(evaluatorResult));
        karate.log('evaluatorResult stringified:', JSON.stringify(evaluatorResult).substring(0, 500));
      } else {
        karate.log('evaluatorResult is null/undefined');
      }
    }
    """

  * def validator = read('classpath:com/preezie/llm/validators/llm-evaluator.js')
  * def toValidate = evaluatorResult.parsedContent && typeof evaluatorResult.parsedContent === 'object' ? evaluatorResult.parsedContent : evaluatorResult
  * def validation = validator.validateLLMResponse(toValidate)

  # no `return` step; expose variables to caller via the call result
  * def evaluatorResultOut = evaluatorResult
  * def validationOut = validation
  * def llmCallSucceededOut = llmCallSucceeded
