Feature: print usage summary (debug)

Scenario: print totals and averages
  * eval
    """
    var File = Java.type('java.io.File');
    var Files = Java.type('java.nio.file.Files');
    var Paths = Java.type('java.nio.file.Paths');
    var path = 'target/usage.csv';
    var f = new File(path);
    karate.log('Checking usage file at', path, 'exists=', f.exists());
    if (!f.exists()) {
      karate.log('No usage file found at', path);
    } else {
      var content = new java.lang.String(Files.readAllBytes(Paths.get(path)), java.nio.charset.StandardCharsets.UTF_8);
      karate.log('====== RAW USAGE FILE ======');
      karate.log(content);
      karate.log('============================');
      var lines = content.split(/\\r?\\n/);
      var totals = {runs:0, prompt:0, completion:0, total:0};
      for (var i=1;i<lines.length;i++){
        if (!lines[i]) continue;
        var cols = lines[i].split(',');
        totals.runs++;
        totals.prompt += parseInt(cols[2]||0);
        totals.completion += parseInt(cols[3]||0);
        totals.total += parseInt(cols[4]||0);
      }
      if (totals.runs === 0) {
        karate.log('No usage rows found (maybe header only)');
      } else {
        var avg = function(v){ return Math.round((v / totals.runs) * 100) / 100; };
        karate.log('========== USAGE SUMMARY ===========');
        karate.log('Total Runs:', totals.runs);
        karate.log('Totals: prompt_tokens=' + totals.prompt + ', completion_tokens=' + totals.completion + ', total_tokens=' + totals.total);
        karate.log('Averages per Run: prompt=' + avg(totals.prompt) + ', completion=' + avg(totals.completion) + ', total=' + avg(totals.total));
        karate.log('====================================');
      }
    }
    """