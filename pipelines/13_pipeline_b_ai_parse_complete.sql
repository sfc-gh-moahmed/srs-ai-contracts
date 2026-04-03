/*=============================================================
  SRS AI Contracts — Step 13: Pipeline B
  AI_PARSE_DOCUMENT (LAYOUT, page_split) → AI_COMPLETE per page

  Differences from Pipeline A:
    - Uses AI_COMPLETE with a prompt-based approach instead of schema-based AI_EXTRACT
    - Model is a PARAMETER — swap between mistral-large2, llama3.3-70b,
      claude-4-sonnet, llama4-maverick at call time
    - snowflake-arctic is explicitly BLOCKED — its 4,096 token total
      context window (input + output combined) is too small for dense
      pricing pages even when split by page

  Model context windows (source: Snowflake docs, April 2026):
    mistral-large2   →  128,000 tokens  (default — best quality/cost)
    llama3.3-70b     →  128,000 tokens  (fastest, cheapest)
    claude-4-sonnet  →  200,000 tokens  (highest quality)
    llama4-maverick  →  128,000 tokens  (strong alternative)
    snowflake-arctic →    4,096 tokens  ← BLOCKED for this use case

  Both pipelines share the same parse cache (PARSED_CONTRACTS_TEXT),
  so parsing only happens once regardless of which pipeline runs first.

  Usage:
    -- Default model (mistral-large2)
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS'
    );
    -- With specific model
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet'
    );

  Requires: 10_create_extraction_tables.sql, 11_upload_pdfs.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

SET DB_NAME     = 'SI';
SET SCHEMA_NAME = 'PUBLIC';

CREATE OR REPLACE PROCEDURE SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
    P_FILENAME    VARCHAR,
    P_CUSTOMER_ID VARCHAR,
    P_MODEL       VARCHAR DEFAULT 'mistral-large2'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_page_count   NUMBER DEFAULT 0;
    v_storage_rows NUMBER DEFAULT 0;
    v_mgmt_rows    NUMBER DEFAULT 0;
    v_method       VARCHAR;
BEGIN

    -- ─────────────────────────────────────────────────────────────
    -- GUARD: Block snowflake-arctic — context window too small
    -- ─────────────────────────────────────────────────────────────
    IF (:P_MODEL = 'snowflake-arctic') THEN
        RETURN 'ERROR: snowflake-arctic has a 4,096 token total context window '
            || '(input + output combined), which is insufficient for dense MSA pricing tables. '
            || 'Use mistral-large2, llama3.3-70b, claude-4-sonnet, or llama4-maverick instead.';
    END IF;

    IF (:P_MODEL NOT IN ('mistral-large2', 'llama3.3-70b', 'claude-4-sonnet', 'llama4-maverick',
                         'mistral-large', 'llama3.1-70b', 'llama4-scout')) THEN
        RETURN 'ERROR: Unsupported model "' || :P_MODEL || '". '
            || 'Supported: mistral-large2, llama3.3-70b, claude-4-sonnet, llama4-maverick';
    END IF;

    LET v_method VARCHAR DEFAULT 'AI_PARSE+AI_COMPLETE_' || :P_MODEL;

    -- ─────────────────────────────────────────────────────────────
    -- STEP 1: Parse (reuse cache if available — same as Pipeline A)
    -- ─────────────────────────────────────────────────────────────
    LET already_parsed NUMBER;
    SELECT COUNT(*) INTO :already_parsed
    FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT
    WHERE FILENAME = :P_FILENAME;

    IF (:already_parsed = 0) THEN
        LET parsed VARIANT;
        SELECT AI_PARSE_DOCUMENT(
            TO_FILE('@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE', :P_FILENAME),
            {'mode': 'LAYOUT', 'page_split': TRUE}
        ) INTO :parsed;

        INSERT INTO SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT
            (FILENAME, CUSTOMER_ID, PAGE_INDEX, PAGE_TEXT, TOTAL_PAGES)
        SELECT
            :P_FILENAME,
            :P_CUSTOMER_ID,
            p.index::NUMBER,
            p.value:content::VARCHAR,
            :parsed:metadata:pageCount::NUMBER
        FROM TABLE(FLATTEN(input => :parsed:pages)) p;
    END IF;

    SELECT COUNT(*) INTO :v_page_count
    FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT
    WHERE FILENAME = :P_FILENAME;

    -- ─────────────────────────────────────────────────────────────
    -- STEP 2: Extract STORAGE PRICING via AI_COMPLETE
    --   Prompt instructs the model to return strict JSON matching
    --   the target schema. response_format => {'type': 'json'}
    --   enforces structured output for supported models.
    -- ─────────────────────────────────────────────────────────────
    DELETE FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = :v_method;

    INSERT INTO IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
        (FILENAME, REGION, CURRENCY, TEMPERATURE, SAMPLE_SIZE,
         QUANTITY_TIER, PRICE, MAX_QUANTITY_TIER, MIN_QUANTITY_TIER,
         CUSTOMER_ID, CUBIC_FOOT_MAX, MIN_SAMPLE_SIZE, MAX_SAMPLE_SIZE,
         TRANSACTION_TYPE, EXTRACTION_METHOD)
    WITH page_completions AS (
        SELECT
            p.FILENAME,
            p.PAGE_INDEX,
            TRY_PARSE_JSON(
                AI_COMPLETE(
                    :P_MODEL,
                    'You are extracting data from an Azenta Life Sciences Rate Card page. '
                    || 'Extract ALL storage pricing rows from this page into a JSON object with key "storage_rows". '
                    || '"storage_rows" must be an array where each element has EXACTLY these keys: '
                    || 'temperature (string, the storage condition heading e.g. "Ambient", "Refrigerated or -20C", "-70C/-80C Nitrogen Chamber"), '
                    || 'sample_size_label (string, column header e.g. "SBS tube <=1.4mL", "5-10mL", "1001-2000mL"), '
                    || 'min_sample_ml (number, minimum mL from label or null), '
                    || 'max_sample_ml (number, maximum mL from label or null), '
                    || 'cubic_foot_max (number if price uses $/Cu.Ft. notation else null), '
                    || 'qty_tier_label (string e.g. "1-500,000" or ">3,000,000"), '
                    || 'min_qty (number), max_qty (number, use 999999999 for open-ended tiers), '
                    || 'price_usd (string), price_eur (string or null), price_sgd (string or null), '
                    || 'region (string, "North America" if not specified). '
                    || 'If this page has NO storage pricing table, return {"storage_rows": []}. '
                    || 'Return ONLY valid JSON. No explanation, no markdown fences.'
                    || CHR(10) || CHR(10) || 'PAGE CONTENT:' || CHR(10) || p.PAGE_TEXT,
                    {'response_format': {'type': 'json'}}
                )
            ) AS result
        FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT p
        WHERE p.FILENAME = :P_FILENAME
          AND (
              LOWER(p.PAGE_TEXT) LIKE '%storage%'
              OR LOWER(p.PAGE_TEXT) LIKE '%ambient%'
              OR LOWER(p.PAGE_TEXT) LIKE '%refrigerat%'
              OR LOWER(p.PAGE_TEXT) LIKE '%nitrogen%'
              OR LOWER(p.PAGE_TEXT) LIKE '%-80%'
          )
          AND result IS NOT NULL
          AND ARRAY_SIZE(result:storage_rows) > 0
    ),
    flattened AS (
        SELECT
            pc.FILENAME,
            row.value:temperature::VARCHAR        AS temperature,
            row.value:sample_size_label::VARCHAR  AS sample_size,
            row.value:qty_tier_label::VARCHAR     AS qty_tier,
            TRY_TO_NUMBER(row.value:min_qty)      AS min_qty,
            TRY_TO_NUMBER(row.value:max_qty)      AS max_qty,
            row.value:price_usd::VARCHAR          AS price_usd,
            row.value:price_eur::VARCHAR          AS price_eur,
            row.value:price_sgd::VARCHAR          AS price_sgd,
            row.value:region::VARCHAR             AS region,
            TRY_TO_DOUBLE(row.value:cubic_foot_max)   AS cubic_foot_max,
            TRY_TO_DOUBLE(row.value:min_sample_ml)    AS min_sample_ml,
            TRY_TO_DOUBLE(row.value:max_sample_ml)    AS max_sample_ml
        FROM page_completions pc,
        LATERAL FLATTEN(input => pc.result:storage_rows) row
    )
    SELECT
        f.FILENAME,
        COALESCE(f.region, 'North America')   AS REGION,
        CASE
            WHEN LOWER(f.region) LIKE '%griesheim%' OR LOWER(f.region) LIKE '%eur%' THEN 'EUR'
            WHEN LOWER(f.region) LIKE '%singapore%' THEN 'SGD'
            ELSE 'USD'
        END AS CURRENCY,
        f.temperature          AS TEMPERATURE,
        f.sample_size          AS SAMPLE_SIZE,
        f.qty_tier             AS QUANTITY_TIER,
        COALESCE(
            CASE
                WHEN LOWER(f.region) LIKE '%griesheim%' THEN f.price_eur
                WHEN LOWER(f.region) LIKE '%singapore%' THEN f.price_sgd
                ELSE f.price_usd
            END,
            f.price_usd
        )                      AS PRICE,
        f.max_qty              AS MAX_QUANTITY_TIER,
        f.min_qty              AS MIN_QUANTITY_TIER,
        :P_CUSTOMER_ID         AS CUSTOMER_ID,
        f.cubic_foot_max       AS CUBIC_FOOT_MAX,
        f.min_sample_ml        AS MIN_SAMPLE_SIZE,
        f.max_sample_ml        AS MAX_SAMPLE_SIZE,
        'STORAGE'              AS TRANSACTION_TYPE,
        :v_method              AS EXTRACTION_METHOD
    FROM flattened f
    WHERE f.temperature IS NOT NULL AND f.price_usd IS NOT NULL;

    SELECT COUNT(*) INTO :v_storage_rows
    FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = :v_method;

    -- ─────────────────────────────────────────────────────────────
    -- STEP 3: Extract MANAGEMENT FEES via AI_COMPLETE
    -- ─────────────────────────────────────────────────────────────
    DELETE FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = :v_method;

    INSERT INTO IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
        (FILENAME, CUSTOMER_ID, FEE_CATEGORY, FEE_NAME, CURRENCY,
         PRICE, UNIT, DESCRIPTION, EXTRACTION_METHOD)
    WITH page_completions AS (
        SELECT
            p.FILENAME,
            TRY_PARSE_JSON(
                AI_COMPLETE(
                    :P_MODEL,
                    'You are extracting data from an Azenta Life Sciences Rate Card page. '
                    || 'Extract ALL fee line items from this page into a JSON object with key "fee_rows". '
                    || '"fee_rows" must be an array where each element has EXACTLY these keys: '
                    || 'fee_category (string, the section this fee belongs to e.g. "Project Initiation Fees", '
                    || '"Sample Administration <=2000mL", "Lab Services", "Professional Services", "Additional Services"), '
                    || 'fee_name (string, the specific fee name), '
                    || 'price_usd (string, USD price or "per request" if variable), '
                    || 'price_eur (string or null), price_sgd (string or null), '
                    || 'unit (string, billing unit e.g. "per sample", "per hour", "per project", "per shipment"), '
                    || 'description (string, fee description from rightmost column or null). '
                    || 'If this page has NO fee tables, return {"fee_rows": []}. '
                    || 'Return ONLY valid JSON. No explanation, no markdown fences.'
                    || CHR(10) || CHR(10) || 'PAGE CONTENT:' || CHR(10) || p.PAGE_TEXT,
                    {'response_format': {'type': 'json'}}
                )
            ) AS result
        FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT p
        WHERE p.FILENAME = :P_FILENAME
          AND (
              LOWER(p.PAGE_TEXT) LIKE '%project initiation%'
              OR LOWER(p.PAGE_TEXT) LIKE '%registration%'
              OR LOWER(p.PAGE_TEXT) LIKE '%retrieval%'
              OR LOWER(p.PAGE_TEXT) LIKE '%professional services%'
              OR LOWER(p.PAGE_TEXT) LIKE '%lab services%'
          )
          AND result IS NOT NULL
          AND ARRAY_SIZE(result:fee_rows) > 0
    )
    SELECT
        pc.FILENAME,
        :P_CUSTOMER_ID          AS CUSTOMER_ID,
        row.value:fee_category::VARCHAR  AS FEE_CATEGORY,
        row.value:fee_name::VARCHAR      AS FEE_NAME,
        'USD'                            AS CURRENCY,
        COALESCE(
            row.value:price_usd::VARCHAR,
            row.value:price_eur::VARCHAR
        )                                AS PRICE,
        row.value:unit::VARCHAR          AS UNIT,
        row.value:description::VARCHAR   AS DESCRIPTION,
        :v_method                        AS EXTRACTION_METHOD
    FROM page_completions pc,
    LATERAL FLATTEN(input => pc.result:fee_rows) row
    WHERE row.value:fee_name IS NOT NULL;

    SELECT COUNT(*) INTO :v_mgmt_rows
    FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = :v_method;

    RETURN 'Pipeline B (' || :P_MODEL || ') complete for ' || :P_CUSTOMER_ID || ' | '
        || 'Pages used from cache: ' || :v_page_count || ' | '
        || 'Storage rows: ' || :v_storage_rows || ' | '
        || 'Mgmt fee rows: ' || :v_mgmt_rows;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'FAILED [Pipeline B / ' || :P_CUSTOMER_ID || ' / ' || :P_MODEL || ']: ' || SQLERRM;
END;
$$;

/*
  Test calls — default model:
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS'
    );

  With model selection:
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'Sanofi_MSA.pdf', 'SANOFI', 'llama3.3-70b'
    );
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'Sanofi_MSA.pdf', 'SANOFI', 'claude-4-sonnet'
    );

  Blocked model (returns error message):
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B(
        'Sanofi_MSA.pdf', 'SANOFI', 'snowflake-arctic'
    );

  NEXT: Run 14_validation_view.sql
*/
