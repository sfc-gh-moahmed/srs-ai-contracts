/*=============================================================
  SRS AI Contracts — Step 12: Pipeline A
  AI_PARSE_DOCUMENT (LAYOUT, page_split) → AI_EXTRACT per page

  Why per-page extraction?
    AI_EXTRACT table output is capped at 4,096 tokens per question.
    Sanofi/BMS Rate Cards have dense 2D pricing matrices (6 qty tiers
    × 11 sample-size columns per temperature) that overflow if extracted
    from the full document at once. Splitting by page keeps each
    extraction well within limits.

  Why cache the parsed text?
    AI_PARSE_DOCUMENT is billed per page. At 600 MSA docs × ~10 pages
    = 6,000 pages, parsing once and reusing avoids re-parsing costs
    when re-running extractions with different schemas.

  Usage:
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
        'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS'
    );
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
        'Sanofi_MSA.pdf', 'SANOFI'
    );

  Requires: 10_create_extraction_tables.sql, 11_upload_pdfs.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

-- >>> CONFIGURE: match values from 10_create_extraction_tables.sql
SET DB_NAME     = 'SI';
SET SCHEMA_NAME = 'PUBLIC';

CREATE OR REPLACE PROCEDURE SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
    P_FILENAME   VARCHAR,
    P_CUSTOMER_ID VARCHAR
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
BEGIN

    -- ─────────────────────────────────────────────────────────────
    -- STEP 1: Parse document (skip if already cached)
    --   AI_PARSE_DOCUMENT with LAYOUT mode preserves table structure
    --   as Markdown — critical for dense pricing matrices.
    --   page_split=TRUE → one JSON element per page in :pages array.
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
    -- STEP 2: Extract STORAGE PRICING — per page
    --   Schema extracts one temperature block's rows per page.
    --   Pages are filtered by keyword to avoid wasted AI calls.
    --   Results are flattened from parallel arrays into rows.
    -- ─────────────────────────────────────────────────────────────
    DELETE FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT';

    INSERT INTO IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
        (FILENAME, REGION, CURRENCY, TEMPERATURE, SAMPLE_SIZE,
         QUANTITY_TIER, PRICE, MAX_QUANTITY_TIER, MIN_QUANTITY_TIER,
         CUSTOMER_ID, CUBIC_FOOT_MAX, MIN_SAMPLE_SIZE, MAX_SAMPLE_SIZE,
         TRANSACTION_TYPE, EXTRACTION_METHOD)
    WITH page_extractions AS (
        SELECT
            p.FILENAME,
            p.PAGE_INDEX,
            AI_EXTRACT(
                p.PAGE_TEXT,
                responseFormat => {
                    'schema': {
                        'type': 'object',
                        'properties': {
                            'storage_rows': {
                                'description': 'All rows from storage pricing tables on this page. Each row represents one combination of quantity tier and sample size with its monthly storage price. Columns: temperature (storage condition e.g. Ambient, Refrigerated or -20C, -70C/-80C, Nitrogen Chamber/LN2), sample_size_label (column header e.g. SBS tube <=1.4mL, Standard Tube <=4mL, 5-10mL, 11-25mL, 26-50mL, 51-100mL, 101-150mL, 151-250mL, 251-500mL, 501-1000mL, 1001-2000mL, >6000mL), min_sample_ml (numeric minimum volume in mL parsed from label), max_sample_ml (numeric maximum volume in mL parsed from label), cubic_foot_max (if price is expressed as $/Cu.Ft., extract that value, else null), qty_tier_label (full tier label e.g. 1-500000 or >3000000), min_qty (numeric minimum quantity from tier), max_qty (numeric maximum quantity from tier), price_usd (price in USD as string), price_eur (price in EUR as string or null), price_sgd (price in SGD as string or null), region (biobank region: North America, Griesheim, Singapore, Beijing, or Global)',
                                'type': 'object',
                                'column_ordering': ['temperature','sample_size_label','min_sample_ml','max_sample_ml','cubic_foot_max','qty_tier_label','min_qty','max_qty','price_usd','price_eur','price_sgd','region'],
                                'properties': {
                                    'temperature':        {'type': 'array'},
                                    'sample_size_label':  {'type': 'array'},
                                    'min_sample_ml':      {'type': 'array'},
                                    'max_sample_ml':      {'type': 'array'},
                                    'cubic_foot_max':     {'type': 'array'},
                                    'qty_tier_label':     {'type': 'array'},
                                    'min_qty':            {'type': 'array'},
                                    'max_qty':            {'type': 'array'},
                                    'price_usd':          {'type': 'array'},
                                    'price_eur':          {'type': 'array'},
                                    'price_sgd':          {'type': 'array'},
                                    'region':             {'type': 'array'}
                                }
                            }
                        }
                    }
                }
            ):response AS extraction
        FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT p
        WHERE p.FILENAME = :P_FILENAME
          AND (
              LOWER(p.PAGE_TEXT) LIKE '%storage%'
              OR LOWER(p.PAGE_TEXT) LIKE '%ambient%'
              OR LOWER(p.PAGE_TEXT) LIKE '%refrigerat%'
              OR LOWER(p.PAGE_TEXT) LIKE '%nitrogen%'
              OR LOWER(p.PAGE_TEXT) LIKE '%-80%'
              OR LOWER(p.PAGE_TEXT) LIKE '%cu.ft%'
          )
          AND extraction IS NOT NULL
          AND extraction:storage_rows IS NOT NULL
    ),
    flattened AS (
        SELECT
            pe.FILENAME,
            pe.extraction:storage_rows:temperature[idx.value]::VARCHAR       AS temperature,
            pe.extraction:storage_rows:sample_size_label[idx.value]::VARCHAR AS sample_size,
            pe.extraction:storage_rows:qty_tier_label[idx.value]::VARCHAR    AS qty_tier,
            TRY_TO_NUMBER(pe.extraction:storage_rows:min_qty[idx.value]::VARCHAR)     AS min_qty,
            TRY_TO_NUMBER(pe.extraction:storage_rows:max_qty[idx.value]::VARCHAR)     AS max_qty,
            pe.extraction:storage_rows:price_usd[idx.value]::VARCHAR         AS price_usd,
            pe.extraction:storage_rows:price_eur[idx.value]::VARCHAR         AS price_eur,
            pe.extraction:storage_rows:price_sgd[idx.value]::VARCHAR         AS price_sgd,
            pe.extraction:storage_rows:region[idx.value]::VARCHAR            AS region,
            TRY_TO_DOUBLE(pe.extraction:storage_rows:cubic_foot_max[idx.value]::VARCHAR)  AS cubic_foot_max,
            TRY_TO_DOUBLE(pe.extraction:storage_rows:min_sample_ml[idx.value]::VARCHAR)   AS min_sample_ml,
            TRY_TO_DOUBLE(pe.extraction:storage_rows:max_sample_ml[idx.value]::VARCHAR)   AS max_sample_ml
        FROM page_extractions pe,
        TABLE(FLATTEN(
            input => ARRAY_GENERATE_RANGE(
                0, ARRAY_SIZE(pe.extraction:storage_rows:temperature)
            ),
            MODE => 'ARRAY'
        )) AS idx
    )
    SELECT
        f.FILENAME,
        COALESCE(f.region, 'North America')  AS REGION,
        CASE
            WHEN LOWER(f.region) LIKE '%griesheim%' OR LOWER(f.region) LIKE '%eur%' THEN 'EUR'
            WHEN LOWER(f.region) LIKE '%singapore%' THEN 'SGD'
            WHEN LOWER(f.region) LIKE '%beijing%' OR LOWER(f.region) LIKE '%china%' THEN 'USD'
            ELSE 'USD'
        END AS CURRENCY,
        f.temperature          AS TEMPERATURE,
        f.sample_size          AS SAMPLE_SIZE,
        f.qty_tier             AS QUANTITY_TIER,
        COALESCE(
            CASE
                WHEN LOWER(f.region) LIKE '%griesheim%' OR LOWER(f.region) LIKE '%eur%' THEN f.price_eur
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
        'AI_PARSE+AI_EXTRACT'  AS EXTRACTION_METHOD
    FROM flattened f
    WHERE f.temperature IS NOT NULL AND f.price_usd IS NOT NULL;

    SELECT COUNT(*) INTO :v_storage_rows
    FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT';

    -- ─────────────────────────────────────────────────────────────
    -- STEP 3: Extract MANAGEMENT FEES — per page
    --   Covers: Project Initiation, Sample Admin, Lab Services,
    --           Professional Services, Additional Services
    -- ─────────────────────────────────────────────────────────────
    DELETE FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT';

    INSERT INTO IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
        (FILENAME, CUSTOMER_ID, FEE_CATEGORY, FEE_NAME, CURRENCY,
         PRICE, UNIT, DESCRIPTION, EXTRACTION_METHOD)
    WITH page_extractions AS (
        SELECT
            p.FILENAME,
            p.PAGE_INDEX,
            AI_EXTRACT(
                p.PAGE_TEXT,
                responseFormat => {
                    'schema': {
                        'type': 'object',
                        'properties': {
                            'fee_rows': {
                                'description': 'All fee line items from sample management, lab services, professional services, and additional services tables on this page. Each row is one fee. Columns: fee_category (section heading e.g. Project Initiation Fees, Sample Administration <=2000mL, Sample Administration >2000mL, Lab Services, Professional Services, Additional Services, Unit Administration), fee_name (specific fee name e.g. Per Project Definition, Registration electronic manifest with barcode, Retrieval per sample, IT fees per hour), price_usd (USD price as string), price_eur (EUR price as string or null), price_sgd (SGD price as string or null), unit (billing unit e.g. per sample, per hour, per project, per shipment, per month), description (fee description or conditions from the rightmost description column)',
                                'type': 'object',
                                'column_ordering': ['fee_category','fee_name','price_usd','price_eur','price_sgd','unit','description'],
                                'properties': {
                                    'fee_category':  {'type': 'array'},
                                    'fee_name':      {'type': 'array'},
                                    'price_usd':     {'type': 'array'},
                                    'price_eur':     {'type': 'array'},
                                    'price_sgd':     {'type': 'array'},
                                    'unit':          {'type': 'array'},
                                    'description':   {'type': 'array'}
                                }
                            }
                        }
                    }
                }
            ):response AS extraction
        FROM SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT p
        WHERE p.FILENAME = :P_FILENAME
          AND (
              LOWER(p.PAGE_TEXT) LIKE '%project initiation%'
              OR LOWER(p.PAGE_TEXT) LIKE '%registration%'
              OR LOWER(p.PAGE_TEXT) LIKE '%retrieval%'
              OR LOWER(p.PAGE_TEXT) LIKE '%professional services%'
              OR LOWER(p.PAGE_TEXT) LIKE '%lab services%'
              OR LOWER(p.PAGE_TEXT) LIKE '%sample management%'
          )
          AND extraction IS NOT NULL
          AND extraction:fee_rows IS NOT NULL
    ),
    flattened AS (
        SELECT
            pe.FILENAME,
            pe.extraction:fee_rows:fee_category[idx.value]::VARCHAR  AS fee_category,
            pe.extraction:fee_rows:fee_name[idx.value]::VARCHAR      AS fee_name,
            pe.extraction:fee_rows:price_usd[idx.value]::VARCHAR     AS price_usd,
            pe.extraction:fee_rows:price_eur[idx.value]::VARCHAR     AS price_eur,
            pe.extraction:fee_rows:price_sgd[idx.value]::VARCHAR     AS price_sgd,
            pe.extraction:fee_rows:unit[idx.value]::VARCHAR          AS unit,
            pe.extraction:fee_rows:description[idx.value]::VARCHAR   AS description
        FROM page_extractions pe,
        TABLE(FLATTEN(
            input => ARRAY_GENERATE_RANGE(
                0, ARRAY_SIZE(pe.extraction:fee_rows:fee_category)
            ),
            MODE => 'ARRAY'
        )) AS idx
    )
    SELECT
        f.FILENAME,
        :P_CUSTOMER_ID         AS CUSTOMER_ID,
        f.fee_category         AS FEE_CATEGORY,
        f.fee_name             AS FEE_NAME,
        'USD'                  AS CURRENCY,
        COALESCE(f.price_usd, f.price_eur, f.price_sgd) AS PRICE,
        f.unit                 AS UNIT,
        f.description          AS DESCRIPTION,
        'AI_PARSE+AI_EXTRACT'  AS EXTRACTION_METHOD
    FROM flattened f
    WHERE f.fee_name IS NOT NULL;

    SELECT COUNT(*) INTO :v_mgmt_rows
    FROM IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST')
    WHERE CUSTOMER_ID = :P_CUSTOMER_ID AND EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT';

    RETURN 'Pipeline A complete for ' || :P_CUSTOMER_ID || ' | '
        || 'Pages parsed: ' || :v_page_count || ' | '
        || 'Storage rows: ' || :v_storage_rows || ' | '
        || 'Mgmt fee rows: ' || :v_mgmt_rows;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'FAILED [Pipeline A / ' || :P_CUSTOMER_ID || ']: ' || SQLERRM;
END;
$$;

/*
  Test calls:
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
        'BMS - MSA AMD 3 06Jan2026 FE.pdf', 'BMS'
    );
    CALL SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A(
        'Sanofi_MSA.pdf', 'SANOFI'
    );

  NEXT: Run 13_pipeline_b_ai_parse_complete.sql
*/
