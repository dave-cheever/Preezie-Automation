package com.preezie.controller;

import com.preezie.model.UsageStatistics;
import com.preezie.service.UsageTrackerService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/usage")
public class UsageController {

    private final UsageTrackerService usageTrackerService;

    public UsageController(UsageTrackerService usageTrackerService) {
        this.usageTrackerService = usageTrackerService;
    }

    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> getSummary() {
        Map<String, Object> summary = new HashMap<>();
        summary.put("requestCount", usageTrackerService.getRequestCount());
        summary.put("averageUsage", usageTrackerService.getAverageUsage());
        summary.put("totalUsage", usageTrackerService.getTotalUsage());
        return ResponseEntity.ok(summary);
    }

    @PostMapping("/reset")
    public ResponseEntity<Map<String, String>> reset() {
        usageTrackerService.reset();
        Map<String, String> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "Usage history cleared");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/export")
    public ResponseEntity<Map<String, String>> exportToFile(
            @RequestParam(required = false) String filename) {

        if (filename == null || filename.isEmpty()) {
            String timestamp = LocalDateTime.now()
                    .format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
            filename = "usage_report_" + timestamp + ".json";
        }

        try {
            usageTrackerService.exportToFile(filename);
            Map<String, String> response = new HashMap<>();
            response.put("status", "success");
            response.put("filename", filename);
            response.put("requestCount", String.valueOf(usageTrackerService.getRequestCount()));
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            Map<String, String> error = new HashMap<>();
            error.put("status", "error");
            error.put("message", e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }

    @PostMapping("/record")
    public ResponseEntity<Map<String, String>> recordUsage(@RequestBody UsageStatistics usage) {
        usageTrackerService.recordUsage(usage);
        Map<String, String> response = new HashMap<>();
        response.put("status", "success");
        response.put("totalRequests", String.valueOf(usageTrackerService.getRequestCount()));
        return ResponseEntity.ok(response);
    }
}
