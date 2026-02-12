// `src/test/resources/com/preezie/js/usage-report.js`

(function () {
  function toNumber(v) {
    return typeof v === 'number' && Number.isFinite(v) ? v : 0;
  }

  function addUsage(acc, usage) {
    var u = usage || {};
    var details = u.prompt_tokens_details || {};

    acc.runs += 1;

    acc.prompt_tokens += toNumber(u.prompt_tokens);
    acc.completion_tokens += toNumber(u.completion_tokens);
    acc.total_tokens += toNumber(u.total_tokens);

    acc.cached_tokens += toNumber(details.cached_tokens);
    acc.audio_tokens += toNumber(details.audio_tokens);

    return acc;
  }

  function finalize(acc) {
    var runs = acc.runs || 0;
    var div = function (n) { return runs > 0 ? n / runs : 0; };

    return {
      runs: runs,
      totals: {
        prompt_tokens: acc.prompt_tokens,
        completion_tokens: acc.completion_tokens,
        total_tokens: acc.total_tokens,
        cached_tokens: acc.cached_tokens,
        audio_tokens: acc.audio_tokens
      },
      averages_per_run: {
        prompt_tokens: div(acc.prompt_tokens),
        completion_tokens: div(acc.completion_tokens),
        total_tokens: div(acc.total_tokens),
        cached_tokens: div(acc.cached_tokens),
        audio_tokens: div(acc.audio_tokens)
      }
    };
  }

  function createUsageReporter() {
    var acc = {
      runs: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
      cached_tokens: 0,
      audio_tokens: 0
    };

    return {
      record: function (usage) { addUsage(acc, usage); },
      summary: function () { return finalize(Object.assign({}, acc)); }
    };
  }

  return { createUsageReporter: createUsageReporter };
})()
