# SRS AI Contracts — Deployment Guide

Snowflake Cortex demo for automated contract pricing extraction and billing anomaly detection.

## What This Demo Does

1. **AI_EXTRACT** — Extracts structured pricing tables from contract PDFs using Cortex
2. **Anomaly Detection** — Compares billing transactions to contract pricing, flags overcharges/undercharges
3. **Cortex Search** — Natural-language search over contract text
4. **Cortex Agent** — Chat interface for billing analysts to query pricing, anomalies, and contracts

## Prerequisites

- Snowflake account with **Cortex** enabled (Enterprise or above)
- Role with `CREATE DATABASE`, `CREATE WAREHOUSE` privileges
- Cortex model access: `claude-4-sonnet` (or adjust in `08_cortex_agent.sql`)

## Quick Start

Run the scripts in order using Snowsight worksheets or SnowSQL:

| Script | Description | Time |
|--------|-------------|------|
| `01_setup_database.sql` | Database, schemas, warehouse, stage | ~5s |
| `02_create_tables.sql` | 4 tables | ~5s |
| `03_sample_data.sql` | Demo data: 3 customers, 38 pricing rules, 32 transactions (11 anomalies) | ~5s |
| `04_extraction_procedure.sql` | `EXTRACT_CONTRACT_PRICING` stored procedure (for real PDFs) | ~5s |
| `05_anomaly_views.sql` | `BILLING_ANOMALIES` + `ANOMALY_SUMMARY` views | ~5s |
| `06_cortex_search.sql` | Cortex Search service over contract text | ~30s |
| `07_semantic_view.sql` | Semantic view with 6 verified queries | ~5s |
| `08_cortex_agent.sql` | Cortex Agent with 3 tools | ~10s |
| `09_verify.sql` | Validation queries — run to confirm everything works | ~5s |

## Customization

### Warehouse
Edit the warehouse name in `01_setup_database.sql`:
```sql
SET WH_NAME = 'YOUR_WAREHOUSE_NAME';
```

### Agent Model
Change the model in `08_cortex_agent.sql` if needed:
```sql
MODEL = 'claude-4-sonnet'  -- or another available model
```

### Adding Real Contract PDFs
1. Upload PDFs to the stage:
   ```sql
   PUT file:///path/to/contract.pdf @SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE;
   ```
2. Run the extraction procedure:
   ```sql
   CALL RAW_DATA.EXTRACT_CONTRACT_PRICING('MSA-2024-001', 'contract.pdf', 'Customer Name');
   ```

## Demo Questions to Ask the Agent

**Anomaly Detection:**
- "Show me all billing anomalies for BioPharm Corp"
- "What is the total revenue impact of overcharges across all customers?"
- "Which transactions have the largest price variance?"
- "List all PRE_ERP transactions with overcharges that need review"

**Contract Pricing:**
- "Show -80C vial pricing tiers for all customers"
- "Compare pricing across customers for liquid nitrogen storage"
- "What are CryoMed Research's rack storage rates?"

**Contract Search:**
- "What are the SLA terms for sample retrieval?"
- "Search for payment terms across all contracts"
- "What compliance certifications does Azenta maintain?"

**Charts:**
- "Chart the revenue impact by customer and anomaly type"
- "Show a bar chart of anomaly counts by customer"

## Architecture

```
Contract PDFs → AI_EXTRACT → CONTRACT_PRICING (structured)
                                    ↓
BILLING_TRANSACTIONS ←→ JOIN → BILLING_ANOMALIES view
                                    ↓
                           Semantic View + Agent
                                    ↓
                        Billing Analyst Review
                                    ↓
                          Oracle Cloud ERP
```

## Data Model

- **RAW_DATA.CONTRACT_METADATA** — Uploaded contract files and extraction status
- **RAW_DATA.CONTRACT_PRICING** — Extracted pricing by temperature, container, volume tier
- **RAW_DATA.BILLING_TRANSACTIONS** — Pre-ERP billing records with `ERP_STATUS` lifecycle
- **RAW_DATA.CONTRACT_TEXT** — Parsed contract sections for search
- **ANALYTICS.BILLING_ANOMALIES** — Transactions joined to pricing with anomaly flags
- **ANALYTICS.ANOMALY_SUMMARY** — Aggregated anomaly stats by customer
- **AGENTS.CONTRACT_SEARCH_SERVICE** — Cortex Search over contract text
- **AGENTS.CONTRACTS_SEMANTIC_VIEW** — Semantic layer for text-to-SQL
- **AGENTS.CONTRACT_PRICING_AGENT** — AI agent with analyst + search + chart tools

## Cleanup

To remove everything:
```sql
DROP DATABASE IF EXISTS SRS_AI_CONTRACTS;
DROP WAREHOUSE IF EXISTS SRS_CONTRACTS_WH;
```
