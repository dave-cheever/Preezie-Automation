Feature: record usage to file

Scenario: append usage line
  * def usage = __arg.usage
  * def tenantId = __arg.tenantId
  * def content = __arg.content
  * eval karate.log('Usage object inside record-usage:', JSON.stringify(usage));
  * eval
    """
    var u = usage || {};
    print('printing u: ', JSON.stringify(u));
    var p = u.prompt_tokens;
    print('prompt tokens:', JSON.stringify(p));
    var c = u.completion_tokens;
    print('completion tokens:', JSON.stringify(c));
    var t = u.total_tokens;
    print('total tokens:', JSON.stringify(t));
    var safeContent = (content || '').replace(/\\r?\\n/g, ' ').replace(/,/g,';');
    var line = tenantId + ',' + safeContent + ',' + p + ',' + c + ',' + t + '\\n';
    var File = Java.type('java.io.File');
    var FileWriter = Java.type('java.io.FileWriter');
    var file = new File('target/usage.csv');
    if (!file.exists()) {
      file.getParentFile().mkdirs();
      var headerWriter = new FileWriter(file);
      headerWriter.write('tenantId,content,prompt_tokens,completion_tokens,total_tokens\\n');
      headerWriter.close();
    }
    var fw = new FileWriter(file, true);
    fw.write(line);
    fw.close();
    karate.log('Appended usage:', line);
    """