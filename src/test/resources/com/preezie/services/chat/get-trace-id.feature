Feature: Chat service - send message and return traceId

  Background:
    * def requestTemplate = read('classpath:com/preezie/services/chat-request.json')
    * def extractTraceId = read('classpath:com/preezie/services/extract-trace-id.js')

  Scenario: send and get traceId
    * def content = __arg.content
    * match content != null
    * match content != ''

    * def tenantIdLocal = __arg.tenantId || karate.get('tenantId')
    * def sessionIdLocal = __arg.sessionId || requestTemplate.sessionId
    * def visitorIdLocal = __arg.visitorId || requestTemplate.visitorId
    * def lastContentLocal = __arg.lastContent || requestTemplate.lastContent
    * def websiteUrlLocal = __arg.websiteUrl || requestTemplate.websiteUrl

    * def req =  read('classpath:com/preezie/services/chat-request.json')
    * set req.content = content
    * set req.sessionId = sessionIdLocal
    * set req.chatMetaData.websiteUrl = websiteUrlLocal
    * set req.lastContent = lastContentLocal
    * set req.visitorId = visitorIdLocal

    Given url baseUrl

    And path '/api/chat'
    And header Tenantid = tenantIdLocal
    And request req
    When method post
    Then status 200

    * def traceId = extractTraceId(responseHeaders, response)
    * match traceId != null
    * match traceId != ''

    * def result = { traceId: (traceId) }
