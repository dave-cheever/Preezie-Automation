package com.preezie.llm.cost;

import java.math.BigDecimal;
import java.util.Map;

public class LLMCostConfig {
    private static final Map<String, ModelPricing> MODEL_PRICING = Map.of(
            "gpt-4", new ModelPricing(new BigDecimal("0.00003"), new BigDecimal("0.00006")),
            "gpt-4.1", new ModelPricing(new BigDecimal("0.000002"), new BigDecimal("0.000008")),
            "gpt-4-turbo", new ModelPricing(new BigDecimal("0.00001"), new BigDecimal("0.00003")),
            "gpt-3.5-turbo", new ModelPricing(new BigDecimal("0.0000005"), new BigDecimal("0.0000015")),
            "claude-3-opus", new ModelPricing(new BigDecimal("0.000015"), new BigDecimal("0.000075")),
            "claude-3-sonnet", new ModelPricing(new BigDecimal("0.000003"), new BigDecimal("0.000015"))
    );

    public static ModelPricing getPricing(String modelName) {
        // Handle model name variations (e.g., "gpt-4.1-2025-04-14" -> "gpt-4.1")
        String normalizedName = modelName.toLowerCase();
        if (MODEL_PRICING.containsKey(normalizedName)) {
            return MODEL_PRICING.get(normalizedName);
        }
        // Try prefix matching for versioned models
        for (String key : MODEL_PRICING.keySet()) {
            if (normalizedName.startsWith(key)) {
                return MODEL_PRICING.get(key);
            }
        }
        // Default to gpt-4 pricing if unknown
        return MODEL_PRICING.getOrDefault("gpt-4", new ModelPricing(BigDecimal.ZERO, BigDecimal.ZERO));
    }

    public static class ModelPricing {
        private final BigDecimal inputCostPerToken;
        private final BigDecimal outputCostPerToken;

        public ModelPricing(BigDecimal inputCostPerToken, BigDecimal outputCostPerToken) {
            this.inputCostPerToken = inputCostPerToken;
            this.outputCostPerToken = outputCostPerToken;
        }

        public BigDecimal getInputCostPerToken() {
            return inputCostPerToken;
        }

        public BigDecimal getOutputCostPerToken() {
            return outputCostPerToken;
        }
    }
}
