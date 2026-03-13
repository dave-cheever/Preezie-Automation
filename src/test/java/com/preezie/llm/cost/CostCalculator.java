package com.preezie.llm.cost;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

public class CostCalculator {

    public CostSummary calculateSummary(List<UsageData> usageDataList) {
        if (usageDataList == null || usageDataList.isEmpty()) {
            return new CostSummary(0, 0, 0, 0, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
        }

        int totalRequests = usageDataList.size();
        int totalPromptTokens = 0;
        int totalCompletionTokens = 0;
        int totalTokens = 0;
        BigDecimal totalInputCost = BigDecimal.ZERO;
        BigDecimal totalOutputCost = BigDecimal.ZERO;

        for (UsageData data : usageDataList) {
            totalPromptTokens += data.getPromptTokens();
            totalCompletionTokens += data.getCompletionTokens();
            totalTokens += data.getTotalTokens();
            totalInputCost = totalInputCost.add(data.getInputCost());
            totalOutputCost = totalOutputCost.add(data.getOutputCost());
        }

        return new CostSummary(
                totalRequests,
                totalPromptTokens,
                totalCompletionTokens,
                totalTokens,
                totalInputCost,
                totalOutputCost,
                totalInputCost.add(totalOutputCost)
        );
    }

    public static class CostSummary {
        private final int totalRequests;
        private final int totalPromptTokens;
        private final int totalCompletionTokens;
        private final int totalTokens;
        private final BigDecimal totalInputCost;
        private final BigDecimal totalOutputCost;
        private final BigDecimal totalCost;

        public CostSummary(int totalRequests, int totalPromptTokens, int totalCompletionTokens,
                           int totalTokens, BigDecimal totalInputCost, BigDecimal totalOutputCost,
                           BigDecimal totalCost) {
            this.totalRequests = totalRequests;
            this.totalPromptTokens = totalPromptTokens;
            this.totalCompletionTokens = totalCompletionTokens;
            this.totalTokens = totalTokens;
            this.totalInputCost = totalInputCost.setScale(6, RoundingMode.HALF_UP);
            this.totalOutputCost = totalOutputCost.setScale(6, RoundingMode.HALF_UP);
            this.totalCost = totalCost.setScale(6, RoundingMode.HALF_UP);
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

        @Override
        public String toString() {
            return String.format("""
                    ═══════════════════════════════════════
                    AI Cost Summary
                    ═══════════════════════════════════════
                    Total Requests:           %d
                    Total Prompt Tokens:      %,d
                    Total Completion Tokens:  %,d
                    Total Tokens:             %,d
                    ───────────────────────────────────────
                    Total Input Cost:         $%.6f
                    Total Output Cost:        $%.6f
                    TOTAL COST:               $%.6f
                    ───────────────────────────────────────
                    Average Cost/Request:     $%.6f
                    Avg Prompt Tokens:        %.2f
                    Avg Completion Tokens:    %.2f
                    ═══════════════════════════════════════
                    """,
                    totalRequests, totalPromptTokens, totalCompletionTokens, totalTokens,
                    totalInputCost, totalOutputCost, totalCost,
                    getAverageCostPerRequest(), getAveragePromptTokens(), getAverageCompletionTokens());
        }
    }
}
