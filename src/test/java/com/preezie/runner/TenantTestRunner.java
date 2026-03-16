package com.preezie.runner;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.preezie.llm.cost.CostReportGenerator;
import com.preezie.llm.cost.TestReportGenerator;
import com.preezie.utils.TestDataFilter;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Test runner for tenant-specific validation tests.
 * Test data is loaded from external CSV files in src/test/resources/testdata/
 * 
 * To enable/disable tenants, edit testdata/tenant-config.json
 * To enable/disable specific test cases, edit the 'enabled' column in each CSV file
 * 
 * Run options:
 *   - mvn test -Dtest=TenantTestRunner              (all enabled tenants)
 *   - mvn test -Dtest=TenantTestRunner#runBlueBungalow   (specific tenant)
 */
public class TenantTestRunner {

    private static final String USAGE_CSV_PATH = System.getProperty("user.dir") + "/target/usage.csv";

    @Test
    void runAllEnabledTenants() throws Exception {
        // Show enabled tenants
        List<String> enabledTenants = TestDataFilter.getEnabledTenants();
        System.out.println("===========================================");
        System.out.println("ENABLED TENANTS: " + enabledTenants);
        System.out.println("===========================================");
        
        if (enabledTenants.isEmpty()) {
            System.out.println("No tenants enabled in tenant-config.json");
            return;
        }

        // Delete existing usage.csv for a clean report
        try {
            Files.deleteIfExists(Paths.get(USAGE_CSV_PATH));
            System.out.println("Cleared previous usage.csv");
        } catch (Exception e) {
            System.out.println("Warning: Could not delete usage.csv: " + e.getMessage());
        }

        // Build the list of feature files to run based on enabled tenants
        StringBuilder featurePaths = new StringBuilder();
        for (String tenant : enabledTenants) {
            String featurePath = getFeaturePathForTenant(tenant);
            if (featurePath != null) {
                if (featurePaths.length() > 0) featurePaths.append(",");
                featurePaths.append(featurePath);
            }
        }

        if (featurePaths.length() == 0) {
            System.out.println("No feature files found for enabled tenants");
            return;
        }

        // Run the tests
        Results results = Runner.path(featurePaths.toString().split(","))
                .outputCucumberJson(true)
                .parallel(1);

        // Print test results summary
        printTestSummary(results);

        // Print cost summary
        printCostSummary();

        // Generate downloadable HTML report
        generateHtmlReport(results);

        // Assert no failures
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }

    @Test
    void runBlueBungalow() throws Exception {
        runSingleTenant("Blue_Bungalow", "classpath:com/preezie/tests/tenants/blue-bungalow-validation.feature");
    }

    @Test
    void runJBHifi() throws Exception {
        runSingleTenant("JB_HIFI", "classpath:com/preezie/tests/tenants/jb-hifi-validation.feature");
    }

    @Test
    void runPuma() throws Exception {
        runSingleTenant("PUMA", "classpath:com/preezie/tests/tenants/puma-validation.feature");
    }

    private void runSingleTenant(String tenantName, String featurePath) throws Exception {
        if (!TestDataFilter.isTenantEnabled(tenantName)) {
            System.out.println("SKIPPED: " + tenantName + " is disabled in tenant-config.json");
            return;
        }

        // Delete existing usage.csv for a clean report
        try {
            Files.deleteIfExists(Paths.get(USAGE_CSV_PATH));
        } catch (Exception e) {
            // ignore
        }

        System.out.println("===========================================");
        System.out.println("Running tests for: " + tenantName);
        System.out.println("===========================================");

        Results results = Runner.path(featurePath)
                .outputCucumberJson(true)
                .parallel(1);

        printTestSummary(results);
        printCostSummary();

        // Generate downloadable HTML report
        generateHtmlReport(results);

        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }

    private String getFeaturePathForTenant(String tenantName) {
        switch (tenantName.toLowerCase().replace(" ", "_")) {
            case "blue_bungalow":
                return "classpath:com/preezie/tests/tenants/blue-bungalow-validation.feature";
            case "jb_hifi":
                return "classpath:com/preezie/tests/tenants/jb-hifi-validation.feature";
            case "puma":
                return "classpath:com/preezie/tests/tenants/puma-validation.feature";
            default:
                System.out.println("Unknown tenant: " + tenantName);
                return null;
        }
    }

    private void printTestSummary(Results results) {
        System.out.println("\n");
        System.out.println("╔══════════════════════════════════════════════════════════════╗");
        System.out.println("║                      TEST RESULTS                            ║");
        System.out.println("╠══════════════════════════════════════════════════════════════╣");
        System.out.printf("║  Total Scenarios: %-43d ║%n", results.getScenariosTotal());
        System.out.printf("║  Passed:          %-43d ║%n", results.getScenariosPassed());
        System.out.printf("║  Failed:          %-43d ║%n", results.getFailCount());
        double passRate = results.getScenariosTotal() > 0 
            ? (double) results.getScenariosPassed() / results.getScenariosTotal() * 100 
            : 0;
        System.out.printf("║  Pass Rate:       %-42.1f%% ║%n", passRate);
        System.out.println("╚══════════════════════════════════════════════════════════════╝");

        // Print failure details if any
        if (results.getFailCount() > 0) {
            System.out.println("\n");
            System.out.println("╔══════════════════════════════════════════════════════════════╗");
            System.out.println("║                    FAILURE DETAILS                           ║");
            System.out.println("╚══════════════════════════════════════════════════════════════╝");
            System.out.println(results.getErrorMessages());
        }
    }

    private void printCostSummary() {
        System.out.println("\n");
        System.out.println("===========================================");
        System.out.println("         GENERATING COST SUMMARY           ");
        System.out.println("===========================================");

        try {
            File usageFile = new File(USAGE_CSV_PATH);
            if (usageFile.exists() && usageFile.length() > 0) {
                CostReportGenerator.generateReport(USAGE_CSV_PATH);
            } else {
                System.out.println("No usage data found in: " + USAGE_CSV_PATH);
                System.out.println("(This may happen if no LLM evaluator calls were made)");
            }
        } catch (Exception e) {
            System.out.println("Error generating cost summary: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void generateHtmlReport(Results results) {
        System.out.println("\n");
        System.out.println("===========================================");
        System.out.println("       GENERATING HTML TEST REPORT         ");
        System.out.println("===========================================");

        try {
            TestReportGenerator reportGenerator = new TestReportGenerator("target/reports");
            reportGenerator.generateFullReport(results, USAGE_CSV_PATH);
        } catch (Exception e) {
            System.out.println("Warning: Could not generate HTML report: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
