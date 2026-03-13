package com.preezie.llm.cost;

import com.intuit.karate.Results;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class TestReportGenerator {

    private final String outputDir;
    private final String timestamp;

    public TestReportGenerator(String outputDir) {
        this.outputDir = outputDir;
        this.timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
    }

    public void generateFullReport(Results results, String usageCsvPath) throws IOException {
        // Create output directory if it doesn't exist
        Files.createDirectories(Paths.get(outputDir));

        // Generate CSV report
        String csvPath = generateCsvReport(results, usageCsvPath);

        // Generate HTML report (can be opened in Excel)
        String htmlPath = generateHtmlReport(results, usageCsvPath);

        System.out.println("\n");
        System.out.println("╔══════════════════════════════════════════════════════════════╗");
        System.out.println("║                    REPORTS GENERATED                         ║");
        System.out.println("╠══════════════════════════════════════════════════════════════╣");
        System.out.println("║  CSV Report:  " + padRight(csvPath, 47) + "║");
        System.out.println("║  HTML Report: " + padRight(htmlPath, 47) + "║");
        System.out.println("╚══════════════════════════════════════════════════════════════╝");
    }

    private String generateCsvReport(Results results, String usageCsvPath) throws IOException {
        String csvPath = outputDir + "/test-report-" + timestamp + ".csv";

        try (PrintWriter writer = new PrintWriter(new FileWriter(csvPath))) {
            // Header
            writer.println("Test Report Generated: " + new Date());
            writer.println();

            // Summary section
            writer.println("=== TEST SUMMARY ===");
            writer.println("Total Scenarios," + results.getScenariosTotal());
            writer.println("Passed," + results.getScenariosPassed());
            writer.println("Failed," + results.getFailCount());
            writer.println("Pass Rate," + String.format("%.2f%%",
                results.getScenariosTotal() > 0
                    ? (double) results.getScenariosPassed() / results.getScenariosTotal() * 100
                    : 0));
            writer.println();

            // Failure details
            if (results.getFailCount() > 0) {
                writer.println("=== FAILURE DETAILS ===");
                writer.println("Scenario,Error Message");

                String errorMessages = results.getErrorMessages();
                if (errorMessages != null && !errorMessages.isEmpty()) {
                    // Parse error messages and write them
                    String[] errors = errorMessages.split("\\n\\n");
                    for (String error : errors) {
                        String cleanError = error.replace(",", ";").replace("\n", " | ");
                        writer.println("Failed Scenario,\"" + cleanError + "\"");
                    }
                }
                writer.println();
            }

            // Cost data if available
            writer.println("=== COST SUMMARY ===");
            try {
                List<UsageData> usageDataList = readUsageData(usageCsvPath);
                if (!usageDataList.isEmpty()) {
                    CostCalculator calculator = new CostCalculator();
                    CostCalculator.CostSummary summary = calculator.calculateSummary(usageDataList);

                    writer.println("Total Requests," + summary.getTotalRequests());
                    writer.println("Total Prompt Tokens," + summary.getTotalPromptTokens());
                    writer.println("Total Completion Tokens," + summary.getTotalCompletionTokens());
                    writer.println("Total Tokens," + summary.getTotalTokens());
                    writer.println("Total Input Cost,$" + summary.getTotalInputCost());
                    writer.println("Total Output Cost,$" + summary.getTotalOutputCost());
                    writer.println("Total Cost,$" + summary.getTotalCost());
                    writer.println("Average Cost per Request,$" + summary.getAverageCostPerRequest());
                    writer.println();

                    // Detailed usage data
                    writer.println("=== DETAILED USAGE DATA ===");
                    writer.println("Tenant ID,Content,Model,Prompt Tokens,Completion Tokens,Total Tokens,Input Cost,Output Cost,Total Cost");
                    for (UsageData data : usageDataList) {
                        writer.printf("%s,%s,%s,%d,%d,%d,$%.6f,$%.6f,$%.6f%n",
                                data.getTenantId(),
                                "\"" + data.getContent().replace("\"", "\"\"") + "\"",
                                data.getModelName(),
                                data.getPromptTokens(),
                                data.getCompletionTokens(),
                                data.getTotalTokens(),
                                data.getInputCost(),
                                data.getOutputCost(),
                                data.getTotalCost());
                    }
                }
            } catch (Exception e) {
                writer.println("Error reading usage data: " + e.getMessage());
            }
        }

        return csvPath;
    }

    private String generateHtmlReport(Results results, String usageCsvPath) throws IOException {
        String htmlPath = outputDir + "/test-report-" + timestamp + ".html";

        try (PrintWriter writer = new PrintWriter(new FileWriter(htmlPath))) {
            writer.println("<!DOCTYPE html>");
            writer.println("<html>");
            writer.println("<head>");
            writer.println("<meta charset='UTF-8'>");
            writer.println("<title>Test Report - " + timestamp + "</title>");
            writer.println("<style>");
            writer.println("body { font-family: Arial, sans-serif; margin: 20px; }");
            writer.println("h1 { color: #333; }");
            writer.println("h2 { color: #666; border-bottom: 2px solid #ddd; padding-bottom: 5px; }");
            writer.println("table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }");
            writer.println("th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }");
            writer.println("th { background-color: #4CAF50; color: white; }");
            writer.println("tr:nth-child(even) { background-color: #f2f2f2; }");
            writer.println(".passed { color: green; font-weight: bold; }");
            writer.println(".failed { color: red; font-weight: bold; }");
            writer.println(".summary-box { background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin-bottom: 20px; }");
            writer.println(".cost-box { background-color: #e8f5e9; padding: 15px; border-radius: 5px; margin-bottom: 20px; }");
            writer.println(".error-box { background-color: #ffebee; padding: 15px; border-radius: 5px; margin-bottom: 20px; white-space: pre-wrap; }");
            writer.println("</style>");
            writer.println("</head>");
            writer.println("<body>");

            // Title
            writer.println("<h1>🧪 Test Execution Report</h1>");
            writer.println("<p>Generated: " + new Date() + "</p>");

            // Summary
            writer.println("<h2>📊 Test Summary</h2>");
            writer.println("<div class='summary-box'>");
            writer.println("<table>");
            writer.println("<tr><th>Metric</th><th>Value</th></tr>");
            writer.println("<tr><td>Total Scenarios</td><td>" + results.getScenariosTotal() + "</td></tr>");
            writer.println("<tr><td>Passed</td><td class='passed'>" + results.getScenariosPassed() + "</td></tr>");
            writer.println("<tr><td>Failed</td><td class='failed'>" + results.getFailCount() + "</td></tr>");
            double passRate = results.getScenariosTotal() > 0
                ? (double) results.getScenariosPassed() / results.getScenariosTotal() * 100
                : 0;
            writer.println("<tr><td>Pass Rate</td><td>" + String.format("%.2f%%", passRate) + "</td></tr>");
            writer.println("</table>");
            writer.println("</div>");

            // Failure details
            if (results.getFailCount() > 0) {
                writer.println("<h2>❌ Failure Details</h2>");
                writer.println("<div class='error-box'>");
                String errorMessages = results.getErrorMessages();
                if (errorMessages != null) {
                    writer.println(escapeHtml(errorMessages));
                }
                writer.println("</div>");
            }

            // Cost summary
            writer.println("<h2>💰 Cost Summary</h2>");
            try {
                List<UsageData> usageDataList = readUsageData(usageCsvPath);
                if (!usageDataList.isEmpty()) {
                    CostCalculator calculator = new CostCalculator();
                    CostCalculator.CostSummary summary = calculator.calculateSummary(usageDataList);

                    writer.println("<div class='cost-box'>");
                    writer.println("<table>");
                    writer.println("<tr><th>Metric</th><th>Value</th></tr>");
                    writer.println("<tr><td>Total Requests</td><td>" + summary.getTotalRequests() + "</td></tr>");
                    writer.println("<tr><td>Total Prompt Tokens</td><td>" + String.format("%,d", summary.getTotalPromptTokens()) + "</td></tr>");
                    writer.println("<tr><td>Total Completion Tokens</td><td>" + String.format("%,d", summary.getTotalCompletionTokens()) + "</td></tr>");
                    writer.println("<tr><td>Total Tokens</td><td>" + String.format("%,d", summary.getTotalTokens()) + "</td></tr>");
                    writer.println("<tr><td>Total Input Cost</td><td>$" + summary.getTotalInputCost() + "</td></tr>");
                    writer.println("<tr><td>Total Output Cost</td><td>$" + summary.getTotalOutputCost() + "</td></tr>");
                    writer.println("<tr><td><strong>Total Cost</strong></td><td><strong>$" + summary.getTotalCost() + "</strong></td></tr>");
                    writer.println("<tr><td>Average Cost per Request</td><td>$" + summary.getAverageCostPerRequest() + "</td></tr>");
                    writer.println("</table>");
                    writer.println("</div>");

                    // Detailed usage table
                    writer.println("<h2>📋 Detailed Usage Data</h2>");
                    writer.println("<table>");
                    writer.println("<tr><th>Tenant ID</th><th>Content</th><th>Model</th><th>Prompt Tokens</th><th>Completion Tokens</th><th>Total Tokens</th><th>Input Cost</th><th>Output Cost</th><th>Total Cost</th></tr>");
                    for (UsageData data : usageDataList) {
                        writer.printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%,d</td><td>%,d</td><td>%,d</td><td>$%.6f</td><td>$%.6f</td><td>$%.6f</td></tr>%n",
                                escapeHtml(data.getTenantId()),
                                escapeHtml(data.getContent()),
                                escapeHtml(data.getModelName()),
                                data.getPromptTokens(),
                                data.getCompletionTokens(),
                                data.getTotalTokens(),
                                data.getInputCost(),
                                data.getOutputCost(),
                                data.getTotalCost());
                    }
                    writer.println("</table>");
                } else {
                    writer.println("<p>No usage data available.</p>");
                }
            } catch (Exception e) {
                writer.println("<p class='failed'>Error reading usage data: " + escapeHtml(e.getMessage()) + "</p>");
            }

            writer.println("</body>");
            writer.println("</html>");
        }

        return htmlPath;
    }

    private List<UsageData> readUsageData(String filePath) throws IOException {
        List<UsageData> usageDataList = new ArrayList<>();
        Path path = Paths.get(filePath);

        if (!Files.exists(path)) {
            return usageDataList;
        }

        List<String> lines = Files.readAllLines(path);
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i).trim();
            if (line.isEmpty()) continue;

            // Skip header
            if (line.startsWith("tenantId") || line.contains("prompt_tokens")) {
                continue;
            }

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

    private String escapeHtml(String text) {
        if (text == null) return "";
        return text
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("\n", "<br>");
    }

    private String padRight(String s, int length) {
        if (s.length() >= length) {
            return s.substring(0, length - 3) + "...";
        }
        return String.format("%-" + length + "s", s);
    }
}

