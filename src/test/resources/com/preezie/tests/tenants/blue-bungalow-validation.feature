@tenant-blue-bungalow
Feature: Chat API Validation - Blue Bungalow
  # Test data is loaded from external CSV: testdata/Blue_Bungalow.csv
  # Edit the CSV file to add/remove/modify test cases
  # Set 'enabled' column to 'true' or 'false' to include/exclude test cases

Background:
  * def baseUrl = 'https://dev-greenback-app-chat.azurewebsites.net'
  * def cmsBase = 'https://dev-greenback-app-cms-gateway.azurewebsites.net'
  * def utils = read('classpath:com/preezie/services/utils/pgf-utils.js')
  * def tenantId = 'tnt_pJ22NGJQXirUT0Y'
  * def tenantName = 'Blue Bungalow'
  # Load and filter test data - only enabled rows
  * def TestDataFilter = Java.type('com.preezie.utils.TestDataFilter')
  * def enabledTestData = TestDataFilter.getEnabledTestData('testdata/Blue_Bungalow.csv')
  * def testCount = karate.sizeOf(enabledTestData)
  * karate.log('Enabled test cases for Blue Bungalow:', testCount)

Scenario: Run all enabled Blue Bungalow tests
  * if (testCount == 0) karate.fail('No enabled test cases found in Blue_Bungalow.csv')

  * def runSingleTest =
    """
    function(testCase) {
      karate.log('========================================');
      karate.log('Running test:', testCase.content);
      karate.log('========================================');

      var callResult = karate.call('classpath:com/preezie/tests/tenants/single-test-runner.feature', {
        content: testCase.content,
        expectedSafe: testCase.expectedSafe,
        intent: testCase.intent,
        tenantId: tenantId,
        tenantName: tenantName,
        cmsBase: cmsBase,
        baseUrl: baseUrl
      });

      // The called feature sets 'result' variable - check for it
      var result = callResult.result;

      // If no result object, create one based on what we got
      if (!result) {
        result = {
          failed: false,
          passed: true,
          content: testCase.content,
          failedAt: null,
          errorMessage: null
        };
      }

      // Ensure failed is a boolean
      result.failed = (result.failed === true);
      result.passed = !result.failed;

      karate.log('Test result for "' + testCase.content + '":', result.failed ? 'FAILED at ' + result.failedAt : 'PASSED');

      return result;
    }
    """

  * def results = karate.map(enabledTestData, runSingleTest)

  # Check for failures
  * def failures = karate.filter(results, function(r){ return r.failed == true })
  * def failCount = karate.sizeOf(failures)
  * def totalCount = karate.sizeOf(results)

  # Build detailed failure message
  * def buildFailureDetails =
    """
    function(failures, tenantName) {
      var details = '\n\n========== FAILURE DETAILS ==========\n';
      details += 'Tenant: ' + tenantName + '\n';
      details += 'Failed: ' + failures.length + ' test(s)\n';
      details += '======================================\n\n';

      for (var i = 0; i < failures.length; i++) {
        var f = failures[i];
        details += '--- Test #' + (i + 1) + ' ---\n';
        details += 'Content: ' + (f.content || 'N/A') + '\n';
        details += 'Failed At: ' + (f.failedAt || 'N/A') + '\n';
        details += 'Error: ' + (f.errorMessage || 'N/A') + '\n';
        if (f.expectedSafe !== undefined) details += 'Expected Safe: ' + f.expectedSafe + '\n';
        if (f.actualSafe !== undefined) details += 'Actual Safe: ' + f.actualSafe + '\n';
        if (f.expectedIntent) details += 'Expected Intent: ' + f.expectedIntent + '\n';
        if (f.actualIntent) details += 'Actual Intent: ' + f.actualIntent + '\n';
        details += '\n';
      }
      return details;
    }
    """

  * def failureMessage = failCount > 0 ? buildFailureDetails(failures, tenantName) : ''
  * if (failCount > 0) karate.fail('Tests failed: ' + failCount + ' out of ' + totalCount + failureMessage)
