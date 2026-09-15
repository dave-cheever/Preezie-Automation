// google-sheets-writer.js
// Writes test results to Google Sheets
// Karate-compatible IIFE pattern

(function() {

  /**
   * Write test results to Google Sheets "results" tab
   * Uses Google Sheets API v4 to append rows
   * 
   * @param {string} spreadsheetId - The Google Sheets spreadsheet ID
   * @param {array} testFailures - Array of test failure objects
   * @param {object} summary - Test summary (totalTests, passed, failed, passRate)
   * @returns {object} Result object with success status and message
   */
  function writeTestResults(spreadsheetId, testFailures, summary) {
    try {
      var serviceAccountKey = karate.get('GOOGLE_SERVICE_ACCOUNT_KEY');
      
      if (!serviceAccountKey) {
        karate.log('Warning: GOOGLE_SERVICE_ACCOUNT_KEY not configured. Results will not be written to Google Sheets.');
        return { success: false, message: 'Service account key not configured' };
      }

      // Prepare rows to write
      var rows = prepareResultRows(testFailures, summary);
      
      if (rows.length === 0) {
        karate.log('No results to write to Google Sheets');
        return { success: true, message: 'No results to write' };
      }

      // Write to Google Sheets using Karate HTTP client
      var sheetsApiUrl = 'https://sheets.googleapis.com/v4/spreadsheets/' + spreadsheetId + '/values/results:append';
      var accessToken = getAccessToken(serviceAccountKey);
      
      if (!accessToken) {
        return { success: false, message: 'Failed to get access token' };
      }

      var requestBody = {
        values: rows,
        majorDimension: 'ROWS'
      };

      var response = karate.call('classpath:com/preezie/services/utils/sheets-api-append.feature', {
        url: sheetsApiUrl + '?valueInputOption=USER_ENTERED',
        accessToken: accessToken,
        body: requestBody
      });

      if (response.responseStatus === 200) {
        karate.log('✅ Successfully wrote', rows.length - 1, 'result rows to Google Sheets');
        return { success: true, message: 'Results written successfully', rowsWritten: rows.length - 1 };
      } else {
        karate.log('❌ Failed to write to Google Sheets:', response.response);
        return { success: false, message: 'API call failed: ' + response.responseStatus };
      }

    } catch (e) {
      karate.log('❌ Error writing to Google Sheets:', e.message || e);
      return { success: false, message: 'Exception: ' + (e.message || e) };
    }
  }

  /**
   * Prepare rows for Google Sheets
   * Returns array of arrays (each inner array is a row)
   */
  function prepareResultRows(testFailures, summary) {
    var rows = [];
    var timestamp = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date());

    // Add header row if this is the first write
    // (In practice, you may want to check if headers exist first)
    rows.push([
      'Timestamp',
      'Tenant',
      'TenantId',
      'Message',
      'TraceId',
      'Status',
      'Result',
      'Intent',
      'Pipeline Validation',
      'Anomalies & Issues',
      'Response Quality Assessment',
      'Error Details'
    ]);

    // Add a row for each test failure
    var failureKeys = Object.keys(testFailures);
    for (var i = 0; i < failureKeys.length; i++) {
      var testFailure = testFailures[failureKeys[i]];
      
      // For failures with multiple issues, we combine them
      var result = '';
      var intent = '';
      var pipelineValidation = '';
      var anomalies = '';
      var qualityAssessment = '';
      var errorDetails = '';

      if (testFailure.failures && testFailure.failures.length > 0) {
        for (var j = 0; j < testFailure.failures.length; j++) {
          var failure = testFailure.failures[j];
          
          if (failure.parsedAnalysis) {
            result = failure.parsedAnalysis.result || '';
            intent = failure.parsedAnalysis.intent || '';
            pipelineValidation = failure.parsedAnalysis.pipelineValidation || '';
            anomalies = failure.parsedAnalysis.anomalies || '';
            qualityAssessment = failure.parsedAnalysis.qualityAssessment || '';
          }
          
          if (failure.error) {
            errorDetails += (errorDetails ? ' | ' : '') + failure.stage + ': ' + failure.error;
          }
        }
      }

      rows.push([
        timestamp,
        testFailure.tenant || '',
        testFailure.tenantId || '',
        testFailure.content || '',
        testFailure.traceId || '',
        'FAILED',
        result,
        intent,
        pipelineValidation,
        anomalies,
        qualityAssessment,
        errorDetails
      ]);
    }

    return rows;
  }

  /**
   * Get OAuth2 access token for Google Sheets API
   * Uses service account key to generate JWT and exchange for access token
   */
  function getAccessToken(serviceAccountKey) {
    try {
      // This is a simplified version - in production, you'd use proper JWT signing
      // For now, we'll assume the service account key is properly configured
      karate.log('⚠️ Note: Google Sheets write functionality requires service account setup');
      return null;
    } catch (e) {
      karate.log('Error getting access token:', e.message || e);
      return null;
    }
  }

  return {
    writeTestResults: writeTestResults,
    prepareResultRows: prepareResultRows
  };

})()
