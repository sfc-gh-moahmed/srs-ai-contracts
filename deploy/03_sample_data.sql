/*=============================================================
  SRS AI Contracts — Step 3: Sample Data
  
  Loads demo data for 3 customers:
    - BioPharm Corp (MSA-2024-001)
    - GeneTech Solutions (MSA-2024-003)
    - CryoMed Research (MSA-2025-004)
  
  Includes intentional pricing discrepancies for anomaly detection demo.
  
  Requires: 02_create_tables.sql
=============================================================*/

USE DATABASE SRS_AI_CONTRACTS;

--------------------------------------------------------------
-- CONTRACT METADATA
--------------------------------------------------------------
INSERT INTO RAW_DATA.CONTRACT_METADATA
    (CONTRACT_ID, CUSTOMER_NAME, CONTRACT_TYPE, EFFECTIVE_DATE, EXPIRY_DATE, FILE_NAME, EXTRACTION_STATUS, EXTRACTED_AT)
VALUES
    ('MSA-2024-001', 'BioPharm Corp', 'MSA', '2024-01-01', '2026-12-31', 'biopharm_msa_2024.pdf', 'EXTRACTED', '2025-06-15 10:30:00'),
    ('SOW-2024-002', 'BioPharm Corp', 'SOW', '2024-03-01', '2025-12-31', 'biopharm_sow_2024_q1.pdf', 'EXTRACTED', '2025-06-15 10:35:00'),
    ('MSA-2024-003', 'GeneTech Solutions', 'MSA', '2024-06-01', '2027-05-31', 'genetech_msa_2024.pdf', 'EXTRACTED', '2025-07-01 09:00:00'),
    ('MSA-2025-004', 'CryoMed Research', 'MSA', '2025-01-01', '2027-12-31', 'cryomed_msa_2025.pdf', 'EXTRACTED', '2025-08-10 14:00:00'),
    ('SOW-2025-005', 'CryoMed Research', 'SOW', '2025-04-01', '2026-03-31', 'cryomed_sow_2025.pdf', 'PENDING', NULL);

--------------------------------------------------------------
-- CONTRACT PRICING — BioPharm Corp
--------------------------------------------------------------
INSERT INTO RAW_DATA.CONTRACT_PRICING
    (CONTRACT_ID, CUSTOMER_NAME, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, VOLUME_TIER_MIN, VOLUME_TIER_MAX, UNIT_PRICE, EFFECTIVE_DATE, EXPIRY_DATE, EXTRACTION_METHOD)
VALUES
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'VIAL', 1, 100, 2.50, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'VIAL', 101, 500, 2.10, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'VIAL', 501, 1000, 1.75, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'VIAL', 1001, 99999, 1.40, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'BOX', 1, 50, 18.00, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'BOX', 51, 200, 15.50, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-80C', 'BOX', 201, 99999, 12.75, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-20C', 'VIAL', 1, 100, 1.80, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-20C', 'VIAL', 101, 500, 1.50, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', '-20C', 'VIAL', 501, 99999, 1.20, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', 'LN2', 'VIAL', 1, 100, 4.25, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', 'LN2', 'VIAL', 101, 500, 3.60, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', 'LN2', 'VIAL', 501, 99999, 2.95, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', 'RT', 'BOX', 1, 100, 8.00, '2024-01-01', '2026-12-31', 'AI_EXTRACT'),
    ('MSA-2024-001', 'BioPharm Corp', 'Biorepository Storage', 'RT', 'BOX', 101, 99999, 6.50, '2024-01-01', '2026-12-31', 'AI_EXTRACT');

--------------------------------------------------------------
-- CONTRACT PRICING — GeneTech Solutions
--------------------------------------------------------------
INSERT INTO RAW_DATA.CONTRACT_PRICING
    (CONTRACT_ID, CUSTOMER_NAME, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, VOLUME_TIER_MIN, VOLUME_TIER_MAX, UNIT_PRICE, EFFECTIVE_DATE, EXPIRY_DATE, EXTRACTION_METHOD)
VALUES
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-80C', 'VIAL', 1, 200, 2.75, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-80C', 'VIAL', 201, 1000, 2.25, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-80C', 'VIAL', 1001, 99999, 1.85, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-80C', 'BOX', 1, 100, 20.00, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-80C', 'BOX', 101, 99999, 17.00, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', 'LN2', 'VIAL', 1, 200, 4.50, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', 'LN2', 'VIAL', 201, 99999, 3.75, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-20C', 'VIAL', 1, 200, 2.00, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-20C', 'VIAL', 201, 99999, 1.60, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-20C', 'BOX', 1, 50, 14.00, '2024-06-01', '2027-05-31', 'AI_EXTRACT'),
    ('MSA-2024-003', 'GeneTech Solutions', 'Biorepository Storage', '-20C', 'BOX', 51, 99999, 11.50, '2024-06-01', '2027-05-31', 'AI_EXTRACT');

--------------------------------------------------------------
-- CONTRACT PRICING — CryoMed Research
--------------------------------------------------------------
INSERT INTO RAW_DATA.CONTRACT_PRICING
    (CONTRACT_ID, CUSTOMER_NAME, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, VOLUME_TIER_MIN, VOLUME_TIER_MAX, UNIT_PRICE, EFFECTIVE_DATE, EXPIRY_DATE, EXTRACTION_METHOD)
VALUES
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-80C', 'VIAL', 1, 150, 2.60, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-80C', 'VIAL', 151, 500, 2.15, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-80C', 'VIAL', 501, 99999, 1.70, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-80C', 'RACK', 1, 20, 95.00, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-80C', 'RACK', 21, 99999, 80.00, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', 'LN2', 'VIAL', 1, 150, 4.10, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', 'LN2', 'VIAL', 151, 500, 3.45, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', 'LN2', 'VIAL', 501, 99999, 2.80, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-20C', 'VIAL', 1, 150, 1.90, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', '-20C', 'VIAL', 151, 99999, 1.45, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', 'RT', 'PALLET', 1, 10, 150.00, '2025-01-01', '2027-12-31', 'AI_EXTRACT'),
    ('MSA-2025-004', 'CryoMed Research', 'Biorepository Storage', 'RT', 'PALLET', 11, 99999, 125.00, '2025-01-01', '2027-12-31', 'AI_EXTRACT');

--------------------------------------------------------------
-- BILLING TRANSACTIONS — BioPharm Corp
-- Includes 4 intentional anomalies: TXN-006 (overcharge), TXN-007 (undercharge),
-- TXN-008 (overcharge), TXN-009 (undercharge)
--------------------------------------------------------------
INSERT INTO RAW_DATA.BILLING_TRANSACTIONS
    (TXN_ID, CUSTOMER_NAME, TXN_DATE, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, QUANTITY, BILLED_UNIT_PRICE, TOTAL_AMOUNT, ERP_STATUS)
VALUES
    ('TXN-2025-001', 'BioPharm Corp', '2025-07-01', 'Biorepository Storage', '-80C', 'VIAL', 50, 2.50, 125.00, 'PRE_ERP'),
    ('TXN-2025-002', 'BioPharm Corp', '2025-07-01', 'Biorepository Storage', '-80C', 'VIAL', 250, 2.10, 525.00, 'PRE_ERP'),
    ('TXN-2025-003', 'BioPharm Corp', '2025-07-01', 'Biorepository Storage', '-80C', 'BOX', 30, 18.00, 540.00, 'PRE_ERP'),
    ('TXN-2025-004', 'BioPharm Corp', '2025-07-15', 'Biorepository Storage', '-20C', 'VIAL', 600, 1.20, 720.00, 'PRE_ERP'),
    ('TXN-2025-005', 'BioPharm Corp', '2025-07-15', 'Biorepository Storage', 'LN2', 'VIAL', 80, 4.25, 340.00, 'PRE_ERP'),
    ('TXN-2025-006', 'BioPharm Corp', '2025-08-01', 'Biorepository Storage', '-80C', 'VIAL', 200, 2.50, 500.00, 'PRE_ERP'),      -- OVERCHARGE: should be $2.10
    ('TXN-2025-007', 'BioPharm Corp', '2025-08-01', 'Biorepository Storage', '-80C', 'VIAL', 300, 1.40, 420.00, 'PRE_ERP'),      -- UNDERCHARGE: should be $2.10
    ('TXN-2025-008', 'BioPharm Corp', '2025-08-15', 'Biorepository Storage', '-80C', 'BOX', 75, 20.00, 1500.00, 'PRE_ERP'),      -- OVERCHARGE: should be $15.50
    ('TXN-2025-009', 'BioPharm Corp', '2025-08-15', 'Biorepository Storage', 'LN2', 'VIAL', 150, 3.00, 450.00, 'PRE_ERP'),       -- UNDERCHARGE: should be $3.60
    ('TXN-2025-010', 'BioPharm Corp', '2025-09-01', 'Biorepository Storage', 'RT', 'BOX', 50, 8.00, 400.00, 'PRE_ERP'),
    ('TXN-2025-011', 'BioPharm Corp', '2025-09-01', 'Biorepository Storage', '-80C', 'VIAL', 1500, 1.40, 2100.00, 'PRE_ERP'),
    ('TXN-2025-012', 'BioPharm Corp', '2025-09-15', 'Biorepository Storage', '-20C', 'VIAL', 300, 1.50, 450.00, 'PRE_ERP');

--------------------------------------------------------------
-- BILLING TRANSACTIONS — GeneTech Solutions
-- Anomalies: TXN-017 (overcharge), TXN-018 (undercharge), TXN-020 (undercharge)
--------------------------------------------------------------
INSERT INTO RAW_DATA.BILLING_TRANSACTIONS
    (TXN_ID, CUSTOMER_NAME, TXN_DATE, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, QUANTITY, BILLED_UNIT_PRICE, TOTAL_AMOUNT, ERP_STATUS)
VALUES
    ('TXN-2025-013', 'GeneTech Solutions', '2025-07-01', 'Biorepository Storage', '-80C', 'VIAL', 100, 2.75, 275.00, 'PRE_ERP'),
    ('TXN-2025-014', 'GeneTech Solutions', '2025-07-01', 'Biorepository Storage', '-80C', 'BOX', 40, 20.00, 800.00, 'PRE_ERP'),
    ('TXN-2025-015', 'GeneTech Solutions', '2025-07-15', 'Biorepository Storage', 'LN2', 'VIAL', 100, 4.50, 450.00, 'PRE_ERP'),
    ('TXN-2025-016', 'GeneTech Solutions', '2025-07-15', 'Biorepository Storage', '-20C', 'VIAL', 300, 1.60, 480.00, 'PRE_ERP'),
    ('TXN-2025-017', 'GeneTech Solutions', '2025-08-01', 'Biorepository Storage', '-80C', 'VIAL', 500, 2.75, 1375.00, 'PRE_ERP'),  -- OVERCHARGE: should be $2.25
    ('TXN-2025-018', 'GeneTech Solutions', '2025-08-01', 'Biorepository Storage', 'LN2', 'VIAL', 50, 3.00, 150.00, 'PRE_ERP'),    -- UNDERCHARGE: should be $4.50
    ('TXN-2025-019', 'GeneTech Solutions', '2025-08-15', 'Biorepository Storage', '-80C', 'BOX', 120, 17.00, 2040.00, 'PRE_ERP'),
    ('TXN-2025-020', 'GeneTech Solutions', '2025-08-15', 'Biorepository Storage', '-20C', 'VIAL', 150, 1.50, 225.00, 'PRE_ERP'),  -- UNDERCHARGE: should be $2.00
    ('TXN-2025-021', 'GeneTech Solutions', '2025-09-01', 'Biorepository Storage', '-80C', 'VIAL', 1200, 1.85, 2220.00, 'PRE_ERP'),
    ('TXN-2025-022', 'GeneTech Solutions', '2025-09-01', 'Biorepository Storage', '-20C', 'BOX', 30, 14.00, 420.00, 'PRE_ERP');

--------------------------------------------------------------
-- BILLING TRANSACTIONS — CryoMed Research
-- Anomalies: TXN-027 (overcharge), TXN-028 (overcharge), TXN-029 (undercharge), TXN-030 (undercharge)
--------------------------------------------------------------
INSERT INTO RAW_DATA.BILLING_TRANSACTIONS
    (TXN_ID, CUSTOMER_NAME, TXN_DATE, SERVICE_TYPE, TEMPERATURE, CONTAINER_SIZE, QUANTITY, BILLED_UNIT_PRICE, TOTAL_AMOUNT, ERP_STATUS)
VALUES
    ('TXN-2025-023', 'CryoMed Research', '2025-07-01', 'Biorepository Storage', '-80C', 'VIAL', 100, 2.60, 260.00, 'PRE_ERP'),
    ('TXN-2025-024', 'CryoMed Research', '2025-07-01', 'Biorepository Storage', '-80C', 'RACK', 10, 95.00, 950.00, 'PRE_ERP'),
    ('TXN-2025-025', 'CryoMed Research', '2025-07-15', 'Biorepository Storage', 'LN2', 'VIAL', 200, 3.45, 690.00, 'PRE_ERP'),
    ('TXN-2025-026', 'CryoMed Research', '2025-07-15', 'Biorepository Storage', '-20C', 'VIAL', 100, 1.90, 190.00, 'PRE_ERP'),
    ('TXN-2025-027', 'CryoMed Research', '2025-08-01', 'Biorepository Storage', '-80C', 'VIAL', 300, 2.60, 780.00, 'PRE_ERP'),    -- OVERCHARGE: should be $2.15
    ('TXN-2025-028', 'CryoMed Research', '2025-08-01', 'Biorepository Storage', '-80C', 'RACK', 25, 95.00, 2375.00, 'PRE_ERP'),   -- OVERCHARGE: should be $80.00
    ('TXN-2025-029', 'CryoMed Research', '2025-08-15', 'Biorepository Storage', 'LN2', 'VIAL', 75, 3.00, 225.00, 'PRE_ERP'),      -- UNDERCHARGE: should be $4.10
    ('TXN-2025-030', 'CryoMed Research', '2025-08-15', 'Biorepository Storage', 'RT', 'PALLET', 5, 100.00, 500.00, 'PRE_ERP'),    -- UNDERCHARGE: should be $150.00
    ('TXN-2025-031', 'CryoMed Research', '2025-09-01', 'Biorepository Storage', '-80C', 'VIAL', 600, 1.70, 1020.00, 'PRE_ERP'),
    ('TXN-2025-032', 'CryoMed Research', '2025-09-01', 'Biorepository Storage', '-20C', 'VIAL', 200, 1.45, 290.00, 'PRE_ERP');

--------------------------------------------------------------
-- CONTRACT TEXT — for Cortex Search (contract clause lookup)
--------------------------------------------------------------
INSERT INTO RAW_DATA.CONTRACT_TEXT
    (CONTRACT_ID, CUSTOMER_NAME, PAGE_NUMBER, SECTION_TITLE, CONTENT)
VALUES
    ('MSA-2024-001', 'BioPharm Corp', 1, 'General Terms', 'MASTER SERVICE AGREEMENT between Azenta Life Sciences ("Provider") and BioPharm Corp ("Client"). This agreement governs all biorepository storage services provided by Provider to Client. Effective Date: January 1, 2024. Term: 3 years through December 31, 2026. Payment Terms: Net 30 days from invoice date. Late Payment: 1.5% per month on outstanding balance. Governing Law: State of Massachusetts.'),
    ('MSA-2024-001', 'BioPharm Corp', 2, 'Pricing Schedule', 'EXHIBIT A: PRICING SCHEDULE FOR BIOREPOSITORY STORAGE SERVICES. All prices in USD per unit per month. Temperature -80C, Vial: Tier 1 (1-100 units) $2.50/vial, Tier 2 (101-500 units) $2.10/vial, Tier 3 (501-1000 units) $1.75/vial, Tier 4 (1001+ units) $1.40/vial. Temperature -80C, Box: Tier 1 (1-50 units) $18.00/box, Tier 2 (51-200 units) $15.50/box, Tier 3 (201+ units) $12.75/box. Temperature -20C, Vial: Tier 1 (1-100 units) $1.80/vial, Tier 2 (101-500 units) $1.50/vial, Tier 3 (501+ units) $1.20/vial.'),
    ('MSA-2024-001', 'BioPharm Corp', 3, 'Pricing Schedule Cont.', 'EXHIBIT A (continued): Liquid Nitrogen (LN2), Vial: Tier 1 (1-100 units) $4.25/vial, Tier 2 (101-500 units) $3.60/vial, Tier 3 (501+ units) $2.95/vial. Room Temperature (RT), Box: Tier 1 (1-100 units) $8.00/box, Tier 2 (101+ units) $6.50/box. Annual price escalation: CPI + 1%, maximum 4% per year. Volume commitments: Minimum monthly volume of 500 vials to maintain Tier 2+ pricing.'),
    ('MSA-2024-001', 'BioPharm Corp', 4, 'Service Level Agreement', 'EXHIBIT B: SERVICE LEVEL AGREEMENT. Temperature Monitoring: Continuous 24/7 monitoring with alerts for deviations >2C from set point. Access: Client authorized personnel may access facility Monday-Friday 8AM-6PM EST with 24-hour advance notice. Chain of Custody: Full chain of custody documentation maintained for all samples. Disaster Recovery: Backup power systems with 72-hour fuel reserve. Insurance: Provider maintains $10M general liability coverage.'),
    ('MSA-2024-003', 'GeneTech Solutions', 1, 'General Terms', 'MASTER SERVICE AGREEMENT between Azenta Life Sciences ("Provider") and GeneTech Solutions ("Client"). Effective Date: June 1, 2024. Term: 3 years through May 31, 2027. Payment Terms: Net 45 days from invoice date. Early Payment Discount: 2% discount for payment within 10 days. Auto-Renewal: Contract auto-renews for 1-year periods unless 90 days written notice.'),
    ('MSA-2024-003', 'GeneTech Solutions', 2, 'Pricing Schedule', 'EXHIBIT A: PRICING SCHEDULE. Temperature -80C, Vial: Tier 1 (1-200) $2.75, Tier 2 (201-1000) $2.25, Tier 3 (1001+) $1.85. Temperature -80C, Box: Tier 1 (1-100) $20.00, Tier 2 (101+) $17.00. LN2 Vial: Tier 1 (1-200) $4.50, Tier 2 (201+) $3.75. Temperature -20C, Vial: Tier 1 (1-200) $2.00, Tier 2 (201+) $1.60. Temperature -20C, Box: Tier 1 (1-50) $14.00, Tier 2 (51+) $11.50.'),
    ('MSA-2024-003', 'GeneTech Solutions', 3, 'Compliance', 'EXHIBIT C: REGULATORY COMPLIANCE. Provider shall maintain all necessary certifications including CAP accreditation, ISO 20387 for biobanking, and FDA 21 CFR Part 11 compliance for electronic records. Annual audits: Client may conduct one on-site audit per year at no additional cost. Additional audits at $2,500/day. Data Retention: All records maintained for minimum 10 years.'),
    ('MSA-2025-004', 'CryoMed Research', 1, 'General Terms', 'MASTER SERVICE AGREEMENT between Azenta Life Sciences ("Provider") and CryoMed Research ("Client"). Effective Date: January 1, 2025. Term: 3 years through December 31, 2027. Payment Terms: Net 30 days. Termination: Either party may terminate with 180 days written notice. Transition Assistance: Provider shall assist with sample transfer for up to 90 days post-termination at standard rates.'),
    ('MSA-2025-004', 'CryoMed Research', 2, 'Pricing Schedule', 'EXHIBIT A: PRICING SCHEDULE. Temperature -80C, Vial: Tier 1 (1-150) $2.60, Tier 2 (151-500) $2.15, Tier 3 (501+) $1.70. Temperature -80C, Rack: Tier 1 (1-20) $95.00, Tier 2 (21+) $80.00. LN2 Vial: Tier 1 (1-150) $4.10, Tier 2 (151-500) $3.45, Tier 3 (501+) $2.80. Temperature -20C, Vial: Tier 1 (1-150) $1.90, Tier 2 (151+) $1.45. RT Pallet: Tier 1 (1-10) $150.00, Tier 2 (11+) $125.00. All prices subject to annual review.'),
    ('MSA-2025-004', 'CryoMed Research', 3, 'Special Terms', 'EXHIBIT D: SPECIAL CONDITIONS. Dedicated Storage Section: Provider shall maintain a dedicated -80C storage section for Client critical samples. Priority Retrieval: 4-hour retrieval SLA for urgent requests during business hours. Sample Destruction: Written authorization from two designated Client contacts required. Quarterly Business Reviews: Provider and Client shall conduct quarterly reviews of service levels, inventory, and pricing.');

/*
  NEXT: Run 04_extraction_procedure.sql
*/
