Feature: print usage summary (debug)

Scenario: print totals and averages
  * eval
    """
    var File = Java.type('java.io.File');
    var Files = Java.type('java.nio.file.Files');
    var Paths = Java.type('java.nio.file.Paths');
    var CostReportGenerator = Java.type('com.preezie.llm.cost.CostReportGenerator');
    var path = java.lang.System.getProperty('user.dir') + '/target/usage.csv';
    var f = new File(path);
    karate.log('Checking usage file at', path, 'exists=', f.exists());
    if (!f.exists()) {
      karate.log('No usage file found at', path);
    } else {
      // Use CostReportGenerator for proper cost calculation
      try {
        CostReportGenerator.generateReport(path);
      } catch (e) {
        karate.log('CostReportGenerator error:', e.message || e);
      }

      // Also show raw data for debugging
      var content = new java.lang.String(Files.readAllBytes(Paths.get(path)), java.nio.charset.StandardCharsets.UTF_8);
      karate.log('====== RAW USAGE FILE ======');
      karate.log(content);
      karate.log('============================');

      // Manual calculation as backup
      var lines = content.split(/\\r?\\n/);
      var totals = {runs:0, prompt:0, completion:0, total:0, inputCost:0, outputCost:0, totalCost:0};
      for (var i=1; i<lines.length; i++){
        if (!lines[i]) continue;
        var cols = lines[i].split(',');
        if (cols.length >= 11) {
          totals.runs++;
          totals.prompt += parseInt(cols[3]||0);
          totals.completion += parseInt(cols[4]||0);
          totals.total += parseInt(cols[5]||0);
          totals.inputCost += parseFloat(cols[8]||0);
          totals.outputCost += parseFloat(cols[9]||0);
          totals.totalCost += parseFloat(cols[10]||0);
        }
      }
      if (totals.runs === 0) {
        karate.log('No usage rows found (maybe header only)');
      } else {
        var avg = function(v){ return Math.round((v / totals.runs) * 100) / 100; };
        karate.log('========== USAGE SUMMARY ===========');
        karate.log('Total Runs:', totals.runs);
        karate.log('Totals: prompt_tokens=' + totals.prompt + ', completion_tokens=' + totals.completion + ', total_tokens=' + totals.total);
        karate.log('Costs: input=$' + totals.inputCost.toFixed(6) + ', output=$' + totals.outputCost.toFixed(6) + ', TOTAL=$' + totals.totalCost.toFixed(6));
        karate.log('Averages per Run: prompt=' + avg(totals.prompt) + ', completion=' + avg(totals.completion) + ', total=' + avg(totals.total));
        karate.log('Average Cost per Run: $' + (totals.totalCost / totals.runs).toFixed(6));
        karate.log('====================================');
      }
    }
    """