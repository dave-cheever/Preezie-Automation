package com.preezie.runner;

import com.intuit.karate.junit5.Karate;

/**
 * Test runner for Google Sheets data-driven tests.
 * 
 * The test data is loaded from a Google Spreadsheet.
 * Make sure the spreadsheet is published to web (File > Share > Publish to web)
 * 
 * Configure the spreadsheet ID via:
 *   - Environment variable: GOOGLE_SHEETS_ID
 *   - System property: -DgoogleSheetsId=YOUR_SPREADSHEET_ID
 *   - .env file: GOOGLE_SHEETS_ID=YOUR_SPREADSHEET_ID
 *   - karate-config.js default value
 * 
 * Required Sheets in the Spreadsheet:
 *   - tenantConfig: columns [tenantName, tenantId, dataFile, enabled]
 *   - {TenantName}: columns [content, expectedSafe, intent, enabled]
 */
public class GoogleSheetsTestRunner {

    @Karate.Test
    Karate runGoogleSheetsTests() {
        return Karate.run("classpath:com/preezie/tests/chat-google-sheets-validation.feature")
                .relativeTo(getClass());
    }
}

