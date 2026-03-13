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

  # 2) CMS trace lookup
  Given url cmsBase
  And path '/cms/agents/trace', chat.traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def traceData = response.data
  # Store values for error messages
  * def currentTenantId = <tenantId>
  * def currentTenantName = '<tenantName>'
  * def currentContent = '<content>'

  # promptGlobalFilter.Safe
  * def pgf = call read('classpath:com/preezie/services/cms/extract-agent-json-key.feature') { data: #(traceData), agentName: 'promptGlobalFilter', key: 'Safe' }
  * eval
    """
    var expected = <expectedSafe>;
    var actual = pgf.value;
    if (actual !== expected) {
      var tenantId = karate.get('currentTenantId');
      var tenantName = karate.get('currentTenantName');
      var content = karate.get('currentContent');
      karate.fail('[promptGlobalFilter FAILED]\\n' +
        'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
        'Content: ' + content + '\\n' +
        'Expected Safe: ' + expected + '\\n' +
        'Actual Safe: ' + actual);
    }
    """

  * eval karate.log('GetIntent start: ')
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
        karate.log('getIntent not present; skipping Intent validation for:', karate.get('currentContent'));
      } else {
        var actual = intent.value;
        if (actual !== expected) {
          var tenantId = karate.get('currentTenantId');
          var tenantName = karate.get('currentTenantName');
          var content = karate.get('currentContent');
          karate.fail('[getIntent FAILED]\\n' +
            'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
            'Content: ' + content + '\\n' +
            'Expected Intent: ' + expected + '\\n' +
            'Actual Intent: ' + actual);
        }
      }
      """
  * eval karate.log('GetIntent end: ')

  * eval karate.log('getIntentSummary Start: ')
  # getIntentSummary -> build evaluator context + call evaluator helper
  * def intentSummaryItems = karate.filter(traceData, function(x){ return x.agentName == 'getIntentSummary' })
  * eval karate.log('getIntentSummary Start: '+ JSON.stringify(intentSummaryItems))
  * def llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems)
  * def promptArgumentsText = utils.getFirstLLMPromptArgumentsText(intentSummaryItems)
  * def llmRequestFormatedText = utils.getFirstLLMRequestFormatedText(intentSummaryItems)

  * eval karate.log('getIntentSummary Start evalArgs: ')
  * def evalArgs =
  """
  {
    "PromptArguments": "#(promptArgumentsText)",
    "LLMRequestFormattedPrompt": "#(llmRequestFormatedText)",
    "UserMessage": "<content>",
    "ResponseLLM": "#(llmResponseText)",
    "tenantId": "<tenantId>",
    "content": "<content>"
  }
  """
  * eval karate.log('getIntentSummary Start evalResult: ')
  * def evalResult = call read('classpath:com/preezie/llm/helpers/run-evaluator.feature') evalArgs
  * eval karate.log('getIntentSummary end evalResult: ')
  * eval
    """
    var passed = evalResult && evalResult.validation && evalResult.validation.pass === true;
    if (!passed) {
      var tenantId = karate.get('currentTenantId');
      var tenantName = karate.get('currentTenantName');
      var content = karate.get('currentContent');
      var responseLLM = karate.get('llmResponseText') || 'null';
      var details = evalResult && evalResult.validation ? JSON.stringify(evalResult.validation, null, 2) : 'no validation object';
      karate.fail('[getIntentSummary FAILED]\\n' +
        'Tenant: ' + tenantName + ' (' + tenantId + ')\\n' +
        'Content: ' + content + '\\n' +
        'ResponseLLM: ' + responseLLM + '\\n' +
        'Validation Details: ' + details);
    }
    """

Examples:
  | tenantId               | tenantName     | content                                                           | expectedSafe | intent        |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | milana white                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | milana ice blue                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | show me white linen pants in a size 14                            | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Im looking for white jackets                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | i dont like my arms, find me dresses that can cover my arms       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | striped pants                                                     | true         | test |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Black wide leg jeans                                               | false         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | black maxi dress with floral pattern                              | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Red plain dress                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | ackley earrings                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | rose gold earings                                                 | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | summer dresses                                                    | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | fun dress good for parties                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | outfit for the beach                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | doti sandals                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Glenda black dress                                                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | reading glasses                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | teal dress                                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | tie pants                                                         | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | green long sleeve dress                                           | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | red or green long sleeve dress between 150 and 250                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | bright coloured bags                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | colourful dresses                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | show me loafers                                                   | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | discounted shoes                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | accessories                                                       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Show me tops under $80                                             | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | do you have any jewellery under $20                                | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Navy pyjamas                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | red dresses in a size 22                                          | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Im usually a size 18, can you show me jeans that would suit me     | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | shoes in a size 10 (fixed)                                        | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | black shoes                                                       | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | bottoms in a size 14                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | wedges                                                            | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | lula dress                                                        | true         | ProductSearch |
  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | olinda pants                                                      | true         | ProductSearch |
  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Sennia dress                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | cayman dress                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | blouses                                                           | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | leather clutches                                                  | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | sandals with arch support                                         | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | white shirts                                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | flowy shirts to wear to work                                      | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | Find me accessories                                               | true         | ProductSearch |
#  | 'tnt_pJ22NGJQXirUT0Y'  | Blue Bungalow  | sequin dress                                                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | red running shoes                         | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black sneakers                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | white puma trainers                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | blue sports shoes                         | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma running shoes                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | mens training sneakers                   | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens running shoes                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | cushioned running sneakers                | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | breathable training shoes                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | lightweight running shoes                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma ignite running shoes                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma velocity nitro                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma devi ate nitro running shoes         | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma rs x sneakers                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma suede classic shoes                  | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma future rider sneakers                | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma cali sneakers                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma mayze sneakers                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma smash sneakers                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma slipstream sneakers                  | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running shoes under 100                   | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | discounted puma sneakers                  | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | affordable training shoes                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | premium running shoes                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma shoes for gym training               | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | basketball shoes                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma basketball sneakers                  | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports shirts                             | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black workout shirt                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | white sports tee                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma training shirts                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | mens gym shirts                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens workout tops                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running shirts                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports tank tops                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | performance training shirt                | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | gym shirts under 50                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | athletic training tops                    | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running shorts                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | gym shorts                                | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black sports shorts                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | mens training shorts                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens running shorts                    | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | breathable running shorts                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | lightweight gym shorts                    | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports shorts under 80                    | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | athletic jogger pants                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black training pants                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | grey sports joggers                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | workout leggings                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running leggings                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens sports leggings                   | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports jackets                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running windbreaker                       | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | training jacket                           | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | lightweight sports jacket                 | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | athletic hoodies                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black gym hoodie                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | grey training hoodie                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports hoodie                             | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | mens athletic hoodie                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens gym hoodie                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports caps                               | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running caps                              | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma logo cap                             | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | gym backpack                              | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports backpack                           | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | training gym bag                          | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports duffle bag                         | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running socks                             | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | athletic socks                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | white sports socks                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | black training socks                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sports bras                               | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | workout sports bra                        | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | womens training bra                      | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | gym sports bra                            | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | athletic clothing                         | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | sportswear                                | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | puma athletic apparel                     | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | running gear                              | true         | ProductSearch |
#    | 'tnt_sZSeICB9hop90GD'  | PUMA       | gym training gear                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony noise cancelling headphones           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple airpods pro                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung galaxy buds                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | wireless bluetooth headphones              | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming headsets                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony wh 1000xm5 headphones                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | bose quietcomfort headphones               | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | jbl wireless earbuds                       | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | over ear headphones                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple airpods max                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | smart tvs                                  | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung 4k tv                              | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | lg oled tv                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony bravia tv                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | televisions under 1000                     | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | 65 inch smart tv                           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | 75 inch tv                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | 4k ultra hd televisions                    | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming televisions                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | android tv                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | playstation 5 console                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | xbox series x console                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | nintendo switch                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming consoles                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | playstation 5 games                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | xbox games                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | nintendo switch games                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming controllers                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | playstation dualsense controller           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | xbox wireless controller                   | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming keyboards                           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming mice                                | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | pc gaming accessories                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming monitors                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | 144hz gaming monitor                       | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | ultrawide monitors                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung gaming monitor                     | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | lg gaming monitor                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple macbook air                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple macbook pro                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | laptops under 1500                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gaming laptops                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | windows laptops                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | ultrabooks                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung galaxy s24                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple iphone 15                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | android smartphones                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | unlocked smartphones                       | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | mobile phones under 1000                   | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | phone cases                                | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | iphone cases                               | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung phone cases                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | phone chargers                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | wireless phone chargers                    | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | portable bluetooth speakers                | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | jbl bluetooth speaker                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony portable speaker                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | party speakers                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | smart speakers                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | google nest speaker                        | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | amazon echo smart speaker                  | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | soundbars                                  | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | dolby atmos soundbars                      | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | samsung soundbar                           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | lg soundbar                                | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony soundbar                              | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | digital cameras                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | mirrorless cameras                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | sony alpha cameras                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | gopro action cameras                       | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | camera tripods                             | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | camera lenses                              | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | drone cameras                              | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | tablets                                    | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple ipad                                 | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | ipad pro                                   | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | android tablets                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | tablet keyboards                           | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | tablet stylus pens                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | streaming devices                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | google chromecast                          | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | apple tv                                   | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | tv streaming devices                       | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | blu ray players                            | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | 4k blu ray players                         | true         | ProductSearch |
#      | 'tnt_sJaLLkeEMDVUI9G'  | JB HIFI    | home theatre systems                       | true         | ProductSearch |
