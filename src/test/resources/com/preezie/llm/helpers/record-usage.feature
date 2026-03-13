Feature: Record LLM Usage and Cost

Scenario: Record usage data with cost calculation
  * eval
    """
    var UsageData = Java.type('com.preezie.llm.cost.UsageData');
    var UsageCsvWriter = Java.type('com.preezie.llm.cost.UsageCsvWriter');
    var csvFilePath = java.lang.System.getProperty('user.dir') + '/target/usage.csv';

    // Strip quotes from tenantId and content if present
    var tenantId = ('' + (__arg.tenantId || '')).replace(/'/g, '').replace(/"/g, '').trim();
    var content = ('' + (__arg.content || '')).replace(/'/g, '').replace(/"/g, '').trim();

    var builder = new UsageData.Builder();
    builder.tenantId(tenantId);
    builder.content(content);
    builder.modelName(__arg.modelName || 'gpt-4');
    builder.promptTokens(__arg.promptTokens || 0);
    builder.completionTokens(__arg.completionTokens || 0);
    builder.totalTokens(__arg.totalTokens || 0);
    builder.cachedTokens(__arg.cachedTokens || 0);
    builder.audioTokens(__arg.audioTokens || 0);
    var usageDataObj = builder.build();

    var writer = new UsageCsvWriter(csvFilePath);
    writer.writeUsage(usageDataObj);
    var cost = usageDataObj.getTotalCost().doubleValue();
    karate.log('Usage recorded - Cost: $' + cost.toFixed(10));
    """
