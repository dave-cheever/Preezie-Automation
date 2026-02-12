package com.preezie.runner;

import com.intuit.karate.junit5.Karate;

import java.nio.file.Files;
import java.nio.file.Path;

public class ApiTestRunner {

    @Karate.Test
    Karate runAll() throws Exception {
        Path outDir = Path.of("target");
        Files.createDirectories(outDir);

        String usageReportPath = outDir
                .resolve("llm-usage-report-" + System.currentTimeMillis() + ".json")
                .toAbsolutePath()
                .toString();

        System.setProperty("llm.usage.report.path", usageReportPath);

        return Karate.run("classpath:com/preezie/tests/chat-traceid-cms-validation.feature")
                .relativeTo(getClass());
    }
}
