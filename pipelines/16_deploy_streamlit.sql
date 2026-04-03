/*=============================================================
  SRS AI Contracts — Step 16: Deploy Streamlit in Snowflake

  Creates the Streamlit app object in Snowflake.

  Steps:
    1. Create a dedicated stage for the app file
    2. Upload app.py using PUT (run from SnowSQL or Snowflake CLI)
    3. Run this script to create the STREAMLIT object
    4. Open from Snowsight: Streamlit > MSA_EXTRACTION_APP

  >>> CONFIGURE: Adjust warehouse name if different from SRS_CONTRACTS_WH
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;
USE SCHEMA AGENTS;

-- 1. Stage for Streamlit app file
CREATE STAGE IF NOT EXISTS SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Hosts Streamlit in Snowflake app files for MSA extraction demo';

-- 2. Upload app.py (run from SnowSQL or Snowflake CLI):
--
--    snowsql -c <connection> -q "PUT file:///path/to/streamlit/app.py @SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
--
--    Or from Snowflake CLI:
--    snow stage copy streamlit/app.py @SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE --overwrite
--
--    Or from SnowSQL:
--    PUT file:///Users/moahmed/Desktop/Dev/Azenta/srs_ai_contracts_demo/streamlit/app.py
--        @SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE
--        AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 3. Create the Streamlit app
CREATE OR REPLACE STREAMLIT SRS_AI_CONTRACTS.AGENTS.MSA_EXTRACTION_APP
    ROOT_LOCATION = '@SRS_AI_CONTRACTS.RAW_DATA.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'SRS_CONTRACTS_WH'
    COMMENT = 'MSA Contract Extraction Pipeline — visualize AI_EXTRACT vs AI_COMPLETE results, run pipelines, and validate against ground truth';

-- 4. Verify
SHOW STREAMLITS IN SCHEMA SRS_AI_CONTRACTS.AGENTS;

-- 5. Grant access to other roles (optional)
-- GRANT USAGE ON STREAMLIT SRS_AI_CONTRACTS.AGENTS.MSA_EXTRACTION_APP TO ROLE <YOUR_ANALYST_ROLE>;

/*
  Open the app in Snowsight:
    Left nav → Streamlit → MSA_EXTRACTION_APP

  Or direct URL:
    https://<account>.snowflakecomputing.com/streamlit/editor/SRS_AI_CONTRACTS/AGENTS/MSA_EXTRACTION_APP
*/
