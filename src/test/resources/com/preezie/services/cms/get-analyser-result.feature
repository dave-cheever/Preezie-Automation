Feature: Get CMS Analyser Result

Scenario:
  * def cmsBase = __arg.cmsBase
  * def traceId = __arg.traceId
  * def cmsIdToken = __arg.cmsIdToken

  * karate.log('🔍 CMS Analyser - Base URL:', cmsBase)
  * karate.log('🔍 CMS Analyser - Trace ID:', traceId)
  * karate.log('🔍 CMS Analyser - Token (first 20 chars):', cmsIdToken ? cmsIdToken.substring(0, 20) + '...' : 'null')

  # Configure longer timeout for analyser API (30 seconds)
  * configure readTimeout = 30000
  
  Given url cmsBase + '/cms/agents/analyser/' + traceId
  And header Authorization = 'Bearer ' + cmsIdToken
  When method get
  Then status 200

  * def statusCode = response.statusCode
  * def errorMessage = response.errorMessage
  * def data = response.data

  * karate.log('📊 Analyser statusCode:', statusCode)
  * karate.log('📊 Analyser errorMessage:', errorMessage)
  * karate.log('📊 Analyser data available:', data != null)
  * if (data != null && data.analysis != null) karate.log('📊 Analysis length:', data.analysis.length)
  * if (data != null && data.analysis == null) karate.log('⚠️  WARNING: data.analysis is NULL')
  * if (data != null && data.analysis == '') karate.log('⚠️  WARNING: data.analysis is EMPTY STRING')

