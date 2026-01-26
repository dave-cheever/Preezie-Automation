Feature: Validate AI Assistant LLM Response

Scenario: LLM response should align with prompt intent
  * def PromptArguments = read('classpath:data/promptArguments.json')
  * def LLMRequestFormattedPrompt = read('classpath:data/llmRequest.txt')
  * def UserMessage = "Find me matching dress for winter"
  * def ResponseLLM = responseFromAssistant

  * def evaluatorPrompt =
  """
  {
    "PromptArguments": "#(PromptArguments)",
    "LLMRequestFormattedPrompt": "#(LLMRequestFormattedPrompt)",
    "UserMessage": "#(UserMessage)",
    "ResponseLLM": "#(ResponseLLM)"
  }
  """

  * def evaluatorPayload =
  """
  {
    "model": "gpt-4.1",
    "messages": [
      { "role": "system", "content": read('classpath:llm/validators/evaluator-prompt.txt') },
      { "role": "user", "content": "#(evaluatorPrompt)" }
    ],
    "temperature": 0
  }
  """

  * call read('classpath:llm/helpers/llm-client.feature')

  * def evaluatorResult = evaluatorResponse
  * def validator = call read('classpath:llm/validators/llm-evaluator.js')
  * def validation = validator.validateLLMResponse(evaluatorResult)

  * match validation.pass == true
