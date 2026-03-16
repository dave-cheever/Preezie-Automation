// Filter CSV data to only return enabled rows
// Usage: * def filteredData = filterEnabled(karate.read('classpath:testdata/Blue_Bungalow.csv'))

function filterEnabled(csvData) {
  if (!csvData || !Array.isArray(csvData)) {
    return [];
  }

  var enabledRows = [];
  for (var i = 0; i < csvData.length; i++) {
    var row = csvData[i];
    // Check if enabled column is true (handles both string 'true' and boolean true)
    if (row.enabled === true || row.enabled === 'true') {
      enabledRows.push(row);
    }
  }

  karate.log('Filtered test data: ' + enabledRows.length + ' enabled out of ' + csvData.length + ' total');
  return enabledRows;
}

// Export
filterEnabled

