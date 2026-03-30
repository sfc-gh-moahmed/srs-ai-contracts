/*=============================================================
  SRS AI Contracts — Step 1: Database, Schemas, Warehouse, Stage
  
  Run this script first. Customize the warehouse name/size below.
=============================================================*/

-- >>> CUSTOMIZE: Change warehouse size if needed
SET WH_NAME = 'SRS_CONTRACTS_WH';

-- 1. Database
CREATE DATABASE IF NOT EXISTS SRS_AI_CONTRACTS;

-- 2. Schemas
CREATE SCHEMA IF NOT EXISTS SRS_AI_CONTRACTS.RAW_DATA;
CREATE SCHEMA IF NOT EXISTS SRS_AI_CONTRACTS.ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SRS_AI_CONTRACTS.AGENTS;

-- 3. Warehouse (XS with 60s auto-suspend)
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($WH_NAME)
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse for SRS AI Contracts pricing extraction and anomaly detection';

-- 4. Internal stage for contract PDFs
CREATE OR REPLACE STAGE SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Internal stage for SRS customer contract PDFs (MSA/SOW)';

/*
  NEXT: Run 02_create_tables.sql
*/
