/*=============================================================
  SRS AI Contracts — Step 6: Cortex Search Service
  
  Creates a search service over CONTRACT_TEXT for natural-language
  contract clause lookup (e.g. "What are BioPharm's LN2 pricing terms?").
  
  Requires: 02_create_tables.sql, 03_sample_data.sql
  Note:     Needs CORTEX_USER database role or equivalent privileges.
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

-- 1. Enable change tracking on the source table (required by Cortex Search)
ALTER TABLE RAW_DATA.CONTRACT_TEXT SET CHANGE_TRACKING = TRUE;

-- 2. Create the search service
CREATE OR REPLACE CORTEX SEARCH SERVICE AGENTS.CONTRACT_SEARCH_SERVICE
  ON CONTENT
  ATTRIBUTES CUSTOMER_NAME, CONTRACT_ID, SECTION_TITLE
  WAREHOUSE = SRS_CONTRACTS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Semantic search over contract text for clause and pricing lookups'
AS (
    SELECT
        CONTENT,
        CUSTOMER_NAME,
        CONTRACT_ID,
        SECTION_TITLE
    FROM RAW_DATA.CONTRACT_TEXT
);

/*
  NEXT: Run 07_semantic_view.sql
*/
