Feature: Run getUserInformation evaluator against getUserInformation

Scenario:
  * karate.log('=== RUN-GETUSERINFORMATION-EVALUATOR.FEATURE STARTED ===')
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

  * def evaluatorSystem = read('classpath:com/preezie/llm/validators/prompts/getuserinformation-evaluator-system.prompt.txt')
  * def evaluatorUser = read('classpath:com/preezie/llm/validators/prompts/getuserinformation-evaluator-user.prompt.txt')
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

  * karate.log('=== CALLING LLM-CLIENT.FEATURE FOR GETUSERINFORMATION EVALUATION ===')
  * def llmResult = call read('classpath:com/preezie/llm/helpers/llm-client.feature')
  * karate.log('=== LLM-CLIENT.FEATURE RETURNED ===')

  # Check if LLM call succeeded
  * def llmCallSucceeded = llmResult.llmCallSucceeded == true
  * karate.log('=== GetUserInformation LLM call succeeded:', llmCallSucceeded)

  * def evaluatorResult = llmResult.evaluatorResponse
  * karate.log('=== GetUserInformation evaluatorResponse received, has usage:', evaluatorResult && evaluatorResult.usage ? 'yes' : 'no')

  # If LLM call failed, create a dummy validation result
  * eval
    """
    if (!llmCallSucceeded) {
      karate.log('=== GETUSERINFORMATION LLM CALL FAILED - Creating fallback result ===');
      evaluatorResult = evaluatorResult || {};
      evaluatorResult.parsedContent = {
        pass: false,
        scores: { relevance: 0, faithfulness: 0, instructionCompliance: 0, semanticCloseness: 0 },
        extractedInfo: 'Unknown',
        expectedInfo: 'Unknown',
        issues: ['LLM API call failed: ' + (evaluatorResult.error ? evaluatorResult.error.message : 'Unknown error')],
        summary: 'GetUserInformation evaluation could not be performed due to API error'
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

  # Record usage - directly write to CSV using Java (for getUserInformation AI cost tracking)
  * print '=== BEFORE GETUSERINFORMATION USAGE RECORDING - evaluatorResult type:', typeof evaluatorResult
  * print '=== evaluatorResult:', evaluatorResult
  * print '=== evaluatorResult.usage:', evaluatorResult ? evaluatorResult.usage : 'no evaluatorResult'
  * eval
    """
    karate.log('=== INSIDE GETUSERINFORMATION USAGE RECORDING EVAL ===');
    karate.log('evaluatorResult exists:', !!evaluatorResult);
    if (evaluatorResult) {
      karate.log('evaluatorResult.usage exists:', !!evaluatorResult.usage);
      karate.log('evaluatorResult keys:', Object.keys(evaluatorResult));
    }

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

        karate.log('=== RECORDING GETUSERINFORMATION USAGE ===');
        karate.log('CSV Path:', csvFilePath);
        karate.log('TenantId:', tenantId);
        karate.log('Content:', content.substring(0, Math.min(50, content.length)));
        karate.log('Prompt Tokens:', promptTokens);
        karate.log('Completion Tokens:', completionTokens);
        karate.log('Total Tokens:', totalTokens);

        var builder = new UsageData.Builder();
        builder.tenantId(tenantId);
        builder.content(content + ' [getUserInformation]');
        builder.modelName('gpt-4.1');
        builder.promptTokens(promptTokens);
        builder.completionTokens(completionTokens);
        builder.totalTokens(totalTokens);
        builder.cachedTokens(cachedTokens);
        builder.audioTokens(audioTokens);
        var usageDataObj = builder.build();

        var writer = new UsageCsvWriter(csvFilePath);
        writer.writeUsage(usageDataObj);
        karate.log('=== GETUSERINFORMATION USAGE RECORDED SUCCESSFULLY ===');
      } catch (e) {
        karate.log('ERROR recording getUserInformation usage:', e);
        karate.log('Error message:', e.message);
        karate.log('Error stack:', e.stack);
      }
    } else {
      karate.log('WARNING: No usage data found in getUserInformation evaluatorResult');
      if (evaluatorResult) {
        karate.log('evaluatorResult content:', JSON.stringify(evaluatorResult).substring(0, 500));
      }
    }
    """

  * def validator = read('classpath:com/preezie/llm/validators/llm-evaluator.js')
  * def toValidate = evaluatorResult.parsedContent && typeof evaluatorResult.parsedContent === 'object' ? evaluatorResult.parsedContent : evaluatorResult
  * def validation = validator.validateLLMResponse(toValidate)

  # Expose variables to caller
  * def getUserInformationEvaluatorResultOut = evaluatorResult
  * def getUserInformationValidationOut = validation
  * def getUserInformationLlmCallSucceededOut = llmCallSucceeded


