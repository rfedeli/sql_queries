# SCC Data Dictionary PDF — Discrepancies & Probe Followups

**Source:** SoftLab data dictionary PDF (SCC SA Base 4.5.5.51.7, dated 2020-07-07).
**Caveat:** Production deployment may be on a newer SCC version. View definitions can drift between releases (column sizes, added/removed columns), so PDF discrepancies don't automatically mean our empirical findings are wrong — they may reflect deployment-specific schema.

This file tracks:
1. Field-level discrepancies between the PDF spec and existing CLAUDE.md documentation or empirical findings.
2. PDF-documented columns we haven't yet validated against the production database.
3. Views in the PDF where we have only one-line descriptions in CLAUDE.md and no probed detail.

For each item, resolution path is one of:
- **Probe and resolve** — run the SQL query, update CLAUDE.md to match observed behavior.
- **Trust PDF** — apply PDF as authoritative; update CLAUDE.md (default for type/size mismatches).
- **Trust empirical** — keep our finding; mark PDF as out-of-date for this deployment.

---

## 1. Field-level discrepancies — PDF vs. existing CLAUDE.md

### 1a. V_S_LAB_PHLEBOTOMIST — string sizes

| Column | PDF | Prior CLAUDE.md | Resolution |
|--------|-----|-----------------|------------|
| LAST_NAME | VARCHAR2 50 | VARCHAR2 51 | PDF applied |
| FIRST_NAME | VARCHAR2 80 | VARCHAR2 51 | PDF applied |
| MIDDLE_NAME | VARCHAR2 27 | VARCHAR2 31 | PDF applied |
| SSN | VARCHAR2 15 | VARCHAR2 (no size) | PDF applied |
| NOTES | VARCHAR2 51 | VARCHAR2 (no size) | PDF applied |

The FIRST_NAME 80 vs. 51 gap is the most suspicious. Probe to confirm production schema matches PDF (and that our prior 51 wasn't actually correct):

```sql
SELECT column_name, data_type, data_length, data_precision
FROM all_tab_columns
WHERE table_name = 'V_S_LAB_PHLEBOTOMIST'
ORDER BY column_id;
```

If actual `data_length` differs from PDF, restore CLAUDE.md to observed value and add a note that the deployment diverges from SCC 4.5.5.51.7 spec.

### 1b. V_S_LAB_CANNED_MESSAGE.DISCARD_CONTAINER — type

| | PDF | Prior CLAUDE.md | Resolution |
|---|-----|-----------------|------------|
| Type | NUMBER 5 | VARCHAR2 (guess) | PDF applied |

The CLAUDE.md type was inferred from column name; PDF documents it as a numeric flag. Probe:

```sql
SELECT data_type, data_length, COUNT(*) AS rows,
       COUNT(DISTINCT discard_container) AS distinct_vals,
       MIN(discard_container) AS min_val,
       MAX(discard_container) AS max_val
FROM V_S_LAB_CANNED_MESSAGE
GROUP BY data_type, data_length;  -- pseudo; cardinality of the flag
```

(The semantics — what value means "discard" vs. "keep" — remains unverified in either source.)

### 1c. V_S_LAB_DEPARTMENT.DESCRIPTION — concatenation

PDF documents `DESCRIPTION` as a virtual column concatenating four base-table fields:

```
DPTEXT1 || DPTEXT2 || DPTEXT3 || DPTEXT4
```

Each segment is VARCHAR2 59. The view also exposes them as `DESCRIPTION_LINE1` through `DESCRIPTION_LINE4`. Our prior CLAUDE.md noted DESCRIPTION but didn't document the line-level columns. **Resolution: notes added to CLAUDE.md.**

### 1d. V_S_LAB_LOCATION.DESCRIPTION — concatenation

Same pattern: `LOTEXT1 || LOTEXT2 || LOTEXT3 || LOTEXT4`. Lines exposed individually as `DESCRIPTION_LINE1`–`DESCRIPTION_LINE4`. PDF also notes `STREET2` is "not on the screen" — present in DB but invisible in the SCC client UI. **Resolution: notes added to CLAUDE.md.**

---

## 2. PDF columns we haven't probed in production

### 2a. V_S_LAB_TEST — additional columns

PDF documents ~140 columns on V_S_LAB_TEST. Our entry covers the workhorse fields. The following PDF columns are not yet in CLAUDE.md detail:

- `PRECISION_NEW` (NUMBER 10) — Precision allowing **negative values from -7 to 7**. Our entry has `PRECISION` and `PRECISION_POSITIVE` (CHAR 1) but not `PRECISION_NEW`. May be the modern version; PRECISION_POSITIVE may be the legacy (positive-only) sibling.
- `DEFAULT_SOURCE` (VARCHAR2 15) — Micro test default source.
- `OBSERVATION_METHOD` (VARCHAR2 20) — Already in CLAUDE.md.
- `NOSOCOMIAL_INF_AFTER` (NUMBER 5) — Hours after which a result is classified nosocomial.
- `IS_PRINT_LBL_PROMPT_RESULT` (VARCHAR2 1) — Print prompt-test result on labels flag.
- `HOLD_AUTOVERIFICATION` / `HOLD_AUTOVERIF` (duplicates) — Hold autoverification until received.
- `MES_TEST_COMMENT` (VARCHAR2 5) — Test comment message ID.
- Series/calculation flags: FL_CALC_NEEDS_RMOD, FL_DO_NOT_MERGE_ST_ORDERS, FL_MANUAL_MERGE_DO_NOT_MERGE.
- HL7 reportability: FL_ELR_RESULT_REPORTABLE, FL_ELR_ORDER_REPORTABLE.

Status: low priority. Not used in core query workflows; PDF documents them for reference.

### 2b. V_S_LAB_DOCTOR — assigning-authority fields

Several "Assigning Authority for X" / "Assigning Facility for X" fields per identifier slot:
- AUTHORITY_FOR_PRIMARY_ID, FACILITY_FOR_PRIMARY_ID
- AUTHORITY_FOR_SECONDARY_ID, FACILITY_FOR_SECONDARY_ID
- AUTHORITY_FOR_THIRD_ID, FACILITY_FOR_THIRD_ID
- AUTHORITY_FOR_NPI, FACILITY_FOR_NPI

Plus name-component breakdowns (NAME_PREFIX, NAME_SUFFIX, NAME_PRO_SUFFIX, NAME_AUTHORITY) and contact-comment columns (PRIMARY_PHONE_COMMENT, ALT_PHONE_COMMENT, MODEM_COMMENT, FAX_COMMENT, etc.).

Status: present in PDF as HL7/FHIR integration fields. Probe only if needed for cross-system identifier work.

### 2c. V_S_LAB_CLINIC — additional flag columns

PDF lists ~80 columns. Our entry covers ~30 workhorse fields. Additional PDF-only columns:
- Assigning-authority fields (FACILITYS_ASSIGNING_AUTHORITY, AUTHORITY_FOR_GENERATED_MRN, FACILITY_FOR_GENERATED_MRN).
- Contact-comment fields paralleling the phone/fax/modem fields.
- Many FL_* boolean flags (FL_AUTOREP, FL_LABEL_AT_OE, FL_CHART_AVAIL, FL_SKIP_BILL, etc.) most marked `DUMP4` in base-table column — bitmask packed.
- ORDERING_PRIORITY, DISCHARGED_DAYS, USER_INSTRUCTIOS (typo in PDF — INSTRUCTIONS).
- AUTO_REP_OPTION_DESC computed via `CSF_SSM_PKG.Lookup` — PDF warns this is a low-performance column; avoid in WHERE clauses.

Status: existing entry covers what we need for queries. Capture in capsule reference.

### 2d. V_S_LAB_INSURANCE — many DEPRECATED columns

PDF marks the following as `DEPRECATED` (NULL on the view, kept for 4.0.7.1 compatibility):
COPAYMENT_AMOUNT, INSURANCE_TAX_1/2/3, TAX_DATE_1/2/3, PRICE_SCHEDULE, OPTION_HEADER_NAME, REDIRECT_PRICES, MEDIGAP_NUMBER, PAYOR_CLAIM_OFFICE_ID, TYPE_OF_BILLING_ECS, BILLER_ID, PAYOR_CONTRACT, PAYOR_CLASS, PAYOR_GROUP, PAPER_CLAIMS, PAPER_FORMAT, TYPE, ELECTRONIC_BILLING, CLIENT_BILLING_FLAG, OTHER_IN_AGING, ELECTRONIC_REMITTANCE, AUTO_WRITEOFF, CAN_BILL_VENIP_AND_TRAVEL, COPAYMENT_REQUIRED, MEDIGAP_PLAN_EXISTS, VENIP_DEFAULT_IN_OE, ACCEPT_ASSIGNMENT, CHECK_TAX_CONDITIONS, FLAG_CREATE_CATEGORY_RECORDS.

Status: insurance billing logic flows through SoftAR (V_S_ARE_INSUR, V_S_ARE_PAYOR, V_S_ARE_BILLRULES). V_S_LAB_INSURANCE is a thin Lab-side view; the deprecated fields confirm AR is the billing source of truth.

### 2e. V_S_LAB_SPECIMEN — DEPRECATED columns to avoid

PDF marks the following as DEPRECATED (use the noted replacement instead):
- `CAPACITY` / `MIN_VOLUME` → use V_S_LAB_TUBE_CAPACITY.
- `VOL_COMMENT` → V_S_LAB_TUBE_CAPACITY.VOL_COMMENT.
- `CAPACITY_AA_ID`, `CAPACITIES_SORT` → internal, deprecated.
- `SPEC_TYPE`, `SPEC_TYPE_MOD`, `SPEC_ADDITIVE` → use TYPE_SOURCE, TYPE_MODIFIER, ADDITIVES_PRESERVATIVES.
- `VENIP_SPEC`, `CAPIL_SPEC`, `URINE_SPEC` → use TYPE_SOURCE (encodes specimen-type flag).
- `IS_INTERVAL_COL`, `IS_COLLECTION`, `EXTENSION` → NULL.
- `ROBOTIC`, `PARENT`, `AUX_TUBE` → NULL.
- `COMMENT_TEXT` → NULL.
- `FAKE_CONTAINER` → DEPRECATED but still indexed; semantics unclear.

Status: notes added to V_S_LAB_SPECIMEN section in CLAUDE.md to flag the workhorse vs. deprecated split.

---

## 3. V_S_SEC_USER and Security module — not in this PDF

The PDF covers SoftLab setup only. The Security module (V_S_SEC_USER, V_S_SEC_USERROLES, V_S_SEC_USERSITEROLE, V_S_SEC_USER_GROUP, V_S_SEC_GROUP_ASSIGNMENT, V_S_SEC_CONTACT_INFO, plus ~25 more) was characterized empirically via §37/§41 in `setup/test_result_history_probe.sql`. Empirical findings remain our source of truth.

### Outstanding questions for V_S_SEC_USER (probe queue)

- Full enum of values in `ROLE` column (observed: `U`, `R` in 5-row sample).
- Meaning of `ID` column negative numeric values (observed: -82, -342, -882, -1323, -1223). Is this a sign-flipped sequence, a tier marker, or something else?
- `SCC_USER` flag — does it distinguish SCC system accounts from user accounts? (Observed empty in 5-row sample.)
- Coverage: how many MOD_TECH values from V_P_LAB_TEST_RESULT_HISTORY in the last 90 days actually join cleanly to V_S_SEC_USER? (§42 in probe file is the existing query.)
- `EMERGENCY_ACCESS` / `EMERGENCY_ROLE` / `FUTURE_ACTIVATE_DATE` / `FUTURE_DEACTIVATE_DATE` — when are these populated?

### V_S_SEC_USERROLES — for role-based filtering

Documented one-line in CLAUDE.md, characterized empirically as containing user-to-role assignments. Probe needed to:
- Get column list (USER_ID, ROLE_ID columns plus metadata).
- Confirm join keys for filtering MOD_TECH amenders by role (Lab Tech vs. Pathologist vs. Sysadmin).

### V_S_SEC_CONTACT_INFO — name fields

Possibly redundant with V_S_SEC_USER's LASTNAME/FIRSTNAME/MIDDLENAME (which are present per §37). Probe to confirm whether CONTACT_INFO carries different/extended demographic fields.

### V_S_SEC_GROUP_ROLES_MAPPING — group→role mapping

Useful for understanding the security model. Probe column list.

**Resolution path for the Security module:** request SCC's Security-module data dictionary PDF separately, or fully characterize via probes if the dictionary isn't available.

---

## 4. Views in the PDF without detailed CLAUDE.md entries

Captured in CLAUDE.md "PDF Capsule Reference — Views in Dictionary, Not Yet Probed" section as 1–3 line capsules with PK, key columns, FK links, and deprecation flags. Promote to full detail entries only when first used in a query. Section covers SoftLab setup, SoftMic patient/setup, and SoftBank patient/setup.

Highest priority for full documentation if used in queries:
- **V_S_LAB_TEST_RANGE** — sex/age/clinic-specific result reference ranges.
- **V_S_LAB_TEST_VALUE** — predefined result values + reflex test triggers.
- **V_S_LAB_TEST_FORMULARY** — ref-lab specific test info, mnemonics, hospital charge.
- **V_S_LAB_TEST_HIS** — HIS test mapping (matters for Epic order interpretation).
- **V_S_LAB_INSURANCE** — Lab-side insurance setup (note: AR is the source of truth).
- **V_S_LAB_DIAGNOSIS** — diagnosis/ICD setup.
- **V_S_LAB_MEDICAL_SERVICE** — medical service codes.
- **V_S_LAB_KEYPAD** — keypad codes (used by tests).
- **V_S_LAB_DOCTORS_GROUP** — doctor groups (used by RBS).
- **V_S_LAB_RBSRRULE** — Rules-Based System rules.
- **V_S_LAB_RV_RBS_RULE / RV_RBS_COND / RV_RBS_ACTION** — Receipt&Verify RBS rule chain.
- **V_S_LAB_TEMPLATE / TEMPLATE_ITEM / TEMPLATE_GROUP** — worksheet templates.

---

## 6. SoftMic-specific PDF findings

### 6a. V_P_MIC_ACTIVE_ORDER — many DEPRECATED columns + computed status

PDF documents `V_P_MIC_ACTIVE_ORDER` as the canonical "active micro orders" view with:
- **Cross-module FK**: `ACTIVE_AA_ID` → `V_P_LAB_ORDER.AA_ID`. This is the link from the micro view back to the central SoftLab order.
- **Computed columns**: `ORDER_STATUS` and `TEST_STATUS` are CASE expressions over base-table flag columns — **not stored** — so don't filter on them with index expectations. The PDF shows them computed at view-definition time.
- **DEPRECATED date columns**: many `*_DATE` and `*_TIME` numeric pairs are marked deprecated; use the canonical `*_DT` Oracle DATE columns.
- **DEPRECATED short flag aliases**: many short-form flags (e.g., `CALLED`, `POSTED`) are deprecated in favor of the longer `*_FLAG` form.

Status: probe needed before authoring queries. Fully document column list in a future expansion.

### 6b. V_P_MIC_PATHREVIEW — PATHOLOGIST_ID ≠ TECH_ID

PDF distinguishes `PATHOLOGIST_ID` (signing pathologist for the review) from `TECH_ID` (tech who performed/recorded the review). Don't conflate the two when building "who reviewed" reports — the path-review chain is two-tier (tech does workup, pathologist signs), parallel to V_P_BB_Result's three-tier review.

### 6c. V_S_MIC_ORGANISM single-letter classification flags — confirmed

PDF confirms the empirical observation in CLAUDE.md V_S_MIC_ORGANISM section:
- `Q_VIRUS`, `R_FUNGI` — domain flags (virus / fungus)
- `A_GRAMPOS`, `B_GRAMNEG`, `C_GRAMVAR` — Gram stain
- `N_COCUS`, `O_BACILLUS` — morphology (coccus / bacillus)

These single-letter flag names are not query-friendly but they're authoritative. Yeast (Candida etc.) routes through `R_FUNGI`. Existing CLAUDE.md notes are correct.

### 6d. SoftMic comment views family — fanout pattern

The micro module has SEVEN comment views, each scoped to a different parent entity:

| View | Parent FK | Scope |
|------|-----------|-------|
| V_P_MIC_COMM | ORDER | Order-level (general) |
| V_P_MIC_ORDER_COMM | ORDER | Order-level (categorized) |
| V_P_MIC_TESTCOMM | TEST | Test-level |
| V_P_MIC_ISOCOMM | ISOLATE | Isolate-level |
| V_P_MIC_MEDIACOMM | MEDIA | Media-plate-level |
| V_P_MIC_COMMON_MEDIACOMM | (no FK) | Reusable common library — referenced by ID from MEDIACOMM |
| V_P_MIC_THERAPYCOMM | SENSI | Drug-therapy comments per sensitivity |

For "all comments on a micro order" you need to UNION all of these (parallel to V_P_LAB_INTERNAL_NOTE in SoftLab, but split across many views instead of one multi-FK view). Probe in production to confirm exact column shapes before writing such a query.

---

## 5. Confirmed-already (no action needed)

These PDF claims match what we already had documented or validated empirically:
- V_S_LAB_TEST.CPT_BASIC_CODE_1–8 — "Not used, added for compatibility with 4.0.7.1." (PDF) ↔ "NOT populated; use V_S_ARE_BILLRULES.BRCPTCODE" (CLAUDE.md). Matches.
- V_S_LAB_DOC_AUTHORIZATION — "Deprecated. Does not exist." (PDF) ↔ "Deprecated — does not exist" (CLAUDE.md).
- V_S_LAB_LOCATION.SENDING_FACITILY — misspelling preserved in PDF and CLAUDE.md.
- V_S_LAB_PHLEBOTOMIST.NURSE flag (Y/N), ACTIVE flag (Y/N) — both confirmed.
- V_S_LAB_LOCATION.SITE column — confirmed by both as physical-location/security-site code.
- V_S_LAB_CANNED_MESSAGE.HLSYS_MESSAGE base table — confirmed cross-module SCC system table.
- V_S_LAB_TEST_GROUP.SERIES_LEVEL — confirmed.
