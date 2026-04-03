/*=============================================================
  SRS AI Contracts — Step 15: End-to-End Run Orchestrator

  Runs all pipeline steps in order for both BMS and Sanofi MSAs.
  Safe to re-run: each procedure deletes its own prior output
  before inserting, keyed by CUSTOMER_ID + EXTRACTION_METHOD.

  Run order:
    1. Setup tables (if not already done)
    2. Upload PDFs (run 11_upload_pdfs.sql from SnowSQL first)
    3. Pipeline A: AI_PARSE_DOCUMENT + AI_EXTRACT
    4. Pipeline B: AI_PARSE_DOCUMENT + AI_COMPLETE (3 models)
    5. Verification queries
    6. Validation summary

  >>> CONFIGURE: DB_NAME / SCHEMA_NAME must match 10_create_extraction_tables.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;
USE WAREHOUSE SRS_CONTRACTS_WH;

SET DB_NAME     = 'SI';
SET SCHEMA_NAME = 'PUBLIC';

-- ═══════════════════════════════════════════════════════════════
-- PHASE 1: PIPELINE A — AI_PARSE_DOCUMENT + AI_EXTRACT
-- ═══════════════════════════════════════════════════════════════

-- BMS (13-page amendment to Master Laboratory Services Agreement)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    'BMS - MSA AMD 3 06Jan2026 FE.pdf',
    'BMS'
);

-- Sanofi (18-page global pricing letter — 6 regions, dense storage matrices)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    'Sanofi_MSA.pdf',
    'SANOFI'
);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2: PIPELINE B — AI_PARSE_DOCUMENT + AI_COMPLETE
--          Run with 3 models to compare extraction quality
--          Note: parsing is cached after Phase 1, so no re-parsing cost
-- ═══════════════════════════════════════════════════════════════

-- Model 1: mistral-large2 (default — best quality/cost balance)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS', 'mistral-large2'
);
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI', 'mistral-large2'
);

-- Model 2: llama3.3-70b (fastest, cheapest — good for high-volume runs)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS', 'llama3.3-70b'
);
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI', 'llama3.3-70b'
);

-- Model 3: claude-4-sonnet (highest quality — use for validation pass)
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS', 'claude-4-sonnet'
);
CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    'Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet'
);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3: VERIFICATION
-- ═══════════════════════════════════════════════════════════════

-- 1. Parse cache: should see 13 pages for BMS, 18 for Sanofi
SELECT FILENAME, CUSTOMER_ID, COUNT(*) AS PAGE_COUNT,
       MAX(TOTAL_PAGES) AS TOTAL_PAGES, MIN(PARSED_AT) AS PARSED_AT
FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT
GROUP BY FILENAME, CUSTOMER_ID
ORDER BY FILENAME;

-- 2. Storage pricing row counts per pipeline/model
SELECT CUSTOMER_ID, EXTRACTION_METHOD, COUNT(*) AS ROW_COUNT
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
GROUP BY CUSTOMER_ID, EXTRACTION_METHOD
ORDER BY CUSTOMER_ID, EXTRACTION_METHOD;

-- 3. Management fee row counts per pipeline/model
SELECT CUSTOMER_ID, EXTRACTION_METHOD, COUNT(*) AS ROW_COUNT
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
GROUP BY CUSTOMER_ID, EXTRACTION_METHOD
ORDER BY CUSTOMER_ID, EXTRACTION_METHOD;

-- 4. Sample storage pricing rows (Pipeline A, BMS)
SELECT TEMPERATURE, SAMPLE_SIZE, QUANTITY_TIER, REGION, CURRENCY, PRICE,
       MIN_QUANTITY_TIER, MAX_QUANTITY_TIER, MIN_SAMPLE_SIZE, MAX_SAMPLE_SIZE
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
WHERE CUSTOMER_ID = 'BMS' AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT'
ORDER BY TEMPERATURE, SAMPLE_SIZE, MIN_QUANTITY_TIER
LIMIT 20;

-- 5. Sample management fee rows (Pipeline A, Sanofi)
SELECT FEE_CATEGORY, FEE_NAME, PRICE, UNIT, LEFT(DESCRIPTION, 80) AS DESCRIPTION_PREVIEW
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
WHERE CUSTOMER_ID = 'SANOFI' AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT'
ORDER BY FEE_CATEGORY, FEE_NAME
LIMIT 20;

-- 6. Pipeline A vs B comparison for BMS storage pricing
SELECT
    a.TEMPERATURE, a.SAMPLE_SIZE, a.QUANTITY_TIER,
    a.PRICE AS PRICE_AI_EXTRACT,
    b.PRICE AS PRICE_AI_COMPLETE_MISTRAL,
    CASE WHEN a.PRICE = b.PRICE THEN 'MATCH' ELSE 'DIFF' END AS STATUS
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST') a
LEFT JOIN IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST') b
    ON a.CUSTOMER_ID = b.CUSTOMER_ID
    AND a.TEMPERATURE = b.TEMPERATURE
    AND a.SAMPLE_SIZE = b.SAMPLE_SIZE
    AND a.QUANTITY_TIER = b.QUANTITY_TIER
    AND b.EXTRACTION_METHOD = 'AI_PARSE+AI_COMPLETE_mistral-large2'
WHERE a.CUSTOMER_ID = 'BMS'
  AND a.EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT'
ORDER BY a.TEMPERATURE, a.SAMPLE_SIZE, a.MIN_QUANTITY_TIER
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════
-- PHASE 4: VALIDATION SUMMARY
-- ═══════════════════════════════════════════════════════════════
SELECT * FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY
ORDER BY CUSTOMER_ID, TABLE_TYPE, EXTRACTION_METHOD;

/*
  ALL DONE. Expected results:
    - PARSED_CONTRACTS_TEXT: 13 rows (BMS) + 18 rows (Sanofi) = 31 rows
    - PRICING table: multiple rows per customer per EXTRACTION_METHOD
    - MGMT table:    multiple rows per customer per EXTRACTION_METHOD
    - Pipeline A and B row counts should be similar (minor differences expected)

  NEXT: Open the Streamlit app in Snowsight to visualize results.
        Run 16_deploy_streamlit.sql to deploy the app.
*/
