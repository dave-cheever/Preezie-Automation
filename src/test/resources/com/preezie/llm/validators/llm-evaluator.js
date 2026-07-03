// File: `src/test/resources/com/preezie/llm/validators/llm-evaluator.js`
//
// Karate `read()` returns the value of the last expression in the file.
// Export an object whose member is an inline function (no scope issues).
({
  validateLLMResponse: function (input) {
    var errors = [];
    var severity = 'fail';
    var warnings = [];

    if (!input) {
      errors.push('missing input object');
      return { pass: false, severity: severity, warnings: warnings, scores: {}, issues: [], summary: '', errors: errors };
    }

    if (input.choices && input.choices.length > 0) {
      var first = input.choices[0] || {};
      var msg = first.message || {};
      var content = msg.content || first.text || '';
      if (!String(content).trim()) errors.push('missing content in choices[0]');
      severity = errors.length === 0 ? 'pass' : 'fail';
      return { pass: errors.length === 0, severity: severity, warnings: warnings, content: content, errors: errors };
    }

    var scores = input.scores || {};
    function num(v) { var n = Number(v); return isNaN(n) ? null : n; }

    var relevance = num(scores.relevance);
    var faithfulness = num(scores.faithfulness);
    var instructionCompliance = num(scores.instructionCompliance);
    var semanticCloseness = num(scores.semanticCloseness);
    var looksLikeFivePointScale = relevance !== null && faithfulness !== null && instructionCompliance !== null && semanticCloseness !== null
      && relevance <= 5 && faithfulness <= 5 && instructionCompliance <= 5 && semanticCloseness <= 5;

    if (relevance === null || faithfulness === null || instructionCompliance === null || semanticCloseness === null) {
      errors.push('one or more score fields missing or non-numeric: ' + JSON.stringify(scores));
    }

    var pass = errors.length === 0
      && relevance >= 4
      && faithfulness >= 4
      && instructionCompliance >= 4
      && semanticCloseness >= 4;

    if (input.severity === 'warning') {
      severity = 'warning';
      pass = true;
    } else if (input.severity === 'pass') {
      severity = 'pass';
    } else {
      if (looksLikeFivePointScale
        && relevance >= 4
        && faithfulness >= 4
        && semanticCloseness >= 4
        && instructionCompliance >= 2
        && instructionCompliance < 4) {
        severity = 'warning';
        pass = true;
      } else {
        severity = pass ? 'pass' : 'fail';
      }
    }

    if (Array.isArray(input.warnings)) {
      warnings = input.warnings;
    }

    return {
      pass: pass,
      severity: severity,
      warnings: warnings,
      scores: scores,
      issues: input.issues || [],
      summary: input.summary || '',
      errors: errors
    };
  }
})
