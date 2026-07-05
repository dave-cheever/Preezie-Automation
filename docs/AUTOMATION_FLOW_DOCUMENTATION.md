# Preezie AI Automation Framework - Complete Flow Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Flow Diagram](#data-flow-diagram)
4. [Test Data Management](#test-data-management)
5. [Agent Validation Flow](#agent-validation-flow)
6. [AI Judge (LLM Evaluator)](#ai-judge-llm-evaluator)
7. [Cost Tracking](#cost-tracking)
8. [Results Reporting](#results-reporting)
9. [Configuration](#configuration)
10. [Detailed Step-by-Step Flow](#detailed-step-by-step-flow)

---

## Overview

The Preezie AI Automation Framework is a **Karate-based** test automation system designed to validate AI-powered e-commerce chat responses. It uses an **AI Judge (LLM as a Judge)** approach to validate the semantic correctness of AI responses instead of relying solely on exact string matching.

### Key Features:
- **Data-driven testing** via Google Sheets
- **Multi-tenant support** (Blue Bungalow, JB HIFI, etc.)
- **AI-powered validation** using OpenAI gpt-5.4-mini as a judge
- **Cost tracking** for LLM API usage
- **Automated results reporting** to Google Sheets

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PREEZIE AUTOMATION FRAMEWORK                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────────┐    ┌───────────────────┐    ┌────────────────────┐  │
│   │  Google Sheets   │───▶│  Test Data Loader │───▶│   Test Executor    │  │
│   │  (Test Data)     │    │  (sheets-reader)  │    │   (Karate DSL)     │  │
│   └──────────────────┘    └───────────────────┘    └────────┬───────────┘  │
│                                                              │              │
│   ┌──────────────────┐    ┌───────────────────┐             │              │
│   │   Chat API       │◀───│  Get Trace ID     │◀────────────┤              │
│   │   (Azure)        │    │  Service          │             │              │
│   └──────────────────┘    └───────────────────┘             │              │
│                                                              │              │
│   ┌──────────────────┐    ┌───────────────────┐             │              │
│   │   CMS Gateway    │◀───│  Trace Lookup     │◀────────────┤              │
│   │   (Azure)        │    │  Service          │             │              │
│   └──────────────────┘    └───────────────────┘             │              │
│                                                              │              │
│   ┌──────────────────┐    ┌───────────────────┐             │              │
│   │   OpenAI API     │◀───│  AI Judge         │◀────────────┘              │
│   │   (gpt-5.4-mini)      │    │  (LLM Evaluator)  │                            │
│   └──────────────────┘    └───────────────────┘                            │
│                                                                             │
│   ┌──────────────────┐    ┌───────────────────┐                            │
│   │   Cost Tracker   │───▶│  Google Sheets    │                            │
│   │   & Reporter     │    │  (Results)        │                            │
│   └──────────────────┘    └───────────────────┘                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              TEST EXECUTION FLOW                                │
└─────────────────────────────────────────────────────────────────────────────────┘

Step 1: Load Test Data
════════════════════════════════════════════════════════════════════════════════════
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  Google Sheets  │─────▶│  tenantConfig   │─────▶│  Filter Enabled │
│  Spreadsheet    │      │  Sheet          │      │  Tenants        │
└─────────────────┘      └─────────────────┘      └────────┬────────┘
                                                           │
                         ┌─────────────────┐               │
                         │ {TenantName}    │◀──────────────┘
                         │ Sheet           │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  Filter Enabled │
                         │  Test Cases     │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  Test Data      │
                         │  Ready          │
                         └─────────────────┘

Step 2: Execute Test for Each Content
════════════════════════════════════════════════════════════════════════════════════
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Test Data   │────▶│  Chat API    │────▶│  TraceId     │────▶│  CMS Lookup  │
│  (content,   │     │  POST        │     │  Returned    │     │  GET trace   │
│   tenantId)  │     │  /api/chat   │     │              │     │  data        │
└──────────────┘     └──────────────┘     └──────────────┘     └──────┬───────┘
                                                                       │
                                                        ┌──────────────▼───────────┐
                                                        │    Trace Data Array      │
                                                        │    [agentName, content]  │
                                                        └──────────────┬───────────┘
                                                                       │
Step 3: Validate Each Agent                                            │
════════════════════════════════════════════════════════════════════════════════════
                                                                       │
  ┌────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│promptGlobalFilter│──▶│   getIntent     │──▶│getIntentSummary │──▶│  getCategories  │
│  (Safe: bool)   │   │  (AI Validated) │   │  (AI Validated) │   │  (AI Validated) │
└─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
                              │                     │                     │
                              │                     │                     │
                      ┌───────▼─────────────────────▼─────────────────────▼───────┐
                      │                     AI JUDGE (OpenAI gpt-5.4-mini)             │
                      │  Validates: Relevance, Faithfulness, Compliance, Semantic │
                      └───────────────────────────────────────────────────────────┘
                                                   │
  ┌────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│findProductFrom  │──▶│  smartResponse  │──▶│getUserInformation│
│Prompt (AI)      │   │  (AI Validated) │   │  (AI Validated) │
└─────────────────┘   └─────────────────┘   └─────────────────┘

Step 4: Record Results & Costs
════════════════════════════════════════════════════════════════════════════════════
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  Track LLM      │──▶│  Calculate      │──▶│  Write to       │
│  Token Usage    │   │  Costs ($)      │   │  Google Sheets  │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

---

## Test Data Management

### Google Sheets Structure

The test data is managed externally in a **Google Spreadsheet** with the following sheets:

#### 1. `tenantConfig` Sheet
Controls which tenants to test.

| Column | Description | Example |
|--------|-------------|---------|
| `tenantName` | Display name of tenant | Blue_Bungalow |
| `tenantId` | Unique tenant identifier | tnt_pJ22NGJQXirUT0Y |
| `dataFile` | Reference to data sheet | Blue_Bungalow |
| `enabled` | TRUE/FALSE to run tests | TRUE |

#### 2. `config` Sheet
Global configuration values.

| Column | Description | Example |
|--------|-------------|---------|
| `key` | Configuration key | sessionId |
| `value` | Configuration value | a5c057ae-fb9c-4a34-97d9-c86aeb426f10 |

Common keys: `sessionId`, `visitorId`

#### 3. `{TenantName}` Sheets (e.g., `Blue_Bungalow`, `JB_HIFI`)
Test data for each tenant.

| Column | Description | Example |
|--------|-------------|---------|
| `content` | User query to test | milana white |
| `expectedSafe` | Expected Safe value | TRUE |
| `enabled` | TRUE/FALSE to run test | TRUE |

#### 4. `Results` Sheet
Output sheet where test results are written automatically.

---

## Agent Validation Flow

### Agents Validated (in order):

```
1. promptGlobalFilter  →  Validates if content is "Safe" (boolean check)
2. getIntentSummary    →  AI validates intent summary response
3. getIntent           →  AI validates intent classification
4. getCategories       →  AI validates category extraction
5. findProductFromPrompt → AI validates product search query extraction
6. smartResponse       →  AI validates smart response generation
7. getUserInformation  →  AI validates user information extraction
```

### How Data is Extracted from Trace:

```javascript
// The trace data contains an array of agent responses
traceData = [
  {
    agentName: "promptGlobalFilter",
    promptContent: {
      llmResponseFormated: '{"Safe": true, ...}',
      arguments: { userPrompt: "...", ... },
      llmRequestFormated: "..."
    }
  },
  {
    agentName: "getIntentSummary", 
    promptContent: {
      llmResponseFormated: "I want to find white linen pants...",
      arguments: {
        userPrompt: "show me white linen pants",
        chatHistory: "...",
        productRecommendationHistory: "...",
        lastDiscussedProduct: "..."
      },
      llmRequestFormated: "System: You are a helpful...\nUser: ..."
    }
  },
  // ... more agents
]
```

### Extraction Functions (pgf-utils.js):

| Function | Purpose | Returns |
|----------|---------|---------|
| `findFirstValidPGF(list, key)` | Finds first valid parsed response | `{parsed, item}` |
| `getFirstLLMResponseText(list)` | Gets LLM response text | String |
| `getFirstIntentSummaryPromptArguments(list)` | Gets getIntentSummary args | Object with userPrompt, chatHistory, etc. |
| `getFirstIntentPromptArguments(list)` | Gets getIntent args | Object with userPrompt, brandOverview, choices |
| `getFirstCategoriesPromptArguments(list)` | Gets getCategories args | Object with userPrompt, brandOverview, lastDiscussedCategories |
| `getFirstFindProductPromptArguments(list)` | Gets findProduct args | Object with userPrompt, genders, dynamicVariantFields |
| `getFirstSmartResponsePromptArguments(list)` | Gets smartResponse args | Object with relevant fields |
| `getFirstUserInformationPromptArguments(list)` | Gets getUserInfo args | Object with userPrompt, brandOverview |

---

## AI Judge (LLM Evaluator)

### How the AI Judge Works:

The AI Judge validates LLM responses by:

1. **Receiving Context:**
   - `PromptArguments`: Input data that was given to the original LLM
   - `LLMRequestFormattedPrompt`: The formatted prompt sent to the LLM
   - `UserMessage`: The original user query
   - `ResponseLLM`: The actual response from the LLM being validated

2. **Evaluating 4 Dimensions:**

| Score | Description | Threshold |
|-------|-------------|-----------|
| **Relevance** (0-5) | Does the response answer the user's intent? | ≥ 4 to pass |
| **Faithfulness** (0-5) | Are there any hallucinations or invented facts? | ≥ 4 to pass |
| **Instruction Compliance** (0-5) | Does it follow the prompt's rules? | ≥ 4 to pass |
| **Semantic Closeness** (0-5) | Does the meaning match the expected interpretation? | ≥ 4 to pass |

3. **Returning Judgment:**
```json
{
  "pass": true,
  "scores": {
    "relevance": 5,
    "faithfulness": 5,
    "instructionCompliance": 4,
    "semanticCloseness": 5
  },
  "issues": [],
  "summary": "Response accurately summarizes user's intent to find white linen pants"
}
```

### System Prompt (AI Judge):
```
You are an LLM Response Validator.

Your job is to evaluate whether the AI assistant's response is semantically aligned
with the intended interpretation derived from the PromptArguments,
the LLMRequestFormattedPrompt, and the UserMessage.

You must judge alignment, not exact wording.
You must detect hallucinations, instruction violations, and irrelevant responses.

You MUST return only valid JSON.
No markdown. No explanations outside JSON.
```

### Validation Files:

| File | Purpose |
|------|---------|
| `run-evaluator.feature` | Evaluates getIntentSummary |
| `run-intent-evaluator.feature` | Evaluates getIntent |
| `run-categories-evaluator.feature` | Evaluates getCategories |
| `run-findproduct-evaluator.feature` | Evaluates findProductFromPrompt |
| `run-smartresponse-evaluator.feature` | Evaluates smartResponse |
| `run-getuserinformation-evaluator.feature` | Evaluates getUserInformation |

---

## Cost Tracking

### Token Usage Recording

Each LLM API call records:
- `prompt_tokens`: Input tokens sent to LLM
- `completion_tokens`: Output tokens generated by LLM
- `total_tokens`: Sum of prompt + completion tokens

### Cost Calculation (gpt-5.4-mini Pricing):
- **Input Cost**: $0.002 per 1,000 tokens
- **Output Cost**: $0.008 per 1,000 tokens

### Cost Formula:
```
Input Cost = (prompt_tokens / 1000) × $0.002
Output Cost = (completion_tokens / 1000) × $0.008
Total Cost = Input Cost + Output Cost
```

### Cost Summary Breakdown:
- **Per Validation Type**: getIntentSummary, getIntent, getCategories, findProductFromPrompt, smartResponse, getUserInformation
- **Combined Total**: Sum of all validation types
- **Average per Request**: Total Cost ÷ Number of Requests

---

## Results Reporting

### Console Output:
```
============================================
           TEST RESULTS SUMMARY              
============================================
Total Tests: 25
Passed: 23
Failed: 2
Pass Rate: 92%
============================================
```

### Google Sheets Output (Results Tab):

| Section | Content |
|---------|---------|
| Header | "PREEZIE AI AUTOMATION TEST RESULTS" |
| Timestamp | Test execution date/time |
| Summary | Total Tests, Passed, Failed, Pass Rate |
| Failed Tests Table | TenantId, TenantName, Content, TraceId, Failed Stage, Error Details |
| Cost Summary | Per validation type + Combined totals |

---

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key for AI Judge | sk-proj-... |
| `FIREBASE_API_KEY` | Firebase API key for CMS auth | AIza... |
| `FIREBASE_EMAIL` | Firebase login email | user@preezie.com |
| `FIREBASE_PASSWORD` | Firebase login password | ******** |
| `GOOGLE_SHEETS_ID` | Spreadsheet ID for test data | 1FV7pek... |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account JSON | /path/to/credentials.json |

### karate-config.js

The configuration file:
1. Loads `.env` file from project root
2. Sets up LLM (OpenAI) configuration
3. Authenticates with Firebase for CMS access
4. Configures usage tracking hooks

---

## Detailed Step-by-Step Flow

### Complete Test Execution Sequence:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: INITIALIZATION                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1.1 GoogleSheetsTestRunner.java starts                                      │
│ 1.2 Delete previous usage.csv for clean reporting                           │
│ 1.3 Load karate-config.js                                                   │
│     ├── Read .env file                                                      │
│     ├── Set OpenAI API key                                                  │
│     └── Authenticate with Firebase → Get cmsIdToken                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: LOAD TEST DATA FROM GOOGLE SHEETS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2.1 google-sheets-reader.js fetches spreadsheet data                        │
│ 2.2 Read tenantConfig sheet → Get enabled tenants                           │
│ 2.3 For each enabled tenant:                                                │
│     ├── Read tenant's data sheet (e.g., Blue_Bungalow)                      │
│     └── Filter enabled test cases                                           │
│ 2.4 Read config sheet → Get sessionId, visitorId                            │
│ 2.5 Merge all test data into single array                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: FOR EACH TEST CASE, EXECUTE                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.1 GET TRACE ID                                                        │ │
│ │     ├── Call get-trace-id.feature                                       │ │
│ │     ├── POST to Chat API: /api/chat                                     │ │
│ │     │   Headers: { Tenantid: tenantId }                                 │ │
│ │     │   Body: { content, sessionId, visitorId, websiteUrl }             │ │
│ │     └── Extract traceId from response                                   │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.2 CMS TRACE LOOKUP                                                    │ │
│ │     ├── Call get-trace-data.feature                                     │ │
│ │     ├── GET: /cms/agents/trace/{traceId}                                │ │
│ │     │   Headers: { Authorization: Bearer cmsIdToken }                   │ │
│ │     └── Receive traceData array with all agent responses                │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.3 VALIDATE promptGlobalFilter                                         │ │
│ │     ├── Filter traceData where agentName == 'promptGlobalFilter'        │ │
│ │     ├── Parse llmResponseFormated JSON                                  │ │
│ │     ├── Extract 'Safe' value (boolean)                                  │ │
│ │     └── Compare with expectedSafe from test data                        │ │
│ │         └── If mismatch → FAIL, record error, skip remaining agents     │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.4 VALIDATE getIntentSummary (AI JUDGE)                                │ │
│ │     ├── Filter traceData where agentName == 'getIntentSummary'          │ │
│ │     ├── Extract:                                                        │ │
│ │     │   ├── llmResponseFormated (the AI's response)                     │ │
│ │     │   ├── arguments (userPrompt, chatHistory, etc.)                   │ │
│ │     │   └── llmRequestFormated (the prompt sent)                        │ │
│ │     ├── Call run-evaluator.feature with:                                │ │
│ │     │   { PromptArguments, LLMRequestFormattedPrompt,                   │ │
│ │     │     UserMessage, ResponseLLM }                                    │ │
│ │     ├── AI Judge evaluates and returns scores                           │ │
│ │     └── If pass != true → FAIL, record error                            │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.5 VALIDATE getIntent (AI JUDGE)                                       │ │
│ │     ├── Filter traceData where agentName == 'getIntent'                 │ │
│ │     ├── Extract prompt arguments (userPrompt, brandOverview, choices)   │ │
│ │     ├── Use actual UserMessage from getIntent's promptArguments         │ │
│ │     │   (NOT the test data content)                                     │ │
│ │     ├── Call run-intent-evaluator.feature                               │ │
│ │     └── If pass != true → FAIL                                          │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.6 VALIDATE getCategories (AI JUDGE)                                   │ │
│ │     ├── Filter traceData where agentName == 'getCategories'             │ │
│ │     ├── Extract (userPrompt, brandOverview, lastDiscussedCategories)    │ │
│ │     ├── Call run-categories-evaluator.feature                           │ │
│ │     └── If pass != true → FAIL                                          │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.7 VALIDATE findProductFromPrompt (AI JUDGE)                           │ │
│ │     ├── Filter traceData where agentName == 'findProductFromPrompt'     │ │
│ │     ├── Extract (userPrompt, genders, dynamicVariantFields)             │ │
│ │     ├── Call run-findproduct-evaluator.feature                          │ │
│ │     └── If pass != true → FAIL                                          │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.8 VALIDATE smartResponse (AI JUDGE)                                   │ │
│ │     ├── Filter traceData where agentName == 'smartResponse'             │ │
│ │     ├── Extract relevant prompt arguments                               │ │
│ │     ├── Call run-smartresponse-evaluator.feature                        │ │
│ │     └── If pass != true → FAIL                                          │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.9 VALIDATE getUserInformation (AI JUDGE)                              │ │
│ │     ├── Filter traceData where agentName == 'getUserInformation'        │ │
│ │     ├── Extract (userPrompt, brandOverview)                             │ │
│ │     ├── Call run-getuserinformation-evaluator.feature                   │ │
│ │     └── If pass != true → FAIL                                          │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ 3.10 RECORD RESULT                                                      │ │
│ │      ├── If all validations pass → results.passed++                     │ │
│ │      └── If any validation fails → results.failed++                     │ │
│ │          └── Record error details: tenant, content, stage, error msg    │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: GENERATE REPORTS                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4.1 Print test results summary to console                                   │
│ 4.2 Print failed test details to console                                    │
│ 4.3 Write test-results.json to target/ folder                               │
│ 4.4 Calculate cost summary from usage.csv                                   │
│ 4.5 Write results to Google Sheets (Results tab)                            │
│     ├── Test summary (passed, failed, pass rate)                            │
│     ├── Failed tests table                                                  │
│     └── AI Cost Summary (per validation type + combined)                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure Reference

```
src/test/
├── java/com/preezie/
│   ├── runner/
│   │   └── GoogleSheetsTestRunner.java      # Main test runner
│   └── llm/cost/
│       ├── CostCalculator.java              # Token cost calculations
│       ├── UsageData.java                   # Usage data model
│       ├── UsageDataWriter.java             # Write usage to CSV
│       └── GoogleSheetsResultWriter.java    # Write results to Sheets
│
└── resources/com/preezie/
    ├── tests/
    │   └── chat-google-sheets-validation.feature  # Main test feature
    │
    ├── services/
    │   ├── chat/
    │   │   └── get-trace-id.feature         # Chat API integration
    │   ├── cms/
    │   │   ├── get-trace-data.feature       # CMS trace lookup
    │   │   └── extract-agent-json-key.feature # Extract agent data
    │   ├── utils/
    │   │   ├── pgf-utils.js                 # Agent data extraction functions
    │   │   └── google-sheets-reader.js      # Google Sheets data loader
    │   └── chat-request.json                # Request template
    │
    └── llm/
        ├── helpers/
        │   ├── llm-client.feature           # OpenAI API client
        │   ├── run-evaluator.feature        # getIntentSummary evaluator
        │   ├── run-intent-evaluator.feature # getIntent evaluator
        │   ├── run-categories-evaluator.feature
        │   ├── run-findproduct-evaluator.feature
        │   ├── run-smartresponse-evaluator.feature
        │   └── run-getuserinformation-evaluator.feature
        │
        └── validators/
            ├── llm-evaluator.js             # Validation logic
            └── prompts/
                ├── evaluator-system.prompt.txt
                └── evaluator-user.prompt.txt
```

---

## Quick Reference: Key Functions

### Getting TraceId
```gherkin
* def chat = karate.call('classpath:com/preezie/services/chat/get-trace-id.feature', {
    content: 'milana white',
    tenantId: 'tnt_pJ22NGJQXirUT0Y',
    sessionId: sessionId,
    visitorId: visitorId
  })
* def traceId = chat.traceId
```

### CMS Trace Lookup
```gherkin
* def cmsResponse = karate.call('classpath:com/preezie/services/cms/get-trace-data.feature', {
    cmsBase: cmsBase,
    traceId: traceId,
    cmsIdToken: cmsIdToken
  })
* def traceData = cmsResponse.data
```

### Filtering Agent Data
```javascript
var intentSummaryItems = karate.filter(traceData, function(x){ 
  return x.agentName == 'getIntentSummary' 
});
```

### Extracting LLM Response
```javascript
var llmResponseText = utils.getFirstLLMResponseText(intentSummaryItems);
var promptArgs = utils.getFirstIntentSummaryPromptArguments(intentSummaryItems);
```

### Running AI Evaluator
```gherkin
* def evalResult = karate.call('classpath:com/preezie/llm/helpers/run-evaluator.feature', {
    PromptArguments: promptArgs,
    LLMRequestFormattedPrompt: llmRequestText,
    UserMessage: content,
    ResponseLLM: llmResponseText,
    tenantId: tenantId,
    content: content
  })
* def passed = evalResult.validationOut.pass === true
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "cmsIdToken is not defined" | Set FIREBASE_API_KEY, FIREBASE_EMAIL, FIREBASE_PASSWORD env vars |
| "Missing LLM API key" | Set OPENAI_API_KEY environment variable |
| "Failed to fetch Google Sheet" | Ensure spreadsheet is published to web |
| "403 Forbidden writing to Sheets" | Ensure Sheets API is enabled & service account has Editor access |
| "AI Judge returns pass: false" | Check the scores - at least one dimension is < 4 |

---

## Summary

The Preezie AI Automation Framework provides:

1. **External Test Data**: Managed in Google Sheets for easy updates
2. **Multi-Tenant Support**: Test multiple clients in one run
3. **AI-Powered Validation**: Uses gpt-5.4-mini to judge response quality
4. **Cost Transparency**: Tracks every API call and calculates costs
5. **Automated Reporting**: Results pushed back to Google Sheets

This approach enables semantic validation rather than brittle string matching, making tests more robust and meaningful.

---

*Document generated for Preezie Automation Framework*
*Last Updated: April 2026*

