/*=============================================================
  SRS AI Contracts — Step 2: Create Tables
  
  Requires: 01_setup_database.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

-- 1. Contract metadata (tracks uploaded contract PDFs)
CREATE OR REPLACE TABLE RAW_DATA.CONTRACT_METADATA (
    CONTRACT_ID         VARCHAR(20)   NOT NULL,
    CUSTOMER_NAME       VARCHAR(200)  NOT NULL,
    CONTRACT_TYPE       VARCHAR(20),
    EFFECTIVE_DATE      DATE,
    EXPIRY_DATE         DATE,
    FILE_NAME           VARCHAR(500),
    EXTRACTION_STATUS   VARCHAR(20) DEFAULT 'PENDING',
    EXTRACTED_AT        TIMESTAMP,
    CREATED_AT          TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Metadata for SRS customer contracts uploaded to stage';

-- 2. Structured pricing extracted from contracts
CREATE OR REPLACE TABLE RAW_DATA.CONTRACT_PRICING (
    PRICING_ID        NUMBER AUTOINCREMENT,
    CONTRACT_ID       VARCHAR(20)   NOT NULL,
    CUSTOMER_NAME     VARCHAR(200)  NOT NULL,
    SERVICE_TYPE      VARCHAR(100),
    TEMPERATURE       VARCHAR(20),
    CONTAINER_SIZE    VARCHAR(20),
    VOLUME_TIER_MIN   NUMBER,
    VOLUME_TIER_MAX   NUMBER,
    UNIT_PRICE        FLOAT        NOT NULL,
    CURRENCY          VARCHAR(3)   DEFAULT 'USD',
    EFFECTIVE_DATE    DATE,
    EXPIRY_DATE       DATE,
    EXTRACTION_METHOD VARCHAR(20),
    CREATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Structured pricing extracted from SRS contracts by Cortex AI';

-- 3. Billing transactions (pre-ERP)
CREATE OR REPLACE TABLE RAW_DATA.BILLING_TRANSACTIONS (
    TXN_ID            VARCHAR(20)   NOT NULL,
    CUSTOMER_NAME     VARCHAR(200)  NOT NULL,
    TXN_DATE          DATE          NOT NULL,
    SERVICE_TYPE      VARCHAR(100),
    TEMPERATURE       VARCHAR(20),
    CONTAINER_SIZE    VARCHAR(20),
    QUANTITY          NUMBER        NOT NULL,
    BILLED_UNIT_PRICE FLOAT         NOT NULL,
    TOTAL_AMOUNT      FLOAT,
    ERP_STATUS        VARCHAR(20)   DEFAULT 'PRE_ERP',
    REVIEWED_BY       VARCHAR(100),
    REVIEWED_AT       TIMESTAMP,
    CREATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Billing transactions pre-ERP for anomaly detection against contract pricing';

-- 4. Parsed contract text (for Cortex Search)
CREATE OR REPLACE TABLE RAW_DATA.CONTRACT_TEXT (
    CONTRACT_ID       VARCHAR(20)   NOT NULL,
    CUSTOMER_NAME     VARCHAR(200)  NOT NULL,
    PAGE_NUMBER       NUMBER,
    SECTION_TITLE     VARCHAR(200),
    CONTENT           VARCHAR(16000),
    CREATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Parsed contract text for Cortex Search indexing';

/*
  NEXT: Run 03_sample_data.sql
*/
