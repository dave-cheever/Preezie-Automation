package com.preezie.service;

import com.preezie.model.UsageStatistics;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.io.FileWriter;
import java.io.IOException;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class UsageTrackerService {
    private final List<UsageStatistics> usageHistory = new CopyOnWriteArrayList<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public void recordUsage(UsageStatistics usage) {
        usageHistory.add(usage);
    }

    public UsageStatistics getAverageUsage() {
        if (usageHistory.isEmpty()) {
            return new UsageStatistics(0, 0, 0, 0, 0);
        }

        int totalPrompt = 0;
        int totalCompletion = 0;
        int totalTokens = 0;
        int totalCached = 0;
        int totalAudio = 0;

        for (UsageStatistics usage : usageHistory) {
            totalPrompt += usage.getPromptTokens();
            totalCompletion += usage.getCompletionTokens();
            totalTokens += usage.getTotalTokens();
            totalCached += usage.getCachedTokens();
            totalAudio += usage.getAudioTokens();
        }

        int count = usageHistory.size();
        return new UsageStatistics(
                totalPrompt / count,
                totalCompletion / count,
                totalTokens / count,
                totalCached / count,
                totalAudio / count
        );
    }

    public UsageStatistics getTotalUsage() {
        int totalPrompt = 0;
        int totalCompletion = 0;
        int totalTokens = 0;
        int totalCached = 0;
        int totalAudio = 0;

        for (UsageStatistics usage : usageHistory) {
            totalPrompt += usage.getPromptTokens();
            totalCompletion += usage.getCompletionTokens();
            totalTokens += usage.getTotalTokens();
            totalCached += usage.getCachedTokens();
            totalAudio += usage.getAudioTokens();
        }

        return new UsageStatistics(totalPrompt, totalCompletion, totalTokens, totalCached, totalAudio);
    }

    public int getRequestCount() {
        return usageHistory.size();
    }

    public void reset() {
        usageHistory.clear();
    }

    public void exportToFile(String filename) throws IOException {
        UsageSummary summary = new UsageSummary(
                getRequestCount(),
                getAverageUsage(),
                getTotalUsage(),
                usageHistory
        );

        try (FileWriter writer = new FileWriter(filename)) {
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(writer, summary);
        }
    }

    // Inner class for export summary
    public static class UsageSummary {
        private int requestCount;
        private UsageStatistics averageUsage;
        private UsageStatistics totalUsage;
        private List<UsageStatistics> history;

        public UsageSummary(int requestCount, UsageStatistics averageUsage,
                            UsageStatistics totalUsage, List<UsageStatistics> history) {
            this.requestCount = requestCount;
            this.averageUsage = averageUsage;
            this.totalUsage = totalUsage;
            this.history = history;
        }

        // Getters for JSON serialization
        public int getRequestCount() { return requestCount; }
        public UsageStatistics getAverageUsage() { return averageUsage; }
        public UsageStatistics getTotalUsage() { return totalUsage; }
        public List<UsageStatistics> getHistory() { return history; }
    }
}
