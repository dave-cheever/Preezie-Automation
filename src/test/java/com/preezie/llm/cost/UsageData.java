package com.preezie.llm.cost;

import java.math.BigDecimal;
import java.math.RoundingMode;

public class UsageData {
    private final String tenantId;
    private final String content;
    private final String modelName;
    private final int promptTokens;
    private final int completionTokens;
    private final int totalTokens;
    private final int cachedTokens;
    private final int audioTokens;
    private final BigDecimal inputCost;
    private final BigDecimal outputCost;
    private final BigDecimal totalCost;

    private UsageData(Builder builder) {
        this.tenantId = builder.tenantId;
        this.content = builder.content;
        this.modelName = builder.modelName;
        this.promptTokens = builder.promptTokens;
        this.completionTokens = builder.completionTokens;
        this.totalTokens = builder.totalTokens;
        this.cachedTokens = builder.cachedTokens;
        this.audioTokens = builder.audioTokens;

        LLMCostConfig.ModelPricing pricing = LLMCostConfig.getPricing(modelName);
        this.inputCost = pricing.getInputCostPerToken()
                .multiply(BigDecimal.valueOf(promptTokens))
                .setScale(6, RoundingMode.HALF_UP);
        this.outputCost = pricing.getOutputCostPerToken()
                .multiply(BigDecimal.valueOf(completionTokens))
                .setScale(6, RoundingMode.HALF_UP);
        this.totalCost = inputCost.add(outputCost);
    }

    // Getters
    public String getTenantId() { return tenantId; }
    public String getContent() { return content; }
    public String getModelName() { return modelName; }
    public int getPromptTokens() { return promptTokens; }
    public int getCompletionTokens() { return completionTokens; }
    public int getTotalTokens() { return totalTokens; }
    public int getCachedTokens() { return cachedTokens; }
    public int getAudioTokens() { return audioTokens; }
    public BigDecimal getInputCost() { return inputCost; }
    public BigDecimal getOutputCost() { return outputCost; }
    public BigDecimal getTotalCost() { return totalCost; }

    public String toCsvRow() {
        return String.format("%s,%s,%s,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f",
                tenantId, content, modelName, promptTokens, completionTokens,
                totalTokens, cachedTokens, audioTokens,
                inputCost, outputCost, totalCost);
    }

    public static class Builder {
        private String tenantId;
        private String content;
        private String modelName = "gpt-4"; // default
        private int promptTokens;
        private int completionTokens;
        private int totalTokens;
        private int cachedTokens;
        private int audioTokens;

        public Builder tenantId(String tenantId) {
            this.tenantId = tenantId;
            return this;
        }

        public Builder content(String content) {
            this.content = content;
            return this;
        }

        public Builder modelName(String modelName) {
            this.modelName = modelName;
            return this;
        }

        public Builder promptTokens(int promptTokens) {
            this.promptTokens = promptTokens;
            return this;
        }

        public Builder completionTokens(int completionTokens) {
            this.completionTokens = completionTokens;
            return this;
        }

        public Builder totalTokens(int totalTokens) {
            this.totalTokens = totalTokens;
            return this;
        }

        public Builder cachedTokens(int cachedTokens) {
            this.cachedTokens = cachedTokens;
            return this;
        }

        public Builder audioTokens(int audioTokens) {
            this.audioTokens = audioTokens;
            return this;
        }

        public UsageData build() {
            return new UsageData(this);
        }
    }
}
