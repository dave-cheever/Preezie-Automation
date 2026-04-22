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

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
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
        // Priority 1: JSON content directly in environment variable (for CI/CD like GitHub Actions)
        String credentialsJson = System.getenv("GOOGLE_CREDENTIALS_JSON");
        if (credentialsJson != null && !credentialsJson.isEmpty()) {
            System.out.println("Loading Google credentials from GOOGLE_CREDENTIALS_JSON environment variable");
            try (InputStream stream = new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8))) {
                return ServiceAccountCredentials.fromStream(stream).createScoped(SCOPES);
            }
        }

        // Priority 2: Path to credentials file in environment variable
        String credentialsPath = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
        
        // Priority 3: System property
        if (credentialsPath == null || credentialsPath.isEmpty()) {
            credentialsPath = System.getProperty("google.credentials.path");
        }
        
        // Priority 4: Default location in project root
        if (credentialsPath == null || credentialsPath.isEmpty()) {
            credentialsPath = "credentials.json";
        }

        // Check if file exists
        if (!Files.exists(Paths.get(credentialsPath))) {
            throw new IOException(
                "Google credentials not found. Please either:\n" +
                "  1. Set GOOGLE_CREDENTIALS_JSON env var with the JSON content, OR\n" +
                "  2. Set GOOGLE_APPLICATION_CREDENTIALS env var to the credentials file path, OR\n" +
                "  3. Place credentials.json in project root\n" +
                "Looked for file at: " + Paths.get(credentialsPath).toAbsolutePath()
            );
        }

        System.out.println("Loading Google credentials from file: " + credentialsPath);
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
        
        // Header section - generate fresh timestamp
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());
        System.out.println("Writing results with timestamp: " + timestamp);
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
            data.add(Arrays.asList("Tenant ID", "Tenant Name", "Content", "Trace ID", "Failed Stage", "Error Message"));
            
            for (FailedTest failedTest : results.getFailedTests()) {
                data.add(Arrays.asList(
                    failedTest.getTenantId(),
                    failedTest.getTenantName(),
                    failedTest.getContent(),
                    failedTest.getTraceId(),
                    failedTest.getFailedStage(),
                    failedTest.getErrorMessage()
                ));
            }
            data.add(Arrays.asList("")); // Empty row
        }
        
        // Cost Summary Section
        if (results.getCostSummary() != null) {
            CostSummary cost = results.getCostSummary();
            
            // getIntentSummary Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getIntentSummary"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getIntentSummaryCost() != null) {
                ValidationTypeCostSummary intentSummaryCost = cost.getIntentSummaryCost();
                data.add(Arrays.asList("Evaluations", intentSummaryCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", intentSummaryCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", intentSummaryCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", intentSummaryCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", intentSummaryCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", intentSummaryCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", intentSummaryCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", intentSummaryCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", intentSummaryCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", intentSummaryCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // getIntent Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getIntent"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getIntentCost() != null) {
                ValidationTypeCostSummary intentCost = cost.getIntentCost();
                data.add(Arrays.asList("Evaluations", intentCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", intentCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", intentCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", intentCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", intentCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", intentCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", intentCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", intentCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", intentCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", intentCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // getCategories Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getCategories"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getCategoriesCost() != null) {
                ValidationTypeCostSummary categoriesCost = cost.getCategoriesCost();
                data.add(Arrays.asList("Evaluations", categoriesCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", categoriesCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", categoriesCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", categoriesCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", categoriesCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", categoriesCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", categoriesCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", categoriesCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", categoriesCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", categoriesCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // findProductFromPrompt Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - findProductFromPrompt"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getFindProductCost() != null) {
                ValidationTypeCostSummary findProductCost = cost.getFindProductCost();
                data.add(Arrays.asList("Evaluations", findProductCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", findProductCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", findProductCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", findProductCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", findProductCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", findProductCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", findProductCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", findProductCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", findProductCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", findProductCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // smartResponse Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - smartResponse"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSmartResponseCost() != null) {
                ValidationTypeCostSummary smartResponseCost = cost.getSmartResponseCost();
                data.add(Arrays.asList("Evaluations", smartResponseCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", smartResponseCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", smartResponseCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", smartResponseCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", smartResponseCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", smartResponseCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", smartResponseCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", smartResponseCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", smartResponseCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", smartResponseCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // getUserInformation Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getUserInformation"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getGetUserInformationCost() != null) {
                ValidationTypeCostSummary getUserInformationCost = cost.getGetUserInformationCost();
                data.add(Arrays.asList("Evaluations", getUserInformationCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", getUserInformationCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", getUserInformationCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", getUserInformationCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", getUserInformationCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", getUserInformationCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", getUserInformationCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", getUserInformationCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", getUserInformationCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", getUserInformationCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // getSpecificQuestionSubIntent Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getSpecificQuestionSubIntent"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSpecificQuestionSubIntentCost() != null) {
                ValidationTypeCostSummary specificQuestionSubIntentCost = cost.getSpecificQuestionSubIntentCost();
                data.add(Arrays.asList("Evaluations", specificQuestionSubIntentCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", specificQuestionSubIntentCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", specificQuestionSubIntentCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", specificQuestionSubIntentCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", specificQuestionSubIntentCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", specificQuestionSubIntentCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", specificQuestionSubIntentCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", specificQuestionSubIntentCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", specificQuestionSubIntentCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", specificQuestionSubIntentCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // getMultiProductQuestionSubIntent Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - getMultiProductQuestionSubIntent"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getMultiProductQuestionSubIntentCost() != null) {
                ValidationTypeCostSummary multiProductQuestionSubIntentCost = cost.getMultiProductQuestionSubIntentCost();
                data.add(Arrays.asList("Evaluations", multiProductQuestionSubIntentCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", multiProductQuestionSubIntentCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", multiProductQuestionSubIntentCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", multiProductQuestionSubIntentCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", multiProductQuestionSubIntentCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", multiProductQuestionSubIntentCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", multiProductQuestionSubIntentCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", multiProductQuestionSubIntentCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", multiProductQuestionSubIntentCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", multiProductQuestionSubIntentCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // specificProductQuestion Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - specificProductQuestion"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSpecificProductQuestionCost() != null) {
                ValidationTypeCostSummary specificProductQuestionCost = cost.getSpecificProductQuestionCost();
                data.add(Arrays.asList("Evaluations", specificProductQuestionCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", specificProductQuestionCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", specificProductQuestionCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", specificProductQuestionCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", specificProductQuestionCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", specificProductQuestionCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", specificProductQuestionCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", specificProductQuestionCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", specificProductQuestionCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", specificProductQuestionCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // specificProductQuestionResponse Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - specificProductQuestionResponse"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSpecificProductQuestionResponseCost() != null) {
                ValidationTypeCostSummary specificProductQuestionResponseCost = cost.getSpecificProductQuestionResponseCost();
                data.add(Arrays.asList("Evaluations", specificProductQuestionResponseCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", specificProductQuestionResponseCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", specificProductQuestionResponseCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", specificProductQuestionResponseCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", specificProductQuestionResponseCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", specificProductQuestionResponseCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", specificProductQuestionResponseCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", specificProductQuestionResponseCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", specificProductQuestionResponseCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", specificProductQuestionResponseCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // specificProductSizeRecommendation Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - specificProductSizeRecommendation"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSpecificProductSizeRecommendationCost() != null) {
                ValidationTypeCostSummary specificProductSizeRecommendationCost = cost.getSpecificProductSizeRecommendationCost();
                data.add(Arrays.asList("Evaluations", specificProductSizeRecommendationCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", specificProductSizeRecommendationCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", specificProductSizeRecommendationCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", specificProductSizeRecommendationCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", specificProductSizeRecommendationCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", specificProductSizeRecommendationCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", specificProductSizeRecommendationCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", specificProductSizeRecommendationCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", specificProductSizeRecommendationCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", specificProductSizeRecommendationCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // similarBaseProduct Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - similarBaseProduct"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getSimilarBaseProductCost() != null) {
                ValidationTypeCostSummary similarBaseProductCost = cost.getSimilarBaseProductCost();
                data.add(Arrays.asList("Evaluations", similarBaseProductCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", similarBaseProductCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", similarBaseProductCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", similarBaseProductCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", similarBaseProductCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", similarBaseProductCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", similarBaseProductCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", similarBaseProductCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", similarBaseProductCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", similarBaseProductCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row

            // productCompareResponse Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("AI COST SUMMARY - productCompareResponse"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            if (cost.getProductCompareResponseCost() != null) {
                ValidationTypeCostSummary productCompareResponseCost = cost.getProductCompareResponseCost();
                data.add(Arrays.asList("Evaluations", productCompareResponseCost.getCount()));
                data.add(Arrays.asList("Prompt Tokens", String.format("%,d", productCompareResponseCost.getPromptTokens())));
                data.add(Arrays.asList("Completion Tokens", String.format("%,d", productCompareResponseCost.getCompletionTokens())));
                data.add(Arrays.asList("Total Tokens", String.format("%,d", productCompareResponseCost.getTotalTokens())));
                data.add(Arrays.asList("Input Cost", String.format("$%.6f", productCompareResponseCost.getInputCost())));
                data.add(Arrays.asList("Output Cost", String.format("$%.6f", productCompareResponseCost.getOutputCost())));
                data.add(Arrays.asList("Total Cost", String.format("$%.6f", productCompareResponseCost.getTotalCost())));
                data.add(Arrays.asList("Avg Cost/Evaluation", String.format("$%.6f", productCompareResponseCost.getAvgCostPerRequest())));
                data.add(Arrays.asList("Avg Prompt Tokens", String.format("%.2f", productCompareResponseCost.getAvgPromptTokens())));
                data.add(Arrays.asList("Avg Completion Tokens", String.format("%.2f", productCompareResponseCost.getAvgCompletionTokens())));
            } else {
                data.add(Arrays.asList("No data", "N/A"));
            }
            data.add(Arrays.asList("")); // Empty row
            
            // Combined Total Section
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("COMBINED TOTAL AI COST SUMMARY"));
            data.add(Arrays.asList("═══════════════════════════════════════════════════════════════"));
            data.add(Arrays.asList("Metric", "Value"));
            data.add(Arrays.asList("Total AI Evaluations", cost.getTotalRequests()));
            int intentSummaryCount = cost.getIntentSummaryCost() != null ? cost.getIntentSummaryCost().getCount() : 0;
            int intentCount = cost.getIntentCost() != null ? cost.getIntentCost().getCount() : 0;
            int categoriesCount = cost.getCategoriesCost() != null ? cost.getCategoriesCost().getCount() : 0;
            int findProductCount = cost.getFindProductCost() != null ? cost.getFindProductCost().getCount() : 0;
            int smartResponseCount = cost.getSmartResponseCost() != null ? cost.getSmartResponseCost().getCount() : 0;
            int getUserInformationCount = cost.getGetUserInformationCost() != null ? cost.getGetUserInformationCost().getCount() : 0;
            int specificQuestionSubIntentCount = cost.getSpecificQuestionSubIntentCost() != null ? cost.getSpecificQuestionSubIntentCost().getCount() : 0;
            int multiProductQuestionSubIntentCount = cost.getMultiProductQuestionSubIntentCost() != null ? cost.getMultiProductQuestionSubIntentCost().getCount() : 0;
            int searchingByTitleCount = cost.getSearchingByTitleCost() != null ? cost.getSearchingByTitleCost().getCount() : 0;
            int specificProductQuestionCount = cost.getSpecificProductQuestionCost() != null ? cost.getSpecificProductQuestionCost().getCount() : 0;
            int specificProductQuestionResponseCount = cost.getSpecificProductQuestionResponseCost() != null ? cost.getSpecificProductQuestionResponseCost().getCount() : 0;
            int specificProductSizeRecommendationCount = cost.getSpecificProductSizeRecommendationCost() != null ? cost.getSpecificProductSizeRecommendationCost().getCount() : 0;
            int similarBaseProductCount = cost.getSimilarBaseProductCost() != null ? cost.getSimilarBaseProductCost().getCount() : 0;
            int productCompareResponseCount = cost.getProductCompareResponseCost() != null ? cost.getProductCompareResponseCost().getCount() : 0;
            data.add(Arrays.asList("  - getIntentSummary", intentSummaryCount));
            data.add(Arrays.asList("  - getIntent", intentCount));
            data.add(Arrays.asList("  - getCategories", categoriesCount));
            data.add(Arrays.asList("  - findProductFromPrompt", findProductCount));
            data.add(Arrays.asList("  - smartResponse", smartResponseCount));
            data.add(Arrays.asList("  - getUserInformation", getUserInformationCount));
            data.add(Arrays.asList("  - getSpecificQuestionSubIntent", specificQuestionSubIntentCount));
            data.add(Arrays.asList("  - getMultiProductQuestionSubIntent", multiProductQuestionSubIntentCount));
            data.add(Arrays.asList("  - searchingByTitle", searchingByTitleCount));
            data.add(Arrays.asList("  - specificProductQuestion", specificProductQuestionCount));
            data.add(Arrays.asList("  - specificProductQuestionResponse", specificProductQuestionResponseCount));
            data.add(Arrays.asList("  - specificProductSizeRecommendation", specificProductSizeRecommendationCount));
            data.add(Arrays.asList("  - similarBaseProduct", similarBaseProductCount));
            data.add(Arrays.asList("  - productCompareResponse", productCompareResponseCount));
            data.add(Arrays.asList(""));
            data.add(Arrays.asList("Total Prompt Tokens", String.format("%,d", cost.getTotalPromptTokens())));
            data.add(Arrays.asList("Total Completion Tokens", String.format("%,d", cost.getTotalCompletionTokens())));
            data.add(Arrays.asList("Total Tokens", String.format("%,d", cost.getTotalTokens())));
            data.add(Arrays.asList(""));
            data.add(Arrays.asList("Total Input Cost", String.format("$%.6f", cost.getTotalInputCost())));
            data.add(Arrays.asList("Total Output Cost", String.format("$%.6f", cost.getTotalOutputCost())));
            data.add(Arrays.asList("TOTAL COST", String.format("$%.6f", cost.getTotalCost())));
            data.add(Arrays.asList(""));
            data.add(Arrays.asList("Average Cost per Evaluation", String.format("$%.6f", cost.getAverageCostPerRequest())));
            data.add(Arrays.asList("Avg Prompt Tokens/Evaluation", String.format("%.2f", cost.getAvgPromptTokensPerRequest())));
            data.add(Arrays.asList("Avg Completion Tokens/Evaluation", String.format("%.2f", cost.getAvgCompletionTokensPerRequest())));
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
            // Clear all values from the sheet (A1:Z1000 to ensure all data is cleared)
            ClearValuesRequest clearRequest = new ClearValuesRequest();
            sheetsService.spreadsheets().values()
                    .clear(spreadsheetId, sheetName + "!A1:Z1000", clearRequest)
                    .execute();
            System.out.println("Cleared existing data from " + sheetName + " sheet");
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
        private String traceId;
        private String failedStage;
        private String errorMessage;

        public FailedTest(String tenantId, String tenantName, String content, String traceId, String failedStage, String errorMessage) {
            this.tenantId = tenantId;
            this.tenantName = tenantName;
            this.content = content;
            this.traceId = traceId;
            this.failedStage = failedStage;
            this.errorMessage = errorMessage;
        }

        public String getTenantId() { return tenantId; }
        public String getTenantName() { return tenantName; }
        public String getContent() { return content; }
        public String getTraceId() { return traceId; }
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
        private ValidationTypeCostSummary intentSummaryCost;
        private ValidationTypeCostSummary intentCost;
        private ValidationTypeCostSummary categoriesCost;
        private ValidationTypeCostSummary findProductCost;
        private ValidationTypeCostSummary smartResponseCost;
        private ValidationTypeCostSummary getUserInformationCost;
        private ValidationTypeCostSummary specificQuestionSubIntentCost;
        private ValidationTypeCostSummary multiProductQuestionSubIntentCost;
        private ValidationTypeCostSummary searchingByTitleCost;
        private ValidationTypeCostSummary specificProductQuestionCost;
        private ValidationTypeCostSummary specificProductQuestionResponseCost;
        private ValidationTypeCostSummary specificProductSizeRecommendationCost;
        private ValidationTypeCostSummary similarBaseProductCost;
        private ValidationTypeCostSummary productCompareResponseCost;

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
        
        public ValidationTypeCostSummary getIntentSummaryCost() { return intentSummaryCost; }
        public void setIntentSummaryCost(ValidationTypeCostSummary intentSummaryCost) { this.intentSummaryCost = intentSummaryCost; }
        
        public ValidationTypeCostSummary getIntentCost() { return intentCost; }
        public void setIntentCost(ValidationTypeCostSummary intentCost) { this.intentCost = intentCost; }
        
        public ValidationTypeCostSummary getCategoriesCost() { return categoriesCost; }
        public void setCategoriesCost(ValidationTypeCostSummary categoriesCost) { this.categoriesCost = categoriesCost; }
        
        public ValidationTypeCostSummary getFindProductCost() { return findProductCost; }
        public void setFindProductCost(ValidationTypeCostSummary findProductCost) { this.findProductCost = findProductCost; }
        
        public ValidationTypeCostSummary getSmartResponseCost() { return smartResponseCost; }
        public void setSmartResponseCost(ValidationTypeCostSummary smartResponseCost) { this.smartResponseCost = smartResponseCost; }
        
        public ValidationTypeCostSummary getGetUserInformationCost() { return getUserInformationCost; }
        public void setGetUserInformationCost(ValidationTypeCostSummary getUserInformationCost) { this.getUserInformationCost = getUserInformationCost; }
        
        public ValidationTypeCostSummary getSpecificQuestionSubIntentCost() { return specificQuestionSubIntentCost; }
        public void setSpecificQuestionSubIntentCost(ValidationTypeCostSummary specificQuestionSubIntentCost) { this.specificQuestionSubIntentCost = specificQuestionSubIntentCost; }
        
        public ValidationTypeCostSummary getMultiProductQuestionSubIntentCost() { return multiProductQuestionSubIntentCost; }
        public void setMultiProductQuestionSubIntentCost(ValidationTypeCostSummary multiProductQuestionSubIntentCost) { this.multiProductQuestionSubIntentCost = multiProductQuestionSubIntentCost; }
        
        public ValidationTypeCostSummary getSearchingByTitleCost() { return searchingByTitleCost; }
        public void setSearchingByTitleCost(ValidationTypeCostSummary searchingByTitleCost) { this.searchingByTitleCost = searchingByTitleCost; }
        
        public ValidationTypeCostSummary getSpecificProductQuestionCost() { return specificProductQuestionCost; }
        public void setSpecificProductQuestionCost(ValidationTypeCostSummary specificProductQuestionCost) { this.specificProductQuestionCost = specificProductQuestionCost; }
        
        public ValidationTypeCostSummary getSpecificProductQuestionResponseCost() { return specificProductQuestionResponseCost; }
        public void setSpecificProductQuestionResponseCost(ValidationTypeCostSummary specificProductQuestionResponseCost) { this.specificProductQuestionResponseCost = specificProductQuestionResponseCost; }
        
        public ValidationTypeCostSummary getSpecificProductSizeRecommendationCost() { return specificProductSizeRecommendationCost; }
        public void setSpecificProductSizeRecommendationCost(ValidationTypeCostSummary specificProductSizeRecommendationCost) { this.specificProductSizeRecommendationCost = specificProductSizeRecommendationCost; }
        
        public ValidationTypeCostSummary getSimilarBaseProductCost() { return similarBaseProductCost; }
        public void setSimilarBaseProductCost(ValidationTypeCostSummary similarBaseProductCost) { this.similarBaseProductCost = similarBaseProductCost; }
        
        public ValidationTypeCostSummary getProductCompareResponseCost() { return productCompareResponseCost; }
        public void setProductCompareResponseCost(ValidationTypeCostSummary productCompareResponseCost) { this.productCompareResponseCost = productCompareResponseCost; }
    }

    /**
     * Cost summary for a specific validation type (getIntentSummary or getIntent)
     */
    public static class ValidationTypeCostSummary {
        private int count;
        private long promptTokens;
        private long completionTokens;
        private long totalTokens;
        private double inputCost;
        private double outputCost;
        private double totalCost;
        private double avgCostPerRequest;
        private double avgPromptTokens;
        private double avgCompletionTokens;

        // Getters and setters
        public int getCount() { return count; }
        public void setCount(int count) { this.count = count; }
        
        public long getPromptTokens() { return promptTokens; }
        public void setPromptTokens(long promptTokens) { this.promptTokens = promptTokens; }
        
        public long getCompletionTokens() { return completionTokens; }
        public void setCompletionTokens(long completionTokens) { this.completionTokens = completionTokens; }
        
        public long getTotalTokens() { return totalTokens; }
        public void setTotalTokens(long totalTokens) { this.totalTokens = totalTokens; }
        
        public double getInputCost() { return inputCost; }
        public void setInputCost(double inputCost) { this.inputCost = inputCost; }
        
        public double getOutputCost() { return outputCost; }
        public void setOutputCost(double outputCost) { this.outputCost = outputCost; }
        
        public double getTotalCost() { return totalCost; }
        public void setTotalCost(double totalCost) { this.totalCost = totalCost; }
        
        public double getAvgCostPerRequest() { return avgCostPerRequest; }
        public void setAvgCostPerRequest(double avgCostPerRequest) { this.avgCostPerRequest = avgCostPerRequest; }
        
        public double getAvgPromptTokens() { return avgPromptTokens; }
        public void setAvgPromptTokens(double avgPromptTokens) { this.avgPromptTokens = avgPromptTokens; }
        
        public double getAvgCompletionTokens() { return avgCompletionTokens; }
        public void setAvgCompletionTokens(double avgCompletionTokens) { this.avgCompletionTokens = avgCompletionTokens; }
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

