Feature: CMS trace data helpers - promptGlobalFilter

Scenario:
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def data = __arg.data
  * def expectedKey = __arg.expectedKey

  * def pgfList = karate.filter(data, function(x){ return x.agentName == 'promptGlobalFilter' })
  * def found = utils.findFirstValidPGF(pgfList, expectedKey)

  * if (!found) karate.fail('promptGlobalFilter not found or invalid. agentName=promptGlobalFilter key=' + expectedKey)

  * def value = found.parsed[expectedKey]
  * def result = { found: '#(found)', value: '#(value)' }
  * return result