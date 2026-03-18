package com.preezie.runner;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.preezie.llm.cost.*;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

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
        
        // Print test results summary to console
        printResultsSummary(results);
        
        // Generate cost summary from usage.csv
        String usageCsvPath = System.getProperty("user.dir") + "/target/usage.csv";
        CostCalculator.CostSummary costSummary = generateCostSummary(usageCsvPath);
        
        // Write results to Google Sheets
        writeResultsToGoogleSheets(results, costSummary, spreadsheetId, usageCsvPath);
        
        // Assert test results
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
    
    private void printResultsSummary(Results results) {
        System.out.println("\n");
        System.out.println("╔══════════════════════════════════════════════════════════════╗");
        System.out.println("║                    TEST RESULTS SUMMARY                       ║");
        System.out.println("╠══════════════════════════════════════════════════════════════╣");
        System.out.println("║  Total Scenarios: " + padRight(String.valueOf(results.getScenariosTotal()), 42) + "║");
        System.out.println("║  Passed:          " + padRight(String.valueOf(results.getScenariosPassed()), 42) + "║");
        System.out.println("║  Failed:          " + padRight(String.valueOf(results.getFailCount()), 42) + "║");
        double passRate = results.getScenariosTotal() > 0 
            ? (double) results.getScenariosPassed() / results.getScenariosTotal() * 100 
            : 0;
        System.out.println("║  Pass Rate:       " + padRight(String.format("%.2f%%", passRate), 42) + "║");
        System.out.println("╚══════════════════════════════════════════════════════════════╝");
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
    
    private void writeResultsToGoogleSheets(Results results, CostCalculator.CostSummary costSummary, 
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
        
        System.out.println("\n✅ Google credentials found, writing results to Google Sheets...");
        
        try {
            GoogleSheetsResultWriter writer = new GoogleSheetsResultWriter(spreadsheetId);
            
            // Build TestResults object
            GoogleSheetsResultWriter.TestResults testResults = new GoogleSheetsResultWriter.TestResults();
            testResults.setTotalTests(results.getScenariosTotal());
            testResults.setPassed(results.getScenariosPassed());
            testResults.setFailed(results.getFailCount());
            
            // Parse error messages into FailedTest objects
            String errorMessages = results.getErrorMessages();
            if (errorMessages != null && !errorMessages.isEmpty()) {
                parseFailedTests(errorMessages, testResults);
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

