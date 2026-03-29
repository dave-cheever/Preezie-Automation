Feature: Debug Usage Recording

Scenario: Test usage CSV writing
  * print '=== STARTING DEBUG USAGE TEST ==='

  * eval
    """
    karate.log('=== Testing Java type loading ===');
    try {
      var UsageData = Java.type('com.preezie.llm.cost.UsageData');
      karate.log('UsageData loaded successfully');

      var UsageCsvWriter = Java.type('com.preezie.llm.cost.UsageCsvWriter');
      karate.log('UsageCsvWriter loaded successfully');

      var File = Java.type('java.io.File');
      var csvFilePath = java.lang.System.getProperty('user.dir') + File.separator + 'target' + File.separator + 'usage.csv';
      karate.log('CSV Path:', csvFilePath);

      var builder = new UsageData.Builder();
      builder.tenantId('test-tenant');
      builder.content('test-content');
      builder.modelName('gpt-4.1');
      builder.promptTokens(100);
      builder.completionTokens(50);
      builder.totalTokens(150);
      builder.cachedTokens(0);
      builder.audioTokens(0);
      var usageDataObj = builder.build();
      karate.log('UsageData object built successfully');

      var writer = new UsageCsvWriter(csvFilePath);
      karate.log('UsageCsvWriter created');

      writer.writeUsage(usageDataObj);
      karate.log('=== USAGE WRITTEN SUCCESSFULLY to:', csvFilePath, '===');
    } catch (e) {
      karate.log('ERROR:', e);
      karate.log('ERROR message:', e.message);
    }
    """

  * print '=== DEBUG USAGE TEST COMPLETED ==='

