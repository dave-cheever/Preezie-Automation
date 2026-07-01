package com.preezie.runner;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.preezie.llm.cost.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Test runner for Google Sheets data-driven tests.
 * 
 * The test data is loaded from a Google Spreadsheet.
 * Make sure the spreadsheet is published to web (File > Share > Publish to web)
 * 
 * Configure the spreadsheet ID via:
 *   - Environment variable: GOOGLE_SHEETS_ID
 *   - System property: -DgoogleSheetsId=YOUR_SPREADSHEET_ID
 *   - .env file: GOOGLE_SHEETS_ID=YOUR_SPREADSHEET_ID
 *   - karate-config.js default value
 * 
 * Required Sheets in the Spreadsheet:
 *   - tenantConfig: columns [tenantName, tenantId, dataFile, enabled]
 *   - config: columns [key, value] (for sessionId, VisitorId, etc.)
 *   - {TenantName}: columns [content, expectedSafe, intent, enabled]
 *   - Results: (output) Test results will be written here
 * 
 * To write results to Google Sheets, you need:
 *   - A Google Cloud Service Account with Sheets API enabled
 *   - Set GOOGLE_APPLICATION_CREDENTIALS env var to the JSON credentials file path
 *   - Share the spreadsheet with the service account email (as Editor)
 */
public class GoogleSheetsTestRunner {

    private static final String TEST_RESULTS_JSON = "target/test-results.json";
    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void runGoogleSheetsTests() {
        // Load .env file and set GOOGLE_APPLICATION_CREDENTIALS if not already set
        loadEnvironmentVariables();
        
        // Delete existing usage.csv for a clean report
        String usageCsvPath = System.getProperty("user.dir") + File.separator + "target" + File.separator + "usage.csv";
        try {
            Files.deleteIfExists(Paths.get(usageCsvPath));
            System.out.println("Cleared previous usage.csv for clean report");
        } catch (IOException e) {
            System.out.println("Warning: Could not delete usage.csv: " + e.getMessage());
        }
        
        // Run the Karate tests
        Results results = Runner.path("classpath:com/preezie/tests/chat-google-sheets-validation.feature")
                .outputCucumberJson(true)
                .parallel(1);
        
        // Get spreadsheet ID from environment or system property
        String spreadsheetId = System.getenv("GOOGLE_SHEETS_ID");
        if (spreadsheetId == null || spreadsheetId.isEmpty()) {
            spreadsheetId = System.getProperty("googleSheetsId", "1FV7pekpUKZ34VjDXuoslernJuGnx3jsjxJI5WkYsHVM");
        }
        
        // Read actual test results from JSON file (written by the feature file)
        TestResultsData actualResults = readTestResultsFromJson();
        
        // Print test results summary to console (using actual counts)
        printResultsSummary(actualResults);
        
        // Generate cost summary from usage.csv
        CostCalculator.CostSummary costSummary = generateCostSummary(usageCsvPath);
        
        // Write results to Google Sheets (using actual counts and error details)
        writeResultsToGoogleSheets(actualResults, costSummary, spreadsheetId, usageCsvPath);
        
        // Assert test results - use actual failed count from JSON
        int actualFailCount = actualResults != null ? actualResults.failed : results.getFailCount();
        assertEquals(0, actualFailCount, 
            actualResults != null ? actualResults.failed + " test case(s) failed" : results.getErrorMessages());
    }
    
    /**
     * Data class to hold test results from JSON
     */
    static class TestResultsData {
        int totalTests;
        int passed;
        int failed;
        int passRate;
        List<FailedTestCase> failedTestCases = new ArrayList<>();
    }
    
    static class FailedTestCase {
        String tenantId;
        String tenantName;
        String content;
        String traceId;
        List<AgentFailure> agentFailures = new ArrayList<>();
    }
    
    static class AgentFailure {
        String failedStage;
        String expected;
        String actual;
        String errorMessage;
        String responseLLM;
        String result;
        String intent;
        String pipelineValidation;
        String anomalies;
        String qualityAssessment;
    }
    
    private TestResultsData readTestResultsFromJson() {
        try {
            File jsonFile = new File(System.getProperty("user.dir") + "/" + TEST_RESULTS_JSON);
            if (!jsonFile.exists()) {
                System.out.println("Warning: test-results.json not found, using Karate results");
                return null;
            }
            
            JsonNode root = objectMapper.readTree(jsonFile);
            TestResultsData data = new TestResultsData();
            data.totalTests = root.path("totalTests").asInt(0);
            data.passed = root.path("passed").asInt(0);
            data.failed = root.path("failed").asInt(0);
            data.passRate = root.path("passRate").asInt(0);
            
            // Read "failures" array (not "errors") - matches what the feature file writes
            JsonNode failuresNode = root.path("failures");
            if (failuresNode.isArray()) {
                for (JsonNode failureNode : failuresNode) {
                    // Create a test case for each failure
                    FailedTestCase testCase = new FailedTestCase();
                    testCase.tenantId = failureNode.path("tenantId").asText("");
                    testCase.tenantName = failureNode.path("tenantName").asText("Unknown");
                    testCase.content = failureNode.path("content").asText("");
                    testCase.traceId = failureNode.path("traceId").asText("N/A");
                    
                    // Each test case contains multiple failures (new structure)
                    JsonNode failuresArrayNode = failureNode.path("failures");
                    if (failuresArrayNode.isArray()) {
                        for (JsonNode failure : failuresArrayNode) {
                            AgentFailure agentFail = new AgentFailure();
                            agentFail.failedStage = failure.path("stage").asText("");
                            agentFail.errorMessage = failure.path("error").asText("");
                            // Read analyser details
                            agentFail.result = failure.path("result").asText("");
                            agentFail.intent = failure.path("intent").asText("");
                            agentFail.pipelineValidation = failure.path("pipelineValidation").asText("");
                            agentFail.anomalies = failure.path("anomalies").asText("");
                            agentFail.qualityAssessment = failure.path("qualityAssessment").asText("");
                            testCase.agentFailures.add(agentFail);
                        }
                    }
                    
                    data.failedTestCases.add(testCase);
                }
            }
            
            System.out.println("✅ Read actual test results from: " + TEST_RESULTS_JSON);
            return data;
            
        } catch (Exception e) {
            System.out.println("Warning: Could not read test-results.json: " + e.getMessage());
            return null;
        }
    }
    
    private void printResultsSummary(TestResultsData actualResults) {
        if (actualResults == null) {
            System.out.println("\n⚠️  No detailed test results available");
            return;
        }
        
        System.out.println("\n");
        System.out.println("╔══════════════════════════════════════════════════════════════╗");
        System.out.println("║                    TEST RESULTS SUMMARY                       ║");
        System.out.println("╠══════════════════════════════════════════════════════════════╣");
        System.out.println("║  Total Test Cases: " + padRight(String.valueOf(actualResults.totalTests), 40) + "║");
        System.out.println("║  Passed:           " + padRight(String.valueOf(actualResults.passed), 40) + "║");
        System.out.println("║  Failed:           " + padRight(String.valueOf(actualResults.failed), 40) + "║");
        System.out.println("║  Pass Rate:        " + padRight(actualResults.passRate + "%", 40) + "║");
        System.out.println("╚══════════════════════════════════════════════════════════════╝");
        
        // Print failed test details
        if (!actualResults.failedTestCases.isEmpty()) {
            System.out.println("\n");
            System.out.println("╔══════════════════════════════════════════════════════════════╗");
            System.out.println("║                    FAILED TESTS DETAILS                       ║");
            System.out.println("╚══════════════════════════════════════════════════════════════╝");
            
            for (int i = 0; i < actualResults.failedTestCases.size(); i++) {
                FailedTestCase testCase = actualResults.failedTestCases.get(i);
                System.out.println("\n--- Failure " + (i + 1) + " of " + actualResults.failedTestCases.size() + " ---");
                System.out.println("  Tenant:      " + testCase.tenantName + " (" + testCase.tenantId + ")");
                System.out.println("  Content:     " + testCase.content);
                System.out.println("  Trace ID:    " + testCase.traceId);
                
                // Display all failed agents for this test case
                for (AgentFailure agentFail : testCase.agentFailures) {
                    System.out.println("  Failed At:   " + agentFail.failedStage);
                    if (agentFail.expected != null && !agentFail.expected.isEmpty()) {
                        System.out.println("  Expected:    " + agentFail.expected);
                        System.out.println("  Actual:      " + agentFail.actual);
                    }
                    if (agentFail.errorMessage != null && !agentFail.errorMessage.isEmpty()) {
                        System.out.println("  Error:       " + agentFail.errorMessage);
                    }
                    // Display analyser details if available
                    if (agentFail.result != null && !agentFail.result.isEmpty()) {
                        System.out.println("  Result:      " + agentFail.result);
                    }
                    if (agentFail.intent != null && !agentFail.intent.isEmpty()) {
                        System.out.println("  Intent:      " + agentFail.intent);
                    }
                    // Add blank line between agents if not the last one
                    if (testCase.agentFailures.indexOf(agentFail) < testCase.agentFailures.size() - 1) {
                        System.out.println();
                    }
                }
            }
            System.out.println("\n═══════════════════════════════════════════════════════════════");
        }
    }
    
    private CostCalculator.CostSummary generateCostSummary(String usageCsvPath) {
        try {
            List<UsageData> usageDataList = readUsageData(usageCsvPath);
            if (!usageDataList.isEmpty()) {
                CostCalculator calculator = new CostCalculator();
                CostCalculator.CostSummary summary = calculator.calculateSummary(usageDataList);
                
                // Print the detailed summary with three sections (getIntentSummary, getIntent, Combined)
                System.out.println("\n");
                System.out.println(summary.toString());
                
                return summary;
            } else {
                System.out.println("\n⚠️  No usage data found in: " + usageCsvPath);
            }
        } catch (Exception e) {
            System.out.println("Warning: Could not generate cost summary: " + e.getMessage());
        }
        return null;
    }
    
    private void writeResultsToGoogleSheets(TestResultsData actualResults, CostCalculator.CostSummary costSummary, 
                                           String spreadsheetId, String usageCsvPath) {
        // Check if Google Sheets writing is enabled
        // Support both: GOOGLE_CREDENTIALS_JSON (JSON content) or GOOGLE_APPLICATION_CREDENTIALS (file path)
        String credentialsJson = System.getenv("GOOGLE_CREDENTIALS_JSON");
        String credentialsPath = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
        if (credentialsPath == null || credentialsPath.isEmpty()) {
            credentialsPath = System.getProperty("google.credentials.path");
        }
        
        boolean hasCredentials = (credentialsJson != null && !credentialsJson.isEmpty()) 
                              || (credentialsPath != null && !credentialsPath.isEmpty());
        
        if (!hasCredentials) {
            System.out.println("\n⚠️  Google Sheets results export skipped (no credentials configured)");
            System.out.println("   To enable, set GOOGLE_CREDENTIALS_JSON env var with JSON content,");
            System.out.println("   or GOOGLE_APPLICATION_CREDENTIALS env var with file path.");
            return;
        }
        
        if (actualResults == null) {
            System.out.println("\n⚠️  Google Sheets results export skipped (no test results data)");
            return;
        }
        
        System.out.println("\n✅ Google credentials found, writing results to Google Sheets...");
        
        try {
            GoogleSheetsResultWriter writer = new GoogleSheetsResultWriter(spreadsheetId);
            
            // Build TestResults object with actual counts
            GoogleSheetsResultWriter.TestResults testResults = new GoogleSheetsResultWriter.TestResults();
            testResults.setTotalTests(actualResults.totalTests);
            testResults.setPassed(actualResults.passed);
            testResults.setFailed(actualResults.failed);
            
            // Add failed test details from actual results
            // Flatten the grouped structure for Google Sheets
            for (FailedTestCase testCase : actualResults.failedTestCases) {
                for (AgentFailure agentFail : testCase.agentFailures) {
                    GoogleSheetsResultWriter.FailedTest failedTest = new GoogleSheetsResultWriter.FailedTest(
                        testCase.tenantId,
                        testCase.tenantName,
                        testCase.content,
                        testCase.traceId,
                        agentFail.failedStage,
                        buildErrorMessage(agentFail)
                    );
                    // Add analyser details
                    failedTest.setResult(agentFail.result);
                    failedTest.setIntent(agentFail.intent);
                    failedTest.setPipelineValidation(agentFail.pipelineValidation);
                    failedTest.setAnomalies(agentFail.anomalies);
                    failedTest.setQualityAssessment(agentFail.qualityAssessment);
                    testResults.addFailedTest(failedTest);
                }
            }
            
            // Add cost summary if available
            if (costSummary != null) {
                GoogleSheetsResultWriter.CostSummary sheetsCostSummary = new GoogleSheetsResultWriter.CostSummary();
                sheetsCostSummary.setTotalRequests(costSummary.getTotalRequests());
                sheetsCostSummary.setTotalPromptTokens(costSummary.getTotalPromptTokens());
                sheetsCostSummary.setTotalCompletionTokens(costSummary.getTotalCompletionTokens());
                sheetsCostSummary.setTotalTokens(costSummary.getTotalTokens());
                sheetsCostSummary.setTotalInputCost(costSummary.getTotalInputCostDouble());
                sheetsCostSummary.setTotalOutputCost(costSummary.getTotalOutputCostDouble());
                sheetsCostSummary.setTotalCost(costSummary.getTotalCostDouble());
                sheetsCostSummary.setAverageCostPerRequest(costSummary.getAverageCostPerRequestDouble());
                sheetsCostSummary.setAvgPromptTokensPerRequest(costSummary.getAvgPromptTokens());
                sheetsCostSummary.setAvgCompletionTokensPerRequest(costSummary.getAvgCompletionTokens());
                
                // Add getIntentSummary breakdown
                CostCalculator.ValidationTypeSummary intentSummaryData = costSummary.getGetIntentSummarySummary();
                if (intentSummaryData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary intentSummaryCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    intentSummaryCost.setCount(intentSummaryData.getCount());
                    intentSummaryCost.setPromptTokens(intentSummaryData.getPromptTokens());
                    intentSummaryCost.setCompletionTokens(intentSummaryData.getCompletionTokens());
                    intentSummaryCost.setTotalTokens(intentSummaryData.getTotalTokens());
                    intentSummaryCost.setInputCost(intentSummaryData.getInputCost().doubleValue());
                    intentSummaryCost.setOutputCost(intentSummaryData.getOutputCost().doubleValue());
                    intentSummaryCost.setTotalCost(intentSummaryData.getTotalCost().doubleValue());
                    intentSummaryCost.setAvgCostPerRequest(intentSummaryData.getAvgCostPerRequest().doubleValue());
                    intentSummaryCost.setAvgPromptTokens(intentSummaryData.getAvgPromptTokens());
                    intentSummaryCost.setAvgCompletionTokens(intentSummaryData.getAvgCompletionTokens());
                    sheetsCostSummary.setIntentSummaryCost(intentSummaryCost);
                }
                
                // Add getIntent breakdown
                CostCalculator.ValidationTypeSummary intentData = costSummary.getGetIntentSummary();
                if (intentData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary intentCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    intentCost.setCount(intentData.getCount());
                    intentCost.setPromptTokens(intentData.getPromptTokens());
                    intentCost.setCompletionTokens(intentData.getCompletionTokens());
                    intentCost.setTotalTokens(intentData.getTotalTokens());
                    intentCost.setInputCost(intentData.getInputCost().doubleValue());
                    intentCost.setOutputCost(intentData.getOutputCost().doubleValue());
                    intentCost.setTotalCost(intentData.getTotalCost().doubleValue());
                    intentCost.setAvgCostPerRequest(intentData.getAvgCostPerRequest().doubleValue());
                    intentCost.setAvgPromptTokens(intentData.getAvgPromptTokens());
                    intentCost.setAvgCompletionTokens(intentData.getAvgCompletionTokens());
                    sheetsCostSummary.setIntentCost(intentCost);
                }
                
                // Add getCategories breakdown
                CostCalculator.ValidationTypeSummary categoriesData = costSummary.getGetCategoriesSummary();
                if (categoriesData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary categoriesCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    categoriesCost.setCount(categoriesData.getCount());
                    categoriesCost.setPromptTokens(categoriesData.getPromptTokens());
                    categoriesCost.setCompletionTokens(categoriesData.getCompletionTokens());
                    categoriesCost.setTotalTokens(categoriesData.getTotalTokens());
                    categoriesCost.setInputCost(categoriesData.getInputCost().doubleValue());
                    categoriesCost.setOutputCost(categoriesData.getOutputCost().doubleValue());
                    categoriesCost.setTotalCost(categoriesData.getTotalCost().doubleValue());
                    categoriesCost.setAvgCostPerRequest(categoriesData.getAvgCostPerRequest().doubleValue());
                    categoriesCost.setAvgPromptTokens(categoriesData.getAvgPromptTokens());
                    categoriesCost.setAvgCompletionTokens(categoriesData.getAvgCompletionTokens());
                    sheetsCostSummary.setCategoriesCost(categoriesCost);
                }
                
                // Add findProductFromPrompt breakdown
                CostCalculator.ValidationTypeSummary findProductData = costSummary.getGetFindProductSummary();
                if (findProductData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary findProductCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    findProductCost.setCount(findProductData.getCount());
                    findProductCost.setPromptTokens(findProductData.getPromptTokens());
                    findProductCost.setCompletionTokens(findProductData.getCompletionTokens());
                    findProductCost.setTotalTokens(findProductData.getTotalTokens());
                    findProductCost.setInputCost(findProductData.getInputCost().doubleValue());
                    findProductCost.setOutputCost(findProductData.getOutputCost().doubleValue());
                    findProductCost.setTotalCost(findProductData.getTotalCost().doubleValue());
                    findProductCost.setAvgCostPerRequest(findProductData.getAvgCostPerRequest().doubleValue());
                    findProductCost.setAvgPromptTokens(findProductData.getAvgPromptTokens());
                    findProductCost.setAvgCompletionTokens(findProductData.getAvgCompletionTokens());
                    sheetsCostSummary.setFindProductCost(findProductCost);
                }
                
                // Add smartResponse breakdown
                CostCalculator.ValidationTypeSummary smartResponseData = costSummary.getGetSmartResponseSummary();
                if (smartResponseData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary smartResponseCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    smartResponseCost.setCount(smartResponseData.getCount());
                    smartResponseCost.setPromptTokens(smartResponseData.getPromptTokens());
                    smartResponseCost.setCompletionTokens(smartResponseData.getCompletionTokens());
                    smartResponseCost.setTotalTokens(smartResponseData.getTotalTokens());
                    smartResponseCost.setInputCost(smartResponseData.getInputCost().doubleValue());
                    smartResponseCost.setOutputCost(smartResponseData.getOutputCost().doubleValue());
                    smartResponseCost.setTotalCost(smartResponseData.getTotalCost().doubleValue());
                    smartResponseCost.setAvgCostPerRequest(smartResponseData.getAvgCostPerRequest().doubleValue());
                    smartResponseCost.setAvgPromptTokens(smartResponseData.getAvgPromptTokens());
                    smartResponseCost.setAvgCompletionTokens(smartResponseData.getAvgCompletionTokens());
                    sheetsCostSummary.setSmartResponseCost(smartResponseCost);
                }
                
                // Add getUserInformation breakdown
                CostCalculator.ValidationTypeSummary getUserInformationData = costSummary.getGetUserInformationSummary();
                if (getUserInformationData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary getUserInformationCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    getUserInformationCost.setCount(getUserInformationData.getCount());
                    getUserInformationCost.setPromptTokens(getUserInformationData.getPromptTokens());
                    getUserInformationCost.setCompletionTokens(getUserInformationData.getCompletionTokens());
                    getUserInformationCost.setTotalTokens(getUserInformationData.getTotalTokens());
                    getUserInformationCost.setInputCost(getUserInformationData.getInputCost().doubleValue());
                    getUserInformationCost.setOutputCost(getUserInformationData.getOutputCost().doubleValue());
                    getUserInformationCost.setTotalCost(getUserInformationData.getTotalCost().doubleValue());
                    getUserInformationCost.setAvgCostPerRequest(getUserInformationData.getAvgCostPerRequest().doubleValue());
                    getUserInformationCost.setAvgPromptTokens(getUserInformationData.getAvgPromptTokens());
                    getUserInformationCost.setAvgCompletionTokens(getUserInformationData.getAvgCompletionTokens());
                    sheetsCostSummary.setGetUserInformationCost(getUserInformationCost);
                }
                
                // Add getSpecificQuestionSubIntent breakdown
                CostCalculator.ValidationTypeSummary specificQuestionSubIntentData = costSummary.getGetSpecificQuestionSubIntentSummary();
                if (specificQuestionSubIntentData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary specificQuestionSubIntentCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    specificQuestionSubIntentCost.setCount(specificQuestionSubIntentData.getCount());
                    specificQuestionSubIntentCost.setPromptTokens(specificQuestionSubIntentData.getPromptTokens());
                    specificQuestionSubIntentCost.setCompletionTokens(specificQuestionSubIntentData.getCompletionTokens());
                    specificQuestionSubIntentCost.setTotalTokens(specificQuestionSubIntentData.getTotalTokens());
                    specificQuestionSubIntentCost.setInputCost(specificQuestionSubIntentData.getInputCost().doubleValue());
                    specificQuestionSubIntentCost.setOutputCost(specificQuestionSubIntentData.getOutputCost().doubleValue());
                    specificQuestionSubIntentCost.setTotalCost(specificQuestionSubIntentData.getTotalCost().doubleValue());
                    specificQuestionSubIntentCost.setAvgCostPerRequest(specificQuestionSubIntentData.getAvgCostPerRequest().doubleValue());
                    specificQuestionSubIntentCost.setAvgPromptTokens(specificQuestionSubIntentData.getAvgPromptTokens());
                    specificQuestionSubIntentCost.setAvgCompletionTokens(specificQuestionSubIntentData.getAvgCompletionTokens());
                    sheetsCostSummary.setSpecificQuestionSubIntentCost(specificQuestionSubIntentCost);
                }
                
                // Add getMultiProductQuestionSubIntent breakdown
                CostCalculator.ValidationTypeSummary multiProductQuestionSubIntentData = costSummary.getGetMultiProductQuestionSubIntentSummary();
                if (multiProductQuestionSubIntentData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary multiProductQuestionSubIntentCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    multiProductQuestionSubIntentCost.setCount(multiProductQuestionSubIntentData.getCount());
                    multiProductQuestionSubIntentCost.setPromptTokens(multiProductQuestionSubIntentData.getPromptTokens());
                    multiProductQuestionSubIntentCost.setCompletionTokens(multiProductQuestionSubIntentData.getCompletionTokens());
                    multiProductQuestionSubIntentCost.setTotalTokens(multiProductQuestionSubIntentData.getTotalTokens());
                    multiProductQuestionSubIntentCost.setInputCost(multiProductQuestionSubIntentData.getInputCost().doubleValue());
                    multiProductQuestionSubIntentCost.setOutputCost(multiProductQuestionSubIntentData.getOutputCost().doubleValue());
                    multiProductQuestionSubIntentCost.setTotalCost(multiProductQuestionSubIntentData.getTotalCost().doubleValue());
                    multiProductQuestionSubIntentCost.setAvgCostPerRequest(multiProductQuestionSubIntentData.getAvgCostPerRequest().doubleValue());
                    multiProductQuestionSubIntentCost.setAvgPromptTokens(multiProductQuestionSubIntentData.getAvgPromptTokens());
                    multiProductQuestionSubIntentCost.setAvgCompletionTokens(multiProductQuestionSubIntentData.getAvgCompletionTokens());
                    sheetsCostSummary.setMultiProductQuestionSubIntentCost(multiProductQuestionSubIntentCost);
                }
                
                // Add searchingByTitle breakdown
                CostCalculator.ValidationTypeSummary searchingByTitleData = costSummary.getGetSearchingByTitleSummary();
                if (searchingByTitleData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary searchingByTitleCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    searchingByTitleCost.setCount(searchingByTitleData.getCount());
                    searchingByTitleCost.setPromptTokens(searchingByTitleData.getPromptTokens());
                    searchingByTitleCost.setCompletionTokens(searchingByTitleData.getCompletionTokens());
                    searchingByTitleCost.setTotalTokens(searchingByTitleData.getTotalTokens());
                    searchingByTitleCost.setInputCost(searchingByTitleData.getInputCost().doubleValue());
                    searchingByTitleCost.setOutputCost(searchingByTitleData.getOutputCost().doubleValue());
                    searchingByTitleCost.setTotalCost(searchingByTitleData.getTotalCost().doubleValue());
                    searchingByTitleCost.setAvgCostPerRequest(searchingByTitleData.getAvgCostPerRequest().doubleValue());
                    searchingByTitleCost.setAvgPromptTokens(searchingByTitleData.getAvgPromptTokens());
                    searchingByTitleCost.setAvgCompletionTokens(searchingByTitleData.getAvgCompletionTokens());
                    sheetsCostSummary.setSearchingByTitleCost(searchingByTitleCost);
                }
                
                // Add specificProductQuestion breakdown
                CostCalculator.ValidationTypeSummary specificProductQuestionData = costSummary.getGetSpecificProductQuestionSummary();
                if (specificProductQuestionData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary specificProductQuestionCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    specificProductQuestionCost.setCount(specificProductQuestionData.getCount());
                    specificProductQuestionCost.setPromptTokens(specificProductQuestionData.getPromptTokens());
                    specificProductQuestionCost.setCompletionTokens(specificProductQuestionData.getCompletionTokens());
                    specificProductQuestionCost.setTotalTokens(specificProductQuestionData.getTotalTokens());
                    specificProductQuestionCost.setInputCost(specificProductQuestionData.getInputCost().doubleValue());
                    specificProductQuestionCost.setOutputCost(specificProductQuestionData.getOutputCost().doubleValue());
                    specificProductQuestionCost.setTotalCost(specificProductQuestionData.getTotalCost().doubleValue());
                    specificProductQuestionCost.setAvgCostPerRequest(specificProductQuestionData.getAvgCostPerRequest().doubleValue());
                    specificProductQuestionCost.setAvgPromptTokens(specificProductQuestionData.getAvgPromptTokens());
                    specificProductQuestionCost.setAvgCompletionTokens(specificProductQuestionData.getAvgCompletionTokens());
                    sheetsCostSummary.setSpecificProductQuestionCost(specificProductQuestionCost);
                }
                
                // Add specificProductQuestionResponse breakdown
                CostCalculator.ValidationTypeSummary specificProductQuestionResponseData = costSummary.getGetSpecificProductQuestionResponseSummary();
                if (specificProductQuestionResponseData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary specificProductQuestionResponseCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    specificProductQuestionResponseCost.setCount(specificProductQuestionResponseData.getCount());
                    specificProductQuestionResponseCost.setPromptTokens(specificProductQuestionResponseData.getPromptTokens());
                    specificProductQuestionResponseCost.setCompletionTokens(specificProductQuestionResponseData.getCompletionTokens());
                    specificProductQuestionResponseCost.setTotalTokens(specificProductQuestionResponseData.getTotalTokens());
                    specificProductQuestionResponseCost.setInputCost(specificProductQuestionResponseData.getInputCost().doubleValue());
                    specificProductQuestionResponseCost.setOutputCost(specificProductQuestionResponseData.getOutputCost().doubleValue());
                    specificProductQuestionResponseCost.setTotalCost(specificProductQuestionResponseData.getTotalCost().doubleValue());
                    specificProductQuestionResponseCost.setAvgCostPerRequest(specificProductQuestionResponseData.getAvgCostPerRequest().doubleValue());
                    specificProductQuestionResponseCost.setAvgPromptTokens(specificProductQuestionResponseData.getAvgPromptTokens());
                    specificProductQuestionResponseCost.setAvgCompletionTokens(specificProductQuestionResponseData.getAvgCompletionTokens());
                    sheetsCostSummary.setSpecificProductQuestionResponseCost(specificProductQuestionResponseCost);
                }
                
                // Add specificProductSizeRecommendation breakdown
                CostCalculator.ValidationTypeSummary specificProductSizeRecommendationData = costSummary.getGetSpecificProductSizeRecommendationSummary();
                if (specificProductSizeRecommendationData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary specificProductSizeRecommendationCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    specificProductSizeRecommendationCost.setCount(specificProductSizeRecommendationData.getCount());
                    specificProductSizeRecommendationCost.setPromptTokens(specificProductSizeRecommendationData.getPromptTokens());
                    specificProductSizeRecommendationCost.setCompletionTokens(specificProductSizeRecommendationData.getCompletionTokens());
                    specificProductSizeRecommendationCost.setTotalTokens(specificProductSizeRecommendationData.getTotalTokens());
                    specificProductSizeRecommendationCost.setInputCost(specificProductSizeRecommendationData.getInputCost().doubleValue());
                    specificProductSizeRecommendationCost.setOutputCost(specificProductSizeRecommendationData.getOutputCost().doubleValue());
                    specificProductSizeRecommendationCost.setTotalCost(specificProductSizeRecommendationData.getTotalCost().doubleValue());
                    specificProductSizeRecommendationCost.setAvgCostPerRequest(specificProductSizeRecommendationData.getAvgCostPerRequest().doubleValue());
                    specificProductSizeRecommendationCost.setAvgPromptTokens(specificProductSizeRecommendationData.getAvgPromptTokens());
                    specificProductSizeRecommendationCost.setAvgCompletionTokens(specificProductSizeRecommendationData.getAvgCompletionTokens());
                    sheetsCostSummary.setSpecificProductSizeRecommendationCost(specificProductSizeRecommendationCost);
                }
                
                // Add similarBaseProduct breakdown
                CostCalculator.ValidationTypeSummary similarBaseProductData = costSummary.getGetSimilarBaseProductSummary();
                if (similarBaseProductData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary similarBaseProductCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    similarBaseProductCost.setCount(similarBaseProductData.getCount());
                    similarBaseProductCost.setPromptTokens(similarBaseProductData.getPromptTokens());
                    similarBaseProductCost.setCompletionTokens(similarBaseProductData.getCompletionTokens());
                    similarBaseProductCost.setTotalTokens(similarBaseProductData.getTotalTokens());
                    similarBaseProductCost.setInputCost(similarBaseProductData.getInputCost().doubleValue());
                    similarBaseProductCost.setOutputCost(similarBaseProductData.getOutputCost().doubleValue());
                    similarBaseProductCost.setTotalCost(similarBaseProductData.getTotalCost().doubleValue());
                    similarBaseProductCost.setAvgCostPerRequest(similarBaseProductData.getAvgCostPerRequest().doubleValue());
                    similarBaseProductCost.setAvgPromptTokens(similarBaseProductData.getAvgPromptTokens());
                    similarBaseProductCost.setAvgCompletionTokens(similarBaseProductData.getAvgCompletionTokens());
                    sheetsCostSummary.setSimilarBaseProductCost(similarBaseProductCost);
                }
                
                // Add productCompareResponse breakdown
                CostCalculator.ValidationTypeSummary productCompareResponseData = costSummary.getGetProductCompareResponseSummary();
                if (productCompareResponseData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary productCompareResponseCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    productCompareResponseCost.setCount(productCompareResponseData.getCount());
                    productCompareResponseCost.setPromptTokens(productCompareResponseData.getPromptTokens());
                    productCompareResponseCost.setCompletionTokens(productCompareResponseData.getCompletionTokens());
                    productCompareResponseCost.setTotalTokens(productCompareResponseData.getTotalTokens());
                    productCompareResponseCost.setInputCost(productCompareResponseData.getInputCost().doubleValue());
                    productCompareResponseCost.setOutputCost(productCompareResponseData.getOutputCost().doubleValue());
                    productCompareResponseCost.setTotalCost(productCompareResponseData.getTotalCost().doubleValue());
                    productCompareResponseCost.setAvgCostPerRequest(productCompareResponseData.getAvgCostPerRequest().doubleValue());
                    productCompareResponseCost.setAvgPromptTokens(productCompareResponseData.getAvgPromptTokens());
                    productCompareResponseCost.setAvgCompletionTokens(productCompareResponseData.getAvgCompletionTokens());
                    sheetsCostSummary.setProductCompareResponseCost(productCompareResponseCost);
                }
                
                // Add findBaseProduct breakdown
                CostCalculator.ValidationTypeSummary findBaseProductData = costSummary.getGetFindBaseProductSummary();
                if (findBaseProductData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary findBaseProductCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    findBaseProductCost.setCount(findBaseProductData.getCount());
                    findBaseProductCost.setPromptTokens(findBaseProductData.getPromptTokens());
                    findBaseProductCost.setCompletionTokens(findBaseProductData.getCompletionTokens());
                    findBaseProductCost.setTotalTokens(findBaseProductData.getTotalTokens());
                    findBaseProductCost.setInputCost(findBaseProductData.getInputCost().doubleValue());
                    findBaseProductCost.setOutputCost(findBaseProductData.getOutputCost().doubleValue());
                    findBaseProductCost.setTotalCost(findBaseProductData.getTotalCost().doubleValue());
                    findBaseProductCost.setAvgCostPerRequest(findBaseProductData.getAvgCostPerRequest().doubleValue());
                    findBaseProductCost.setAvgPromptTokens(findBaseProductData.getAvgPromptTokens());
                    findBaseProductCost.setAvgCompletionTokens(findBaseProductData.getAvgCompletionTokens());
                    sheetsCostSummary.setFindBaseProductCost(findBaseProductCost);
                }

                // Add findProductsToBundle breakdown
                CostCalculator.ValidationTypeSummary findProductsToBundleData = costSummary.getGetFindProductsToBundleSummary();
                if (findProductsToBundleData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary findProductsToBundleCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    findProductsToBundleCost.setCount(findProductsToBundleData.getCount());
                    findProductsToBundleCost.setPromptTokens(findProductsToBundleData.getPromptTokens());
                    findProductsToBundleCost.setCompletionTokens(findProductsToBundleData.getCompletionTokens());
                    findProductsToBundleCost.setTotalTokens(findProductsToBundleData.getTotalTokens());
                    findProductsToBundleCost.setInputCost(findProductsToBundleData.getInputCost().doubleValue());
                    findProductsToBundleCost.setOutputCost(findProductsToBundleData.getOutputCost().doubleValue());
                    findProductsToBundleCost.setTotalCost(findProductsToBundleData.getTotalCost().doubleValue());
                    findProductsToBundleCost.setAvgCostPerRequest(findProductsToBundleData.getAvgCostPerRequest().doubleValue());
                    findProductsToBundleCost.setAvgPromptTokens(findProductsToBundleData.getAvgPromptTokens());
                    findProductsToBundleCost.setAvgCompletionTokens(findProductsToBundleData.getAvgCompletionTokens());
                    sheetsCostSummary.setFindProductsToBundleCost(findProductsToBundleCost);
                }

                // Add generalConversation breakdown
                CostCalculator.ValidationTypeSummary generalConversationData = costSummary.getGetGeneralConversationSummary();
                if (generalConversationData != null) {
                    GoogleSheetsResultWriter.ValidationTypeCostSummary generalConversationCost = new GoogleSheetsResultWriter.ValidationTypeCostSummary();
                    generalConversationCost.setCount(generalConversationData.getCount());
                    generalConversationCost.setPromptTokens(generalConversationData.getPromptTokens());
                    generalConversationCost.setCompletionTokens(generalConversationData.getCompletionTokens());
                    generalConversationCost.setTotalTokens(generalConversationData.getTotalTokens());
                    generalConversationCost.setInputCost(generalConversationData.getInputCost().doubleValue());
                    generalConversationCost.setOutputCost(generalConversationData.getOutputCost().doubleValue());
                    generalConversationCost.setTotalCost(generalConversationData.getTotalCost().doubleValue());
                    generalConversationCost.setAvgCostPerRequest(generalConversationData.getAvgCostPerRequest().doubleValue());
                    generalConversationCost.setAvgPromptTokens(generalConversationData.getAvgPromptTokens());
                    generalConversationCost.setAvgCompletionTokens(generalConversationData.getAvgCompletionTokens());
                    sheetsCostSummary.setGeneralConversationCost(generalConversationCost);
                }
                
                // Add detailed usage data
                List<UsageData> usageDataList = readUsageData(usageCsvPath);
                for (UsageData usage : usageDataList) {
                    GoogleSheetsResultWriter.UsageDetail detail = new GoogleSheetsResultWriter.UsageDetail();
                    detail.setTenantId(usage.getTenantId());
                    detail.setContent(usage.getContent());
                    detail.setModelName(usage.getModelName());
                    detail.setPromptTokens(usage.getPromptTokens());
                    detail.setCompletionTokens(usage.getCompletionTokens());
                    detail.setTotalTokens(usage.getTotalTokens());
                    detail.setInputCost(usage.getInputCostDouble());
                    detail.setOutputCost(usage.getOutputCostDouble());
                    detail.setTotalCost(usage.getTotalCostDouble());
                    sheetsCostSummary.addUsageDetail(detail);
                }
                
                testResults.setCostSummary(sheetsCostSummary);
            }
            
            // Write to Google Sheets
            writer.writeResults(testResults);
            
            System.out.println("\n✅ Test results exported to Google Sheets 'Results' tab");
            
        } catch (IOException | GeneralSecurityException e) {
            System.out.println("\n⚠️  Failed to write results to Google Sheets: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    private String buildErrorMessage(AgentFailure agentFail) {
        StringBuilder sb = new StringBuilder();
        
        // For promptGlobalFilter and getIntent - show expected vs actual
        if (agentFail.expected != null && !agentFail.expected.isEmpty() && 
            agentFail.actual != null && !agentFail.actual.isEmpty()) {
            sb.append("Expected: ").append(agentFail.expected)
              .append("\n")
              .append("Actual: ").append(agentFail.actual);
        }
        
        // Add the detailed error message (includes scores, issues, summary for getIntentSummary)
        if (agentFail.errorMessage != null && !agentFail.errorMessage.isEmpty()) {
            if (sb.length() > 0) sb.append("\n");
            
            // For getIntentSummary failures, format each score/issue on its own line
            if (agentFail.errorMessage.contains(" | ")) {
                String[] parts = agentFail.errorMessage.split(" \\| ");
                for (String part : parts) {
                    sb.append(part.trim()).append("\n");
                }
                // Remove trailing newline
                if (sb.length() > 0 && sb.charAt(sb.length() - 1) == '\n') {
                    sb.setLength(sb.length() - 1);
                }
            } else {
                sb.append(agentFail.errorMessage);
            }
        }
        
        // Add LLM response for getIntentSummary if not already in errorMessage
        if (agentFail.responseLLM != null && !agentFail.responseLLM.isEmpty() && 
            (agentFail.errorMessage == null || !agentFail.errorMessage.contains("LLM"))) {
            if (sb.length() > 0) sb.append("\n");
            // Truncate long LLM responses for display
            String llmText = agentFail.responseLLM.length() > 200 
                ? agentFail.responseLLM.substring(0, 200) + "..." 
                : agentFail.responseLLM;
            sb.append("LLM Response: ").append(llmText);
        }
        
        return sb.length() > 0 ? sb.toString() : "Validation failed - check logs for details";
    }
    
    // Legacy method kept for backward compatibility
    private void parseFailedTests(String errorMessages, GoogleSheetsResultWriter.TestResults testResults) {
        // Parse error messages - this is a simplified parser
        // In a real implementation, you'd parse the structured error output
        String[] sections = errorMessages.split("\\[FAILURE \\d+ of \\d+\\]");
        for (String section : sections) {
            if (section.trim().isEmpty()) continue;
            
            String tenantId = extractValue(section, "Tenant:", "(");
            String tenantName = extractValueBetween(section, "Tenant:", "(", ")");
            String content = extractValue(section, "Content:", "Failed At:");
            String failedStage = extractValue(section, "Failed At:", "Expected:");
            String error = section.contains("Error:") ? extractValue(section, "Error:", "\n") : "";
            
            if (tenantName == null || tenantName.isEmpty()) {
                tenantName = "Unknown";
            }
            
            testResults.addFailedTest(new GoogleSheetsResultWriter.FailedTest(
                tenantId != null ? tenantId.trim() : "",
                tenantName.trim(),
                content != null ? content.trim() : "",
                "N/A",  // traceId not available in legacy parsing
                failedStage != null ? failedStage.trim() : "",
                error != null ? error.trim() : section.trim()
            ));
        }
    }
    
    private String extractValue(String text, String startMarker, String endMarker) {
        int startIdx = text.indexOf(startMarker);
        if (startIdx == -1) return null;
        startIdx += startMarker.length();
        
        int endIdx = text.indexOf(endMarker, startIdx);
        if (endIdx == -1) endIdx = text.length();
        
        return text.substring(startIdx, endIdx).trim();
    }
    
    private String extractValueBetween(String text, String before, String start, String end) {
        int beforeIdx = text.indexOf(before);
        if (beforeIdx == -1) return null;
        
        int startIdx = text.indexOf(start, beforeIdx);
        if (startIdx == -1) return null;
        startIdx += start.length();
        
        int endIdx = text.indexOf(end, startIdx);
        if (endIdx == -1) return null;
        
        return text.substring(startIdx, endIdx).trim();
    }
    
    private List<UsageData> readUsageData(String filePath) throws IOException {
        List<UsageData> usageDataList = new ArrayList<>();
        Path path = Paths.get(filePath);
        
        if (!Files.exists(path)) {
            return usageDataList;
        }
        
        List<String> lines = Files.readAllLines(path);
        for (String line : lines) {
            if (line.trim().isEmpty()) continue;
            if (line.startsWith("tenantId") || line.contains("prompt_tokens")) continue;
            
            // Parse CSV respecting quoted fields (handles commas inside quotes)
            String[] values = parseCsvLine(line);
            if (values.length >= 8) {
                try {
                    usageDataList.add(new UsageData.Builder()
                            .tenantId(values[0].replace("\"", "").trim())
                            .content(values[1].replace("\"", "").trim())
                            .modelName(values[2].replace("\"", "").trim())
                            .promptTokens(Integer.parseInt(values[3].trim()))
                            .completionTokens(Integer.parseInt(values[4].trim()))
                            .totalTokens(Integer.parseInt(values[5].trim()))
                            .cachedTokens(Integer.parseInt(values[6].trim()))
                            .audioTokens(Integer.parseInt(values[7].trim()))
                            .build());
                } catch (NumberFormatException e) {
                    System.out.println("Warning: Failed to parse line: " + line);
                    System.out.println("  Error: " + e.getMessage());
                }
            }
        }
        
        return usageDataList;
    }
    
    /**
     * Parse a CSV line respecting quoted fields (commas inside quotes are not delimiters).
     */
    private String[] parseCsvLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inQuotes = false;
        
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '"') {
                if (inQuotes && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    current.append('"');
                    i++; // skip escaped quote
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == ',' && !inQuotes) {
                fields.add(current.toString());
                current = new StringBuilder();
            } else {
                current.append(c);
            }
        }
        fields.add(current.toString());
        
        return fields.toArray(new String[0]);
    }
    
    private String padRight(String s, int length) {
        if (s.length() >= length) {
            return s.substring(0, length - 3) + "...";
        }
        return String.format("%-" + length + "s", s);
    }
    
    /**
     * Load environment variables from .env file if not already set as system environment variables
     */
    private void loadEnvironmentVariables() {
        try {
            // Check if GOOGLE_APPLICATION_CREDENTIALS is already set
            String existingCredentials = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
            if (existingCredentials != null && !existingCredentials.isEmpty()) {
                System.out.println("✅ GOOGLE_APPLICATION_CREDENTIALS already set: " + existingCredentials);
                return;
            }
            
            // Load .env file from project root
            String projectDir = System.getProperty("user.dir");
            Path envFile = Paths.get(projectDir, ".env");
            
            if (!Files.exists(envFile)) {
                System.out.println("⚠️  .env file not found at: " + envFile);
                return;
            }
            
            List<String> lines = Files.readAllLines(envFile);
            for (String line : lines) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) {
                    continue;
                }
                
                int equalsIndex = line.indexOf('=');
                if (equalsIndex > 0) {
                    String key = line.substring(0, equalsIndex).trim();
                    String value = line.substring(equalsIndex + 1).trim();
                    
                    // Set GOOGLE_APPLICATION_CREDENTIALS as system property if found in .env
                    if (key.equals("GOOGLE_APPLICATION_CREDENTIALS")) {
                        // Convert relative path to absolute path
                        Path credentialsPath = Paths.get(projectDir, value);
                        String absolutePath = credentialsPath.toAbsolutePath().toString();
                        System.setProperty("google.credentials.path", absolutePath);
                        System.out.println("✅ Loaded Google credentials from .env: " + absolutePath);
                        break;
                    }
                }
            }
        } catch (IOException e) {
            System.out.println("⚠️  Warning: Could not load .env file: " + e.getMessage());
        }
    }
}

