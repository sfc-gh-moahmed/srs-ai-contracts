---
title: "SRS AI Contracts — Pricing Extraction & Billing Anomaly Detection"
author: "Snowflake"

---

# SRS AI Contracts
## Pricing Extraction & Billing Anomaly Detection

**Proof of Concept** — Leveraging Snowflake Cortex to extract contract pricing, detect billing discrepancies, and enable proactive correction before ERP invoicing.

![w:900](https://kroki.io/mermaid/svg/eNqVkNFqwjAUhu_3FAeEXSnrVuucDKFNGx24WVplgyIj1rQWs0TSqBP68EtrqV5sMJO7k__7-U5SSbZrmAQ3oI8dIcGVJLEC38X581IOX0P7Lpy-L6DTGRbzLRNkVYAThVwcEkY2FEJFUrqocKcK2S-f3scssNGsABSFSu5itZN0Bb7M4oynZeuMLBnNTxQqKXAjm4svwo7gUkVjlQleBj2eZryu9yInY0w3gEsUKV99STte4C9ODVXIrRwwI2kBOJruqYzXRKY0h9uSmPNVMzm14goI6D6jhwJG-gekot9gp5Srkngj2p4wmBCe7ppVR6dVt1sp9rSAcTTVv8YoICZ2q0pca1XJXB313IZEuw9aiVXedq6k2NBByzTNi5BThx6eHMvrN6H7e6v3iNuxYELqhiS5QND1iFsjGPcc86yCkGUZxu-I9x973PR29bnoNYy_ekfX249rpItsbBlnlX7fM9EF8gMMc95O)

### Business Impact
- **Improve pricing accuracy** across all SRS customer contracts
- **Reduce billing errors** before invoices reach customers
- **Collect cash sooner** by catching undercharges pre-ERP
- **Enhance operational efficiency** with AI-powered contract intelligence

---

## The Problem & Solution

<div class="columns">
<div class="col">

### Current Challenges

| Challenge | Impact |
|---|---|
| Complex pricing in MSA/SOW | Manual lookup errors |
| Variables: temp, size, tiers | Wrong tier applied |
| No pre-ERP price validation | Errors reach customers |
| Manual contract review | Time-consuming, inconsistent |
| Billing corrections post-ERP | Delayed cash collection |

### Pricing Complexity Example

| Temperature | Container | Tier (Units) | Price |
|---|---|---|---|
| -80°C | Vial | 1-100 | $2.50 |
| -80°C | Vial | 101-500 | $2.10 |
| -80°C | Vial | 501-1000 | $1.75 |
| -80°C | Vial | 1001+ | $1.40 |
| -80°C | Box | 1-50 | $18.00 |
| LN2 | Vial | 1-100 | $4.25 |

> Each customer has unique tiers -- 3 customers = 38 pricing rules

</div>
<div class="col">

### Snowflake Cortex Solution

**Three-Layer Architecture:**

**1. AI Contract Extraction**
- Upload contract PDFs to Snowflake Stage
- `AI_EXTRACT` pulls structured pricing tables directly from PDFs
- Zero model training -- works out of the box
- Outputs standardized pricing per customer/temp/size/tier

**2. Automated Anomaly Detection**
- Join billing transactions against contract pricing
- Match on: customer + temperature + container + volume tier
- Flag: <span class="orange">OVERCHARGE</span> | <span class="red">UNDERCHARGE</span> | <span class="green">WITHIN_TOLERANCE</span>
- Calculate revenue impact per discrepancy

**3. Cortex Agent for Review**
- Natural language interface for billing analysts
- "Show me all anomalies for BioPharm this month"
- "What's our total revenue leakage from undercharges?"
- "What are the payment terms in the GeneTech contract?"
- Two tools: **Cortex Analyst** (structured queries) + **Cortex Search** (contract clauses)

</div>
</div>

---

## How It Works: Contract Extraction to Anomaly Detection

<div class="columns">
<div class="col">

### Data Flow

![w:520](https://kroki.io/mermaid/svg/eNqVkF1r2zAUhu_3Kw6UXq0Bp669pIyCLduxQioXW_0AUYxilMbMtYKsdnTz_nsV26S-yKCVLiTE85zzHj0pvtsCDb6BWR5DstaKFxpugghkDZnmT-IRJpOr1sN5-EBTD9EWfLbMEgKpaHaybsRjZ_sdFlVca1GDpxR_a1pADCWk0_KbFCNMFkD5uhqcgPl4tTKPuUFIZiickKxrCOHfpSzrfQr00mj5LNTPtbqi4nkH3yEr_whz0FKof10l1DvdPeySXHNdbFuIGOJV8WJiCbjjquR1IeC0bx_1k63lq4DpaQsLltyFKYq9dBGOCV9U8jdM9kjMbklwjLkv9dbE3TOY3WMaY5LTZBWaudAA9rmIhCHakpEkP3zPtUdR3IONfqsEeLApq-ryZOPs91mjlfwlLk9s2x5B_gCdz30nnB2g6dRxf0RnhaykMhU2m5GCvq4En4myGKAocn37A0LIcSzreN34oFyYNVIs638KHpQL5EWO9RFlNgttdFxZDsp8Pj_wruuO4HdGH-Hy)

</div>
<div class="col">

### Step 1: Extract Pricing from Contract PDF
```sql
SELECT AI_EXTRACT(
  file => TO_FILE('@CONTRACT_STAGE', 'biopharm_msa.pdf'),
  responseFormat => {
    'schema': { 'type': 'object', 'properties': {
      'pricing_table': {
        'description': 'Pricing schedule with temperature,
          container_size, volume_tier_min/max, unit_price',
        'type': 'object',
        'column_ordering': ['temperature','container_size',
          'volume_tier_min','volume_tier_max','unit_price'],
        'properties': {
          'temperature':    { 'type': 'array' },
          'container_size': { 'type': 'array' },
          'volume_tier_min':{ 'type': 'array' },
          'volume_tier_max':{ 'type': 'array' },
          'unit_price':     { 'type': 'array' } }}}}});
```

### Step 2: Detect Anomalies
```sql
-- Join billing to contract pricing, flag discrepancies
SELECT TXN_ID, CUSTOMER_NAME, BILLED_UNIT_PRICE,
  CONTRACT_UNIT_PRICE, PRICE_VARIANCE_PCT,
  CASE WHEN variance > 1% THEN 'OVERCHARGE'
       WHEN variance < -1% THEN 'UNDERCHARGE'
  END AS ANOMALY_TYPE
FROM BILLING_TRANSACTIONS b
JOIN CONTRACT_PRICING cp
  ON b.CUSTOMER = cp.CUSTOMER
  AND b.TEMP = cp.TEMP AND b.SIZE = cp.SIZE
  AND b.QTY BETWEEN cp.TIER_MIN AND cp.TIER_MAX;
```

</div>
</div>

---

## Demo Results: Anomalies Detected

<div class="columns">
<div class="col">

### Anomalies Found Across 3 Customers (32 transactions)

| Customer | Anomaly | Count | Revenue Impact |
|---|---|---|---|
| CryoMed Research | <span class="orange">OVERCHARGE</span> | 2 | +$510.00 |
| BioPharm Corp | <span class="orange">OVERCHARGE</span> | 2 | +$417.50 |
| GeneTech Solutions | <span class="orange">OVERCHARGE</span> | 1 | +$250.00 |
| CryoMed Research | <span class="red">UNDERCHARGE</span> | 2 | -$332.50 |
| BioPharm Corp | <span class="red">UNDERCHARGE</span> | 2 | -$300.00 |
| GeneTech Solutions | <span class="red">UNDERCHARGE</span> | 2 | -$150.00 |

**Total Overcharges:** $1,177.50 (5 txns) -- risk of customer disputes
**Total Undercharges:** $782.50 (6 txns) -- direct revenue leakage

### Example: Wrong Tier Applied
| Field | Value |
|---|---|
| Customer | BioPharm Corp |
| Transaction | TXN-2025-007 |
| Service | -80°C Vial Storage |
| Quantity | 300 units |
| Billed Price | $1.40/vial |
| **Contract Price** | **$2.10/vial** (Tier 101-500) |
| Variance | **-33.3%** |
| **Revenue Lost** | **-$210.00** |

</div>
<div class="col">

### Cortex Agent: Natural Language Review

![w:460](https://kroki.io/mermaid/svg/eNqVkE9rwjAYh-_7FC8IOynUdXFOhpCmjRcPusouxUPsUg3WZCQpKvTDr39i7cGLySWQ5_n93mSv2d8Blt8vUC2cBCLPhdwDliy_GruF0WheYnOEdcGNFUqWECREacsvgPdc2m0jBg0XW12kttD8t8b1tQTSsW3e107PY35i0ooUfgQ_93WipNUstUByVhheQnizY850eqjljtnwi-smtQxREq-XoCSstEirF9Twa1WrTlUxbNgu56blw4anSTfHPb3Su4JVSJ0QNcIiwdKcuYazsAcImWXtLW1vm7Ox15wDhqz6xdkgQ_UeGqvVkc8Gvu_3oMBBb58BiqYdNB6jyQcdpipXukrIsp5CnELpJPDvuYQg5HmPldAp7wRT5N1HmU4jnzxWoucHo8-3LJziYm-Kh_0Q9ZV_5jDMyw==)

### Sample Agent Conversations

**Billing Analyst asks:**
> "Show me all undercharges for BioPharm this month"

**Agent returns** (via Cortex Analyst):
| TXN | Temp | Qty | Billed | Contract | Impact |
|---|---|---|---|---|---|
| TXN-2025-007 | -80°C | 300 | $1.40 | $2.10 | -$210 |
| TXN-2025-009 | LN2 | 150 | $3.00 | $3.60 | -$90 |

**SRS Manager asks:**
> "What are the payment terms in the BioPharm contract?"

**Agent returns** (via Cortex Search):
> "Payment Terms: Net 30 days from invoice date. Late Payment: 1.5% per month on outstanding balance."

</div>
</div>

---

## Scalability & Production Considerations

<div class="columns">
<div class="col">

### Scalability

| Dimension | Approach |
|---|---|
| **Contract Volume** | `DIRECTORY()` table + `AI_EXTRACT` batch processing -- parse all PDFs in one query |
| **New Contracts** | Snowflake Task triggers extraction on new uploads via stage streams |
| **Incremental Processing** | Only extract new/modified contracts; cache parsed results |
| **Pricing Updates** | Track contract amendments; maintain version history |
| **Performance** | AI_EXTRACT: ~$0.04/page; 93-97% accuracy on contracts |

### Oracle ERP Integration Pattern

```
┌─────────────────────────────────────────┐
│ Pre-ERP Pipeline (Snowflake)            │
│                                         │
│ Billing Data → Anomaly Check → Review   │
│      ↓              ↓            ↓      │
│  Raw Txns     Flag Issues    Approve/   │
│                              Correct    │
│                                ↓        │
│              ERP_STATUS = 'APPROVED'     │
└───────────────┬─────────────────────────┘
                │ COPY INTO / API
                ▼
┌─────────────────────────────────────────┐
│ Oracle Cloud ERP                        │
│ Invoice Generation → Send to Customer   │
└─────────────────────────────────────────┘
```

</div>
<div class="col">

### Implementation Considerations

**Data Governance**
- Contract PDFs stay in Snowflake internal stage (encrypted at rest)
- Row-level security can restrict analyst access by customer
- Full audit trail via ACCESS_HISTORY

**Accuracy & Validation**
- AI_EXTRACT achieves 93-97% accuracy on structured contracts
- Human-in-the-loop: extracted pricing is reviewed before activation
- Confidence scoring: compare extracted vs. known pricing on initial contracts

**Cost Estimate (Monthly)**

| Component | Volume | Est. Cost |
|---|---|---|
| AI_EXTRACT (contracts) | 50 contracts, ~10 pages each | ~$20 |
| Cortex Search (indexing) | 500 contract pages | ~$5 |
| Cortex Agent (queries) | ~500 queries/month | ~$15 |
| Warehouse (XS, auto-suspend) | Anomaly detection | ~$30 |
| **Total** | | **~$70/month** |

### Industry Adoption

- **Insurance**: Claims extraction and pricing validation
- **Healthcare**: Contract compliance and billing audit
- **Procurement**: Vendor contract price verification
- **Legal**: Clause extraction and obligation tracking

> Snowflake Cortex AI functions are GA and production-ready as of 2025. Zero external dependencies -- all processing stays within Snowflake's security perimeter.

</div>
</div>

---

## Next Steps & POC Roadmap

<div class="columns">
<div class="col">

### POC Deliverables (Built in Demo Account)

| Component | Status |
|---|---|
| Database & schemas (`SRS_AI_CONTRACTS`) | Done |
| Contract stage + metadata tables | Done |
| Structured pricing table (38 rules, 3 customers) | Done |
| Billing transactions (32 txns with anomalies) | Done |
| `AI_EXTRACT` stored procedure | Done |
| Anomaly detection views | Done |
| Cortex Search service (contract clauses) | Done |
| Semantic View (pricing + anomaly analytics) | Done |
| Cortex Agent (Analyst + Search) | Done |

### What This POC Demonstrates

1. **End-to-end pipeline**: PDF contract → structured pricing → anomaly detection → agent review
2. **AI_EXTRACT on real contract structures**: Biorepository Storage with temp/size/tier pricing
3. **Pre-ERP quality gate**: Catch overcharges and undercharges before invoicing
4. **Natural language access**: Billing analysts query anomalies conversationally

</div>
<div class="col">

### Production Expansion Path

**Phase 1: Pilot** (Current)
- 3 sample customers, Biorepository Storage
- Manual PDF upload to stage
- Agent for billing analyst review

**Phase 2: Expand**
- Onboard all active SRS contracts
- Add Sample Management, Genomic Services pricing
- Automated contract ingestion (S3/email integration)
- Snowflake Task for scheduled anomaly detection

**Phase 3: Production**
- Oracle ERP staging integration (COPY INTO / API)
- Role-based access (billing analyst, SRS manager, finance)
- Alert notifications for high-impact anomalies
- Quarterly contract re-extraction for amendments
- Dashboard for executive pricing health metrics

### Key Ask from SRS & IT Teams

> 1. **Sample contracts**: Provide 3-5 real MSA/SOW PDFs (redacted if needed) to validate AI_EXTRACT accuracy on actual pricing tables
> 2. **Billing data feed**: Access to pre-ERP billing dataset schema for integration design
> 3. **ERP staging format**: Oracle Cloud ERP expected data format for approved transactions

</div>
</div>
