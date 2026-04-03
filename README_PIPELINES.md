# MSA Contract Extraction Pipeline — Deployment Guide

End-to-end guide for extracting structured pricing from Azenta MSA PDFs using Snowflake Cortex AI functions.

## What This Pipeline Does

1. **AI_PARSE_DOCUMENT** — Parses PDF pages into structured Markdown (LAYOUT mode), cached per page
2. **Pipeline A: AI_EXTRACT** — Schema-based structured extraction, one page at a time
3. **Pipeline B: AI_COMPLETE** — Prompt-based extraction with swappable LLM models
4. **Validation** — Compares extracted data against ground-truth tables in SI.PUBLIC
5. **Streamlit App** — Snowflake-native UI to run pipelines, compare results, and review validation

## Key Design Decisions

### Why per-page parsing?

`AI_EXTRACT` table output is capped at **4,096 tokens per question**. Sanofi/BMS Rate Cards contain dense 2D pricing matrices (6 quantity tiers × 11 sample-size columns per temperature), which overflow this limit when processed as a full document. Using `AI_PARSE_DOCUMENT` with `page_split=TRUE` and processing one page at a time keeps output well within limits.

### Why cache the parsed text?

`AI_PARSE_DOCUMENT` is billed per page. At 600 contracts × ~10 pages = 6,000 pages, parsing once and storing the result in `PARSED_CONTRACTS_TEXT` means you can re-run Pipeline A, Pipeline B (multiple models), and different schemas without paying parsing costs again.

### Why is `snowflake-arctic` blocked in Pipeline B?

`snowflake-arctic` has a **4,096 token total context window** (input + output combined). A single dense pricing page in Markdown (~300–800 tokens) plus a prompt (~500 tokens) plus JSON response can exceed this limit. The procedure explicitly rejects `snowflake-arctic` with a descriptive error message.

## Prerequisites

- Snowflake account with Cortex AI functions enabled (Enterprise or above)
- Role with `CREATE PROCEDURE`, `CREATE VIEW`, `CREATE STREAMLIT` privileges
- Cortex model access: `mistral-large2` minimum (or adjust in Pipeline B)
- Target database `SI` with schema `PUBLIC` existing (or change `SET DB_NAME` in each script)

## File Structure

```
srs_ai_contracts_demo/
├── deploy/                              # Existing anomaly detection demo (01–09)
│   ├── 01_setup_database.sql
│   ├── 02_create_tables.sql
│   └── ...
├── pipelines/                           # NEW: MSA extraction pipeline
│   ├── 10_create_extraction_tables.sql  # DDL: parse cache + 2 output tables
│   ├── 11_upload_pdfs.sql               # PUT commands for BMS + Sanofi PDFs
│   ├── 12_pipeline_a_ai_parse_extract.sql  # Stored proc: AI_PARSE_DOCUMENT + AI_EXTRACT
│   ├── 13_pipeline_b_ai_parse_complete.sql # Stored proc: AI_PARSE_DOCUMENT + AI_COMPLETE
│   ├── 14_validation_view.sql           # Validation views vs ground-truth tables
│   ├── 15_run_all.sql                   # End-to-end orchestrator
│   └── 16_deploy_streamlit.sql          # CREATE STREAMLIT DDL
├── streamlit/
│   └── app.py                           # Streamlit in Snowflake app (5 tabs)
└── msa_extraction_pipeline.md           # Marp presentation (this architecture overview)
```

## Quick Start

### Step 1: Run the existing demo setup (if not already done)
```sql
-- In Snowsight, run in order:
deploy/01_setup_database.sql
deploy/02_create_tables.sql
```

### Step 2: Create extraction tables
```sql
-- Edit DB_NAME / SCHEMA_NAME at the top if needed (default: SI.PUBLIC)
-- Run in Snowsight:
pipelines/10_create_extraction_tables.sql
```

### Step 3: Upload PDFs (requires SnowSQL CLI)
```bash
snowsql -c <your_connection> -f pipelines/11_upload_pdfs.sql
```
Or from SnowSQL interactive:
```sql
PUT file:///Users/moahmed/Downloads/'BMS - MSA AMD 3 06Jan2026 FE.pdf'
    @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file:///Users/moahmed/Downloads/Sanofi_MSA.pdf
    @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
ALTER STAGE SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE REFRESH;
```

### Step 4: Create stored procedures
```sql
-- Run in Snowsight:
pipelines/12_pipeline_a_ai_parse_extract.sql
pipelines/13_pipeline_b_ai_parse_complete.sql
```

### Step 5: Create validation views
```sql
-- Edit SET VALIDATION_PRICING_TABLE / VALIDATION_MGMT_TABLE if you have ground-truth tables
pipelines/14_validation_view.sql
```

### Step 6: Run the full pipeline
```sql
pipelines/15_run_all.sql
```

### Step 7: Deploy Streamlit app
```bash
# Upload app.py to stage (SnowSQL):
snowsql -c <connection> -q "PUT file:///path/to/streamlit/app.py @SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```
```sql
-- Then run:
pipelines/16_deploy_streamlit.sql
```

## Running Individual Pipelines

```sql
-- Pipeline A (AI_EXTRACT — schema-based)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS'
);
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    'Sanofi_MSA.pdf', 'SANOFI'
);

-- Pipeline B (AI_COMPLETE — prompt-based, default model: mistral-large2)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI'
);

-- Pipeline B with specific model
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet'
);
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI', 'llama3.3-70b'
);
```

## Model Options for Pipeline B

| Model | Context Window | Recommended Use |
|-------|---------------|-----------------|
| `mistral-large2` | 128K | Default — best quality/cost |
| `llama3.3-70b` | 128K | High-volume batch runs |
| `claude-4-sonnet` | 200K | Highest quality, validation |
| `llama4-maverick` | 128K | Alternative |
| ~~`snowflake-arctic`~~ | 4,096 | ❌ Blocked — context too small |

## Verification Queries

```sql
-- Check parse cache (expect 13 rows for BMS, 18 for Sanofi)
SELECT FILENAME, COUNT(*) AS PAGE_COUNT
FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT
GROUP BY FILENAME;

-- Row counts per pipeline
SELECT CUSTOMER_ID, EXTRACTION_METHOD, COUNT(*) AS ROWS
FROM SI.PUBLIC.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST
GROUP BY 1, 2 ORDER BY 1, 2;

-- Validation summary (if validation tables exist)
SELECT * FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY;
```

## Batch Processing (600 Contracts)

```sql
-- Run Pipeline A on all PDFs in stage
SELECT CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    d.RELATIVE_PATH,
    REPLACE(REPLACE(d.RELATIVE_PATH, '.pdf', ''), ' ', '_')
)
FROM DIRECTORY(@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE) d
WHERE d.RELATIVE_PATH LIKE '%.pdf';
```

## Customization

### Change target database/schema
Edit `SET DB_NAME` and `SET SCHEMA_NAME` at the top of scripts `10`, `12`, `13`, `14`, `15`.

### Change warehouse
Edit `01_setup_database.sql` or set `USE WAREHOUSE <name>` before calling procedures.

### Change validation tables
Edit `SET VALIDATION_PRICING_TABLE` and `SET VALIDATION_MGMT_TABLE` in `14_validation_view.sql`.

## Cleanup

```sql
-- Remove pipeline objects (keeps existing anomaly detection demo intact)
DROP TABLE IF EXISTS SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT;
DROP PROCEDURE IF EXISTS SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(VARCHAR, VARCHAR, VARCHAR);
DROP VIEW IF EXISTS SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_PRICING;
DROP VIEW IF EXISTS SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_MGMT;
DROP VIEW IF EXISTS SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY;
DROP STREAMLIT IF EXISTS SRS_AI_CONTRACTS.AGENTS.MSA_EXTRACTION_APP;
-- Also drop SI.PUBLIC tables if created by this demo:
DROP TABLE IF EXISTS SI.PUBLIC.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST;
DROP TABLE IF EXISTS SI.PUBLIC.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST;
```
