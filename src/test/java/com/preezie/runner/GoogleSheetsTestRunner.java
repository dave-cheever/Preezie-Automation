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
        String usageCsvPath = System.getProperty("user.dir") + "/target/usage.csv";
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
        List<FailedTestData> errors = new ArrayList<>();
    }
    
    static class FailedTestData {
        String tenantId;
        String tenantName;
        String content;
        String failedStage;
        String expected;
        String actual;
        String errorMessage;
        String responseLLM;
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
            
            JsonNode errorsNode = root.path("errors");
            if (errorsNode.isArray()) {
                for (JsonNode errorNode : errorsNode) {
                    FailedTestData failedTest = new FailedTestData();
                    failedTest.tenantId = errorNode.path("tenantId").asText("");
                    failedTest.tenantName = errorNode.path("tenantName").asText("Unknown");
                    failedTest.content = errorNode.path("content").asText("");
                    failedTest.failedStage = errorNode.path("failedStage").asText("");
                    failedTest.expected = errorNode.path("expected").asText("");
                    failedTest.actual = errorNode.path("actual").asText("");
                    failedTest.errorMessage = errorNode.path("errorMessage").asText("");
                    failedTest.responseLLM = errorNode.path("responseLLM").asText("");
                    data.errors.add(failedTest);
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
        if (!actualResults.errors.isEmpty()) {
            System.out.println("\n");
            System.out.println("╔══════════════════════════════════════════════════════════════╗");
            System.out.println("║                    FAILED TESTS DETAILS                       ║");
            System.out.println("╚══════════════════════════════════════════════════════════════╝");
            
            for (int i = 0; i < actualResults.errors.size(); i++) {
                FailedTestData err = actualResults.errors.get(i);
                System.out.println("\n--- Failure " + (i + 1) + " of " + actualResults.errors.size() + " ---");
                System.out.println("  Tenant:      " + err.tenantName + " (" + err.tenantId + ")");
                System.out.println("  Content:     " + err.content);
                System.out.println("  Failed At:   " + err.failedStage);
                if (!err.expected.isEmpty()) {
                    System.out.println("  Expected:    " + err.expected);
                    System.out.println("  Actual:      " + err.actual);
                }
                if (!err.errorMessage.isEmpty()) {
                    System.out.println("  Error:       " + err.errorMessage);
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
                
                System.out.println("\n");
                System.out.println("╔══════════════════════════════════════════════════════════════╗");
                System.out.println("║                    AI COST SUMMARY                            ║");
                System.out.println("╠══════════════════════════════════════════════════════════════╣");
                System.out.println("║  Total Requests:         " + padRight(String.valueOf(summary.getTotalRequests()), 35) + "║");
                System.out.println("║  Total Prompt Tokens:    " + padRight(String.format("%,d", summary.getTotalPromptTokens()), 35) + "║");
                System.out.println("║  Total Completion Tokens:" + padRight(String.format("%,d", summary.getTotalCompletionTokens()), 35) + "║");
                System.out.println("║  Total Tokens:           " + padRight(String.format("%,d", summary.getTotalTokens()), 35) + "║");
                System.out.println("╠──────────────────────────────────────────────────────────────╣");
                System.out.println("║  Total Input Cost:       " + padRight("$" + summary.getTotalInputCost(), 35) + "║");
                System.out.println("║  Total Output Cost:      " + padRight("$" + summary.getTotalOutputCost(), 35) + "║");
                System.out.println("║  TOTAL COST:             " + padRight("$" + summary.getTotalCost(), 35) + "║");
                System.out.println("╠──────────────────────────────────────────────────────────────╣");
                System.out.println("║  Avg Cost/Request:       " + padRight("$" + summary.getAverageCostPerRequest(), 35) + "║");
                System.out.println("╚══════════════════════════════════════════════════════════════╝");
                
                return summary;
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
            for (FailedTestData err : actualResults.errors) {
                testResults.addFailedTest(new GoogleSheetsResultWriter.FailedTest(
                    err.tenantId,
                    err.tenantName,
                    err.content,
                    err.failedStage,
                    buildErrorMessage(err)
                ));
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
    
    private String buildErrorMessage(FailedTestData err) {
        StringBuilder sb = new StringBuilder();
        
        // For promptGlobalFilter and getIntent - show expected vs actual
        if (!err.expected.isEmpty() && !err.actual.isEmpty()) {
            sb.append("Expected: ").append(err.expected).append(", Actual: ").append(err.actual);
        }
        
        // Add the detailed error message (includes scores, issues, summary for getIntentSummary)
        if (!err.errorMessage.isEmpty()) {
            if (sb.length() > 0) sb.append(" | ");
            sb.append(err.errorMessage);
        }
        
        // Add LLM response for getIntentSummary if not already in errorMessage
        if (!err.responseLLM.isEmpty() && !err.errorMessage.contains("LLM")) {
            if (sb.length() > 0) sb.append(" | ");
            // Truncate long LLM responses for display
            String llmText = err.responseLLM.length() > 200 
                ? err.responseLLM.substring(0, 200) + "..." 
                : err.responseLLM;
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
            
            String[] values = line.split(",");
            if (values.length >= 8) {
                try {
                    usageDataList.add(new UsageData.Builder()
                            .tenantId(values[0].replace("'", "").replace("\"", "").trim())
                            .content(values[1].replace("'", "").replace("\"", "").trim())
                            .modelName(values[2].replace("'", "").replace("\"", "").trim())
                            .promptTokens(Integer.parseInt(values[3].trim()))
                            .completionTokens(Integer.parseInt(values[4].trim()))
                            .totalTokens(Integer.parseInt(values[5].trim()))
                            .cachedTokens(Integer.parseInt(values[6].trim()))
                            .audioTokens(Integer.parseInt(values[7].trim()))
                            .build());
                } catch (NumberFormatException e) {
                    // Skip invalid lines
                }
            }
        }
        
        return usageDataList;
    }
    
    private String padRight(String s, int length) {
        if (s.length() >= length) {
            return s.substring(0, length - 3) + "...";
        }
        return String.format("%-" + length + "s", s);
    }
}

