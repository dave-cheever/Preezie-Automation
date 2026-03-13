package com.preezie.llm.cost;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class CostReportGenerator {

    public static void generateReport(String csvFilePath) throws IOException {
        List<UsageData> usageDataList = readUsageFromCsv(csvFilePath);
        CostCalculator calculator = new CostCalculator();
        CostCalculator.CostSummary summary = calculator.calculateSummary(usageDataList);

        System.out.println(summary);
    }

    private static List<UsageData> readUsageFromCsv(String filePath) throws IOException {
        List<UsageData> usageDataList = new ArrayList<>();

        try (BufferedReader br = new BufferedReader(new FileReader(filePath))) {
            String line;
            int lineNumber = 0;

            while ((line = br.readLine()) != null) {
                lineNumber++;
                if (line.trim().isEmpty()) continue;

                // Skip header line if present (starts with "tenantId" or contains column names)
                if (lineNumber == 1 && (line.startsWith("tenantId") || line.contains("prompt_tokens"))) {
                    continue;
                }

                String[] values = line.split(",");
                if (values.length >= 8) {
                    try {
                        // Remove quotes from values if present
                        String tenantId = values[0].replace("'", "").replace("\"", "").trim();
                        String content = values[1].replace("'", "").replace("\"", "").trim();
                        String modelName = values[2].replace("'", "").replace("\"", "").trim();

                        usageDataList.add(new UsageData.Builder()
                                .tenantId(tenantId)
                                .content(content)
                                .modelName(modelName)
                                .promptTokens(Integer.parseInt(values[3].trim()))
                                .completionTokens(Integer.parseInt(values[4].trim()))
                                .totalTokens(Integer.parseInt(values[5].trim()))
                                .cachedTokens(Integer.parseInt(values[6].trim()))
                                .audioTokens(Integer.parseInt(values[7].trim()))
                                .build());
                    } catch (NumberFormatException e) {
                        System.err.println("Warning: Failed to parse line " + lineNumber + ": " + line);
                        System.err.println("  Error: " + e.getMessage());
                    }
                } else {
                    System.err.println("Warning: Line " + lineNumber + " has insufficient columns (" + values.length + "): " + line);
                }
            }
        }

        System.out.println("Read " + usageDataList.size() + " usage records from CSV");
        return usageDataList;
    }

    public static void main(String[] args) {
        try {
            generateReport("target/usage.csv");
        } catch (IOException e) {
            System.err.println("Error generating cost report: " + e.getMessage());
        }
    }
}
