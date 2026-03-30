/*=============================================================
  SRS AI Contracts — Step 9: Verification Queries
  
  Run after all previous scripts to confirm everything deployed
  correctly. Every query should return results.
  
  Requires: All previous scripts (01 through 08)
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

-- 1. Verify tables — expect 5, 38, 32, 10 rows
SELECT 'CONTRACT_METADATA' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM RAW_DATA.CONTRACT_METADATA
UNION ALL
SELECT 'CONTRACT_PRICING', COUNT(*) FROM RAW_DATA.CONTRACT_PRICING
UNION ALL
SELECT 'BILLING_TRANSACTIONS', COUNT(*) FROM RAW_DATA.BILLING_TRANSACTIONS
UNION ALL
SELECT 'CONTRACT_TEXT', COUNT(*) FROM RAW_DATA.CONTRACT_TEXT;

-- 2. Verify anomaly detection — expect 11 anomalies (overcharges + undercharges)
SELECT ANOMALY_TYPE, COUNT(*) AS COUNT
FROM ANALYTICS.BILLING_ANOMALIES
GROUP BY ANOMALY_TYPE
ORDER BY ANOMALY_TYPE;

-- 3. Verify anomaly summary by customer
SELECT CUSTOMER_NAME, ANOMALY_TYPE, TXN_COUNT, TOTAL_REVENUE_IMPACT
FROM ANALYTICS.ANOMALY_SUMMARY
WHERE ANOMALY_TYPE IN ('OVERCHARGE', 'UNDERCHARGE')
ORDER BY CUSTOMER_NAME, ANOMALY_TYPE;

-- 4. Show top anomalies by revenue impact
SELECT TXN_ID, CUSTOMER_NAME, TEMPERATURE, CONTAINER_SIZE,
       QUANTITY, BILLED_UNIT_PRICE, CONTRACT_UNIT_PRICE,
       PRICE_DIFFERENCE, REVENUE_IMPACT, ANOMALY_TYPE
FROM ANALYTICS.BILLING_ANOMALIES
WHERE ANOMALY_TYPE IN ('OVERCHARGE', 'UNDERCHARGE')
ORDER BY ABS(REVENUE_IMPACT) DESC
LIMIT 10;

-- 5. Verify Cortex Search Service
SHOW CORTEX SEARCH SERVICES IN SCHEMA SRS_AI_CONTRACTS.AGENTS;

-- 6. Verify Semantic View
SHOW SEMANTIC VIEWS IN SCHEMA SRS_AI_CONTRACTS.AGENTS;

-- 7. Verify Agent
SHOW AGENTS IN SCHEMA SRS_AI_CONTRACTS.AGENTS;

-- 8. Verify stored procedure
SHOW PROCEDURES IN SCHEMA SRS_AI_CONTRACTS.RAW_DATA;

/*
  ALL DONE. If all queries return results, the demo is ready.
  
  Try asking the agent:
    - "Show me all billing anomalies for BioPharm Corp"
    - "What is the total revenue impact of overcharges?"
    - "What are CryoMed's -80C vial pricing tiers?"
    - "Search contracts for SLA and retrieval terms"
*/
