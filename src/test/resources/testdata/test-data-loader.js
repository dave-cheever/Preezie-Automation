// Test data loader helper for Karate
// Reads CSV files per tenant and merges with tenant configuration

function loadTestData() {
  var tenantConfig = karate.read('classpath:testdata/tenant-config.json');
  var allTestData = [];

  for (var i = 0; i < tenantConfig.tenants.length; i++) {
    var tenant = tenantConfig.tenants[i];

    // Skip disabled tenants
    if (!tenant.enabled) {
      karate.log('Skipping disabled tenant:', tenant.tenantName);
      continue;
    }

    try {
      // Read the CSV file for this tenant
      var csvData = karate.read('classpath:testdata/' + tenant.dataFile);

      // Add tenant info to each row
      for (var j = 0; j < csvData.length; j++) {
        var row = csvData[j];
        allTestData.push({
          tenantId: tenant.tenantId,
          tenantName: tenant.tenantName.replace(/_/g, ' '), // Convert underscores to spaces for display
          content: row.content,
          expectedSafe: row.expectedSafe === 'true' || row.expectedSafe === true,
          intent: row.intent
        });
      }

      karate.log('Loaded', csvData.length, 'test cases for tenant:', tenant.tenantName);
    } catch (e) {
      karate.log('WARNING: Could not load data for tenant:', tenant.tenantName, e);
    }
  }

  karate.log('Total test cases loaded:', allTestData.length);
  return allTestData;
}

function loadTestDataForTenant(tenantName) {
  var tenantConfig = karate.read('classpath:testdata/tenant-config.json');
  var testData = [];

  for (var i = 0; i < tenantConfig.tenants.length; i++) {
    var tenant = tenantConfig.tenants[i];

    if (tenant.tenantName === tenantName || tenant.tenantName.replace(/_/g, ' ') === tenantName) {
      try {
        var csvData = karate.read('classpath:testdata/' + tenant.dataFile);

        for (var j = 0; j < csvData.length; j++) {
          var row = csvData[j];
          testData.push({
            tenantId: tenant.tenantId,
            tenantName: tenant.tenantName.replace(/_/g, ' '),
            content: row.content,
            expectedSafe: row.expectedSafe === 'true' || row.expectedSafe === true,
            intent: row.intent
          });
        }

        karate.log('Loaded', csvData.length, 'test cases for tenant:', tenantName);
      } catch (e) {
        karate.log('WARNING: Could not load data for tenant:', tenantName, e);
      }
      break;
    }
  }

  return testData;
}

function getTenantConfig() {
  return karate.read('classpath:testdata/tenant-config.json');
}

function getEnabledTenants() {
  var config = karate.read('classpath:testdata/tenant-config.json');
  var enabled = [];
  for (var i = 0; i < config.tenants.length; i++) {
    if (config.tenants[i].enabled) {
      enabled.push(config.tenants[i]);
    }
  }
  return enabled;
}

// Export functions
({
  loadTestData: loadTestData,
  loadTestDataForTenant: loadTestDataForTenant,
  getTenantConfig: getTenantConfig,
  getEnabledTenants: getEnabledTenants
})

