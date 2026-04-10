package com.preezie.llm.cost;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

public class CostCalculator {

    public CostSummary calculateSummary(List<UsageData> usageDataList) {
        if (usageDataList == null || usageDataList.isEmpty()) {
            return new CostSummary(0, 0, 0, 0, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, 
                    new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary());
        }

        int totalRequests = usageDataList.size();
        int totalPromptTokens = 0;
        int totalCompletionTokens = 0;
        int totalTokens = 0;
        BigDecimal totalInputCost = BigDecimal.ZERO;
        BigDecimal totalOutputCost = BigDecimal.ZERO;
        
        // Separate tracking for each validation type
        ValidationTypeSummary intentSummarySummary = new ValidationTypeSummary();
        ValidationTypeSummary intentSummary = new ValidationTypeSummary();
        ValidationTypeSummary categoriesSummary = new ValidationTypeSummary();
        ValidationTypeSummary findProductSummary = new ValidationTypeSummary();
        ValidationTypeSummary smartResponseSummary = new ValidationTypeSummary();
        ValidationTypeSummary getUserInformationSummary = new ValidationTypeSummary();
        ValidationTypeSummary specificQuestionSubIntentSummary = new ValidationTypeSummary();
        ValidationTypeSummary multiProductQuestionSubIntentSummary = new ValidationTypeSummary();
        ValidationTypeSummary searchingByTitleSummary = new ValidationTypeSummary();

        for (UsageData data : usageDataList) {
            totalPromptTokens += data.getPromptTokens();
            totalCompletionTokens += data.getCompletionTokens();
            totalTokens += data.getTotalTokens();
            totalInputCost = totalInputCost.add(data.getInputCost());
            totalOutputCost = totalOutputCost.add(data.getOutputCost());
            
            // Count by validation type
            String content = data.getContent();
            if (content != null) {
                if (content.contains("[getIntentSummary]")) {
                    intentSummarySummary.addUsage(data);
                } else if (content.contains("[getIntent]")) {
                    intentSummary.addUsage(data);
                } else if (content.contains("[getCategories]")) {
                    categoriesSummary.addUsage(data);
                } else if (content.contains("[findProductFromPrompt]")) {
                    findProductSummary.addUsage(data);
                } else if (content.contains("[smartResponse]")) {
                    smartResponseSummary.addUsage(data);
                } else if (content.contains("[getUserInformation]")) {
                    getUserInformationSummary.addUsage(data);
                } else if (content.contains("[getSpecificQuestionSubIntent]")) {
                    specificQuestionSubIntentSummary.addUsage(data);
                } else if (content.contains("[getMultiProductQuestionSubIntent]")) {
                    multiProductQuestionSubIntentSummary.addUsage(data);
                } else if (content.contains("[searchingByTitle]")) {
                    searchingByTitleSummary.addUsage(data);
                }
            }
        }

        return new CostSummary(
                totalRequests,
                totalPromptTokens,
                totalCompletionTokens,
                totalTokens,
                totalInputCost,
                totalOutputCost,
                totalInputCost.add(totalOutputCost),
                intentSummarySummary,
                intentSummary,
                categoriesSummary,
                findProductSummary,
                smartResponseSummary,
                getUserInformationSummary,
                specificQuestionSubIntentSummary,
                multiProductQuestionSubIntentSummary,
                searchingByTitleSummary
        );
    }

    /**
     * Holds summary data for a specific validation type (getIntent or getIntentSummary)
     */
    public static class ValidationTypeSummary {
        private int count = 0;
        private int promptTokens = 0;
        private int completionTokens = 0;
        private int totalTokens = 0;
        private BigDecimal inputCost = BigDecimal.ZERO;
        private BigDecimal outputCost = BigDecimal.ZERO;

        public void addUsage(UsageData data) {
            count++;
            promptTokens += data.getPromptTokens();
            completionTokens += data.getCompletionTokens();
            totalTokens += data.getTotalTokens();
            inputCost = inputCost.add(data.getInputCost());
            outputCost = outputCost.add(data.getOutputCost());
        }

        public int getCount() { return count; }
        public int getPromptTokens() { return promptTokens; }
        public int getCompletionTokens() { return completionTokens; }
        public int getTotalTokens() { return totalTokens; }
        public BigDecimal getInputCost() { return inputCost; }
        public BigDecimal getOutputCost() { return outputCost; }
        public BigDecimal getTotalCost() { return inputCost.add(outputCost); }
        
        public double getAvgPromptTokens() { return count > 0 ? (double) promptTokens / count : 0; }
        public double getAvgCompletionTokens() { return count > 0 ? (double) completionTokens / count : 0; }
        public BigDecimal getAvgCostPerRequest() {
            return count > 0 ? getTotalCost().divide(BigDecimal.valueOf(count), 6, RoundingMode.HALF_UP) : BigDecimal.ZERO;
        }
    }

    public static class CostSummary {
        private final int totalRequests;
        private final int totalPromptTokens;
        private final int totalCompletionTokens;
        private final int totalTokens;
        private final BigDecimal totalInputCost;
        private final BigDecimal totalOutputCost;
        private final BigDecimal totalCost;
        private final ValidationTypeSummary getIntentSummarySummary;
        private final ValidationTypeSummary getIntentSummary;
        private final ValidationTypeSummary getCategoriesSummary;
        private final ValidationTypeSummary getFindProductSummary;
        private final ValidationTypeSummary getSmartResponseSummary;
        private final ValidationTypeSummary getGetUserInformationSummary;
        private final ValidationTypeSummary getSpecificQuestionSubIntentSummary;
        private final ValidationTypeSummary getMultiProductQuestionSubIntentSummary;
        private final ValidationTypeSummary getSearchingByTitleSummary;

        public CostSummary(int totalRequests, int totalPromptTokens, int totalCompletionTokens,
                           int totalTokens, BigDecimal totalInputCost, BigDecimal totalOutputCost,
                           BigDecimal totalCost, ValidationTypeSummary getIntentSummarySummary,
                           ValidationTypeSummary getIntentSummary, ValidationTypeSummary getCategoriesSummary,
                           ValidationTypeSummary getFindProductSummary, ValidationTypeSummary getSmartResponseSummary,
                           ValidationTypeSummary getGetUserInformationSummary, ValidationTypeSummary getSpecificQuestionSubIntentSummary,
                           ValidationTypeSummary getMultiProductQuestionSubIntentSummary, ValidationTypeSummary getSearchingByTitleSummary) {
            this.totalRequests = totalRequests;
            this.totalPromptTokens = totalPromptTokens;
            this.totalCompletionTokens = totalCompletionTokens;
            this.totalTokens = totalTokens;
            this.totalInputCost = totalInputCost.setScale(6, RoundingMode.HALF_UP);
            this.totalOutputCost = totalOutputCost.setScale(6, RoundingMode.HALF_UP);
            this.totalCost = totalCost.setScale(6, RoundingMode.HALF_UP);
            this.getIntentSummarySummary = getIntentSummarySummary;
            this.getIntentSummary = getIntentSummary;
            this.getCategoriesSummary = getCategoriesSummary;
            this.getFindProductSummary = getFindProductSummary;
            this.getSmartResponseSummary = getSmartResponseSummary;
            this.getGetUserInformationSummary = getGetUserInformationSummary;
            this.getSpecificQuestionSubIntentSummary = getSpecificQuestionSubIntentSummary;
            this.getMultiProductQuestionSubIntentSummary = getMultiProductQuestionSubIntentSummary;
            this.getSearchingByTitleSummary = getSearchingByTitleSummary;
        }

        public BigDecimal getAverageCostPerRequest() {
            return totalRequests > 0
                    ? totalCost.divide(BigDecimal.valueOf(totalRequests), 6, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
        }

        public double getAveragePromptTokens() {
            return totalRequests > 0 ? (double) totalPromptTokens / totalRequests : 0;
        }

        public double getAverageCompletionTokens() {
            return totalRequests > 0 ? (double) totalCompletionTokens / totalRequests : 0;
        }

        // Getters
        public int getTotalRequests() { return totalRequests; }
        public int getTotalPromptTokens() { return totalPromptTokens; }
        public int getTotalCompletionTokens() { return totalCompletionTokens; }
        public int getTotalTokens() { return totalTokens; }
        public BigDecimal getTotalInputCost() { return totalInputCost; }
        public BigDecimal getTotalOutputCost() { return totalOutputCost; }
        public BigDecimal getTotalCost() { return totalCost; }
        public ValidationTypeSummary getGetIntentSummarySummary() { return getIntentSummarySummary; }
        public ValidationTypeSummary getGetIntentSummary() { return getIntentSummary; }
        public ValidationTypeSummary getGetCategoriesSummary() { return getCategoriesSummary; }
        public ValidationTypeSummary getGetFindProductSummary() { return getFindProductSummary; }
        public ValidationTypeSummary getGetSmartResponseSummary() { return getSmartResponseSummary; }
        public ValidationTypeSummary getGetUserInformationSummary() { return getGetUserInformationSummary; }
        public ValidationTypeSummary getGetSpecificQuestionSubIntentSummary() { return getSpecificQuestionSubIntentSummary; }
        public ValidationTypeSummary getGetMultiProductQuestionSubIntentSummary() { return getMultiProductQuestionSubIntentSummary; }
        public ValidationTypeSummary getGetSearchingByTitleSummary() { return getSearchingByTitleSummary; }
        
        // Double getters for easier use
        public double getTotalInputCostDouble() { return totalInputCost.doubleValue(); }
        public double getTotalOutputCostDouble() { return totalOutputCost.doubleValue(); }
        public double getTotalCostDouble() { return totalCost.doubleValue(); }
        public double getAverageCostPerRequestDouble() { return getAverageCostPerRequest().doubleValue(); }
        public double getAvgPromptTokens() { return getAveragePromptTokens(); }
        public double getAvgCompletionTokens() { return getAverageCompletionTokens(); }

        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder();
            
            // getIntentSummary Section
            sb.append("""
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getIntentSummary
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getIntentSummarySummary.getCount(),
                    getIntentSummarySummary.getPromptTokens(),
                    getIntentSummarySummary.getCompletionTokens(),
                    getIntentSummarySummary.getTotalTokens(),
                    getIntentSummarySummary.getInputCost(),
                    getIntentSummarySummary.getOutputCost(),
                    getIntentSummarySummary.getTotalCost(),
                    getIntentSummarySummary.getAvgCostPerRequest(),
                    getIntentSummarySummary.getAvgPromptTokens(),
                    getIntentSummarySummary.getAvgCompletionTokens()));

            // getIntent Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getIntent
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getIntentSummary.getCount(),
                    getIntentSummary.getPromptTokens(),
                    getIntentSummary.getCompletionTokens(),
                    getIntentSummary.getTotalTokens(),
                    getIntentSummary.getInputCost(),
                    getIntentSummary.getOutputCost(),
                    getIntentSummary.getTotalCost(),
                    getIntentSummary.getAvgCostPerRequest(),
                    getIntentSummary.getAvgPromptTokens(),
                    getIntentSummary.getAvgCompletionTokens()));

            // getCategories Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getCategories
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getCategoriesSummary.getCount(),
                    getCategoriesSummary.getPromptTokens(),
                    getCategoriesSummary.getCompletionTokens(),
                    getCategoriesSummary.getTotalTokens(),
                    getCategoriesSummary.getInputCost(),
                    getCategoriesSummary.getOutputCost(),
                    getCategoriesSummary.getTotalCost(),
                    getCategoriesSummary.getAvgCostPerRequest(),
                    getCategoriesSummary.getAvgPromptTokens(),
                    getCategoriesSummary.getAvgCompletionTokens()));

            // findProductFromPrompt Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - findProductFromPrompt
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getFindProductSummary.getCount(),
                    getFindProductSummary.getPromptTokens(),
                    getFindProductSummary.getCompletionTokens(),
                    getFindProductSummary.getTotalTokens(),
                    getFindProductSummary.getInputCost(),
                    getFindProductSummary.getOutputCost(),
                    getFindProductSummary.getTotalCost(),
                    getFindProductSummary.getAvgCostPerRequest(),
                    getFindProductSummary.getAvgPromptTokens(),
                    getFindProductSummary.getAvgCompletionTokens()));

            // smartResponse Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - smartResponse
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getSmartResponseSummary.getCount(),
                    getSmartResponseSummary.getPromptTokens(),
                    getSmartResponseSummary.getCompletionTokens(),
                    getSmartResponseSummary.getTotalTokens(),
                    getSmartResponseSummary.getInputCost(),
                    getSmartResponseSummary.getOutputCost(),
                    getSmartResponseSummary.getTotalCost(),
                    getSmartResponseSummary.getAvgCostPerRequest(),
                    getSmartResponseSummary.getAvgPromptTokens(),
                    getSmartResponseSummary.getAvgCompletionTokens()));

            // getUserInformation Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getUserInformation
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getGetUserInformationSummary.getCount(),
                    getGetUserInformationSummary.getPromptTokens(),
                    getGetUserInformationSummary.getCompletionTokens(),
                    getGetUserInformationSummary.getTotalTokens(),
                    getGetUserInformationSummary.getInputCost(),
                    getGetUserInformationSummary.getOutputCost(),
                    getGetUserInformationSummary.getTotalCost(),
                    getGetUserInformationSummary.getAvgCostPerRequest(),
                    getGetUserInformationSummary.getAvgPromptTokens(),
                    getGetUserInformationSummary.getAvgCompletionTokens()));

            // getSpecificQuestionSubIntent Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getSpecificQuestionSubIntent
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getSpecificQuestionSubIntentSummary.getCount(),
                    getSpecificQuestionSubIntentSummary.getPromptTokens(),
                    getSpecificQuestionSubIntentSummary.getCompletionTokens(),
                    getSpecificQuestionSubIntentSummary.getTotalTokens(),
                    getSpecificQuestionSubIntentSummary.getInputCost(),
                    getSpecificQuestionSubIntentSummary.getOutputCost(),
                    getSpecificQuestionSubIntentSummary.getTotalCost(),
                    getSpecificQuestionSubIntentSummary.getAvgCostPerRequest(),
                    getSpecificQuestionSubIntentSummary.getAvgPromptTokens(),
                    getSpecificQuestionSubIntentSummary.getAvgCompletionTokens()));

            // getMultiProductQuestionSubIntent Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - getMultiProductQuestionSubIntent
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getMultiProductQuestionSubIntentSummary.getCount(),
                    getMultiProductQuestionSubIntentSummary.getPromptTokens(),
                    getMultiProductQuestionSubIntentSummary.getCompletionTokens(),
                    getMultiProductQuestionSubIntentSummary.getTotalTokens(),
                    getMultiProductQuestionSubIntentSummary.getInputCost(),
                    getMultiProductQuestionSubIntentSummary.getOutputCost(),
                    getMultiProductQuestionSubIntentSummary.getTotalCost(),
                    getMultiProductQuestionSubIntentSummary.getAvgCostPerRequest(),
                    getMultiProductQuestionSubIntentSummary.getAvgPromptTokens(),
                    getMultiProductQuestionSubIntentSummary.getAvgCompletionTokens()));

            // searchingByTitle Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - searchingByTitle
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Evaluations:              %d
                    Prompt Tokens:            %,d
                    Completion Tokens:        %,d
                    Total Tokens:             %,d
                    Input Cost:               $%.6f
                    Output Cost:              $%.6f
                    Total Cost:               $%.6f
                    Avg Cost/Evaluation:      $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    """,
                    getSearchingByTitleSummary.getCount(),
                    getSearchingByTitleSummary.getPromptTokens(),
                    getSearchingByTitleSummary.getCompletionTokens(),
                    getSearchingByTitleSummary.getTotalTokens(),
                    getSearchingByTitleSummary.getInputCost(),
                    getSearchingByTitleSummary.getOutputCost(),
                    getSearchingByTitleSummary.getTotalCost(),
                    getSearchingByTitleSummary.getAvgCostPerRequest(),
                    getSearchingByTitleSummary.getAvgPromptTokens(),
                    getSearchingByTitleSummary.getAvgCompletionTokens()));

            // Combined Total Section
            sb.append("""
                    
                    ═══════════════════════════════════════════════════════════════
                                    COMBINED TOTAL AI COST SUMMARY
                    ═══════════════════════════════════════════════════════════════
                    """);
            sb.append(String.format("""
                    Total AI Evaluations:     %d
                      - getIntentSummary:     %d
                      - getIntent:            %d
                      - getCategories:        %d
                      - findProductFromPrompt:%d
                      - smartResponse:        %d
                      - getUserInformation:   %d
                      - getSpecificQuestionSubIntent: %d
                      - getMultiProductQuestionSubIntent: %d
                      - searchingByTitle:     %d
                    ───────────────────────────────────────────────────────────────
                    Total Prompt Tokens:      %,d
                    Total Completion Tokens:  %,d
                    Total Tokens:             %,d
                    ───────────────────────────────────────────────────────────────
                    Total Input Cost:         $%.6f
                    Total Output Cost:        $%.6f
                    TOTAL COST:               $%.6f
                    ───────────────────────────────────────────────────────────────
                    Average Cost/Evaluation:  $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    ═══════════════════════════════════════════════════════════════
                    """,
                    totalRequests, getIntentSummarySummary.getCount(), getIntentSummary.getCount(), getCategoriesSummary.getCount(), getFindProductSummary.getCount(), getSmartResponseSummary.getCount(), getGetUserInformationSummary.getCount(), getSpecificQuestionSubIntentSummary.getCount(), getMultiProductQuestionSubIntentSummary.getCount(), getSearchingByTitleSummary.getCount(),
                    totalPromptTokens, totalCompletionTokens, totalTokens,
                    totalInputCost, totalOutputCost, totalCost,
                    getAverageCostPerRequest(), getAveragePromptTokens(), getAverageCompletionTokens()));

            return sb.toString();
        }
    }
}
