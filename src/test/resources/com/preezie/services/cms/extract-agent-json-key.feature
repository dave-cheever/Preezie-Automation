Feature: Extract a JSON key from the first valid parsed payload for an agent

Scenario:
  * karate.log('>>> running extract-agent-json-key.feature from classpath')
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def data = __arg.data
  * def agentName = __arg.agentName
  * def key = __arg.key
  * print '--- extract-agent-json-key debug ---'
  * print 'agentName arg:', '[' + agentName + ']'
  * print 'typeof data:', typeof data
  * print 'isArray(data):', Array.isArray(data)
  * print 'data length:', (Array.isArray(data) ? data.length : 'n/a')
  * def first5 = Array.isArray(data) ? karate.map(data.slice(0,5), function(x){ return x && x.agentName ? '[' + x.agentName + ']' : '<no-agentName>' }) : []
  * print 'first 5 agentNames:', first5

  * if (!data) karate.fail('data is null/undefined')
  * if (!agentName) karate.fail('agentName is null/undefined')
  * if (!key) karate.fail('key is null/undefined')

  * def items = []
  * eval
  """
  var wanted = ('' + agentName).trim().toLowerCase();
  var matches = [];

  for (var i = 0; i < data.length; i++) {
    var x = data[i];
    var got = (x && x.agentName !== undefined && x.agentName !== null) ? ('' + x.agentName) : null;

    if (got !== null) {
      var norm = got.trim().toLowerCase();
      if (norm === wanted) matches.push(x);
    }
  }

  items = matches;

  karate.log('wanted agentName:', wanted);
  karate.log('first 10 agentName raw:', data.slice(0,10).map(function(x){
    return x && x.agentName !== undefined ? '[' + ('' + x.agentName) + ']' : '<no-agentName>';
  }));
  """
  * print 'items length:', items.length
  * if (!items || items.length == 0) karate.fail('No items found for agentName=' + agentName)

  * def found = utils.findFirstValidPGF(items, key)

  * eval
  """
  if (!found) {
    found = karate.find(items, function(x){
      if (!x) return false;

      var p = x.parsed || x.output || x.result;
      if (!p) return false;

      if (typeof p === 'string') {
        try { p = JSON.parse(p); }
        catch(e) { return false; }
      }

      return p[key] !== undefined;
    });
  }
  """

  * if (!found) karate.fail('No valid agent payload found. agentName=' + agentName + ' key=' + key)

  * def parsed = found.parsed || found.output || found.result
  * if (typeof parsed === 'string') parsed = JSON.parse(parsed)

  * def value = parsed[key]
  * def result = { found: found, value: value }
  * def foundOut = found
  * def valueOut = value
