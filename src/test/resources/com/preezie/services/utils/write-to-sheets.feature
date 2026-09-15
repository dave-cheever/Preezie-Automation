Feature: Write test results to Google Sheets

Scenario: Append results to Google Sheets
  * def spreadsheetId = __arg.spreadsheetId
  * def testResults = __arg.testResults
  * def timestamp = __arg.timestamp
  
  * karate.log('📝 Writing', testResults.length, 'test results to Google Sheets...')
  
  # Prepare rows for Google Sheets
  * def rows = []
  * def header = ['Timestamp', 'Tenant', 'TenantId', 'Message', 'TraceId', 'Status', 'Result', 'Intent', 'Pipeline Validation', 'Anomalies & Issues', 'Response Quality Assessment', 'Error Details']
  * eval rows.push(header)
  
  * eval
    """
    for (var i = 0; i < testResults.length; i++) {
      var test = testResults[i];
      var row = [
        timestamp,
        test.tenant || '',
        test.tenantId || '',
        test.content || '',
        test.traceId || 'N/A',
        test.status || 'UNKNOWN',
        test.result || '',
        test.intent || '',
        test.pipelineValidation || '',
        test.anomalies || '',
        test.qualityAssessment || '',
        test.errorDetails || ''
      ];
      rows.push(row);
    }
    """
  
  # Build the Google Sheets API URL
  * def sheetsApiUrl = 'https://sheets.googleapis.com/v4/spreadsheets/' + spreadsheetId + '/values/results:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS'
  
  # Check if we have credentials
  * def serviceAccountJson = karate.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  
  # If no service account, just log and skip
  * if (!serviceAccountJson) karate.log('⚠️  No GOOGLE_SERVICE_ACCOUNT_JSON configured. Skipping Google Sheets write. Results are in target/test-results.csv')
  * if (!serviceAccountJson) karate.abort()
  
  # Get access token (this would require JWT signing - for now we'll use a simpler approach)
  * karate.log('Note: Google Sheets API write requires OAuth2 setup')
  * karate.log('For now, please import target/test-results.csv manually into Google Sheets')
  * karate.abort()
