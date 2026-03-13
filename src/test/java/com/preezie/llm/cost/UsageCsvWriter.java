package com.preezie.llm.cost;

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class UsageCsvWriter {
    private static final String CSV_HEADER = "tenantId,content,modelName,prompt_tokens,completion_tokens,total_tokens,cached_tokens,audio_tokens,input_cost,output_cost,total_cost";
    private final String filePath;

    public UsageCsvWriter(String filePath) {
        this.filePath = filePath;
    }

    public void writeUsage(UsageData usageData) throws IOException {
        Path path = Paths.get(filePath);
        boolean fileExists = Files.exists(path);

        try (FileWriter writer = new FileWriter(filePath, true)) {
            if (!fileExists) {
                writer.write(CSV_HEADER + "\n");
            }
            writer.write(usageData.toCsvRow() + "\n");
        }
    }
}
