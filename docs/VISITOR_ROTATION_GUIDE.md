# Visitor Rotation System - Usage Guide

## Overview

The **Visitor Rotation System** automatically generates new `visitorId` values when testing with chat widgets that have per-visitor message limits. This prevents test failures caused by hitting the widget's spam protection limits.

---

## Problem Being Solved

**Scenario**: Your test suite has 60 test messages, but the chat widget blocks visitors after 10 messages.

**Without Rotation**: Tests 11-60 fail with "message limit exceeded" errors.

**With Rotation**: System automatically switches to a new `visitorId` every 10 messages, allowing all 60 tests to succeed.

---

## How It Works

### 1. **Initialization** (happens once per test run)
```javascript
visitorRotation.initialize('visitor_base_id', 10)
// Base ID: visitor_base_id
// Limit: 10 messages per visitor
```

### 2. **Get VisitorId** (before each message)
```javascript
var visitorId = visitorRotation.getNextVisitorId();
// Returns: visitor_base_id (messages 1-10)
// Returns: visitor_base_id_1 (messages 11-20)
// Returns: visitor_base_id_2 (messages 21-30)
// ... and so on
```

### 3. **Record Message** (after successful send)
```javascript
visitorRotation.recordMessageSent();
// Increments counter: 1/10, 2/10, ... 10/10, then rotates
```

### 4. **Automatic Rotation**
When the counter reaches the limit (e.g., 10/10):
- Next call to `getNextVisitorId()` generates a new ID
- Counter resets to 0
- Logs: `[VisitorRotation] 🔄 Rotating to: visitor_base_id_1 (rotation #1)`

---

## Configuration

### In `chat-google-sheets-validation.feature`

**Line ~40:** Adjust the message limit based on the widget's actual limit

```gherkin
* def messageLimit = 10   # CHANGE THIS to match widget's limit
```

**Common Values:**
- `10` - Conservative (recommended default)
- `20` - If widget allows more messages
- `5` - If widget is very strict

**Tip**: Set the limit **1-2 messages lower** than the widget's actual limit to be safe. For example, if the widget blocks at 12 messages, use `messageLimit = 10`.

---

## Google Sheets Configuration

### Option 1: Use Default Auto-Generated VisitorId (Recommended)

**Do nothing** - the system will automatically generate: `visitor_auto_1716345678_0` (timestamp-based)

### Option 2: Provide Base VisitorId in Google Sheets

In your **`config`** sheet, add:

| key | value |
|-----|-------|
| sessionId | your-session-id |
| visitorId | visitor_mytest_2026 |

The system will use `visitor_mytest_2026` as the base and append `_1`, `_2`, etc. for rotations.

---

## Logs and Monitoring

### Initialization Log
```
[VisitorRotation] Initialized - Base: visitor_base_id | Limit: 10
```

### Per-Message Progress Log
```
[VisitorRotation] 📊 Count: 1/10 | Current: visitor_base_id
[VisitorRotation] 📊 Count: 2/10 | Current: visitor_base_id
...
[VisitorRotation] 📊 Count: 10/10 | Current: visitor_base_id
```

### Rotation Event Log
```
[VisitorRotation] 🔄 Rotating to: visitor_base_id_1 (rotation #1)
[VisitorRotation] 📊 Count: 1/10 | Current: visitor_base_id_1
```

### Test Case Logs
```
========================================
Testing: Show me white linen pants
Tenant: Blue_Bungalow (tnt_pJ22NGJQXirUT0Y)
Expected Safe: true
SessionId: session_abc123
VisitorId: visitor_base_id_1    <-- Auto-rotated ID
========================================
```

---

## Example Test Run with 25 Messages

```
Messages 1-10  → visitorId: visitor_base_id
Messages 11-20 → visitorId: visitor_base_id_1  (rotation #1)
Messages 21-25 → visitorId: visitor_base_id_2  (rotation #2)
```

**Result**: All 25 messages succeed, no limit errors! ✅

---

## API Reference

### Functions Available in `visitor-rotation.js`

#### `initialize(baseVisitorId, rotationLimit)`
Initialize the rotation system (call once at test start).

**Parameters:**
- `baseVisitorId` (string): Base ID to use (optional, auto-generates if null)
- `rotationLimit` (number): Number of messages before rotating (default: 10)

**Returns:** Initial visitorId (string)

**Example:**
```javascript
var initialId = visitorRotation.initialize('visitor_test', 15);
// Returns: 'visitor_test'
```

---

#### `getNextVisitorId()`
Get the current visitorId (rotates automatically if limit reached).

**Parameters:** None

**Returns:** Current visitorId (string)

**Example:**
```javascript
var id = visitorRotation.getNextVisitorId();
// Returns: 'visitor_test' or 'visitor_test_1', etc.
```

---

#### `recordMessageSent()`
Record that a message was successfully sent (increments counter).

**Parameters:** None

**Returns:** None

**Example:**
```javascript
// After successful chat API call
visitorRotation.recordMessageSent();
```

---

#### `getStats()`
Get current rotation statistics for debugging.

**Parameters:** None

**Returns:** Object with current state
```javascript
{
  baseVisitorId: 'visitor_test',
  currentVisitorId: 'visitor_test_1',
  messageCount: 5,
  rotationLimit: 10,
  rotationIndex: 1
}
```

---

#### `reset()`
Reset the rotation state (useful for starting a new test run).

**Parameters:** None

**Returns:** None

**Example:**
```javascript
visitorRotation.reset();
```

---

## Troubleshooting

### Problem: Still getting "message limit exceeded" errors

**Solution 1:** Lower the `messageLimit` value
```gherkin
* def messageLimit = 8   # Try a lower value
```

**Solution 2:** Check if the widget uses a different limit mechanism
- Some widgets may limit by IP address instead of visitorId
- Some may use combined session+visitor limits

**Solution 3:** Verify rotation is working
Look for rotation logs: `🔄 Rotating to: ...`

If you don't see rotation logs, the limit may be set too high.

---

### Problem: Different tenants have different limits

**Solution:** Configure per-tenant limits in the test data

**Update `getAllEnabledTestData()` in `google-sheets-reader.js`:**
```javascript
// Add messageLimit column to each tenant's test sheet
row.messageLimit = row.messageLimit || 10; // Default to 10
```

**Update `chat-google-sheets-validation.feature`:**
```javascript
var messageLimit = testCase.messageLimit || 10;
visitorRotation.initialize(baseVisitorId, messageLimit);
```

---

## Best Practices

✅ **Set limit conservatively** - Use 80-90% of actual widget limit  
✅ **Monitor logs** - Watch for rotation events to verify it's working  
✅ **Test with small dataset first** - Verify rotation with 15-20 messages before running full suite  
✅ **Document widget limits** - Keep a note of each widget's actual limit for reference  

---

## Files Modified

1. **Created:** `src/test/resources/com/preezie/services/utils/visitor-rotation.js`
   - Core rotation logic

2. **Updated:** `src/test/resources/com/preezie/tests/chat-google-sheets-validation.feature`
   - Added visitor rotation initialization
   - Updated `runTest` function to use dynamic visitorId
   - Added `recordMessageSent()` call after successful messages

---

## Support

For issues or questions about visitor rotation:
1. Check logs for rotation events
2. Verify `messageLimit` is set correctly
3. Review this guide's troubleshooting section

