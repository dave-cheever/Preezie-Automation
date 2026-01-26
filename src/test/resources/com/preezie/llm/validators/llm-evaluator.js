// File: `src/test/resources/com/preezie/llm/validators/llm-evaluator.js`
//
// Karate `read()` returns the value of the last expression in the file.
// Export an object whose member is an inline function (no scope issues).
({
  validateLLMResponse: function (input) {
    var errors = [];

    if (!input) {
      errors.push('missing input object');
      return { pass: false, scores: {}, issues: [], summary: '', errors: errors };
    }

    if (input.choices && input.choices.length > 0) {
      var first = input.choices[0] || {};
      var msg = first.message || {};
      var content = msg.content || first.text || '';
      if (!String(content).trim()) errors.push('missing content in choices[0]');
      return { pass: errors.length === 0, content: content, errors: errors };
    }

    var scores = input.scores || {};
    function num(v) { var n = Number(v); return isNaN(n) ? null : n; }

    var relevance = num(scores.relevance);
    var faithfulness = num(scores.faithfulness);
    var instructionCompliance = num(scores.instructionCompliance);
    var semanticCloseness = num(scores.semanticCloseness);

    if (relevance === null || faithfulness === null || instructionCompliance === null || semanticCloseness === null) {
      errors.push('one or more score fields missing or non-numeric: ' + JSON.stringify(scores));
    }

    var pass = errors.length === 0
      && relevance >= 4
      && faithfulness >= 4
      && instructionCompliance >= 4
      && semanticCloseness >= 4;

    return {
      pass: pass,
      scores: scores,
      issues: input.issues || [],
      summary: input.summary || '',
      errors: errors
    };
  }
})
