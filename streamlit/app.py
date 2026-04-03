# MSA Contract Extraction App
# Streamlit in Snowflake — runs natively inside Snowflake, no external deployment needed
# Uses get_active_session() for all queries

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# ─────────────────────────────────────────────────────────────
# CONFIGURE: match your deployment schema
# ─────────────────────────────────────────────────────────────
DB_NAME     = "SI"
SCHEMA_NAME = "PUBLIC"
PRICING_TABLE = f"{DB_NAME}.{SCHEMA_NAME}.SRS_CONTRACT_CUSTOMER_PRICING_ALL_CURR_DATA_TEST"
MGMT_TABLE    = f"{DB_NAME}.{SCHEMA_NAME}.SRS_CONTRACT_CUSTOMER_SAMPLE_MGMT_PRICING_TEST"
VALIDATION_PRICING_VIEW = "SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_PRICING"
VALIDATION_MGMT_VIEW    = "SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_MGMT"
VALIDATION_SUMMARY_VIEW = "SRS_AI_CONTRACTS.ANALYTICS.EXTRACTION_VALIDATION_SUMMARY"
PARSE_CACHE             = "SRS_AI_CONTRACTS.RAW_DATA.PARSED_CONTRACTS_TEXT"
PROC_A = "SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_A"
PROC_B = "SRS_AI_CONTRACTS.RAW_DATA.EXTRACT_PIPELINE_B"

ALLOWED_MODELS = [
    "mistral-large2",
    "llama3.3-70b",
    "claude-4-sonnet",
    "llama4-maverick",
]

AZENTA_BLUE   = "#11567F"
AZENTA_LIGHT  = "#29B5E8"

st.set_page_config(
    page_title="MSA Extraction Pipeline",
    page_icon="🧬",
    layout="wide",
)

# Header
st.markdown(
    f"""
    <div style='background:{AZENTA_BLUE};padding:16px 24px;border-radius:8px;margin-bottom:16px'>
        <h2 style='color:white;margin:0'>🧬 MSA Contract Extraction Pipeline</h2>
        <p style='color:#aad4ea;margin:4px 0 0 0'>AI_PARSE_DOCUMENT → AI_EXTRACT & AI_COMPLETE | Azenta SRS Demo</p>
    </div>
    """,
    unsafe_allow_html=True,
)

session = get_active_session()


def run_query(sql: str) -> pd.DataFrame:
    try:
        return session.sql(sql).to_pandas()
    except Exception as e:
        st.error(f"Query error: {e}")
        return pd.DataFrame()


def call_proc(sql: str) -> str:
    try:
        result = session.sql(sql).collect()
        return result[0][0] if result else "No result returned"
    except Exception as e:
        return f"ERROR: {e}"


# ─────────────────────────────────────────────────────────────
# TABS
# ─────────────────────────────────────────────────────────────
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "▶ Run Pipeline",
    "📦 Storage Pricing",
    "💼 Management Fees",
    "⚖️ A vs B Comparison",
    "✅ Validation",
])


# ══════════════════════════════════════════
# TAB 1: Run Pipeline
# ══════════════════════════════════════════
with tab1:
    st.subheader("Run Extraction Pipeline")

    # Get available PDFs from stage
    stage_df = run_query(
        "SELECT RELATIVE_PATH FROM DIRECTORY(@SRS_AI_CONTRACTS.RAW_DATA.CONTRACT_STAGE) "
        "WHERE RELATIVE_PATH LIKE '%.pdf' ORDER BY LAST_MODIFIED DESC"
    )
    pdf_options = stage_df["RELATIVE_PATH"].tolist() if not stage_df.empty else [
        "BMS - MSA AMD 3 06Jan2026 FE.pdf", "Sanofi_MSA.pdf"
    ]

    col1, col2 = st.columns(2)
    with col1:
        selected_file = st.selectbox("PDF File (from stage)", pdf_options)
        customer_id = st.text_input("Customer ID", value="BMS" if "BMS" in selected_file else "SANOFI")

    with col2:
        pipeline = st.radio("Pipeline", ["A — AI_EXTRACT (schema-based)", "B — AI_COMPLETE (prompt-based)"])
        if "B" in pipeline:
            selected_model = st.selectbox(
                "Model",
                ALLOWED_MODELS,
                help="snowflake-arctic is excluded — its 4,096 token context window is too small for dense pricing tables.",
            )
        else:
            selected_model = None

    st.divider()

    # Parse cache status
    cache_df = run_query(
        f"SELECT FILENAME, COUNT(*) AS PAGES_CACHED FROM {PARSE_CACHE} "
        f"WHERE FILENAME = '{selected_file}' GROUP BY 1"
    )
    if not cache_df.empty:
        st.success(f"Parse cache: {int(cache_df['PAGES_CACHED'].iloc[0])} pages already cached for this file — no re-parsing cost.")
    else:
        st.info("This file has not been parsed yet. Pipeline will call AI_PARSE_DOCUMENT.")

    if st.button("🚀 Run Pipeline", type="primary"):
        with st.spinner("Running extraction (this may take 30–90 seconds)..."):
            if "A" in pipeline:
                sql = f"CALL {PROC_A}('{selected_file}', '{customer_id}')"
            else:
                sql = f"CALL {PROC_B}('{selected_file}', '{customer_id}', '{selected_model}')"
            result = call_proc(sql)
        if "FAILED" in result or "ERROR" in result:
            st.error(result)
        else:
            st.success(result)

    st.divider()
    st.caption("**Architecture**: PDF → AI_PARSE_DOCUMENT (LAYOUT, page_split=TRUE) → per-page cache → "
               "Pipeline A: AI_EXTRACT with schema | Pipeline B: AI_COMPLETE with JSON prompt")


# ══════════════════════════════════════════
# TAB 2: Storage Pricing
# ══════════════════════════════════════════
with tab2:
    st.subheader("Extracted Storage Pricing")

    col1, col2, col3, col4 = st.columns(4)
    with col1:
        cust_filter = st.selectbox("Customer", ["All", "BMS", "SANOFI"], key="sp_cust")
    with col2:
        method_df = run_query(f"SELECT DISTINCT EXTRACTION_METHOD FROM {PRICING_TABLE} ORDER BY 1")
        methods = ["All"] + method_df["EXTRACTION_METHOD"].tolist() if not method_df.empty else ["All"]
        method_filter = st.selectbox("Extraction Method", methods, key="sp_method")
    with col3:
        temp_df = run_query(f"SELECT DISTINCT TEMPERATURE FROM {PRICING_TABLE} ORDER BY 1")
        temps = ["All"] + temp_df["TEMPERATURE"].tolist() if not temp_df.empty else ["All"]
        temp_filter = st.selectbox("Temperature", temps, key="sp_temp")
    with col4:
        region_df = run_query(f"SELECT DISTINCT REGION FROM {PRICING_TABLE} ORDER BY 1")
        regions = ["All"] + region_df["REGION"].tolist() if not region_df.empty else ["All"]
        region_filter = st.selectbox("Region", regions, key="sp_region")

    where_clauses = []
    if cust_filter != "All":
        where_clauses.append(f"CUSTOMER_ID = '{cust_filter}'")
    if method_filter != "All":
        where_clauses.append(f"EXTRACTION_METHOD = '{method_filter}'")
    if temp_filter != "All":
        where_clauses.append(f"TEMPERATURE = '{temp_filter}'")
    if region_filter != "All":
        where_clauses.append(f"REGION = '{region_filter}'")

    where_sql = ("WHERE " + " AND ".join(where_clauses)) if where_clauses else ""

    pricing_df = run_query(
        f"SELECT CUSTOMER_ID, FILENAME, TEMPERATURE, SAMPLE_SIZE, QUANTITY_TIER, "
        f"REGION, CURRENCY, PRICE, MIN_QUANTITY_TIER, MAX_QUANTITY_TIER, "
        f"MIN_SAMPLE_SIZE, MAX_SAMPLE_SIZE, CUBIC_FOOT_MAX, EXTRACTION_METHOD "
        f"FROM {PRICING_TABLE} {where_sql} "
        f"ORDER BY CUSTOMER_ID, TEMPERATURE, SAMPLE_SIZE, MIN_QUANTITY_TIER LIMIT 500"
    )

    st.metric("Rows shown", len(pricing_df))
    if not pricing_df.empty:
        st.dataframe(pricing_df, use_container_width=True, height=450)

        csv = pricing_df.to_csv(index=False)
        st.download_button("Download CSV", csv, "storage_pricing.csv", "text/csv")
    else:
        st.info("No data found. Run Pipeline A or B first.")


# ══════════════════════════════════════════
# TAB 3: Management Fees
# ══════════════════════════════════════════
with tab3:
    st.subheader("Extracted Management Fees")

    col1, col2, col3 = st.columns(3)
    with col1:
        cust_m = st.selectbox("Customer", ["All", "BMS", "SANOFI"], key="mf_cust")
    with col2:
        method_m_df = run_query(f"SELECT DISTINCT EXTRACTION_METHOD FROM {MGMT_TABLE} ORDER BY 1")
        methods_m = ["All"] + method_m_df["EXTRACTION_METHOD"].tolist() if not method_m_df.empty else ["All"]
        method_m = st.selectbox("Extraction Method", methods_m, key="mf_method")
    with col3:
        cat_df = run_query(f"SELECT DISTINCT FEE_CATEGORY FROM {MGMT_TABLE} ORDER BY 1")
        cats = ["All"] + cat_df["FEE_CATEGORY"].tolist() if not cat_df.empty else ["All"]
        cat_filter = st.selectbox("Fee Category", cats, key="mf_cat")

    where_m = []
    if cust_m != "All":
        where_m.append(f"CUSTOMER_ID = '{cust_m}'")
    if method_m != "All":
        where_m.append(f"EXTRACTION_METHOD = '{method_m}'")
    if cat_filter != "All":
        where_m.append(f"FEE_CATEGORY = '{cat_filter}'")
    where_m_sql = ("WHERE " + " AND ".join(where_m)) if where_m else ""

    mgmt_df = run_query(
        f"SELECT CUSTOMER_ID, FEE_CATEGORY, FEE_NAME, CURRENCY, PRICE, UNIT, "
        f"LEFT(DESCRIPTION, 120) AS DESCRIPTION, EXTRACTION_METHOD "
        f"FROM {MGMT_TABLE} {where_m_sql} "
        f"ORDER BY CUSTOMER_ID, FEE_CATEGORY, FEE_NAME LIMIT 500"
    )

    st.metric("Rows shown", len(mgmt_df))
    if not mgmt_df.empty:
        st.dataframe(mgmt_df, use_container_width=True, height=450)
        csv_m = mgmt_df.to_csv(index=False)
        st.download_button("Download CSV", csv_m, "management_fees.csv", "text/csv")
    else:
        st.info("No data found. Run Pipeline A or B first.")


# ══════════════════════════════════════════
# TAB 4: Pipeline A vs B Comparison
# ══════════════════════════════════════════
with tab4:
    st.subheader("Pipeline A vs B — Side-by-Side Comparison")

    col1, col2, col3 = st.columns(3)
    with col1:
        cust_c = st.selectbox("Customer", ["BMS", "SANOFI"], key="cmp_cust")
    with col2:
        table_c = st.selectbox("Table", ["Storage Pricing", "Management Fees"], key="cmp_table")
    with col3:
        model_c = st.selectbox("Pipeline B model to compare", ALLOWED_MODELS, key="cmp_model")

    method_b = f"AI_PARSE+AI_COMPLETE_{model_c}"

    if table_c == "Storage Pricing":
        comp_df = run_query(f"""
            SELECT
                a.TEMPERATURE, a.SAMPLE_SIZE, a.QUANTITY_TIER, a.REGION,
                a.PRICE  AS PRICE_PIPELINE_A,
                b.PRICE  AS PRICE_PIPELINE_B,
                CASE
                    WHEN b.PRICE IS NULL        THEN '⚪ B missing'
                    WHEN a.PRICE = b.PRICE      THEN '✅ Match'
                    ELSE '🔴 Diff'
                END AS STATUS
            FROM {PRICING_TABLE} a
            LEFT JOIN {PRICING_TABLE} b
                ON  a.CUSTOMER_ID   = b.CUSTOMER_ID
                AND a.TEMPERATURE   = b.TEMPERATURE
                AND a.SAMPLE_SIZE   = b.SAMPLE_SIZE
                AND a.QUANTITY_TIER = b.QUANTITY_TIER
                AND a.REGION        = b.REGION
                AND b.EXTRACTION_METHOD = '{method_b}'
            WHERE a.CUSTOMER_ID = '{cust_c}'
              AND a.EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT'
            ORDER BY a.TEMPERATURE, a.SAMPLE_SIZE, a.MIN_QUANTITY_TIER
            LIMIT 500
        """)
    else:
        comp_df = run_query(f"""
            SELECT
                a.FEE_CATEGORY, a.FEE_NAME,
                a.PRICE  AS PRICE_PIPELINE_A,
                b.PRICE  AS PRICE_PIPELINE_B,
                CASE
                    WHEN b.PRICE IS NULL    THEN '⚪ B missing'
                    WHEN a.PRICE = b.PRICE  THEN '✅ Match'
                    ELSE '🔴 Diff'
                END AS STATUS
            FROM {MGMT_TABLE} a
            LEFT JOIN {MGMT_TABLE} b
                ON  a.CUSTOMER_ID  = b.CUSTOMER_ID
                AND a.FEE_CATEGORY = b.FEE_CATEGORY
                AND a.FEE_NAME     = b.FEE_NAME
                AND b.EXTRACTION_METHOD = '{method_b}'
            WHERE a.CUSTOMER_ID = '{cust_c}'
              AND a.EXTRACTION_METHOD = 'AI_PARSE+AI_EXTRACT'
            ORDER BY a.FEE_CATEGORY, a.FEE_NAME
            LIMIT 500
        """)

    if not comp_df.empty:
        total     = len(comp_df)
        matched   = int((comp_df["STATUS"] == "✅ Match").sum())
        diffed    = int((comp_df["STATUS"] == "🔴 Diff").sum())
        missing_b = int((comp_df["STATUS"] == "⚪ B missing").sum())

        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Total rows (A)", total)
        m2.metric("Match", matched, delta=f"{100*matched//total if total else 0}%")
        m3.metric("Diff", diffed)
        m4.metric("B missing", missing_b)

        def highlight_status(val):
            if val == "🔴 Diff":
                return "background-color: #ffd6d6"
            if val == "⚪ B missing":
                return "background-color: #fff3cd"
            return ""

        styled = comp_df.style.applymap(highlight_status, subset=["STATUS"])
        st.dataframe(styled, use_container_width=True, height=450)
    else:
        st.info("No comparison data found. Run both Pipeline A and Pipeline B for the same customer first.")


# ══════════════════════════════════════════
# TAB 5: Validation
# ══════════════════════════════════════════
with tab5:
    st.subheader("Validation vs Ground Truth")

    st.caption(
        "Compares extracted values against the SI.PUBLIC validation tables. "
        "If validation tables are not yet populated, EXPECTED_PRICE will be NULL "
        "and all rows will show NO_EXPECTED."
    )

    # Summary metrics
    summary_df = run_query(
        f"SELECT * FROM {VALIDATION_SUMMARY_VIEW} ORDER BY CUSTOMER_ID, TABLE_TYPE, EXTRACTION_METHOD"
    )

    if not summary_df.empty:
        for _, row in summary_df.iterrows():
            rate = row.get("MATCH_RATE_PCT", 0) or 0
            color = "#2ecc71" if rate >= 90 else "#f39c12" if rate >= 70 else "#e74c3c"
            st.markdown(
                f"<div style='border-left:4px solid {color};padding:6px 12px;margin:4px 0;"
                f"background:#f8f9fa;border-radius:4px'>"
                f"<b>{row['CUSTOMER_ID']}</b> | {row['TABLE_TYPE']} | "
                f"{row['EXTRACTION_METHOD']} — "
                f"<span style='color:{color};font-weight:bold'>{rate}% match</span> "
                f"({row['MATCHED_ROWS']}/{row['TOTAL_ROWS'] - row.get('NO_EXPECTED_ROWS',0)} rows with expected)</div>",
                unsafe_allow_html=True,
            )

        st.divider()
        st.dataframe(summary_df, use_container_width=True)
    else:
        st.info("No validation data yet. Ensure validation views exist and at least one pipeline has run.")

    st.divider()
    st.subheader("Row-Level Mismatches")

    v_col1, v_col2, v_col3 = st.columns(3)
    with v_col1:
        v_table = st.selectbox("Table", ["Storage Pricing", "Management Fees"], key="val_table")
    with v_col2:
        v_cust = st.selectbox("Customer", ["All", "BMS", "SANOFI"], key="val_cust")
    with v_col3:
        v_status = st.selectbox("Status filter", ["MISMATCH", "All except NO_EXPECTED", "All"], key="val_status")

    view = VALIDATION_PRICING_VIEW if v_table == "Storage Pricing" else VALIDATION_MGMT_VIEW

    v_where = []
    if v_cust != "All":
        v_where.append(f"CUSTOMER_ID = '{v_cust}'")
    if v_status == "MISMATCH":
        v_where.append("MATCH_STATUS = 'MISMATCH'")
    elif v_status == "All except NO_EXPECTED":
        v_where.append("MATCH_STATUS != 'NO_EXPECTED'")
    v_where_sql = ("WHERE " + " AND ".join(v_where)) if v_where else ""

    mismatch_df = run_query(
        f"SELECT * FROM {view} {v_where_sql} ORDER BY MATCH_STATUS, CUSTOMER_ID LIMIT 200"
    )

    if not mismatch_df.empty:
        st.dataframe(mismatch_df, use_container_width=True, height=400)
    else:
        st.info("No rows match the current filters.")
