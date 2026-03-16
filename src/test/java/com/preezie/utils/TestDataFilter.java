package com.preezie.utils;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * Utility class to filter test data from CSV files based on 'enabled' column.
 * Also checks tenant-config.json to determine which tenants are enabled.
 */
public class TestDataFilter {

    private static final ObjectMapper mapper = new ObjectMapper();

    /**
     * Reads CSV and returns only rows where enabled=true
     */
    public static List<Map<String, Object>> getEnabledTestData(String csvResourcePath) {
        List<Map<String, Object>> enabledRows = new ArrayList<>();
        
        try (InputStream is = TestDataFilter.class.getClassLoader().getResourceAsStream(csvResourcePath)) {
            if (is == null) {
                System.err.println("Could not find resource: " + csvResourcePath);
                return enabledRows;
            }
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(is));
            String headerLine = reader.readLine();
            if (headerLine == null) return enabledRows;
            
            String[] headers = headerLine.split(",");
            String line;
            
            while ((line = reader.readLine()) != null) {
                if (line.trim().isEmpty()) continue;
                
                String[] values = line.split(",");
                Map<String, Object> row = new HashMap<>();
                
                for (int i = 0; i < headers.length && i < values.length; i++) {
                    String value = values[i].trim();
                    // Convert boolean strings
                    if ("true".equalsIgnoreCase(value)) {
                        row.put(headers[i].trim(), true);
                    } else if ("false".equalsIgnoreCase(value)) {
                        row.put(headers[i].trim(), false);
                    } else {
                        row.put(headers[i].trim(), value);
                    }
                }
                
                // Only include if enabled is true
                Object enabled = row.get("enabled");
                if (Boolean.TRUE.equals(enabled) || "true".equalsIgnoreCase(String.valueOf(enabled))) {
                    enabledRows.add(row);
                }
            }
        } catch (Exception e) {
            System.err.println("Error reading CSV: " + e.getMessage());
            e.printStackTrace();
        }
        
        System.out.println("Filtered " + enabledRows.size() + " enabled rows from " + csvResourcePath);
        return enabledRows;
    }

    /**
     * Check if a tenant is enabled in tenant-config.json
     */
    public static boolean isTenantEnabled(String tenantName) {
        try (InputStream is = TestDataFilter.class.getClassLoader().getResourceAsStream("testdata/tenant-config.json")) {
            if (is == null) {
                System.err.println("tenant-config.json not found");
                return true; // Default to enabled if config not found
            }
            
            Map<String, Object> config = mapper.readValue(is, Map.class);
            List<Map<String, Object>> tenants = (List<Map<String, Object>>) config.get("tenants");
            
            for (Map<String, Object> tenant : tenants) {
                String name = (String) tenant.get("tenantName");
                if (tenantName.equalsIgnoreCase(name) || 
                    tenantName.replace(" ", "_").equalsIgnoreCase(name) ||
                    tenantName.replace("_", " ").equalsIgnoreCase(name)) {
                    Object enabled = tenant.get("enabled");
                    return Boolean.TRUE.equals(enabled);
                }
            }
        } catch (Exception e) {
            System.err.println("Error reading tenant config: " + e.getMessage());
        }
        return true; // Default to enabled
    }

    /**
     * Get list of enabled tenant names
     */
    public static List<String> getEnabledTenants() {
        List<String> enabledTenants = new ArrayList<>();
        
        try (InputStream is = TestDataFilter.class.getClassLoader().getResourceAsStream("testdata/tenant-config.json")) {
            if (is == null) return enabledTenants;
            
            Map<String, Object> config = mapper.readValue(is, Map.class);
            List<Map<String, Object>> tenants = (List<Map<String, Object>>) config.get("tenants");
            
            for (Map<String, Object> tenant : tenants) {
                Object enabled = tenant.get("enabled");
                if (Boolean.TRUE.equals(enabled)) {
                    enabledTenants.add((String) tenant.get("tenantName"));
                }
            }
        } catch (Exception e) {
            System.err.println("Error reading tenant config: " + e.getMessage());
        }
        
        return enabledTenants;
    }
}

