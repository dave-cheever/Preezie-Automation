// File: `src/test/resources/com/preezie/tests/extract-trace-id.js`
function(h, body){
  var t =
    (h['trace-id'] && h['trace-id'][0]) ||
    (h['Trace-Id'] && h['Trace-Id'][0]) ||
    (h['traceparent'] && h['traceparent'][0]) ||
    (h['Request-Id'] && h['Request-Id'][0]) ||
    (h['request-id'] && h['request-id'][0]) ||
    null;

  if (!t && body) {
    t = body.traceId || body.TraceId || body.correlationId || body.requestId || null;
  }
  return t;
}