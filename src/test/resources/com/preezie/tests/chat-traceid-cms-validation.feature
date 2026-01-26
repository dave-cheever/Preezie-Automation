Feature: Chat API - TraceId (data driven) + CMS validation

Background:
  * def baseUrl = 'https://dev-greenback-app-chat.azurewebsites.net'
  * def cmsBase = 'https://dev-greenback-app-cms-gateway.azurewebsites.net'
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')

Scenario Outline: promptGlobalFilter should match expected Safe for: <content>
  # 1) Chat -> TraceId
  * def chat = call read('classpath:com/preezie/services/chat/get-trace-id.feature') { content: '<content>', tenantId: <tenantId> }
  * match chat.traceId != null
  * match chat.traceId != ''
  * print 'prompt:', '<content>'
  * print 'traceId:', chat.traceId

  # 2) CMS trace lookup
  Given url cmsBase
  And path '/cms/agents/trace', chat.traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def traceData = response.data
  * print 'traceData:', traceData
  # promptGlobalFilter.Safe
  * def pgf = call read('classpath:com/preezie/services/cms/extract-agent-json-key.feature') { data: #(traceData), agentName: 'promptGlobalFilter', key: 'Safe' }
  * match pgf.value == <expectedSafe>

  # getIntent.Intent
  * def getIntentItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntent' })
  * eval
    """
    if (getIntentItems.length > 0) {
      var intent = karate.call('classpath:com/preezie/services/cms/extract-agent-json-key.feature', { data: traceData, agentName: 'getIntent', key: 'Intent' });
      karate.set('intent', intent);
    } else {
      karate.log('getIntent not present; skipping Intent validation');
      karate.set('intent', null);
    }
    """
  * eval
      """
      var expected = '<intent>';
      if (intent == null) {
        karate.log('getIntent not present; skipping Intent validation for:', '<content>');
      } else {
        var actual = intent.value;
        if (actual !== expected) {
          var intentJson = JSON.stringify(intent, null, 2);
          karate.fail('getIntent validation failed\\nExpected: ' + expected + '\\nActual: ' + actual);
        }
      }
      """

  # getIntentSummary -> build evaluator context + call evaluator helper
  * def intentSummaryItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntentSummary' })
  * def llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems)
  * def promptArgumentsText = utils.getFirstLLMPromptArgumentsText(intentSummaryItems)
  * def llmRequestFormatedText = utils.getFirstLLMRequestFormatedText(intentSummaryItems)


  * def evalArgs =
  """
  {
    "PromptArguments": "#(promptArgumentsText)",
    "LLMRequestFormattedPrompt": "#(llmRequestFormatedText)",
    "UserMessage": "<content>",
    "ResponseLLM": "#(llmResponseText)"
  }
  """
  * def evalResult = call read('classpath:com/preezie/llm/helpers/run-evaluator.feature') evalArgs
  * eval
    """
    var passed = evalResult && evalResult.validation && evalResult.validation.pass === true;
    if (!passed) {
      var responseLLM = karate.get('llmResponseText') || 'null';
      var details = evalResult && evalResult.validation ? JSON.stringify(evalResult.validation, null, 2) : 'no validation object';
      karate.fail('getIntentSummary validation failed\\nResponseLLM:\\n' + responseLLM + '\\nValidation details:\\n' + details);
    }
    """


Examples:
  | tenantId               | tenantName     | content                                                           | expectedSafe | intent        |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | milana white                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | milana ice blue                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | show me white linen pants in a size 14                            | true         | ProductSearch |
  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Im looking for white jackets                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | i dont like my arms, find me dresses that can cover my arms       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | striped pants                                                     | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Black wide leg jeans                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | black maxi dress with floral pattern                              | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Red plain dress                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | ackley earrings                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | rose gold earings                                                 | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | summer dresses                                                    | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | fun dress good for parties                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | outfit for the beach                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | doti sandals                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Glenda black dress                                                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | reading glasses                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | teal dress                                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | tie pants                                                         | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | green long sleeve dress                                           | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | red or green long sleeve dress between 150 and 250                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | bright coloured bags                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | colourful dresses                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | show me loafers                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | discounted shoes                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | accessories                                                       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Show me tops under $80                                             | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | do you have any jewellery under $20                                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Navy pyjamas                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | red dresses in a size 22                                          | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Im usually a size 18, can you show me jeans that would suit me     | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | shoes in a size 10 (fixed)                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | black shoes                                                       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | bottoms in a size 14                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | wedges                                                            | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | lula dress                                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | olinda pants                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Sennia dress                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | cayman dress                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | blouses                                                           | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | leather clutches                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | sandals with arch support                                         | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | white shirts                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | flowy shirts to wear to work                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | Find me accessories                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUTAS'  | Blue Bungalow  | sequin dress                                                      | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | 75-inch 4K Smart TVs                                               | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | OLED TVs with Dolby Vision                                         | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | HDMI cables that support 8K resolution                             | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | TV wall mounts for a 65-inch TV                                    | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Wireless soundbars with subwoofers                                 | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | TV stands with built-in cable management                           | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Bluetooth soundbars under $500                                      | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | TV backlighting kits                                                | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | HDMI splitters for dual screens                                     | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Show me Sony TVs                                                    | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Show me Samsung soundbars                                           | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Show me TV wall brackets                                             | true         | ProductSearch |
#  | 'tnt_8p01sa4gMQGkoIl'  | JB             | Soundbars with Dolby Atmos                                           | true         | ProductSearch |

