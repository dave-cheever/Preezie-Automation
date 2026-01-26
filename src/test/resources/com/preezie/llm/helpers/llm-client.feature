Feature: LLM client

Background:
  # Prefer JVM system property set via -DllmApiKey=...
  * def llmApiKey = karate.properties['llmApiKey']
  # Fallback to OS env var OPENAI_API_KEY
  * if (!llmApiKey) llmApiKey = Java.type('java.lang.System').getenv('OPENAI_API_KEY')
  # Also accept passing the env var as a Karate/JVM property if needed
  * if (!llmApiKey) llmApiKey = karate.properties['OPENAI_API_KEY']
  * if (!llmApiKey) karate.fail('Missing API key: set -DllmApiKey or OPENAI_API_KEY env var')

  * def base = karate.properties['llmBaseUrl'] ? karate.properties['llmBaseUrl'] : 'https://api.openai.com'
  * def urlBase = base.endsWith('/v1') ? base : base + '/v1'

Scenario: call evaluator
  Given url urlBase
  And path 'chat/completions'
  And header Authorization = 'Bearer ' + llmApiKey
  And header Content-Type = 'application/json'
  And request evaluatorPayload
  When method post
  Then status 200
  * def evaluatorResponse = response
