package com.preezie.llm.cost;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

public class CostCalculator {

    public CostSummary calculateSummary(List<UsageData> usageDataList) {
        if (usageDataList == null || usageDataList.isEmpty()) {
            return new CostSummary(0, 0, 0, 0, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, 
                    new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary(), new ValidationTypeSummary());
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
        ValidationTypeSummary specificProductQuestionSummary = new ValidationTypeSummary();
        ValidationTypeSummary specificProductQuestionResponseSummary = new ValidationTypeSummary();
        ValidationTypeSummary specificProductSizeRecommendationSummary = new ValidationTypeSummary();
        ValidationTypeSummary similarBaseProductSummary = new ValidationTypeSummary();
        ValidationTypeSummary productCompareResponseSummary = new ValidationTypeSummary();
        ValidationTypeSummary findBaseProductSummary = new ValidationTypeSummary();
        ValidationTypeSummary findProductsToBundleSummary = new ValidationTypeSummary();
        ValidationTypeSummary generalConversationSummary = new ValidationTypeSummary();

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
                } else if (content.contains("[specificProductQuestionResponse]")) {
                    specificProductQuestionResponseSummary.addUsage(data);
                } else if (content.contains("[specificProductSizeRecommendation]")) {
                    specificProductSizeRecommendationSummary.addUsage(data);
                } else if (content.contains("[similarBaseProduct]")) {
                    similarBaseProductSummary.addUsage(data);
                } else if (content.contains("[productCompareResponse]")) {
                    productCompareResponseSummary.addUsage(data);
                } else if (content.contains("[findBaseProduct]")) {
                    findBaseProductSummary.addUsage(data);
                } else if (content.contains("[findProductsToBundle]")) {
                    findProductsToBundleSummary.addUsage(data);
                } else if (content.contains("[generalConversation]")) {
                    generalConversationSummary.addUsage(data);
                } else if (content.contains("[specificProductQuestion]")) {
                    specificProductQuestionSummary.addUsage(data);
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
                searchingByTitleSummary,
                specificProductQuestionSummary,
                specificProductQuestionResponseSummary,
                specificProductSizeRecommendationSummary,
                similarBaseProductSummary,
                productCompareResponseSummary,
                findBaseProductSummary,
                findProductsToBundleSummary,
                generalConversationSummary
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
        private final ValidationTypeSummary getSpecificProductQuestionSummary;
        private final ValidationTypeSummary getSpecificProductQuestionResponseSummary;
        private final ValidationTypeSummary getSpecificProductSizeRecommendationSummary;
        private final ValidationTypeSummary getSimilarBaseProductSummary;
        private final ValidationTypeSummary getProductCompareResponseSummary;
        private final ValidationTypeSummary getFindBaseProductSummary;
        private final ValidationTypeSummary getFindProductsToBundleSummary;
        private final ValidationTypeSummary getGeneralConversationSummary;

        public CostSummary(int totalRequests, int totalPromptTokens, int totalCompletionTokens,
                           int totalTokens, BigDecimal totalInputCost, BigDecimal totalOutputCost,
                           BigDecimal totalCost, ValidationTypeSummary getIntentSummarySummary,
                           ValidationTypeSummary getIntentSummary, ValidationTypeSummary getCategoriesSummary,
                           ValidationTypeSummary getFindProductSummary, ValidationTypeSummary getSmartResponseSummary,
                           ValidationTypeSummary getGetUserInformationSummary, ValidationTypeSummary getSpecificQuestionSubIntentSummary,
                           ValidationTypeSummary getMultiProductQuestionSubIntentSummary, ValidationTypeSummary getSearchingByTitleSummary,
                           ValidationTypeSummary getSpecificProductQuestionSummary, ValidationTypeSummary getSpecificProductQuestionResponseSummary,
                            ValidationTypeSummary getSpecificProductSizeRecommendationSummary,
                            ValidationTypeSummary getSimilarBaseProductSummary,
                            ValidationTypeSummary getProductCompareResponseSummary,
                            ValidationTypeSummary getFindBaseProductSummary,
                            ValidationTypeSummary getFindProductsToBundleSummary,
                            ValidationTypeSummary getGeneralConversationSummary) {
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
            this.getSpecificProductQuestionSummary = getSpecificProductQuestionSummary;
            this.getSpecificProductQuestionResponseSummary = getSpecificProductQuestionResponseSummary;
            this.getSpecificProductSizeRecommendationSummary = getSpecificProductSizeRecommendationSummary;
            this.getSimilarBaseProductSummary = getSimilarBaseProductSummary;
            this.getProductCompareResponseSummary = getProductCompareResponseSummary;
            this.getFindBaseProductSummary = getFindBaseProductSummary;
            this.getFindProductsToBundleSummary = getFindProductsToBundleSummary;
            this.getGeneralConversationSummary = getGeneralConversationSummary;
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
        public ValidationTypeSummary getGetSpecificProductQuestionSummary() { return getSpecificProductQuestionSummary; }
        public ValidationTypeSummary getGetSpecificProductQuestionResponseSummary() { return getSpecificProductQuestionResponseSummary; }
        public ValidationTypeSummary getGetSpecificProductSizeRecommendationSummary() { return getSpecificProductSizeRecommendationSummary; }
        public ValidationTypeSummary getGetSimilarBaseProductSummary() { return getSimilarBaseProductSummary; }
        public ValidationTypeSummary getGetProductCompareResponseSummary() { return getProductCompareResponseSummary; }
        public ValidationTypeSummary getGetFindBaseProductSummary() { return getFindBaseProductSummary; }
        public ValidationTypeSummary getGetFindProductsToBundleSummary() { return getFindProductsToBundleSummary; }
        public ValidationTypeSummary getGetGeneralConversationSummary() { return getGeneralConversationSummary; }
        
        // Double getters for easier use
        public double getTotalInputCostDouble() { return totalInputCost.doubleValue(); }
        public double getTotalOutputCostDouble() { return totalOutputCost.doubleValue(); }
        public double getTotalCostDouble() { return totalCost.doubleValue(); }
        public double getAverageCostPerRequestDouble() { return getAverageCostPerRequest().doubleValue(); }
        public double getAvgPromptTokens() { return getAveragePromptTokens(); }
        public double getAvgCompletionTokens() { return getAverageCompletionTokens(); }

        private void appendSummarySection(StringBuilder sb, String title, ValidationTypeSummary summary) {
            if (summary == null || summary.getCount() <= 0) {
                return;
            }

            sb.append(String.format("""
                    ═══════════════════════════════════════════════════════════════
                                    AI COST SUMMARY - %s
                    ═══════════════════════════════════════════════════════════════
                    """, title));
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
                    summary.getCount(),
                    summary.getPromptTokens(),
                    summary.getCompletionTokens(),
                    summary.getTotalTokens(),
                    summary.getInputCost(),
                    summary.getOutputCost(),
                    summary.getTotalCost(),
                    summary.getAvgCostPerRequest(),
                    summary.getAvgPromptTokens(),
                    summary.getAvgCompletionTokens()));
        }

        private void appendCountLine(StringBuilder sb, String label, int count) {
            if (count > 0) {
                sb.append(String.format("  - %-32s %d%n", label + ":", count));
            }
        }

        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder();
            appendSummarySection(sb, "getIntentSummary", getIntentSummarySummary);
            appendSummarySection(sb, "getIntent", getIntentSummary);
            appendSummarySection(sb, "getCategories", getCategoriesSummary);
            appendSummarySection(sb, "findProductFromPrompt", getFindProductSummary);
            appendSummarySection(sb, "smartResponse", getSmartResponseSummary);
            appendSummarySection(sb, "getUserInformation", getGetUserInformationSummary);
            appendSummarySection(sb, "getSpecificQuestionSubIntent", getSpecificQuestionSubIntentSummary);
            appendSummarySection(sb, "getMultiProductQuestionSubIntent", getMultiProductQuestionSubIntentSummary);
            appendSummarySection(sb, "searchingByTitle", getSearchingByTitleSummary);
            appendSummarySection(sb, "specificProductQuestion", getSpecificProductQuestionSummary);
            appendSummarySection(sb, "specificProductQuestionResponse", getSpecificProductQuestionResponseSummary);
            appendSummarySection(sb, "specificProductSizeRecommendation", getSpecificProductSizeRecommendationSummary);
            appendSummarySection(sb, "similarBaseProduct", getSimilarBaseProductSummary);
            appendSummarySection(sb, "productCompareResponse", getProductCompareResponseSummary);
            appendSummarySection(sb, "findBaseProduct", getFindBaseProductSummary);
            appendSummarySection(sb, "findProductsToBundle", getFindProductsToBundleSummary);
            appendSummarySection(sb, "generalConversation", getGeneralConversationSummary);

            if (totalRequests > 0) {
                sb.append("""
                        
                        ═══════════════════════════════════════════════════════════════
                                        COMBINED TOTAL AI COST SUMMARY
                        ═══════════════════════════════════════════════════════════════
                        """);
                sb.append("Total AI Evaluations:     ").append(totalRequests).append('\n');
                appendCountLine(sb, "getIntentSummary", getIntentSummarySummary.getCount());
                appendCountLine(sb, "getIntent", getIntentSummary.getCount());
                appendCountLine(sb, "getCategories", getCategoriesSummary.getCount());
                appendCountLine(sb, "findProductFromPrompt", getFindProductSummary.getCount());
                appendCountLine(sb, "smartResponse", getSmartResponseSummary.getCount());
                appendCountLine(sb, "getUserInformation", getGetUserInformationSummary.getCount());
                appendCountLine(sb, "getSpecificQuestionSubIntent", getSpecificQuestionSubIntentSummary.getCount());
                appendCountLine(sb, "getMultiProductQuestionSubIntent", getMultiProductQuestionSubIntentSummary.getCount());
                appendCountLine(sb, "searchingByTitle", getSearchingByTitleSummary.getCount());
                appendCountLine(sb, "specificProductQuestion", getSpecificProductQuestionSummary.getCount());
                appendCountLine(sb, "specificProductQuestionResponse", getSpecificProductQuestionResponseSummary.getCount());
                appendCountLine(sb, "specificProductSizeRecommendation", getSpecificProductSizeRecommendationSummary.getCount());
                appendCountLine(sb, "similarBaseProduct", getSimilarBaseProductSummary.getCount());
                appendCountLine(sb, "productCompareResponse", getProductCompareResponseSummary.getCount());
                appendCountLine(sb, "findBaseProduct", getFindBaseProductSummary.getCount());
                appendCountLine(sb, "findProductsToBundle", getFindProductsToBundleSummary.getCount());
                appendCountLine(sb, "generalConversation", getGeneralConversationSummary.getCount());
                sb.append("───────────────────────────────────────────────────────────────\n");
                sb.append(String.format("Total Prompt Tokens:      %,d%n", totalPromptTokens));
                sb.append(String.format("Total Completion Tokens:  %,d%n", totalCompletionTokens));
                sb.append(String.format("Total Tokens:             %,d%n", totalTokens));
                sb.append("───────────────────────────────────────────────────────────────\n");
                sb.append(String.format("Total Input Cost:         $%.6f%n", totalInputCost));
                sb.append(String.format("Total Output Cost:        $%.6f%n", totalOutputCost));
                sb.append(String.format("TOTAL COST:               $%.6f%n", totalCost));
                sb.append("───────────────────────────────────────────────────────────────\n");
                sb.append(String.format("Average Cost/Evaluation:  $%.6f%n", getAverageCostPerRequest()));
                sb.append(String.format("Avg Prompt Tokens:        %.2f%n", getAveragePromptTokens()));
                sb.append(String.format("Avg Completion Tokens:    %.2f%n", getAverageCompletionTokens()));
                sb.append("═══════════════════════════════════════════════════════════════\n");
            }

            return sb.toString();
        }
    }
}
