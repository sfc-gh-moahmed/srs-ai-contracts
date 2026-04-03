/*=============================================================
  SRS AI Contracts — Step 11: Upload PDFs to Stage

  Uploads BMS and Sanofi MSA PDFs to CONTRACT_STAGE,
  then refreshes the directory table for AI functions to discover them.

  Run from SnowSQL CLI or Snowsight (PUT only works from SnowSQL or
  the Snowflake CLI — not from a Snowsight worksheet directly).

  Usage (SnowSQL):
    snowsql -c <connection> -f 11_upload_pdfs.sql

  Or run PUT commands manually in SnowSQL, then run the
  verification queries below in Snowsight.

  >>> CONFIGURE: Update LOCAL_PDF_PATH to match your local directory
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;
USE SCHEMA RAW_DATA;

-- ─────────────────────────────────────────────────────────────
-- 1. Upload PDFs to stage
--    AUTO_COMPRESS=FALSE keeps original PDF bytes intact
--    OVERWRITE=TRUE replaces existing files on re-run
-- ─────────────────────────────────────────────────────────────

-- BMS Third Amendment to Master Laboratory Services Agreement (13 pages)
PUT file:///Users/moahmed/Downloads/'BMS - MSA AMD 3 06Jan2026 FE.pdf'
    @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE
    AUTO_COMPRESS = FALSE
    OVERWRITE = TRUE;

-- Sanofi Global Pricing Letter (18 pages, 6-region rate card)
PUT file:///Users/moahmed/Downloads/Sanofi_MSA.pdf
    @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE
    AUTO_COMPRESS = FALSE
    OVERWRITE = TRUE;

-- ─────────────────────────────────────────────────────────────
-- 2. Refresh directory table so AI functions can see new files
-- ─────────────────────────────────────────────────────────────
ALTER STAGE SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE REFRESH;

-- ─────────────────────────────────────────────────────────────
-- 3. Verify uploads
--    Expect: BMS file (~size) + Sanofi file (~size) listed
-- ─────────────────────────────────────────────────────────────
LIST @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE PATTERN='.*\\.pdf';

-- Directory table view (used by AI functions internally)
SELECT RELATIVE_PATH, SIZE, LAST_MODIFIED
FROM DIRECTORY(@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE)
WHERE RELATIVE_PATH LIKE '%.pdf'
ORDER BY LAST_MODIFIED DESC;

/*
  Expected output:
    BMS - MSA AMD 3 06Jan2026 FE.pdf   ~XXX KB
    Sanofi_MSA.pdf                      ~XXX KB

  NEXT: Run 12_pipeline_a_ai_parse_extract.sql
        Run 13_pipeline_b_ai_parse_complete.sql
*/
