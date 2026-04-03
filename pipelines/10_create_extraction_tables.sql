/*=============================================================
  SRS AI Contracts — Step 10: Create Extraction Tables

  Creates:
    1. PARSED_CONTRACTS_TEXT  — per-page parse cache (AI_PARSE_DOCUMENT)
    2. SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST  — storage pricing
    3. SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST    — management fees

  CONFIGURE: Set DB_NAME and SCHEMA_NAME below before running.
  Both output tables will be created in DB_NAME.SCHEMA_NAME.
  The parse cache is created in SRS_AI_CONTRACTS.RAW_DATA.

  Requires: 01_setup_database.sql
=============================================================*/

-- >>> CONFIGURE: target database and schema for output tables
SET DB_NAME     = 'SI';
SET SCHEMA_NAME = 'PUBLIC';

USE DATABASE SRS_AI_CONTRACTS;

-- ─────────────────────────────────────────────────────────────
-- 1. Parse cache — one row per page per document
--    Populated by AI_PARSE_DOCUMENT(mode='LAYOUT', page_split=TRUE)
--    Parse once, extract many times — avoids re-parsing costs at scale
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT (
    FILENAME        VARCHAR(255)   NOT NULL,
    CUSTOMER_ID     VARCHAR(50)    NOT NULL,
    PAGE_INDEX      NUMBER(10,0)   NOT NULL,  -- 0-based page index from page_split
    PAGE_TEXT       VARCHAR(32000),           -- Markdown content from AI_PARSE_DOCUMENT LAYOUT
    TOTAL_PAGES     NUMBER(10,0),             -- Total pages in document (from metadata)
    PARSED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_parsed_text PRIMARY KEY (FILENAME, PAGE_INDEX)
) COMMENT = 'Per-page parsed text cache from AI_PARSE_DOCUMENT. Parse once, reuse for Pipeline A and B.';

-- ─────────────────────────────────────────────────────────────
-- 2. Storage Pricing — TRANSACTION_TYPE = STORAGE (default)
--    Populated by both Pipeline A (AI_EXTRACT) and Pipeline B (AI_COMPLETE)
--    EXTRACTION_METHOD distinguishes which pipeline/model produced the row
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST') (
    FILENAME            VARCHAR(255),
    REGION              VARCHAR(50),
    CURRENCY            VARCHAR(10),
    TEMPERATURE         VARCHAR(100),
    SAMPLE_SIZE         VARCHAR(50),
    QUANTITY_TIER       VARCHAR(50),
    PRICE               VARCHAR(50),
    MAX_QUANTITY_TIER   NUMBER(38,0),
    MIN_QUANTITY_TIER   NUMBER(38,0),
    CUSTOMER_ID         VARCHAR(50),
    CUBIC_FOOT_MAX      FLOAT,
    MIN_SAMPLE_SIZE     FLOAT,
    MAX_SAMPLE_SIZE     FLOAT,
    TRANSACTION_TYPE    VARCHAR(50)    DEFAULT 'STORAGE',
    -- Audit columns (pipeline traceability)
    EXTRACTION_METHOD   VARCHAR(100),  -- 'AI_PARSE+AI_EXTRACT' or 'AI_PARSE+AI_COMPLETE_<model>'
    EXTRACTED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Storage pricing extracted from MSA PDFs. Populated by Pipeline A (AI_EXTRACT) and Pipeline B (AI_COMPLETE).';

-- ─────────────────────────────────────────────────────────────
-- 3. Management Fees
--    Covers: Project Initiation, Sample Admin, Lab Services,
--            Professional Services, Additional Services
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME || '.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST') (
    FILENAME            VARCHAR(255),
    CUSTOMER_ID         VARCHAR(50),
    FEE_CATEGORY        VARCHAR(100),
    FEE_NAME            VARCHAR(255),
    CURRENCY            VARCHAR(20),
    PRICE               VARCHAR(50),
    UNIT                VARCHAR(100),
    DESCRIPTION         VARCHAR(2000),
    -- Audit columns
    EXTRACTION_METHOD   VARCHAR(100),
    EXTRACTED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Management fees extracted from MSA PDFs. Covers project initiation, sample admin, professional services, etc.';

-- Verify
SHOW TABLES LIKE 'PARSED_CONTRACTS_TEXT' IN SRS_AI_CONTRACTS.RAW_DATA;
SHOW TABLES LIKE 'SRS_CONTRACT_CUSTOMER%' IN IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME);

/*
  NEXT: Run 11_upload_pdfs.sql
*/
