Feature: Get CMS Trace Data

Scenario:
  * def cmsBase = __arg.cmsBase
  * def traceId = __arg.traceId
  * def cmsIdToken = __arg.cmsIdToken

  * karate.log('🔍 CMS Base URL:', cmsBase)
    * karate.log('🔍 Trace ID:', traceId)
    * karate.log('🔍 Token (first 20 chars):', cmsIdToken ? cmsIdToken.substring(0, 20) + '...' : 'null')

  Given url cmsBase + '/cms/agents/trace/'+ traceId
#  And path '/cms/agents/trace/', traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def data = response.data

