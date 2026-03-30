/*=============================================================
  SRS AI Contracts — Step 4: AI_EXTRACT Stored Procedure
  
  This procedure extracts structured pricing from a contract PDF
  uploaded to the CONTRACT_STAGE using Snowflake Cortex AI_EXTRACT.
  
  Usage (after uploading a PDF to the stage):
    CALL RAW_DATA.EXTRACT_CONTRACT_PRICING(
      'MSA-2024-001',           -- contract ID
      'biopharm_msa_2024.pdf',  -- file name on stage
      'BioPharm Corp'           -- customer name
    );
  
  The demo sample data is pre-loaded, so this procedure is for
  PRODUCTION use with real contract PDFs.
  
  Requires: 02_create_tables.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

CREATE OR REPLACE PROCEDURE RAW_DATA.EXTRACT_CONTRACT_PRICING(
    P_CONTRACT_ID VARCHAR,
    P_FILE_NAME VARCHAR,
    P_CUSTOMER_NAME VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Step 1: Extract structured pricing from PDF using AI_EXTRACT
    LET extraction VARIANT;
    SELECT AI_EXTRACT(
        file => TO_FILE('@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE', :P_FILE_NAME),
        responseFormat => {
            'schema': {
                'type': 'object',
                'properties': {
                    'pricing_table': {
                        'description': 'Complete pricing schedule table with columns for storage temperature (e.g. -80C, -20C, RT, LN2), container size (e.g. VIAL, BOX, RACK, PALLET), volume tier minimum, volume tier maximum, and unit price per month in USD',
                        'type': 'object',
                        'column_ordering': ['temperature', 'container_size', 'volume_tier_min', 'volume_tier_max', 'unit_price'],
                        'properties': {
                            'temperature':      { 'type': 'array' },
                            'container_size':    { 'type': 'array' },
                            'volume_tier_min':   { 'type': 'array' },
                            'volume_tier_max':   { 'type': 'array' },
                            'unit_price':        { 'type': 'array' }
                        }
                    },
                    'effective_date': {
                        'description': 'Contract effective date in YYYY-MM-DD format',
                        'type': 'string'
                    },
                    'expiry_date': {
                        'description': 'Contract expiry date in YYYY-MM-DD format',
                        'type': 'string'
                    }
                }
            }
        }
    ):response INTO :extraction;

    -- Step 2: Flatten the pricing table arrays and insert into CONTRACT_PRICING
    INSERT INTO SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_PRICING
        (CONTRACT_ID, CUSTOMER_NAME, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE,
         VOLUME_TIER_MIN, VOLUME_TIER_MAX, UNIT_PRICE, EFFECTIVE_DATE, EXPIRY_DATE, EXTRACTION_METHOD)
    SELECT
        :P_CONTRACT_ID,
        :P_CUSTOMER_NAME,
        'Biorepository Storage',
        pt.value:temperature::VARCHAR,
        pt.value:container_size::VARCHAR,
        pt.value:volume_tier_min::NUMBER,
        pt.value:volume_tier_max::NUMBER,
        pt.value:unit_price::FLOAT,
        TRY_TO_DATE(:extraction:effective_date::VARCHAR, 'YYYY-MM-DD'),
        TRY_TO_DATE(:extraction:expiry_date::VARCHAR, 'YYYY-MM-DD'),
        'AI_EXTRACT'
    FROM TABLE(FLATTEN(
        input => ARRAY_GENERATE_RANGE(0, ARRAY_SIZE(:extraction:pricing_table:temperature)),
        MODE => 'ARRAY'
    )) AS idx,
    LATERAL (
        SELECT OBJECT_CONSTRUCT(
            'temperature', :extraction:pricing_table:temperature[idx.value],
            'container_size', :extraction:pricing_table:container_size[idx.value],
            'volume_tier_min', :extraction:pricing_table:volume_tier_min[idx.value],
            'volume_tier_max', :extraction:pricing_table:volume_tier_max[idx.value],
            'unit_price', :extraction:pricing_table:unit_price[idx.value]
        ) AS value
    ) AS pt;

    -- Step 3: Update contract metadata status
    UPDATE SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_METADATA
    SET EXTRACTION_STATUS = 'EXTRACTED', EXTRACTED_AT = CURRENT_TIMESTAMP()
    WHERE CONTRACT_ID = :P_CONTRACT_ID;

    RETURN 'Successfully extracted pricing for contract ' || :P_CONTRACT_ID || ' (' || :P_CUSTOMER_NAME || ')';
EXCEPTION
    WHEN OTHER THEN
        UPDATE SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_METADATA
        SET EXTRACTION_STATUS = 'FAILED'
        WHERE CONTRACT_ID = :P_CONTRACT_ID;
        RETURN 'FAILED: ' || SQLERRM;
END;
$$;

/*
  NEXT: Run 05_anomaly_views.sql
*/
