// google-sheets-reader.js
// Reads data from a published Google Spreadsheet
// Karate-compatible IIFE pattern

(function() {

  function fetchSheetAsCsv(spreadsheetId, sheetName) {
    var url = 'https://docs.google.com/spreadsheets/d/' + spreadsheetId + '/gviz/tq?tqx=out:csv&sheet=' + encodeURIComponent(sheetName);

    try {
      var URL = Java.type('java.net.URL');
      var BufferedReader = Java.type('java.io.BufferedReader');
      var InputStreamReader = Java.type('java.io.InputStreamReader');
      var StandardCharsets = Java.type('java.nio.charset.StandardCharsets');

      var connection = new URL(url).openConnection();
      connection.setRequestMethod('GET');
      connection.setConnectTimeout(10000);
      connection.setReadTimeout(10000);

      var reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), StandardCharsets.UTF_8));
      var lines = [];
      var line;
      while ((line = reader.readLine()) !== null) {
        lines.push('' + line);
      }
      reader.close();

      return lines;
    } catch (e) {
      karate.log('ERROR fetching Google Sheet:', e);
      return [];
    }
  }

  function parseCsvLine(line) {
    var result = [];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      var c = line.charAt(i);

      if (c === '"') {
        if (inQuotes && i + 1 < line.length && line.charAt(i + 1) === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c === ',' && !inQuotes) {
        result.push(current.trim());
        current = '';
      } else {
        current += c;
      }
    }
    result.push(current.trim());

    return result;
  }

  function csvToObjects(lines) {
    if (!lines || lines.length < 2) return [];

    var headers = parseCsvLine(lines[0]);
    var objects = [];

    for (var i = 1; i < lines.length; i++) {
      var values = parseCsvLine(lines[i]);
      if (values.length === 0 || (values.length === 1 && values[0] === '')) continue;

      var obj = {};
      for (var j = 0; j < headers.length; j++) {
        var header = headers[j];
        var value = j < values.length ? values[j] : '';

        if (typeof value === 'string') {
          var lowerVal = value.toLowerCase();
          if (lowerVal === 'true') value = true;
          else if (lowerVal === 'false') value = false;
        }

        obj[header] = value;
      }
      objects.push(obj);
    }

    return objects;
  }

  function getTenantConfig(spreadsheetId) {
    var lines = fetchSheetAsCsv(spreadsheetId, 'tenantConfig');
    var configs = csvToObjects(lines);

    var enabledTenants = [];
    for (var i = 0; i < configs.length; i++) {
      var cfg = configs[i];
      if (cfg.enabled === true || cfg.enabled === 'TRUE' || cfg.enabled === 'true') {
        enabledTenants.push(cfg);
      }
    }

    karate.log('Loaded tenant configs from Google Sheets:', configs.length, 'total,', enabledTenants.length, 'enabled');
    return enabledTenants;
  }

  function getTestDataForTenant(spreadsheetId, sheetName) {
    var lines = fetchSheetAsCsv(spreadsheetId, sheetName);
    var testData = csvToObjects(lines);

    var enabledTests = [];
    for (var i = 0; i < testData.length; i++) {
      var row = testData[i];
      if (row.enabled === true || row.enabled === 'TRUE' || row.enabled === 'true') {
        enabledTests.push(row);
      }
    }

    karate.log('Loaded test data for', sheetName + ':', testData.length, 'total,', enabledTests.length, 'enabled');
    return enabledTests;
  }

  function getConfigValues(spreadsheetId) {
    // Read key-value pairs from 'config' sheet
    var lines = fetchSheetAsCsv(spreadsheetId, 'config');
    var configObj = {};

    if (lines && lines.length > 1) {
      // Expecting columns: key, value
      for (var i = 1; i < lines.length; i++) {
        var values = parseCsvLine(lines[i]);
        if (values.length >= 2 && values[0]) {
          var key = values[0].trim();
          var val = values[1] ? values[1].trim() : '';
          configObj[key] = val;
        }
      }
    }

    karate.log('Loaded config values from Google Sheets:', JSON.stringify(configObj));
    return configObj;
  }

  function getAllEnabledTestData(spreadsheetId) {
    var tenants = getTenantConfig(spreadsheetId);
    var allTestData = [];

    // Get global config values (sessionId, visitorId, etc.)
    var globalConfig = getConfigValues(spreadsheetId);
    var sessionId = globalConfig.sessionId || null;
    var visitorId = globalConfig.VisitorId || globalConfig.visitorId || null;

    karate.log('Using sessionId from config:', sessionId);
    karate.log('Using visitorId from config:', visitorId);

    for (var i = 0; i < tenants.length; i++) {
      var tenant = tenants[i];
      var sheetName = tenant.dataFile || tenant.tenantName;
      if (sheetName && sheetName.indexOf('.csv') > -1) {
        sheetName = sheetName.replace('.csv', '');
      }
      var testData = getTestDataForTenant(spreadsheetId, sheetName);

      for (var j = 0; j < testData.length; j++) {
        var row = testData[j];
        row.tenantId = tenant.tenantId;
        row.tenantName = tenant.tenantName;
        // Add sessionId and visitorId from config sheet
        row.sessionId = sessionId;
        row.visitorId = visitorId;
        allTestData.push(row);
      }
    }

    karate.log('Total enabled test cases:', allTestData.length);
    return allTestData;
  }

  return {
    fetchSheetAsCsv: fetchSheetAsCsv,
    parseCsvLine: parseCsvLine,
    csvToObjects: csvToObjects,
    getTenantConfig: getTenantConfig,
    getTestDataForTenant: getTestDataForTenant,
    getAllEnabledTestData: getAllEnabledTestData,
    getConfigValues: getConfigValues
  };

})()
