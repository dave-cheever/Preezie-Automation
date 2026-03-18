package com.preezie.llm.cost;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.sheets.v4.Sheets;
import com.google.api.services.sheets.v4.SheetsScopes;
import com.google.api.services.sheets.v4.model.*;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;

import java.io.FileInputStream;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * Writes test results and cost summary to a Google Sheets "Results" sheet.
 * 
 * Requires a Google Cloud Service Account with Google Sheets API enabled.
 * The service account email must be added as an editor to the spreadsheet.
 * 
 * Configuration:
 *   - Set GOOGLE_APPLICATION_CREDENTIALS env var to path of service account JSON file
 *   - Or place credentials.json in project root
 */
public class GoogleSheetsResultWriter {

    private static final String APPLICATION_NAME = "Preezie Automation Test Results";
    private static final JsonFactory JSON_FACTORY = GsonFactory.getDefaultInstance();
    private static final List<String> SCOPES = Collections.singletonList(SheetsScopes.SPREADSHEETS);

    private final Sheets sheetsService;
    private final String spreadsheetId;

    public GoogleSheetsResultWriter(String spreadsheetId) throws IOException, GeneralSecurityException {
        this.spreadsheetId = spreadsheetId;
        this.sheetsService = createSheetsService();
    }

    private Sheets createSheetsService() throws IOException, GeneralSecurityException {
        final NetHttpTransport httpTransport = GoogleNetHttpTransport.newTrustedTransport();
        
        GoogleCredentials credentials = getCredentials();
        
        return new Sheets.Builder(httpTransport, JSON_FACTORY, new HttpCredentialsAdapter(credentials))
                .setApplicationName(APPLICATION_NAME)
                .build();
    }

    private GoogleCredentials getCredentials() throws IOException {
        // Try environment variable first
        String credentialsPath = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
        
        // Fall back to system property
        if (credentialsPath == null || credentialsPath.isEmpty()) {
            credentialsPath = System.getProperty("google.credentials.path");
        }
        
        // Fall back to default location in project
        if (credentialsPath == null || credentialsPath.isEmpty()) {
            credentialsPath = "credentials.json";
        }

        try (FileInputStream serviceAccountStream = new FileInputStream(credentialsPath)) {
            return ServiceAccountCredentials.fromStream(serviceAccountStream)
                    .createScoped(SCOPES);
        }
    }

    /**
     * Writes test results to the "Results" sheet.
     */
    public void writeResults(TestResults results) throws IOException {
        String sheetName = "Results";
        
        // Clear existing content
        clearSheet(sheetName);
        
        // Build the data to write
        List<List<Object>> data = new ArrayList<>();
        
        // Header section
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());
        data.add(Arrays.asList("TEST EXECUTION REPORT"));
        data.add(Arrays.asList("Generated:", timestamp));
        data.add(Arrays.asList("")); // Empty row
        
        // Test Summary Section
        data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
        data.add(Arrays.asList("TEST SUMMARY"));
        data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
        data.add(Arrays.asList("Metric", "Value"));
        data.add(Arrays.asList("Total Tests Run", results.getTotalTests()));
        data.add(Arrays.asList("Passed", results.getPassed()));
        data.add(Arrays.asList("Failed", results.getFailed()));
        data.add(Arrays.asList("Pass Rate", String.format("%.2f%%", results.getPassRate())));
        data.add(Arrays.asList("")); // Empty row
        
        // Failed Tests Section (if any)
        if (!results.getFailedTests().isEmpty()) {
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("FAILED TESTS DETAILS"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Tenant ID", "Tenant Name", "Content", "Failed Stage", "Error Message"));
            
            for (FailedTest failedTest : results.getFailedTests()) {
                data.add(Arrays.asList(
                    failedTest.getTenantId(),
                    failedTest.getTenantName(),
                    failedTest.getContent(),
                    failedTest.getFailedStage(),
                    failedTest.getErrorMessage()
                ));
            }
            data.add(Arrays.asList("")); // Empty row
        }
        
        // Cost Summary Section
        if (results.getCostSummary() != null) {
            CostSummary cost = results.getCostSummary();
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            data.add(Arrays.asList("Total LLM Requests", cost.getTotalRequests()));
            data.add(Arrays.asList("Total Prompt Tokens", String.format("%,d", cost.getTotalPromptTokens())));
            data.add(Arrays.asList("Total Completion Tokens", String.format("%,d", cost.getTotalCompletionTokens())));
            data.add(Arrays.asList("Total Tokens", String.format("%,d", cost.getTotalTokens())));
            data.add(Arrays.asList(""));
            data.add(Arrays.asList("Total Input Cost", String.format("$%.6f", cost.getTotalInputCost())));
            data.add(Arrays.asList("Total Output Cost", String.format("$%.6f", cost.getTotalOutputCost())));
            data.add(Arrays.asList("TOTAL COST", String.format("$%.6f", cost.getTotalCost())));
            data.add(Arrays.asList(""));
            data.add(Arrays.asList("Average Cost per Request", String.format("$%.6f", cost.getAverageCostPerRequest())));
            data.add(Arrays.asList("Avg Prompt Tokens/Request", String.format("%.2f", cost.getAvgPromptTokensPerRequest())));
            data.add(Arrays.asList("Avg Completion Tokens/Request", String.format("%.2f", cost.getAvgCompletionTokensPerRequest())));
            data.add(Arrays.asList("")); // Empty row
            
            // Detailed Usage Data
            if (cost.getUsageDetails() != null && !cost.getUsageDetails().isEmpty()) {
                data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
                data.add(Arrays.asList("DETAILED USAGE PER REQUEST"));
                data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
                data.add(Arrays.asList("Tenant ID", "Content", "Model", "Prompt Tokens", "Completion Tokens", "Total Tokens", "Input Cost", "Output Cost", "Total Cost"));
                
                for (UsageDetail detail : cost.getUsageDetails()) {
                    data.add(Arrays.asList(
                        detail.getTenantId(),
                        detail.getContent(),
                        detail.getModelName(),
                        detail.getPromptTokens(),
                        detail.getCompletionTokens(),
                        detail.getTotalTokens(),
                        String.format("$%.6f", detail.getInputCost()),
                        String.format("$%.6f", detail.getOutputCost()),
                        String.format("$%.6f", detail.getTotalCost())
                    ));
                }
            }
        }
        
        // Write data to sheet
        writeToSheet(sheetName, data);
        
        // Apply formatting
        applyFormatting(sheetName, data.size());
        
        System.out.println("✅ Results written to Google Sheets: " + sheetName);
    }

    private void clearSheet(String sheetName) throws IOException {
        try {
            ClearValuesRequest clearRequest = new ClearValuesRequest();
            sheetsService.spreadsheets().values()
                    .clear(spreadsheetId, sheetName + "!A:Z", clearRequest)
                    .execute();
        } catch (Exception e) {
            // Sheet might not exist or be empty, that's okay
            System.out.println("Note: Could not clear sheet (may be empty): " + e.getMessage());
        }
    }

    private void writeToSheet(String sheetName, List<List<Object>> data) throws IOException {
        ValueRange body = new ValueRange().setValues(data);
        
        sheetsService.spreadsheets().values()
                .update(spreadsheetId, sheetName + "!A1", body)
                .setValueInputOption("USER_ENTERED")
                .execute();
    }

    private void applyFormatting(String sheetName, int rowCount) throws IOException {
        // Get sheet ID
        Integer sheetId = getSheetId(sheetName);
        if (sheetId == null) {
            System.out.println("Warning: Could not find sheet ID for formatting");
            return;
        }

        List<Request> requests = new ArrayList<>();

        // Bold the header rows (title, section headers)
        requests.add(new Request().setRepeatCell(new RepeatCellRequest()
                .setRange(new GridRange()
                        .setSheetId(sheetId)
                        .setStartRowIndex(0)
                        .setEndRowIndex(1)
                        .setStartColumnIndex(0)
                        .setEndColumnIndex(2))
                .setCell(new CellData()
                        .setUserEnteredFormat(new CellFormat()
                                .setTextFormat(new TextFormat().setBold(true).setFontSize(14))))
                .setFields("userEnteredFormat(textFormat)")));

        // Auto-resize columns
        requests.add(new Request().setAutoResizeDimensions(new AutoResizeDimensionsRequest()
                .setDimensions(new DimensionRange()
                        .setSheetId(sheetId)
                        .setDimension("COLUMNS")
                        .setStartIndex(0)
                        .setEndIndex(10))));

        try {
            BatchUpdateSpreadsheetRequest batchRequest = new BatchUpdateSpreadsheetRequest()
                    .setRequests(requests);
            sheetsService.spreadsheets().batchUpdate(spreadsheetId, batchRequest).execute();
        } catch (Exception e) {
            System.out.println("Warning: Could not apply formatting: " + e.getMessage());
        }
    }

    private Integer getSheetId(String sheetName) throws IOException {
        Spreadsheet spreadsheet = sheetsService.spreadsheets().get(spreadsheetId).execute();
        for (Sheet sheet : spreadsheet.getSheets()) {
            if (sheet.getProperties().getTitle().equals(sheetName)) {
                return sheet.getProperties().getSheetId();
            }
        }
        return null;
    }

    // Inner classes for data transfer
    public static class TestResults {
        private int totalTests;
        private int passed;
        private int failed;
        private List<FailedTest> failedTests = new ArrayList<>();
        private CostSummary costSummary;

        public int getTotalTests() { return totalTests; }
        public void setTotalTests(int totalTests) { this.totalTests = totalTests; }
        
        public int getPassed() { return passed; }
        public void setPassed(int passed) { this.passed = passed; }
        
        public int getFailed() { return failed; }
        public void setFailed(int failed) { this.failed = failed; }
        
        public double getPassRate() {
            return totalTests > 0 ? (double) passed / totalTests * 100 : 0;
        }
        
        public List<FailedTest> getFailedTests() { return failedTests; }
        public void setFailedTests(List<FailedTest> failedTests) { this.failedTests = failedTests; }
        public void addFailedTest(FailedTest test) { this.failedTests.add(test); }
        
        public CostSummary getCostSummary() { return costSummary; }
        public void setCostSummary(CostSummary costSummary) { this.costSummary = costSummary; }
    }

    public static class FailedTest {
        private String tenantId;
        private String tenantName;
        private String content;
        private String failedStage;
        private String errorMessage;

        public FailedTest(String tenantId, String tenantName, String content, String failedStage, String errorMessage) {
            this.tenantId = tenantId;
            this.tenantName = tenantName;
            this.content = content;
            this.failedStage = failedStage;
            this.errorMessage = errorMessage;
        }

        public String getTenantId() { return tenantId; }
        public String getTenantName() { return tenantName; }
        public String getContent() { return content; }
        public String getFailedStage() { return failedStage; }
        public String getErrorMessage() { return errorMessage; }
    }

    public static class CostSummary {
        private int totalRequests;
        private long totalPromptTokens;
        private long totalCompletionTokens;
        private long totalTokens;
        private double totalInputCost;
        private double totalOutputCost;
        private double totalCost;
        private double averageCostPerRequest;
        private double avgPromptTokensPerRequest;
        private double avgCompletionTokensPerRequest;
        private List<UsageDetail> usageDetails = new ArrayList<>();

        // Getters and setters
        public int getTotalRequests() { return totalRequests; }
        public void setTotalRequests(int totalRequests) { this.totalRequests = totalRequests; }
        
        public long getTotalPromptTokens() { return totalPromptTokens; }
        public void setTotalPromptTokens(long totalPromptTokens) { this.totalPromptTokens = totalPromptTokens; }
        
        public long getTotalCompletionTokens() { return totalCompletionTokens; }
        public void setTotalCompletionTokens(long totalCompletionTokens) { this.totalCompletionTokens = totalCompletionTokens; }
        
        public long getTotalTokens() { return totalTokens; }
        public void setTotalTokens(long totalTokens) { this.totalTokens = totalTokens; }
        
        public double getTotalInputCost() { return totalInputCost; }
        public void setTotalInputCost(double totalInputCost) { this.totalInputCost = totalInputCost; }
        
        public double getTotalOutputCost() { return totalOutputCost; }
        public void setTotalOutputCost(double totalOutputCost) { this.totalOutputCost = totalOutputCost; }
        
        public double getTotalCost() { return totalCost; }
        public void setTotalCost(double totalCost) { this.totalCost = totalCost; }
        
        public double getAverageCostPerRequest() { return averageCostPerRequest; }
        public void setAverageCostPerRequest(double averageCostPerRequest) { this.averageCostPerRequest = averageCostPerRequest; }
        
        public double getAvgPromptTokensPerRequest() { return avgPromptTokensPerRequest; }
        public void setAvgPromptTokensPerRequest(double avgPromptTokensPerRequest) { this.avgPromptTokensPerRequest = avgPromptTokensPerRequest; }
        
        public double getAvgCompletionTokensPerRequest() { return avgCompletionTokensPerRequest; }
        public void setAvgCompletionTokensPerRequest(double avgCompletionTokensPerRequest) { this.avgCompletionTokensPerRequest = avgCompletionTokensPerRequest; }
        
        public List<UsageDetail> getUsageDetails() { return usageDetails; }
        public void setUsageDetails(List<UsageDetail> usageDetails) { this.usageDetails = usageDetails; }
        public void addUsageDetail(UsageDetail detail) { this.usageDetails.add(detail); }
    }

    public static class UsageDetail {
        private String tenantId;
        private String content;
        private String modelName;
        private int promptTokens;
        private int completionTokens;
        private int totalTokens;
        private double inputCost;
        private double outputCost;
        private double totalCost;

        // Getters and setters
        public String getTenantId() { return tenantId; }
        public void setTenantId(String tenantId) { this.tenantId = tenantId; }
        
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
        
        public String getModelName() { return modelName; }
        public void setModelName(String modelName) { this.modelName = modelName; }
        
        public int getPromptTokens() { return promptTokens; }
        public void setPromptTokens(int promptTokens) { this.promptTokens = promptTokens; }
        
        public int getCompletionTokens() { return completionTokens; }
        public void setCompletionTokens(int completionTokens) { this.completionTokens = completionTokens; }
        
        public int getTotalTokens() { return totalTokens; }
        public void setTotalTokens(int totalTokens) { this.totalTokens = totalTokens; }
        
        public double getInputCost() { return inputCost; }
        public void setInputCost(double inputCost) { this.inputCost = inputCost; }
        
        public double getOutputCost() { return outputCost; }
        public void setOutputCost(double outputCost) { this.outputCost = outputCost; }
        
        public double getTotalCost() { return totalCost; }
        public void setTotalCost(double totalCost) { this.totalCost = totalCost; }
    }
}

