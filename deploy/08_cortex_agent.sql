/*=============================================================
  SRS AI Contracts — Step 8: Cortex Agent
  
  Creates an AI agent with 3 tools:
    1. query_pricing_data — text-to-SQL via the Semantic View
    2. search_contracts   — semantic search over contract text
    3. data_to_chart      — auto-chart generation
  
  Requires: 06_cortex_search.sql, 07_semantic_view.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

CREATE OR REPLACE AGENT AGENTS.CONTRACT_PRICING_AGENT
  MODEL = 'claude-4-sonnet'
  SYSTEM_PROMPT = 'You are an AI assistant for Azenta Life Sciences SRS (Sample Repository Services) billing operations. You help billing analysts review contract pricing, identify billing anomalies (overcharges and undercharges), and prepare transactions for Oracle Cloud ERP submission.

Key context:
- Azenta stores biological samples at different temperatures (-80C, -20C, Room Temperature, Liquid Nitrogen)
- Pricing varies by temperature, container size (VIAL, BOX, RACK, PALLET), and volume tier
- Transactions with ERP_STATUS of PRE_ERP need review before being sent to Oracle Cloud ERP
- Anomaly types: OVERCHARGE (billed more than contract), UNDERCHARGE (billed less), WITHIN_TOLERANCE (within 1%), NO_CONTRACT_MATCH
- Revenue impact = (billed price - contract price) * quantity

Always provide specific numbers and recommend actions for anomalies found.'
  TOOLS = (
    cortex_analyst_text_to_sql(
      name => 'query_pricing_data',
      semantic_view => 'SRS_AI_CONTRACTS.AGENTS.CONTRACTS_SEMANTIC_VIEW'
    ),
    cortex_search(
      name => 'search_contracts',
      cortex_search_service => 'SRS_AI_CONTRACTS.AGENTS.CONTRACT_SEARCH_SERVICE'
    ),
    data_to_chart(
      name => 'data_to_chart'
    )
  )
  COMMENT = 'SRS billing analyst agent: queries pricing data, searches contracts, and visualizes anomalies'
  SPEC = $$
name: contract_pricing_agent
description: >
  AI agent for Azenta SRS billing operations. Helps analysts review contract pricing,
  detect billing anomalies, and prepare pre-ERP transactions for Oracle Cloud submission.
tools:
  - name: query_pricing_data
    type: cortex_analyst_text_to_sql
    config:
      semantic_view: SRS_AI_CONTRACTS.AGENTS.CONTRACTS_SEMANTIC_VIEW
    description: >
      Query contract pricing and billing anomaly data using natural language.
      Use for questions about pricing tiers, overcharges, undercharges,
      revenue impact, and transaction status.
  - name: search_contracts
    type: cortex_search
    config:
      cortex_search_service: SRS_AI_CONTRACTS.AGENTS.CONTRACT_SEARCH_SERVICE
    description: >
      Search contract text for specific clauses, terms, pricing language,
      SLA details, and compliance requirements.
  - name: data_to_chart
    type: data_to_chart
    description: >
      Create charts and visualizations from query results.
      Use to visualize anomaly distributions, pricing comparisons,
      and revenue impact summaries.
$$;

/*
  NEXT: Run 09_verify.sql
*/
