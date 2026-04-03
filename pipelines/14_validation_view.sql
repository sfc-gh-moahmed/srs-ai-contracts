/*=============================================================
  SRS AI Contracts — Step 14: Validation Views

  Compares extracted data against existing validation tables
  in SI.PUBLIC (your ground-truth dataset).

  CONFIGURE: Set validation table names below.
  If you do not yet have validation tables, run the script
  as-is — the views will show NULL for expected values but
  the extracted data will still be visible.

  Creates:
    1. EXTRACTION_VALIDATION_PRICING   — row-level storage price comparison
    2. EXTRACTION_VALIDATION_MGMT      — row-level management fee comparison
    3. EXTRACTION_VALIDATION_SUMMARY   — match rate summary by customer/method

  Requires: 12_pipeline_a_ai_parse_extract.sql (or 13_) to have run
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

-- >>> CONFIGURE: set to your actual validation table names
--     If not available yet, leave as-is; views will show NULLs for expected values
SET DB_NAME                  = 'SI';
SET SCHEMA_NAME              = 'PUBLIC';
SET VALIDATION_PRICING_TABLE = 'SI.PUBLIC.SRS_CONTRACT_CUSTOMER_PRICING_VALIDATION';
SET VALIDATION_MGMT_TABLE    = 'SI.PUBLIC.SRS_CONTRACT_CUSTOMER_MGMT_PRICING_VALIDATION';

-- ─────────────────────────────────────────────────────────────
-- 1. Storage Pricing validation — row-level diff
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_PRICING AS
SELECT
    e.CUSTOMER_ID,
    e.FILENAME,
    e.EXTRACTION_METHOD,
    e.TEMPERATURE,
    e.SAMPLE_SIZE,
    e.QUANTITY_TIER,
    e.REGION,
    e.CURRENCY,
    e.PRICE                               AS EXTRACTED_PRICE,
    v.PRICE                               AS EXPECTED_PRICE,
    TRY_TO_DOUBLE(e.PRICE)                AS EXTRACTED_PRICE_NUM,
    TRY_TO_DOUBLE(v.PRICE)                AS EXPECTED_PRICE_NUM,
    ROUND(
        ABS(TRY_TO_DOUBLE(e.PRICE) - TRY_TO_DOUBLE(v.PRICE)), 6
    )                                     AS PRICE_DELTA,
    ROUND(
        100.0 * ABS(TRY_TO_DOUBLE(e.PRICE) - TRY_TO_DOUBLE(v.PRICE))
        / NULLIF(TRY_TO_DOUBLE(v.PRICE), 0), 2
    )                                     AS PRICE_DELTA_PCT,
    CASE
        WHEN v.PRICE IS NULL          THEN 'NO_EXPECTED'
        WHEN e.PRICE = v.PRICE        THEN 'EXACT_MATCH'
        WHEN PRICE_DELTA <= 0.0001    THEN 'NEAR_MATCH'
        WHEN PRICE_DELTA_PCT <= 1.0   THEN 'WITHIN_1PCT'
        ELSE 'MISMATCH'
    END                                   AS MATCH_STATUS,
    e.EXTRACTED_AT
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST') e
LEFT JOIN IDENTIFIER($VALIDATION_PRICING_TABLE) v
    ON  e.CUSTOMER_ID   = v.CUSTOMER_ID
    AND UPPER(e.TEMPERATURE)  = UPPER(v.TEMPERATURE)
    AND UPPER(e.SAMPLE_SIZE)  = UPPER(v.SAMPLE_SIZE)
    AND UPPER(e.QUANTITY_TIER)= UPPER(v.QUANTITY_TIER)
    AND UPPER(e.REGION)       = UPPER(v.REGION)
COMMENT = 'Row-level comparison of extracted storage pricing vs. ground-truth validation table.';

-- ─────────────────────────────────────────────────────────────
-- 2. Management Fees validation — row-level diff
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_MGMT AS
SELECT
    e.CUSTOMER_ID,
    e.FILENAME,
    e.EXTRACTION_METHOD,
    e.FEE_CATEGORY,
    e.FEE_NAME,
    e.CURRENCY,
    e.PRICE                          AS EXTRACTED_PRICE,
    v.PRICE                          AS EXPECTED_PRICE,
    TRY_TO_DOUBLE(e.PRICE)           AS EXTRACTED_PRICE_NUM,
    TRY_TO_DOUBLE(v.PRICE)           AS EXPECTED_PRICE_NUM,
    ROUND(
        ABS(TRY_TO_DOUBLE(e.PRICE) - TRY_TO_DOUBLE(v.PRICE)), 6
    )                                AS PRICE_DELTA,
    CASE
        WHEN v.PRICE IS NULL         THEN 'NO_EXPECTED'
        WHEN e.PRICE = v.PRICE       THEN 'EXACT_MATCH'
        WHEN ABS(TRY_TO_DOUBLE(e.PRICE) - TRY_TO_DOUBLE(v.PRICE)) <= 0.01 THEN 'NEAR_MATCH'
        ELSE 'MISMATCH'
    END                              AS MATCH_STATUS,
    e.EXTRACTED_AT
FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST') e
LEFT JOIN IDENTIFIER($VALIDATION_MGMT_TABLE) v
    ON  e.CUSTOMER_ID  = v.CUSTOMER_ID
    AND UPPER(e.FEE_CATEGORY) = UPPER(v.FEE_CATEGORY)
    AND UPPER(e.FEE_NAME)     = UPPER(v.FEE_NAME)
COMMENT = 'Row-level comparison of extracted management fees vs. ground-truth validation table.';

-- ─────────────────────────────────────────────────────────────
-- 3. Summary — match rate by customer and extraction method
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY AS
WITH pricing_stats AS (
    SELECT
        CUSTOMER_ID,
        EXTRACTION_METHOD,
        'STORAGE_PRICING'                                 AS TABLE_TYPE,
        COUNT(*)                                          AS TOTAL_ROWS,
        SUM(CASE WHEN MATCH_STATUS IN ('EXACT_MATCH','NEAR_MATCH') THEN 1 ELSE 0 END) AS MATCHED_ROWS,
        SUM(CASE WHEN MATCH_STATUS = 'MISMATCH'  THEN 1 ELSE 0 END) AS MISMATCHED_ROWS,
        SUM(CASE WHEN MATCH_STATUS = 'NO_EXPECTED' THEN 1 ELSE 0 END) AS NO_EXPECTED_ROWS
    FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_PRICING
    GROUP BY 1, 2
),
mgmt_stats AS (
    SELECT
        CUSTOMER_ID,
        EXTRACTION_METHOD,
        'MANAGEMENT_FEES'                                 AS TABLE_TYPE,
        COUNT(*)                                          AS TOTAL_ROWS,
        SUM(CASE WHEN MATCH_STATUS IN ('EXACT_MATCH','NEAR_MATCH') THEN 1 ELSE 0 END) AS MATCHED_ROWS,
        SUM(CASE WHEN MATCH_STATUS = 'MISMATCH'  THEN 1 ELSE 0 END) AS MISMATCHED_ROWS,
        SUM(CASE WHEN MATCH_STATUS = 'NO_EXPECTED' THEN 1 ELSE 0 END) AS NO_EXPECTED_ROWS
    FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_MGMT
    GROUP BY 1, 2
)
SELECT
    CUSTOMER_ID,
    EXTRACTION_METHOD,
    TABLE_TYPE,
    TOTAL_ROWS,
    MATCHED_ROWS,
    MISMATCHED_ROWS,
    NO_EXPECTED_ROWS,
    ROUND(100.0 * MATCHED_ROWS / NULLIF(TOTAL_ROWS - NO_EXPECTED_ROWS, 0), 1) AS MATCH_RATE_PCT
FROM pricing_stats
UNION ALL
SELECT * FROM mgmt_stats
ORDER BY CUSTOMER_ID, TABLE_TYPE, EXTRACTION_METHOD;

-- Quick check
SELECT * FROM SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY
ORDER BY CUSTOMER_ID, TABLE_TYPE, EXTRACTION_METHOD;

/*
  NEXT: Run 15_run_all.sql for end-to-end execution
*/
