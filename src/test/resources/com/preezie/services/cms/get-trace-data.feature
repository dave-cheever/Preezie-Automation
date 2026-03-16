Feature: Get CMS Trace Data

Scenario:
  * def cmsBase = __arg.cmsBase
  * def traceId = __arg.traceId
  * def cmsIdToken = __arg.cmsIdToken

  Given url cmsBase
  And path '/cms/agents/trace', traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def traceData = response.data

