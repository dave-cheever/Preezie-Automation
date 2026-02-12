package com.preezie.model;

public class UsageStatistics {
    private int promptTokens;
    private int completionTokens;
    private int totalTokens;
    private int cachedTokens;
    private int audioTokens;

    public UsageStatistics() {}

    public UsageStatistics(int promptTokens, int completionTokens, int totalTokens,
                           int cachedTokens, int audioTokens) {
        this.promptTokens = promptTokens;
        this.completionTokens = completionTokens;
        this.totalTokens = totalTokens;
        this.cachedTokens = cachedTokens;
        this.audioTokens = audioTokens;
    }

    // Getters and setters
    public int getPromptTokens() { return promptTokens; }
    public void setPromptTokens(int promptTokens) { this.promptTokens = promptTokens; }
    public int getCompletionTokens() { return completionTokens; }
    public void setCompletionTokens(int completionTokens) { this.completionTokens = completionTokens; }
    public int getTotalTokens() { return totalTokens; }
    public void setTotalTokens(int totalTokens) { this.totalTokens = totalTokens; }
    public int getCachedTokens() { return cachedTokens; }
    public void setCachedTokens(int cachedTokens) { this.cachedTokens = cachedTokens; }
    public int getAudioTokens() { return audioTokens; }
    public void setAudioTokens(int audioTokens) { this.audioTokens = audioTokens; }
}
