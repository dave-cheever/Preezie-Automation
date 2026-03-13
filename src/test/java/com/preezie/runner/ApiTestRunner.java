package com.preezie.runner;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.preezie.llm.cost.CostReportGenerator;
import com.preezie.llm.cost.TestReportGenerator;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class ApiTestRunner {

    @Test
    void runAll() throws Exception {
        Path outDir = Path.of("target");
        Files.createDirectories(outDir);

        // Delete old usage.csv to start fresh
        Path usageCsvPath = outDir.resolve("usage.csv");
        if (Files.exists(usageCsvPath)) {
            Files.delete(usageCsvPath);
            System.out.println("Deleted old usage.csv for clean report");
        }

        String usageReportPath = outDir
                .resolve("llm-usage-report-" + System.currentTimeMillis() + ".json")
                .toAbsolutePath()
                .toString();

        System.setProperty("llm.usage.report.path", usageReportPath);

        Results results = Runner.path("classpath:com/preezie/tests/chat-traceid-cms-validation.feature")
                .outputCucumberJson(true)
                .parallel(1);

        // Print test results summary
        System.out.println("\n");
        System.out.println("╔══════════════════════════════════════════════════════════════╗");
        System.out.println("║                      TEST RESULTS                            ║");
        System.out.println("╠══════════════════════════════════════════════════════════════╣");
        System.out.printf("║  Total Scenarios: %-43d ║%n", results.getScenariosTotal());
        System.out.printf("║  Passed:          %-43d ║%n", results.getScenariosPassed());
        System.out.printf("║  Failed:          %-43d ║%n", results.getFailCount());
        System.out.println("╚══════════════════════════════════════════════════════════════╝");

        // Print failure details if any
        if (results.getFailCount() > 0) {
            System.out.println("\n");
            System.out.println("╔══════════════════════════════════════════════════════════════╗");
            System.out.println("║                    FAILURE DETAILS                           ║");
            System.out.println("╚══════════════════════════════════════════════════════════════╝");
            System.out.println(results.getErrorMessages());
        }

        // Print cost summary after all tests complete
        System.out.println("\n");
        try {
            CostReportGenerator.generateReport("target/usage.csv");
        } catch (Exception e) {
            System.err.println("Warning: Could not generate cost report: " + e.getMessage());
        }

        // Generate downloadable reports (CSV and HTML)
        try {
            TestReportGenerator reportGenerator = new TestReportGenerator("target/reports");
            reportGenerator.generateFullReport(results, "target/usage.csv");
        } catch (Exception e) {
            System.err.println("Warning: Could not generate downloadable reports: " + e.getMessage());
        }

        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
