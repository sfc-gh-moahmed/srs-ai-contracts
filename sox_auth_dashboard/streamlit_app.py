"""
SOX Authentication Evidence Dashboard
Aledade — Snowflake Account Authentication Controls
Runs as Streamlit in Snowflake (SiS).
"""
import streamlit as st
import pandas as pd
from datetime import datetime

# ─── Page Config ──────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="SOX Auth Evidence",
    layout="wide",
    initial_sidebar_state="collapsed",
)

st.markdown("""
<style>
[data-testid="stMetricDelta"] svg { display: none; }
</style>
""", unsafe_allow_html=True)

# ─── Snowflake Session ────────────────────────────────────────────────────────
@st.cache_resource
def get_session():
    """Returns a Snowpark session — works in SiS and local dev."""
    try:
        from snowflake.snowpark.context import get_active_session
        return get_active_session()
    except Exception:
        conn = st.connection("snowflake")
        return conn.session()


def run_sql(sql: str) -> pd.DataFrame:
    """Execute SQL and return a pandas DataFrame."""
    return get_session().sql(sql).to_pandas()


# ─── Data Loaders (all cached 5 min) ─────────────────────────────────────────
@st.cache_data(ttl=300)
def load_users() -> pd.DataFrame:
    return run_sql("""
        SELECT
            NAME,
            LOGIN_NAME,
            COALESCE(EMAIL, '')            AS EMAIL,
            COALESCE(TYPE, 'PERSON')       AS TYPE,
            HAS_PASSWORD,
            HAS_RSA_PUBLIC_KEY,
            EXT_AUTHN_DUO,
            COALESCE(DEFAULT_ROLE, '')     AS DEFAULT_ROLE,
            CREATED_ON,
            LAST_SUCCESS_LOGIN
        FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
        WHERE DELETED_ON IS NULL
          AND DISABLED = 'false'
        ORDER BY NAME
    """)


@st.cache_data(ttl=300)
def load_integrations() -> pd.DataFrame:
    return get_session().sql("SHOW INTEGRATIONS").to_pandas()


@st.cache_data(ttl=300)
def load_password_params() -> pd.DataFrame:
    return get_session().sql("SHOW PARAMETERS LIKE 'PASSWORD%' IN ACCOUNT").to_pandas()


@st.cache_data(ttl=300)
def load_password_policies() -> pd.DataFrame:
    try:
        return get_session().sql("SHOW PASSWORD POLICIES").to_pandas()
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=300)
def load_policy_references() -> pd.DataFrame:
    return run_sql("""
        SELECT
            POLICY_NAME,
            POLICY_KIND,
            REF_DATABASE_NAME,
            REF_SCHEMA_NAME,
            REF_ENTITY_NAME,
            REF_ENTITY_DOMAIN
        FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
        WHERE POLICY_KIND = 'PASSWORD_POLICY'
        ORDER BY POLICY_NAME
    """)


@st.cache_data(ttl=300)
def load_mfa_login_history() -> pd.DataFrame:
    return run_sql("""
        SELECT
            USER_NAME,
            COALESCE(SECOND_AUTHENTICATION_FACTOR, 'None') AS SECOND_FACTOR,
            COUNT(*)                                        AS LOGIN_COUNT,
            MAX(EVENT_TIMESTAMP)                            AS LAST_LOGIN
        FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
        WHERE EVENT_TIMESTAMP >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
          AND IS_SUCCESS = 'YES'
        GROUP BY USER_NAME, SECOND_AUTHENTICATION_FACTOR
        ORDER BY USER_NAME
    """)


@st.cache_data(ttl=300)
def load_privileged_grants() -> pd.DataFrame:
    return run_sql("""
        SELECT
            GRANTEE_NAME,
            ROLE,
            GRANTED_BY,
            CREATED_ON
        FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
        WHERE ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN')
          AND DELETED_ON IS NULL
        ORDER BY GRANTEE_NAME, ROLE
    """)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def pct(numerator: int, denominator: int) -> float:
    return round(numerator / denominator * 100, 1) if denominator > 0 else 0.0


def csv_btn(df: pd.DataFrame, label: str, filename: str) -> None:
    st.download_button(
        label=f"Download {label} (CSV)",
        data=df.to_csv(index=False).encode("utf-8"),
        file_name=filename,
        mime="text/csv",
    )


def color_bool(val):
    """Styler: green for True, red for False."""
    if val is True:
        return "background-color:#00d4aa22;color:#00d4aa;font-weight:bold"
    if val is False:
        return "background-color:#ff4b4b22;color:#ff4b4b;font-weight:bold"
    return ""


def color_status(val):
    """Styler for PASS / WARN / FAIL strings."""
    mapping = {
        "PASS": "background-color:#00d4aa22;color:#00d4aa;font-weight:bold",
        "WARN": "background-color:#ffa50022;color:#ffa500;font-weight:bold",
        "FAIL": "background-color:#ff4b4b22;color:#ff4b4b;font-weight:bold",
    }
    return mapping.get(str(val).upper(), "")


# ─── Load All Data ────────────────────────────────────────────────────────────
with st.spinner("Loading authentication data from SNOWFLAKE.ACCOUNT_USAGE…"):
    users_df       = load_users()
    integrations_df = load_integrations()
    pw_params_df   = load_password_params()
    pw_policies_df = load_password_policies()
    policy_refs_df = load_policy_references()
    mfa_history_df = load_mfa_login_history()
    priv_grants_df = load_privileged_grants()

# ─── Derived Datasets ─────────────────────────────────────────────────────────
human_df   = users_df[users_df["TYPE"].isin(["PERSON", ""])].copy()
service_df = users_df[users_df["TYPE"].isin(["SERVICE", "LEGACY_SERVICE"])].copy()

# SSO integrations
sso_integ = pd.DataFrame()
if not integrations_df.empty and "type" in integrations_df.columns:
    sso_integ = integrations_df[
        integrations_df["type"].str.upper().isin(["SAML2", "OAUTH"])
    ]
sso_configured = len(sso_integ) > 0

# SSO compliance: human user is compliant when HAS_PASSWORD = False (forced SSO)
human_df["SSO_COMPLIANT"] = human_df["HAS_PASSWORD"] == False
sso_n        = int(human_df["SSO_COMPLIANT"].sum())
sso_pct      = pct(sso_n, len(human_df))

# MFA compliance: Duo enrolled
human_df["MFA_ENROLLED"] = human_df["EXT_AUTHN_DUO"] == True
mfa_n        = int(human_df["MFA_ENROLLED"].sum())
mfa_pct      = pct(mfa_n, len(human_df))

# Password policy: any named policy exists / is attached
pw_policy_ok = not pw_policies_df.empty or not policy_refs_df.empty

# Glass break: privileged accounts lacking controls
priv_set = (
    set(priv_grants_df["GRANTEE_NAME"].str.upper())
    if not priv_grants_df.empty else set()
)
service_df["IS_PRIVILEGED"] = service_df["NAME"].str.upper().isin(priv_set)
human_df["IS_PRIVILEGED"]   = human_df["NAME"].str.upper().isin(priv_set)

flagged_svc   = service_df[service_df["IS_PRIVILEGED"]].copy()
flagged_svc["GLASS_BREAK_REASON"] = "Service account with elevated role (no MFA by default)"

flagged_human = human_df[
    human_df["IS_PRIVILEGED"] & ~human_df["MFA_ENROLLED"]
].copy()
flagged_human["GLASS_BREAK_REASON"] = "Human admin without Duo MFA enrolled"

glass_break_df = pd.concat(
    [flagged_svc, flagged_human], ignore_index=True
)
n_glass = len(glass_break_df)

# ─── Page Header ──────────────────────────────────────────────────────────────
st.title("SOX Authentication Evidence Dashboard")
st.caption(
    f"Aledade — Snowflake Account  |  "
    f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}  |  "
    "Data sourced from SNOWFLAKE.ACCOUNT_USAGE (up to 2-hour latency)"
)
st.divider()

# ─── Tabs ─────────────────────────────────────────────────────────────────────
tab_ov, tab_sso, tab_mfa, tab_pw, tab_gb = st.tabs([
    "Overview",
    "SSO Coverage",
    "MFA Coverage",
    "Password Policy",
    "Glass Break Accounts",
])


# ══════════════════════════════════════════════════════════════════════════════
# OVERVIEW TAB
# ══════════════════════════════════════════════════════════════════════════════
with tab_ov:
    st.subheader("SOX Authentication Controls — At a Glance")

    c1, c2, c3, c4 = st.columns(4)
    with c1:
        st.metric(
            "SSO Coverage (Human)",
            f"{sso_pct}%",
            f"{sso_n} / {len(human_df)} users compliant",
        )
    with c2:
        st.metric(
            "MFA Enrollment (Duo)",
            f"{mfa_pct}%",
            f"{mfa_n} / {len(human_df)} users enrolled",
        )
    with c3:
        st.metric(
            "Password Policy",
            "PASS" if pw_policy_ok else "FAIL",
            "Named policy found" if pw_policy_ok else "No named policy attached",
        )
    with c4:
        st.metric(
            "Glass Break Accounts",
            n_glass,
            "Flagged for review" if n_glass > 0 else "None flagged",
        )

    st.divider()
    st.subheader("Control Summary")

    def _status(sso_ok, sso_pct_v, mfa_ok, mfa_pct_v, pw_ok, n_gb):
        rows = [
            {
                "Control ID": "AUTH-01",
                "Control": "SSO integration configured",
                "Status": "PASS" if sso_ok else "FAIL",
                "Finding": (
                    f"{len(sso_integ)} SAML2/OAuth integration(s) active"
                    if sso_ok else "No SSO integrations found"
                ),
            },
            {
                "Control ID": "AUTH-02",
                "Control": "Human users — password disabled (forced SSO)",
                "Status": (
                    "PASS" if sso_pct_v == 100
                    else "WARN" if sso_pct_v >= 90
                    else "FAIL"
                ),
                "Finding": f"{sso_n}/{len(human_df)} human users have no local password",
            },
            {
                "Control ID": "AUTH-03",
                "Control": "MFA (Duo) enrolled for all human users",
                "Status": (
                    "PASS" if mfa_pct_v >= 95
                    else "WARN" if mfa_pct_v >= 70
                    else "FAIL"
                ),
                "Finding": f"{mfa_n}/{len(human_df)} human users enrolled in Duo MFA",
            },
            {
                "Control ID": "AUTH-04",
                "Control": "Named password policy attached to account",
                "Status": "PASS" if pw_ok else "FAIL",
                "Finding": (
                    f"{len(policy_refs_df)} policy attachment(s) found"
                    if pw_ok else "No password policy attached — account uses Snowflake defaults"
                ),
            },
            {
                "Control ID": "AUTH-05",
                "Control": "Privileged accounts have appropriate controls",
                "Status": "PASS" if n_gb == 0 else "FAIL",
                "Finding": (
                    f"{n_gb} account(s) with elevated roles lack MFA or key-pair auth"
                    if n_gb > 0 else "All privileged accounts have controls in place"
                ),
            },
        ]
        return pd.DataFrame(rows)

    summary_df = _status(
        sso_configured, sso_pct, mfa_n, mfa_pct, pw_policy_ok, n_glass
    )
    styled_summary = summary_df.style.map(color_status, subset=["Status"])
    st.dataframe(styled_summary, use_container_width=True, hide_index=True)
    csv_btn(summary_df, "Control Summary", "sox_control_summary.csv")


# ══════════════════════════════════════════════════════════════════════════════
# SSO TAB
# ══════════════════════════════════════════════════════════════════════════════
with tab_sso:
    st.subheader("Single Sign-On (SSO) Coverage")

    # SSO integrations block
    st.markdown("#### SSO Integrations")
    if sso_configured:
        st.success(
            f"{len(sso_integ)} SSO integration(s) active (SAML2 / OAuth). "
            "Human users are redirected through the identity provider."
        )
        st.dataframe(sso_integ, use_container_width=True, hide_index=True)
    else:
        st.error(
            "No SAML2 or OAuth integrations found. "
            "Users authenticate with local Snowflake credentials only."
        )
        if not integrations_df.empty:
            with st.expander("Show all integrations"):
                st.dataframe(integrations_df, use_container_width=True, hide_index=True)

    st.divider()

    # Per-user SSO status
    st.markdown("#### Human User SSO Compliance")
    st.caption(
        "**Compliant** = `HAS_PASSWORD = FALSE` (local password disabled; user must authenticate via IdP).  \n"
        "**Non-compliant** = `HAS_PASSWORD = TRUE` (user can bypass SSO with a local Snowflake password)."
    )

    c1, c2, c3 = st.columns(3)
    c1.metric("Total Human Users", len(human_df))
    c2.metric("Compliant (no password)", sso_n)
    c3.metric("Non-Compliant (has password)", len(human_df) - sso_n)

    sso_tbl = human_df[[
        "NAME", "LOGIN_NAME", "EMAIL", "DEFAULT_ROLE",
        "HAS_PASSWORD", "HAS_RSA_PUBLIC_KEY", "LAST_SUCCESS_LOGIN", "SSO_COMPLIANT",
    ]].rename(columns={
        "NAME": "User", "LOGIN_NAME": "Login", "EMAIL": "Email",
        "DEFAULT_ROLE": "Default Role", "HAS_PASSWORD": "Has Password",
        "HAS_RSA_PUBLIC_KEY": "Has RSA Key", "LAST_SUCCESS_LOGIN": "Last Login",
        "SSO_COMPLIANT": "SSO Compliant",
    })

    non_compliant = sso_tbl[sso_tbl["SSO Compliant"] == False]
    if not non_compliant.empty:
        st.warning(f"{len(non_compliant)} user(s) are non-compliant — local password enabled")
        with st.expander("Non-compliant users", expanded=True):
            st.dataframe(
                non_compliant.style.map(color_bool, subset=["SSO Compliant"]),
                use_container_width=True, hide_index=True,
            )

    with st.expander("All human users"):
        st.dataframe(
            sso_tbl.style.map(color_bool, subset=["SSO Compliant"]),
            use_container_width=True, hide_index=True,
        )
    csv_btn(sso_tbl, "SSO Coverage", "sox_sso_coverage.csv")


# ══════════════════════════════════════════════════════════════════════════════
# MFA TAB
# ══════════════════════════════════════════════════════════════════════════════
with tab_mfa:
    st.subheader("Multi-Factor Authentication (MFA) Coverage")

    c1, c2, c3 = st.columns(3)
    c1.metric("Total Human Users", len(human_df))
    c2.metric("Duo MFA Enrolled", mfa_n)
    c3.metric("Not Enrolled", len(human_df) - mfa_n)

    st.divider()
    st.markdown("#### MFA Method Usage — Last 90 Days")
    st.caption(
        "Sourced from `LOGIN_HISTORY.SECOND_AUTHENTICATION_FACTOR`. "
        "'None' indicates logins with no second factor."
    )
    if not mfa_history_df.empty:
        # Pivot: summarise by second factor
        factor_summary = (
            mfa_history_df.groupby("SECOND_FACTOR")["LOGIN_COUNT"]
            .sum()
            .reset_index()
            .rename(columns={"SECOND_FACTOR": "Second Factor", "LOGIN_COUNT": "Total Logins"})
            .sort_values("Total Logins", ascending=False)
        )
        st.dataframe(factor_summary, use_container_width=True, hide_index=True)

        with st.expander("Per-user login factor breakdown"):
            st.dataframe(mfa_history_df, use_container_width=True, hide_index=True)
        csv_btn(mfa_history_df, "MFA Login History", "sox_mfa_login_history.csv")
    else:
        st.info("No login history available for the last 90 days.")

    st.divider()
    st.markdown("#### Per-User Duo Enrollment Status")

    mfa_tbl = human_df[[
        "NAME", "LOGIN_NAME", "EMAIL", "DEFAULT_ROLE",
        "EXT_AUTHN_DUO", "HAS_PASSWORD", "LAST_SUCCESS_LOGIN",
    ]].rename(columns={
        "NAME": "User", "LOGIN_NAME": "Login", "EMAIL": "Email",
        "DEFAULT_ROLE": "Default Role", "EXT_AUTHN_DUO": "Duo Enrolled",
        "HAS_PASSWORD": "Has Password", "LAST_SUCCESS_LOGIN": "Last Login",
    })

    not_enrolled = mfa_tbl[mfa_tbl["Duo Enrolled"] == False]
    if not not_enrolled.empty:
        st.warning(f"{len(not_enrolled)} user(s) are NOT enrolled in Duo MFA")
        with st.expander("Users without MFA", expanded=True):
            st.dataframe(
                not_enrolled.style.map(color_bool, subset=["Duo Enrolled"]),
                use_container_width=True, hide_index=True,
            )

    with st.expander("All human users"):
        st.dataframe(
            mfa_tbl.style.map(color_bool, subset=["Duo Enrolled"]),
            use_container_width=True, hide_index=True,
        )
    csv_btn(mfa_tbl, "MFA Coverage", "sox_mfa_coverage.csv")


# ══════════════════════════════════════════════════════════════════════════════
# PASSWORD POLICY TAB
# ══════════════════════════════════════════════════════════════════════════════
with tab_pw:
    st.subheader("Password Policy")

    st.markdown("#### Account-Level Password Parameters")
    st.caption(
        "Default Snowflake account password settings "
        "(from `SHOW PARAMETERS LIKE 'PASSWORD%' IN ACCOUNT`)."
    )
    if not pw_params_df.empty:
        st.dataframe(pw_params_df, use_container_width=True, hide_index=True)
        csv_btn(pw_params_df, "Password Parameters", "sox_password_params.csv")
    else:
        st.info("Unable to retrieve password parameters — verify role has ACCOUNTADMIN privileges.")

    st.divider()
    st.markdown("#### Named Password Policies (`SHOW PASSWORD POLICIES`)")
    if not pw_policies_df.empty:
        st.success(f"{len(pw_policies_df)} named password policy(ies) found")
        st.dataframe(pw_policies_df, use_container_width=True, hide_index=True)
        csv_btn(pw_policies_df, "Password Policies", "sox_password_policies.csv")
    else:
        st.warning(
            "No named password policies found. "
            "Snowflake default password rules are in effect. "
            "For stronger SOX compliance, create and attach a `PASSWORD POLICY` to the account."
        )

    st.divider()
    st.markdown("#### Password Policy Attachments (`ACCOUNT_USAGE.POLICY_REFERENCES`)")
    if not policy_refs_df.empty:
        st.success(f"Password policy is attached to {len(policy_refs_df)} object(s)")
        st.dataframe(policy_refs_df, use_container_width=True, hide_index=True)
        csv_btn(policy_refs_df, "Policy Attachments", "sox_policy_references.csv")
    else:
        st.error(
            "No password policy attachments found. "
            "Without an account-level `PASSWORD POLICY`, minimum complexity and "
            "expiry requirements may not be enforced consistently."
        )

    st.divider()
    st.markdown("#### SOX Minimum Requirements Reference")
    st.info(
        "Minimum recommended settings for a SOX-compliant Snowflake password policy:\n\n"
        "| Parameter | Recommended Value |\n"
        "|---|---|\n"
        "| `PASSWORD_MIN_LENGTH` | 14 |\n"
        "| `PASSWORD_MIN_UPPER_CASE_CHARS` | 1 |\n"
        "| `PASSWORD_MIN_SPECIAL_CHARS` | 1 |\n"
        "| `PASSWORD_MIN_AGE_DAYS` | 1 |\n"
        "| `PASSWORD_MAX_AGE_DAYS` | 90 |\n"
        "| `PASSWORD_MAX_RETRIES` | 5 |\n"
        "| `PASSWORD_LOCKOUT_TIME_MINS` | 15 |\n"
        "| `PASSWORD_HISTORY` | 12 |\n\n"
        "Attach to your account after creation:\n"
        "```sql\n"
        "ALTER ACCOUNT SET PASSWORD POLICY <db>.<schema>.<policy_name>;\n"
        "```"
    )


# ══════════════════════════════════════════════════════════════════════════════
# GLASS BREAK ACCOUNTS TAB
# ══════════════════════════════════════════════════════════════════════════════
with tab_gb:
    st.subheader("Glass Break / Privileged Accounts")
    st.caption(
        "Glass break accounts hold elevated roles (ACCOUNTADMIN, SECURITYADMIN, SYSADMIN) "
        "and are intended for emergency or operational use only. "
        "SOX requires these accounts to be tightly controlled, logged, and regularly reviewed."
    )

    # Privileged grants overview
    st.markdown("#### Privileged Role Grants")
    st.caption("All users currently granted ACCOUNTADMIN, SECURITYADMIN, or SYSADMIN.")
    if not priv_grants_df.empty:
        priv_with_type = priv_grants_df.merge(
            users_df[["NAME", "TYPE", "EXT_AUTHN_DUO", "HAS_PASSWORD", "LAST_SUCCESS_LOGIN"]],
            left_on="GRANTEE_NAME", right_on="NAME", how="left",
        ).drop(columns=["NAME"], errors="ignore")
        st.dataframe(priv_with_type, use_container_width=True, hide_index=True)
        csv_btn(priv_with_type, "Privileged Grants", "sox_privileged_grants.csv")
    else:
        st.info("No privileged role grants found (ACCOUNTADMIN / SECURITYADMIN / SYSADMIN).")

    st.divider()

    # Service accounts
    st.markdown("#### Service Accounts")
    st.caption("Accounts with `TYPE = SERVICE` or `LEGACY_SERVICE`.")
    if not service_df.empty:
        svc_tbl = service_df[[
            "NAME", "LOGIN_NAME", "TYPE", "HAS_PASSWORD",
            "HAS_RSA_PUBLIC_KEY", "EXT_AUTHN_DUO",
            "DEFAULT_ROLE", "LAST_SUCCESS_LOGIN", "IS_PRIVILEGED",
        ]].rename(columns={
            "NAME": "User", "LOGIN_NAME": "Login", "TYPE": "Account Type",
            "HAS_PASSWORD": "Has Password", "HAS_RSA_PUBLIC_KEY": "Has RSA Key",
            "EXT_AUTHN_DUO": "Duo Enrolled", "DEFAULT_ROLE": "Default Role",
            "LAST_SUCCESS_LOGIN": "Last Login", "IS_PRIVILEGED": "Has Admin Role",
        })
        st.dataframe(
            svc_tbl.style
                .map(color_bool, subset=["Has Password", "Has RSA Key", "Duo Enrolled", "Has Admin Role"]),
            use_container_width=True, hide_index=True,
        )
        csv_btn(svc_tbl, "Service Accounts", "sox_service_accounts.csv")
    else:
        st.info("No service accounts (TYPE = SERVICE / LEGACY_SERVICE) found.")

    st.divider()

    # Flagged accounts
    st.markdown("#### Flagged Accounts — Require Immediate Review")
    if not glass_break_df.empty:
        st.error(
            f"{n_glass} account(s) flagged: elevated privileges with insufficient controls."
        )
        flag_cols = [c for c in [
            "NAME", "LOGIN_NAME", "TYPE", "HAS_PASSWORD",
            "EXT_AUTHN_DUO", "LAST_SUCCESS_LOGIN", "GLASS_BREAK_REASON",
        ] if c in glass_break_df.columns]
        flag_tbl = glass_break_df[flag_cols].rename(columns={
            "NAME": "User", "LOGIN_NAME": "Login", "TYPE": "Account Type",
            "HAS_PASSWORD": "Has Password", "EXT_AUTHN_DUO": "Duo Enrolled",
            "LAST_SUCCESS_LOGIN": "Last Login", "GLASS_BREAK_REASON": "Reason Flagged",
        })
        st.dataframe(
            flag_tbl.style.map(color_bool, subset=["Has Password", "Duo Enrolled"]),
            use_container_width=True, hide_index=True,
        )
        csv_btn(flag_tbl, "Flagged Accounts", "sox_glass_break_flagged.csv")
    else:
        st.success(
            "No accounts flagged. All users with elevated roles have appropriate controls."
        )

    st.divider()
    st.markdown("#### Recommended Controls for Glass Break Accounts")
    st.info(
        "**SOX best practices for Snowflake glass break accounts:**\n\n"
        "1. **Disable password auth** — use RSA key pair only:\n"
        "   ```sql\n   ALTER USER <name> SET RSA_PUBLIC_KEY = '<public_key>';\n   ALTER USER <name> UNSET PASSWORD;\n   ```\n"
        "2. **Store credentials in a PAM vault** (CyberArk, HashiCorp Vault, AWS Secrets Manager)\n"
        "3. **Alert on ACCOUNTADMIN usage** — set up a task to monitor `LOGIN_HISTORY` and alert on out-of-hours logins\n"
        "4. **Quarterly access review** — review all ACCOUNTADMIN / SYSADMIN grants every quarter\n"
        "5. **Break-glass SOP** — document the procedure for unlocking the account, usage logging, and post-incident review\n"
        "6. **Rotate credentials** after every use"
    )
