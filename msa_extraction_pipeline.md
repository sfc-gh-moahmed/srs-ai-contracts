---
title: "MSA Contract Extraction Pipeline"
author: "Azenta SRS × Snowflake Cortex"
theme: default
marp: true
paginate: true
style: |
  section { font-size: 17px; padding: 20px 30px 15px 30px; }
  table { font-size: 13px; margin: 4px 0; }
  h1 { color: #29B5E8; font-size: 30px; margin: 0 0 4px 0; }
  h2 { color: #11567F; font-size: 24px; margin: 0 0 4px 0; }
  h3 { font-size: 19px; margin: 0 0 2px 0; }
  .columns { display: flex; gap: 1.5rem; }
  .col { flex: 1; }
  code { font-size: 12px; }
  pre { font-size: 12px; margin: 4px 0; }
  blockquote { font-size: 15px; margin: 4px 0; border-left: 4px solid #29B5E8; padding-left: 10px; }
  li { font-size: 16px; margin: 2px 0; }
  p { margin: 4px 0; }
  ul, ol { margin: 4px 0; }
  .tag { background: #11567F; color: white; padding: 2px 8px; border-radius: 4px; font-size: 13px; }
  .green { color: #27ae60; font-weight: bold; }
  .red { color: #e74c3c; font-weight: bold; }
  .blue { color: #11567F; font-weight: bold; }
---

# MSA Contract Extraction Pipeline
## Snowflake Cortex AI × Azenta SRS

**Document Intelligence at Scale** — Extract, Compare, Validate

- 2 real MSA contracts: **BMS** (13 pages) + **Sanofi** (18 pages)
- 2 AI pipelines: **AI_EXTRACT** (schema) vs **AI_COMPLETE** (prompt)
- 2 output tables: **Storage Pricing** + **Management Fees**
- Streamlit in Snowflake for visualization + validation

---

## The Business Problem

Azenta manages **~600 customer MSA contracts** with complex pricing tables.

Manual extraction is:
- Error-prone (dense 2D matrices, multi-currency, multi-region)
- Slow (hours per contract)
- Inconsistent across analysts

**Goal:** Automated pipeline that extracts, structures, and validates pricing from PDFs into Snowflake tables — enabling billing accuracy checks at scale.

---

## Document Structure (What We're Extracting)

<div class="columns">
<div class="col">

**Storage Pricing** — 2D matrix
- Rows: Quantity tiers (1–500K, 500K–1M, ...)
- Columns: Sample sizes (≤1.4mL → >6000mL)
- Per temperature: Ambient, −20°C, −80°C, LN2
- Per region: 6 biobank locations
- Multi-currency: USD / EUR / SGD

</div>
<div class="col">

**Management Fees** — tabular
- Project Initiation Fees
- Sample Administration (≤2000mL / >2000mL)
- Lab Services
- Professional Services
- Additional Services

</div>
</div>

> **Challenge:** 6 qty tiers × 11 sample-size columns × 3 temperatures = 198+ cells per document

---

## Architecture Overview

![Architecture diagram](https://kroki.io/mermaid/svg/eNpN0N2KwjAQBeB7n2JewBfwYiHNTxWsDTYrC6GU7DrUgRhLDfj6ZqcL21wdON8MScY5TDdwagPlCG-VAUMRn_BI0OUwYg_b7QdUXhwGK86dHlQrPxt9cj2PVFxLz50aZHtyZyFdNzj99UckE-UtTRgpIYgdlG2l_5Vro_9NxUa2jT1qpxekGBnf5cdcbgZ2ph9KI7jwHXFNat-EVMQdUwaD5TUropctq1xzNpz3_hIiXUOm8gEXwtcyVC8l5z3nQ7nGjOEeKYOYpv4NlOFYUw==)

---

## Why AI_PARSE_DOCUMENT First?

Both pipelines start with `AI_PARSE_DOCUMENT` — here's why:

| Reason | Impact at 600 MSA scale |
|--------|------------------------|
| **Parse once, extract many** | Re-run Pipeline A, B, multiple models without re-paying PDF parsing |
| **LAYOUT mode preserves tables** | Dense 2D matrices → structured Markdown — critical for accuracy |
| **Debuggable** | Inspect intermediate text to diagnose extraction failures |
| **Page-level control** | Filter to only relevant pages before expensive AI calls |

> `AI_EXTRACT` *can* accept a file directly — but two-stage with cache is best practice at scale.

---

## The Critical Token Limit Problem

`AI_EXTRACT` table output is capped at **4,096 output tokens per question**.

Sanofi Rate Card: 198+ pricing cells → JSON output easily overflows → **silent truncation, rows dropped**.

**Solution: page_split=TRUE**

![Token strategy](https://kroki.io/mermaid/svg/eNpdz29LwzAQBvD3for7AoMpIvONkDXZH1xt2TJQQhmxvdWwmNTmyua3t0tAxHv9e-65a3vdfYDkNzAOUxxdQCj5AjrdYgWTyRPMFVsfSrbdiQMvsn0uXiRs2Fuxl1VMzaPKVOEQen-GDvuYhkC-xyahLCJ-XSVe5ZZl8tclwCMQKtcXuJ8-PoAfqBsIyJ_GmyL-GjCQ8S4FRAws1M641mJqPBoKEPQR7fff2uW1NivyciOk-Ne7jGKlbu9mz1B7R3ghOBvXjJ98-gZtSG4V3VrpviZTw7v19QmbdCp50rb6AY9sYKE=)

> Single page ≈ 150–400 tokens of pricing JSON — safely within 4,096 limit.

---

## Pipeline A: AI_PARSE_DOCUMENT + AI_EXTRACT

![Pipeline A](https://kroki.io/mermaid/svg/eNpVzu0KgjAUBuD_XcW5AW8gKFjzbAl-MScUI8aSZYKVuN0_6QrR8_d9zntOO5rhCanYwTRElTGDzxsqb1p7gyg6wkmRRJdEVKjjgtYZ5hJSci1qCcOEtBv6zh-kqPEWOk5hi6rSjtEMoDHN04I3997-BA0iVqzrvR334PxnnOGs3ZrgQh52E8chZvNneJGCULmUuOnYy_wYBsbXbCpyG8OCOatKFoJw1KVIaJLz9b88kERlPJOaIVb_8Asm0lov)

**Schema-based extraction** — deterministic, no prompt engineering needed.

- `responseFormat` defines exact columns + descriptions
- `column_ordering` with parallel arrays → flatten via `ARRAY_GENERATE_RANGE`
- Two `AI_EXTRACT` calls per document: one for storage, one for fees
- Avoids 10-table-question-per-call limit

---

## Pipeline A: Key SQL Pattern

```sql
-- Per-page extraction: one row per page in cache table
WITH page_extractions AS (
    SELECT PAGE_TEXT,
        AI_EXTRACT(
            PAGE_TEXT,
            responseFormat => {
                'schema': { 'type': 'object', 'properties': {
                    'storage_rows': {
                        'description': 'All storage pricing rows...',
                        'type': 'object',
                        'column_ordering': ['temperature','sample_size_label',
                                           'min_qty','max_qty','price_usd'],
                        'properties': {
                            'temperature':  {'type': 'array'},
                            'price_usd':    {'type': 'array'} -- ...etc
                        }
                    }
                }}
            }
        ):response AS extraction
    FROM PARSED_CONTRACTS_TEXT
    WHERE FILENAME = :P_FILENAME AND PAGE_TEXT ILIKE '%storage%'
)
-- Flatten parallel arrays into rows
SELECT extraction:storage_rows:temperature[idx.value]::VARCHAR AS temperature,
       extraction:storage_rows:price_usd[idx.value]::VARCHAR   AS price
FROM page_extractions,
TABLE(FLATTEN(ARRAY_GENERATE_RANGE(0, ARRAY_SIZE(...)))) AS idx;
```

---

## Pipeline B: AI_PARSE_DOCUMENT + AI_COMPLETE

![Pipeline B](https://kroki.io/mermaid/svg/eNpNy00OgyAQhuF9TzEX8ApNEEdigz8BNg0xhFaiC38Isujxa9FFZ_Ul7zNjsH4CLm5wHNHUvic3gLejg-g-sYcsu0OuSWVoW3ccFcKyDW4-SLBLn97yhKh-yLYBH7bFRwhu99u6u1PQJAqtxNN0REg0P3u2IjXUnCgUhEN5DIVXxBRLLVUrCEPTiYpWDYNoX7P7J0zXrFamRJRX_AKL7TyJ)

**Prompt-based extraction** — flexible, model-swappable, better for varied document layouts.

Key differences from Pipeline A:
- `AI_COMPLETE(model, prompt + page_text, {'response_format': {'type':'json'}})`
- Model is a **parameter** — swap at call time
- `TRY_PARSE_JSON()` safely handles malformed responses
- `LATERAL FLATTEN` on JSON array response

---

## Pipeline B: Model Options

| Model | Context Window | Best For |
|-------|---------------|----------|
| `mistral-large2` | 128K | **Default** — best quality/cost balance |
| `llama3.3-70b` | 128K | Fastest, cheapest — high-volume batch |
| `claude-4-sonnet` | 200K | Highest quality — validation pass |
| `llama4-maverick` | 128K | Strong alternative |
| ~~`snowflake-arctic`~~ | ~~4,096~~| ❌ **BLOCKED** — total context too small |

> `snowflake-arctic` is explicitly rejected by the procedure with a clear error message.

```sql
CALL EXTRACT_PIPELINE_B('Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet');
-- Returns: Pipeline B (claude-4-sonnet) complete | Pages: 18 | Storage rows: 132 | Mgmt rows: 48
```

---

## Shared Parse Cache: Cost Savings

```sql
-- Parse once — stored per page
SELECT FILENAME, COUNT(*) AS PAGES
FROM PARSED_CONTRACTS_TEXT
GROUP BY FILENAME;
-- BMS:   13 pages
-- Sanofi: 18 pages   ← parse cost paid ONCE

-- Re-run Pipeline B with 3 models: ZERO additional parsing cost
CALL EXTRACT_PIPELINE_B('Sanofi_MSA.pdf', 'SANOFI', 'mistral-large2');
CALL EXTRACT_PIPELINE_B('Sanofi_MSA.pdf', 'SANOFI', 'llama3.3-70b');    -- no re-parse
CALL EXTRACT_PIPELINE_B('Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet'); -- no re-parse
```

> At 600 documents: parse once = ~6,000 pages. Re-running extractions with different models/schemas costs only AI function tokens, not PDF parsing.

---

## Output Tables

<div class="columns">
<div class="col">

**Storage Pricing**
`SI.PUBLIC.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST`

```
FILENAME          → source PDF
CUSTOMER_ID       → BMS / SANOFI
TEMPERATURE       → Ambient / -20C / -80C
SAMPLE_SIZE       → ≤1.4mL → >6000mL
QUANTITY_TIER     → 1-500,000 etc.
MIN/MAX_QTY       → numeric tier bounds
MIN/MAX_SAMPLE_SIZE → mL bounds
PRICE             → per region/currency
REGION / CURRENCY → North America / USD
CUBIC_FOOT_MAX    → for $/Cu.Ft. pricing
TRANSACTION_TYPE  → STORAGE (default)
EXTRACTION_METHOD → which pipeline/model
```

</div>
<div class="col">

**Management Fees**
`SI.PUBLIC.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST`

```
FILENAME
CUSTOMER_ID
FEE_CATEGORY      → Project Initiation
                    Sample Admin ≤2000mL
                    Lab Services
                    Professional Services
FEE_NAME          → specific fee name
CURRENCY
PRICE
UNIT              → per sample / per hour
DESCRIPTION       → conditions/notes
EXTRACTION_METHOD
```

</div>
</div>

---

## Validation Layer

Three views compare extracted output against ground-truth tables:

```sql
-- Row-level match status
SELECT CUSTOMER_ID, EXTRACTION_METHOD, TEMPERATURE, SAMPLE_SIZE,
       EXTRACTED_PRICE, EXPECTED_PRICE, PRICE_DELTA, MATCH_STATUS
FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_PRICING
WHERE MATCH_STATUS = 'MISMATCH';

-- Match rate summary
SELECT CUSTOMER_ID, EXTRACTION_METHOD, TABLE_TYPE,
       MATCHED_ROWS, TOTAL_ROWS, MATCH_RATE_PCT
FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY;
```

**Match statuses:** `EXACT_MATCH` · `NEAR_MATCH` · `WITHIN_1PCT` · `MISMATCH` · `NO_EXPECTED`

---

## Streamlit in Snowflake App

5 tabs, runs natively in Snowsight — no external infrastructure:

| Tab | Purpose |
|-----|---------|
| **▶ Run Pipeline** | Select file + customer, choose A or B, pick model, execute stored proc |
| **📦 Storage Pricing** | Filterable grid by temperature / region / method |
| **💼 Management Fees** | Filterable grid by fee category / customer / method |
| **⚖️ A vs B Comparison** | Side-by-side diff: ✅ Match / 🔴 Diff / ⚪ B missing |
| **✅ Validation** | Match rate gauges + row-level mismatch table |

```sql
-- Deploy
CREATE OR REPLACE STREAMLIT SRS_AI_CONTRACTS.AGENTS.MSA_EXTRACTION_APP
    ROOT_LOCATION = '@SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'SRS_CONTRACTS_WH';
```

---

## End-to-End Run Order

```
01  01_setup_database.sql          ← existing (database, stage, warehouse)
02  10_create_extraction_tables.sql ← parse cache + 2 output tables
03  11_upload_pdfs.sql              ← PUT BMS + Sanofi to CONTRACT_STAGE
04  12_pipeline_a_ai_parse_extract.sql  ← create stored proc A
05  13_pipeline_b_ai_parse_complete.sql ← create stored proc B
06  14_validation_view.sql          ← 3 validation views
07  15_run_all.sql                  ← CALL both procs for both files + verify
08  16_deploy_streamlit.sql         ← PUT app.py + CREATE STREAMLIT
```

All scripts use `SET DB_NAME / SET SCHEMA_NAME` at the top — fully portable to any Snowflake account.

---

## Scaling to 600 Contracts

| Step | Per-document cost driver | Optimization |
|------|--------------------------|-------------|
| Parse | Pages × 970 tokens | Cache — parse once per file |
| AI_EXTRACT | Pages × 970 tokens (input) + table output ≤4,096/question | Page filter — only relevant pages |
| AI_COMPLETE | Prompt + page_text tokens | Per-page — avoid oversized context |
| Batch | Sequential stored proc calls | Wrap in `CALL` loop over directory table |

```sql
-- Batch all PDFs in stage
SELECT CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    d.RELATIVE_PATH,
    REPLACE(REPLACE(d.RELATIVE_PATH, '.pdf',''), ' ', '_')
)
FROM DIRECTORY(@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE) d
WHERE d.RELATIVE_PATH LIKE '%.pdf';
```

---

## Summary

<div class="columns">
<div class="col">

**Pipeline A: AI_EXTRACT**
- Schema-enforced → deterministic
- Best for structured tables
- Faster, no prompt tuning
- 2 calls per doc (storage + fees)
- ✅ Recommended for production

</div>
<div class="col">

**Pipeline B: AI_COMPLETE**
- Prompt-flexible → adaptable
- Best for varied document layouts
- Model-swappable (4 options)
- Better for nuanced reasoning
- ✅ Recommended for validation / edge cases

</div>
</div>

**Both share the parse cache** → parse cost is paid once regardless of how many times you extract.

> Repo: `https://github.com/sfc-gh-moahmed/srs-ai-contracts`

---

<!-- _class: lead -->

# Questions?

**Repo:** `github.com/sfc-gh-moahmed/srs-ai-contracts`

Run order: `deploy/01–09` (existing demo) → `pipelines/10–16` (new pipeline)

`CALL EXTRACT_PIPELINE_A('Sanofi_MSA.pdf', 'SANOFI');`
