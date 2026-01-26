Feature: Run evaluator against provided context

Scenario:
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

  * call read('classpath:com/preezie/llm/helpers/llm-client.feature')

  * def evaluatorResult = evaluatorResponse
  * eval
    """
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
    """

  * def validator = read('classpath:com/preezie/llm/validators/llm-evaluator.js')
  * def toValidate = evaluatorResult.parsedContent && typeof evaluatorResult.parsedContent === 'object' ? evaluatorResult.parsedContent : evaluatorResult
  * def validation = validator.validateLLMResponse(toValidate)

  # no `return` step; expose variables to caller via the call result
  * def evaluatorResultOut = evaluatorResult
  * def validationOut = validation
