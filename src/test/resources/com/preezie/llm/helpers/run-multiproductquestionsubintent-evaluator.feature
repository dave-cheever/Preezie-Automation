Feature: Run evaluator against getMultiProductQuestionSubIntent classification

Scenario:
  * karate.log('=== RUN-MULTIPRODUCTQUESTIONSUBINTENT-EVALUATOR.FEATURE STARTED ===')
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

  * def evaluatorSystem = read('classpath:com/preezie/llm/validators/prompts/multiproductquestionsubintent-evaluator-system.prompt.txt')
  * def evaluatorUser = read('classpath:com/preezie/llm/validators/prompts/multiproductquestionsubintent-evaluator-user.prompt.txt')
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

  * karate.log('=== CALLING LLM-CLIENT.FEATURE FOR MULTIPRODUCTQUESTIONSUBINTENT EVALUATION ===')
  * def llmResult = call read('classpath:com/preezie/llm/helpers/llm-client.feature')
  * karate.log('=== LLM-CLIENT.FEATURE RETURNED ===')

  # Check if LLM call succeeded
  * def llmCallSucceeded = llmResult.llmCallSucceeded == true
  * karate.log('=== MultiProductQuestionSubIntent LLM call succeeded:', llmCallSucceeded)

  * def evaluatorResult = llmResult.evaluatorResponse
  * karate.log('=== MultiProductQuestionSubIntent evaluatorResponse received, has usage:', evaluatorResult && evaluatorResult.usage ? 'yes' : 'no')

  # If LLM call failed, create a dummy validation result
  * eval
    """
    if (!llmCallSucceeded) {
      karate.log('=== MULTIPRODUCTQUESTIONSUBINTENT LLM CALL FAILED - Creating fallback result ===');
      evaluatorResult = evaluatorResult || {};
      evaluatorResult.parsedContent = {
        pass: false,
        scores: { relevance: 0, faithfulness: 0, instructionCompliance: 0, semanticCloseness: 0 },
        classifiedSubIntent: 'Unknown',
        expectedSubIntentCategory: 'Unknown',
        issues: ['LLM API call failed: ' + (evaluatorResult.error ? evaluatorResult.error.message : 'Unknown error')],
        summary: 'MultiProductQuestionSubIntent evaluation could not be performed due to API error'
      };
    } else {
      if (typeof evaluatorResult === 'string') {
        try { evaluatorResult = JSON.parse(evaluatorResult); } catch(e) {}
      }
      if (evaluatorResult && evaluatorResult.choices && evaluatorResult.choices.length > 0) {
        var content = evaluatorResult.choices[0].message && evaluatorResult.choices[0].message.content;
        if (content) {
          var text = content.replace(/```json/g, '').replace(/```/g, '');
          try { evaluatorResult.parsedContent = JSON.parse(text); } catch(e) { evaluatorResult.parsedContent = text; }
        }
      }
    }
    """

  # Record usage - directly write to CSV using Java (for getMultiProductQuestionSubIntent AI cost tracking)
  * print '=== BEFORE MULTIPRODUCTQUESTIONSUBINTENT USAGE RECORDING - evaluatorResult type:', typeof evaluatorResult
  * eval
    """
    karate.log('=== INSIDE MULTIPRODUCTQUESTIONSUBINTENT USAGE RECORDING EVAL ===');
    if (evaluatorResult && evaluatorResult.usage) {
      try {
        var UsageData = Java.type('com.preezie.llm.cost.UsageData');
        var UsageCsvWriter = Java.type('com.preezie.llm.cost.UsageCsvWriter');
        var File = Java.type('java.io.File');
        var projectDir = java.lang.System.getProperty('user.dir');
        var csvFilePath = projectDir + File.separator + 'target' + File.separator + 'usage.csv';

        var tenantId = (__arg.tenantId || '').toString().replace(/'/g, '').replace(/"/g, '').trim();
        var content = (__arg.content || '').toString().replace(/'/g, '').replace(/"/g, '').trim();

        var promptTokens = parseInt(evaluatorResult.usage.prompt_tokens) || 0;
        var completionTokens = parseInt(evaluatorResult.usage.completion_tokens) || 0;
        var totalTokens = parseInt(evaluatorResult.usage.total_tokens) || 0;
        var cachedTokens = evaluatorResult.usage.prompt_tokens_details ? (parseInt(evaluatorResult.usage.prompt_tokens_details.cached_tokens) || 0) : 0;
        var audioTokens = evaluatorResult.usage.prompt_tokens_details ? (parseInt(evaluatorResult.usage.prompt_tokens_details.audio_tokens) || 0) : 0;

        karate.log('=== RECORDING MULTIPRODUCTQUESTIONSUBINTENT USAGE ===');
        karate.log('TenantId:', tenantId);
        karate.log('Content:', content.substring(0, Math.min(50, content.length)));
        karate.log('Prompt Tokens:', promptTokens);
        karate.log('Completion Tokens:', completionTokens);
        karate.log('Total Tokens:', totalTokens);

        var builder = new UsageData.Builder();
        builder.tenantId(tenantId);
        builder.content(content + ' [getMultiProductQuestionSubIntent]');
        builder.modelName('gpt-4.1');
        builder.promptTokens(promptTokens);
        builder.completionTokens(completionTokens);
        builder.totalTokens(totalTokens);
        builder.cachedTokens(cachedTokens);
        builder.audioTokens(audioTokens);
        var usageDataObj = builder.build();

        var writer = new UsageCsvWriter(csvFilePath);
        writer.writeUsage(usageDataObj);
        karate.log('=== MULTIPRODUCTQUESTIONSUBINTENT USAGE RECORDED SUCCESSFULLY ===');
      } catch (e) {
        karate.log('ERROR recording multiProductQuestionSubIntent usage:', e);
      }
    } else {
      karate.log('WARNING: No usage data found in multiProductQuestionSubIntent evaluatorResult');
    }
    """

  * def validator = read('classpath:com/preezie/llm/validators/llm-evaluator.js')
  * def toValidate = evaluatorResult.parsedContent && typeof evaluatorResult.parsedContent === 'object' ? evaluatorResult.parsedContent : evaluatorResult
  * def validation = validator.validateLLMResponse(toValidate)

  # Expose variables to caller
  * def multiProductQuestionSubIntentEvaluatorResultOut = evaluatorResult
  * def multiProductQuestionSubIntentValidationOut = validation
  * def multiProductQuestionSubIntentLlmCallSucceededOut = llmCallSucceeded


