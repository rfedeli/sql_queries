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

**Resolved 2026-05-01**.

| Column | PDF | Prior CLAUDE.md | Probe | Real-data cap |
|--------|-----|-----------------|-------|---------------|
| LAST_NAME | VARCHAR2 50 | VARCHAR2 51 | **VARCHAR2 50** ✓ PDF | 24 chars (52% headroom) |
| FIRST_NAME | VARCHAR2 80 | VARCHAR2 51 | **VARCHAR2 80** ✓ PDF | 12 chars (85% headroom) |
| MIDDLE_NAME | VARCHAR2 27 | VARCHAR2 31 | **VARCHAR2 27** ✓ PDF | 6 chars |
| SSN | VARCHAR2 15 | VARCHAR2 (no size) | **VARCHAR2 15** ✓ PDF | NULL on all 57 rows — vestigial |
| NOTES | VARCHAR2 51 | VARCHAR2 (no size) | **VARCHAR2 51** ✓ PDF | NULL on all 57 rows — vestigial |

PDF spec confirmed exactly. CLAUDE.md updated to drop hedging language and document NOTES/SSN as vestigial.

**Bonus findings:**
- Production column order has `ZIP` before `STATE` (CLAUDE.md previously listed STATE first); table reordered to match.
- `NOTES` and `SSN` columns are NULL on all 57 rows — schema slots that aren't populated in this deployment.

### 1b. V_S_LAB_CANNED_MESSAGE.DISCARD_CONTAINER — type + cardinality

**Resolved 2026-05-01**.

| | PDF | Prior CLAUDE.md | Probe |
|---|-----|-----------------|-------|
| Type | NUMBER 5 | VARCHAR2 (guess) | **NUMBER(5,0), nullable** ✓ PDF |
| Cardinality | unknown | "100% populated; semantics unverified" | **Always 0** across 9,144/9,144 rows / 2,418/2,418 distinct message IDs |
| Within-message variance | unknown | unknown | **None** — every message ID has consistent DISCARD_CONTAINER across all its lines |

**Conclusion:** column is NUMBER(5,0) per PDF, but functionally **vestigial** in this deployment — always 0 with no exceptions. Schema slot exists, behavior implied by PDF is theoretical here. Do not filter expecting non-zero rows. CLAUDE.md updated.

(The semantics — what a non-zero value would mean — remains unverified, but academic given no rows ever carry one.)

### 1c. V_S_LAB_DEPARTMENT.DESCRIPTION — concatenation + accessor columns

**Resolved 2026-05-01**.

PDF documents `DESCRIPTION` as a virtual column concatenating four base-table fields (`DPTEXT1 || DPTEXT2 || DPTEXT3 || DPTEXT4`, each VARCHAR2 59), AND claims the view exposes them individually as `DESCRIPTION_LINE1`–`DESCRIPTION_LINE4`.

**Probe REFUTES the accessor-column claim for this deployment:**
- `ALL_TAB_COLUMNS WHERE column_name LIKE 'DESCRIPTION%'` returns only one row: `DESCRIPTION VARCHAR2(236)`.
- `SELECT DESCRIPTION_LINE4 FROM V_S_LAB_DEPARTMENT` raises `ORA-00904: invalid identifier`.

Three independent confirmations the LINE columns do not exist on the view here. The concatenation claim itself (DPTEXT1..4) is consistent with the 236-char width (4 × 59 = 236), so the underlying base-table layout matches PDF — only the accessor columns are missing.

**Workaround for line-level access:** `SUBSTR(DESCRIPTION, 1, 59)`, `SUBSTR(DESCRIPTION, 60, 59)`, etc., or query the base-table `DPTEXT*` columns directly if accessible. CLAUDE.md updated.

### 1d. V_S_LAB_LOCATION.DESCRIPTION — concatenation + accessor columns

**Resolved 2026-05-01**.

Same finding as §1c: PDF documents `LOTEXT1 || LOTEXT2 || LOTEXT3 || LOTEXT4` virtual column AND `DESCRIPTION_LINE1`–`DESCRIPTION_LINE4` accessor columns. Probe confirms only `DESCRIPTION VARCHAR2(236)` exists on the view. Same workaround applies. CLAUDE.md updated.

PDF's note that `STREET2` is "not on the screen" (present in DB but hidden in SCC client UI) was already in CLAUDE.md and is not affected by this finding.

---

## 2. PDF columns we haven't probed in production

### 2a. V_S_LAB_TEST — additional columns

**Resolved 2026-05-01**.

V_S_LAB_TEST has **202 columns total — 159 live, 43 vestigial (DATA_LENGTH=0)**. Volume: 17,714 component-level test rows.

**All 12 PDF-flagged "additional columns" confirmed live:**
- `PRECISION_NEW` (NUMBER 22 (10)) — modern precision column with −7 to +7 range; coexists with legacy `PRECISION` and `PRECISION_POSITIVE`
- `DEFAULT_SOURCE`, `OBSERVATION_METHOD`, `NOSOCOMIAL_INF_AFTER`, `IS_PRINT_LBL_PROMPT_RESULT`, `MES_TEST_COMMENT` ✓
- `HOLD_AUTOVERIF` AND `HOLD_AUTOVERIFICATION` — both live, both adjacent (cols 175/176), confirmed PDF "duplicates" claim
- `FL_CALC_NEEDS_RMOD`, `FL_DO_NOT_MERGE_ST_ORDERS`, `FL_MANUAL_MERGE_DO_NOT_MERGE` ✓
- `FL_ELR_RESULT_REPORTABLE`, `FL_ELR_ORDER_REPORTABLE` ✓

**Vestigial set (43 columns, DATA_LENGTH=0):**
- All 32 billing-code slots: `CPT_BASIC_CODE_1`–`8`, `CPT_ALTERNATE_CODE_1`–`8`, `BILLING_CODE_1`–`8`, `CPT_EXP_DATE_1`–`8` — confirms existing CLAUDE.md note ("not populated; use V_S_ARE_BILLRULES.BRCPTCODE")
- `LBL_TEXT_1`–`3`, `QC_DISPLAY_WARNING`, `QC_TIME_LIMIT`, `CAP_ROUTINE_WEIGHT`, `CAP_STAT_WEIGHT`, `FL_IS_BBANK_TEST`, `FL_ANALIZE_COMPS_TOGETHER`, `CHART_REPORT_NO`, `SEROLOGY_TEST`

**Other findings:**
- `FL_10` (col 35), `FL_12` (col 37) — generically-numbered flag columns sitting among named FL_* set; semantics unverified
- `NAME_UPPER` (VARCHAR2 236) — uppercase computed search column

CLAUDE.md V_S_LAB_TEST entry expanded with PDF-confirmed-additional subsection, generically-numbered-flag note, and full vestigial column list.

### 2b. V_S_LAB_DOCTOR — assigning-authority fields

**Resolved 2026-05-01**.

V_S_LAB_DOCTOR has **112 columns total — 93 live, 19 vestigial (DATA_LENGTH=0)**. Volume: **207,182 rows** (massive — accumulates external referring physicians from Epic/outreach/reference-lab flows).

**All 8 PDF-flagged HL7/FHIR assigning-authority fields confirmed live:**
- `AUTHORITY_FOR_PRIMARY_ID` / `FACILITY_FOR_PRIMARY_ID`
- `AUTHORITY_FOR_SECONDARY_ID` / `FACILITY_FOR_SECONDARY_ID`
- `AUTHORITY_FOR_THIRD_ID` / `FACILITY_FOR_THIRD_ID`
- `AUTHORITY_FOR_NPI` / `FACILITY_FOR_NPI`

**Contact-comment fields confirmed live (all 4 PDF-flagged + 4 extras):**
- PDF-named: `PRIMARY_PHONE_COMMENT`, `ALT_PHONE_COMMENT`, `MODEM_COMMENT`, `FAX_COMMENT` ✓
- Extras: `PAGER_COMMENT`, `EMAIL_COMMENT`, `PRIMARY_PHONE_EQUIPMENT_TYPE`, `ALT_PHONE_EQUIPMENT_TYPE`

**PDF "NAME_*" fields don't exist with PDF naming** — the schema uses simpler legacy names: PDF's `NAME_PREFIX` → schema `TITLE`, `NAME_SUFFIX` → `SUFFIX`, `NAME_PRO_SUFFIX` → `PROFESSIONAL_SUFFIX`. PDF used FHIR-style naming from a newer dictionary version.

**Notable findings:**
- **`MARGING` typo preserved at schema level** — `ROE_ALLOW_ORDER_MARGING`, `ROE_SELECTIVE_ORDER_MARGING`, `ROE_PREVENT_ORDER_MARGING` (cols 76-78). All vestigial. Plus parallel `FL_ROE_ALLOW_MERG`, `FL_ROE_SELECT_MERG`, `FL_ROE_PREV_MERG` (cols 109-111) — also vestigial. **Entire ROE merge-control concept is vestigial here** despite being live on V_S_LAB_CLINIC (interesting cross-view divergence).
- **`DC*` prefix family** (DCPAGER, DCFAX, DCEMAIL, DCREPFORMAT, DCREPLAYOUT, DCMICFORMAT, DC_COUNTY) — possibly "discharged" or "doctor's-clinic" duplicate slots. Mystery prefix family; not yet probed for population.
- **Two SSN columns**: `SSN` and `SOCIAL_SEC_NUMBER` — both VARCHAR2 15, duplicates. PHI-sensitive even at master-data level.
- **NPI/UPIN have UPPER doppelgangers** for case-insensitive search.

CLAUDE.md V_S_LAB_DOCTOR entry expanded from ~10 columns to the full 112-column shape.

### 2c. V_S_LAB_CLINIC — additional flag columns

**Resolved 2026-05-01**.

V_S_LAB_CLINIC has **129 columns total — 123 live, only 6 vestigial (DATA_LENGTH=0)**. Volume: 1,397 clinics. Notably less dead schema than peers (~5%) — most of the 80+ PDF-claimed columns are operationally live.

**All PDF-flagged columns confirmed live:**
- Assigning-authority: `FACILITYS_ASSIGNING_AUTHORITY`, `AUTHORITY_FOR_GENERATED_MRN`, `FACILITY_FOR_GENERATED_MRN` ✓
- Contact-comment fields (6 columns) ✓
- `FL_AUTOREP`, `FL_LABEL_AT_OE`, `FL_CHART_AVAIL`, `FL_SKIP_BILL` ✓
- `ORDERING_PRIORITY`, `DISCHARGED_DAYS` ✓
- **`USER_INSTRUCTIOS` typo confirmed at schema level** (PDF was right about the typo — schema name has the misspelling)
- `AUTO_REP_OPTION_DESC` (VARCHAR2 4000) — PDF-flagged slow computed column via `CSF_SSM_PKG.Lookup` ✓

**Vestigial set (only 6 columns):** `PRICE`, `BALANCE`, `TOTAL_PAYMENT`, `FL_SKIP_AR_POST`, `FL_SKIP_CALL`, `FL_PRIVATE_LOCATION`.

**Major finding — massive FL_ / FLAG_ duplicate-column legacy:**

Many concepts have BOTH a modern `FL_*` and a legacy `FLAG_*` column live alongside each other — 7 confirmed pairs (FL_AUTOREP / FLAG_AUTOPRINT_REPORT, FL_AUTOREP_MIC / FLAG_AUTOPRINT_MIC_REPORT, FL_GENERATE_MRN / FLAG_GENERATE_MRN, FL_CHART_AVAIL / FLAG_CHART_AVAILABLE, FL_SKIP_AR_POST / FLAG_SKIP_POSTING_AR, FL_SINGLE_REP_FIN / FLAG_PRINT_SINGLE_REPORT_FINAL, PRE_OPS / FLAG_PRE_OP_CLINIC). Pick the modern `FL_*` form.

**Other duplicate pairs:**
- `NAME_UPPER` / `CLNAME_UPPER` (both VARCHAR2 400)
- `PHONE1_EXT` / `CLTEL1EXT`, `PHONE2_EXT` / `CLTEL2EXT` (legacy CLTEL naming)
- `STARTING_DATE` (NUMBER YYYYMMDD) / `STARTING_DT` (DATE)
- `FACILITY` / `FACILITY_NAME`

**Cross-view divergence with V_S_LAB_DOCTOR:** the ROE merge family (FL_ROE_*) is **live** on V_S_LAB_CLINIC but **vestigial** on V_S_LAB_DOCTOR. Same conceptual columns, opposite live/dead status across the two views. If working on ROE merge logic, query the CLINIC flags.

CLAUDE.md V_S_LAB_CLINIC entry expanded from 12 columns to the full 129-column shape.

### 2d. V_S_LAB_INSURANCE — many DEPRECATED columns

**Resolved 2026-05-01**.

PDF marks ~32 columns as DEPRECATED (NULL on view, kept for 4.0.7.1 compat). Probe confirms exactly: **63 columns total — 31 live, 32 with `DATA_LENGTH=0`** (Oracle "placeholder slot, can hold no data"). All PDF-flagged columns matched the schema-vestigial set without exception.

Volume: 689 rows (the complete insurance master roster). Population probe confirmed `COUNT()=0` on every flagged column.

Live columns (basic identification + 12 Lab-side workflow CHAR(1) flags + a few cross-system identifiers like PAYOR_ID, PROVIDER_NUMBER) match the AR-is-source-of-truth pattern: every billing/payor/EDI/medigap field is dead. Promoted from PDF capsule to full CLAUDE.md entry.

### 2e. V_S_LAB_SPECIMEN — DEPRECATED columns to avoid

**Resolved 2026-05-01**.

PDF marks ~18 columns as DEPRECATED. Probe confirms exactly: **42 columns total — 24 live, 18 with `DATA_LENGTH=0`**. PDF-flagged set matches schema-vestigial set without exception:
- `CAPACITY` / `MIN_VOLUME` / `VOL_COMMENT` / `CAPACITY_AA_ID` / `CAPACITIES_SORT` — moved to V_S_LAB_TUBE_CAPACITY
- `SPEC_TYPE` / `SPEC_TYPE_MOD` / `SPEC_ADDITIVE` — replaced by TYPE_SOURCE / TYPE_MODIFIER / ADDITIVES_PRESERVATIVES
- `VENIP_SPEC` / `CAPIL_SPEC` / `URINE_SPEC` — encoded in TYPE_SOURCE
- `IS_INTERVAL_COL` / `IS_COLLECTION` / `EXTENSION` / `ROBOTIC` / `PARENT` / `AUX_TUBE` / `COMMENT_TEXT` — vestigial slots

Volume: 235 rows (the complete tube-type roster).

**One PDF claim refuted:** PDF said `FAKE_CONTAINER` is "DEPRECATED but still indexed; semantics unclear." Probe shows `VARCHAR2(1)` with `100%` population across all 235 rows — it's a fully-active per-tube-type flag. CLAUDE.md updated to flag this as the lone PDF error.

CLAUDE.md V_S_LAB_SPECIMEN entry expanded from 16 columns to the full 42-column shape.

---

## 3. V_S_SEC_USER and Security module — not in this PDF

The PDF covers SoftLab setup only. The Security module was characterized empirically via §37/§41 in `setup/test_result_history_probe.sql` (run 2026-05-01).

### Resolved questions for V_S_SEC_USER

All previously-listed open questions are settled in CLAUDE.md V_S_SEC_USER profile (lines ~852–858). Quick references:

- **`ROLE` enum**: U (97.7%, user accounts) / R (2.3%, role definitions inline). Verified — full enum.
- **`ID` negative numeric pattern**: decorative, 99.8% of all rows have negative ID regardless of ROLE — not a useful discriminator.
- **`SCC_USER='Y'`**: 7 rows total — rarity flag for super-accounts; useful for auditor-attention scoring.
- **MOD_TECH coverage**: characterized in V_P_LAB_TEST_RESULT_HISTORY notes (§42 in test_result_history_probe.sql).
- **`EMERGENCY_ACCESS` / `EMERGENCY_ROLE`**: 0% populated — vestigial.
- **`FUTURE_ACTIVATE_DATE` / `FUTURE_DEACTIVATE_DATE` / `LAST_PWD_DATE`**: NUMBER(10,0) with sentinel values; max real values from 2019–2020 — effectively vestigial. Don't compare to SYSDATE.

### Resolved column shapes (Tier 2A)

**Resolved 2026-05-01**.

| View | Rows | Status |
|------|------|--------|
| `V_S_SEC_USERROLES` | 9,012 | 4 cols (AA_ID, ROLE_ID, USER_ID, SITE_ID — all NOT NULL). Workhorse — entire authorization model in practice |
| `V_S_SEC_USER` | 3,547 | Already documented |
| `V_S_SEC_USERSITEROLE` | 20 | Vestigial overlay (already noted) |
| `V_S_SEC_CONTACT_INFO` | 9 | 24 cols polymorphic via `TYPE`; tiny — likely a few ref-lab/supplier contacts only, NOT user demographics |
| `V_S_SEC_GROUP_ROLES_MAPPING` | 1 | LDAP↔SCC role bridge — set up but **operationally unused** |
| `V_S_SEC_USER_GROUP` | 0 | Group definitions table (NOT a junction). Empty — concept never operationalized |
| `V_S_SEC_GROUP_ASSIGNMENT` | 0 | Polymorphic group-membership junction. Empty — concept never operationalized |

**Big-picture finding:** despite the schema supporting a layered model (direct grants + LDAP-bridged + internal-groups), only the direct-grant path (V_S_SEC_USERROLES) is populated. The LDAP and internal-group paths are theoretical in this deployment.

**Notable structural finding:** `V_S_SEC_USERROLES.SITE_ID` is NOT NULL on the view itself — every grant is inherently site-scoped. This makes `V_S_SEC_USERSITEROLE` (20 rows) a redundant overlay rather than a needed extension.

CLAUDE.md updated with full column-level documentation and a "Security module — full composition" subsection.

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

**Resolved 2026-05-01**.

**View shape**: 198 columns total (the widest view in this dictionary). Order-grain — perfect 1:1 with V_P_LAB_ORDER (12,886 rows = 12,886 distinct ACTIVE_AA_IDs over 30 days). Volume: ~430 micro orders/day = ~6.7% of total order volume.

**PDF claims verified**:
- ✓ Cross-module FK `ACTIVE_AA_ID` → `V_P_LAB_ORDER.AA_ID` — **100% populated, no orphans** (12,884/12,884 join rate). Stronger than PDF's "this is the link" wording suggested.
- ✓ `ORDER_STATUS` is computed CASE — clean 5-value enum: `FINAL` (70.07%), `CANCELLED` (11.9%), `PRELIM` (9.5%), `INTERIM` (6.01%), `PENDING` (2.53%). Lifecycle: PENDING → PRELIM → INTERIM → FINAL (or CANCELLED at any point).
- ✓ Numeric `*_DATE`/`*_TIME` pairs alongside canonical `*_DT` columns confirmed across 11 timestamp families (COLL, RCVD, PRELIM, INTERIM, FINAL, RCVD_IN_MIC, PLATED, TECH_VERIF, REP, ADM, WORKLOAD). `-1` is the "not set" sentinel for the numeric pair.

**PDF claims refuted**:
- ✗ `TEST_STATUS` does NOT exist on V_P_MIC_ACTIVE_ORDER (verified — `ALL_TAB_COLUMNS` returns nothing; `SELECT TEST_STATUS FROM V_P_MIC_ACTIVE_ORDER` raises `ORA-00904`). Likely lives on `V_P_MIC_TEST` instead.
- ✗ Short-form flag deprecation (PDF named `CALLED`, `POSTED`) — those exact names don't exist on the view. Either renamed to FLAG_* form already, or removed entirely.

**Other findings**:
- 7 schema-vestigial columns (`DATA_LENGTH=0`): `B1FLAGS1_FLAGS`, `B1FLAGS2_FLAGS`, `BILLING_NUM`, `FLAG_GSN`, `FLAG_GSP`, `FLAG_V`, `MRN`. Surprisingly few given the 198-column total.
- ~9 duplicate-column legacy pairs (`*_TECH_ID` ↔ `*_TECH` for 7 tech roles, plus `WARD_ID`↔`ISO_WARD`, `LOCATION`↔`LOC`, `ORDER_NUMBER`↔`ORDER_NUM`, `PATIENT_TYPE`↔`PAT_TYPE`, `REQ_DOCTOR_ID`↔`REQ_DR`).
- Two schema-preserved typos: **ISOLATEION** (col 177, should be ISOLATION — both columns coexist), **PATHEVIEW_*** (cols 119–120, missing `R` from PATHREVIEW).
- `B1*` prefix family (B1CASE, B1STUDY_0–4, B1WRKLDATE/TIME, FLAG_B1DRAW) is empty on routine orders — likely amendment/revision data, hypothesis not yet directly verified.
- Single-letter flags `FLAG_C`/`D`/`P`/`I`/`F`/`L`/`X` exist; semantics unverified.
- ~90 FLAG_* columns total — extensive workflow-state matrix.

CLAUDE.md V_P_MIC_ACTIVE_ORDER entry promoted from PDF capsule to full ~80-line section under "SoftMic (Microbiology) Views — Detail."

### 6b. V_P_MIC_PATHREVIEW — PATHOLOGIST_ID ≠ TECH_ID

PDF distinguishes `PATHOLOGIST_ID` (signing pathologist for the review) from `TECH_ID` (tech who performed/recorded the review). Don't conflate the two when building "who reviewed" reports — the path-review chain is two-tier (tech does workup, pathologist signs), parallel to V_P_BB_Result's three-tier review.

### 6c. V_S_MIC_ORGANISM single-letter classification flags — confirmed

PDF confirms the empirical observation in CLAUDE.md V_S_MIC_ORGANISM section:
- `Q_VIRUS`, `R_FUNGI` — domain flags (virus / fungus)
- `A_GRAMPOS`, `B_GRAMNEG`, `C_GRAMVAR` — Gram stain
- `N_COCUS`, `O_BACILLUS` — morphology (coccus / bacillus)

These single-letter flag names are not query-friendly but they're authoritative. Yeast (Candida etc.) routes through `R_FUNGI`. Existing CLAUDE.md notes are correct.

### 6d. SoftMic comment views family — fanout pattern

**Resolved 2026-05-01**.

The micro module has SEVEN comment views, all sharing a common 12-column comment skeleton (TEXT, TYPE, 5 FLAG_*, MOD_* triple) plus PK + parent FK + sort + author columns. Verified shapes and volumes:

| View | Cols | Rows | Parent FK | Author cols | Status |
|------|------|------|-----------|-------------|--------|
| V_P_MIC_TESTCOMM | 15 | 6,318,372 | TEST_AA_ID | TECH_ID + TECHNIK | Workhorse |
| V_P_MIC_MEDIACOMM | 15 | 3,420,647 | MEDIA_AA_ID | TECH_ID + TECHNIK | Workhorse |
| V_P_MIC_ISOCOMM | 15 | 2,006,608 | ISOLATE_AA_ID + cryptic `I1_U1_SORT` | TECH_ID + TECHNIK | Workhorse |
| V_P_MIC_THERAPYCOMM | 15 | 43,942 | SENSI_AA_ID | **TECHNIK_ID + TECHNIK** (no TECH_ID) | Modest |
| V_P_MIC_ORDER_COMM | 14 | 13,935 | ACTIVE_ORDER_AA_ID | TECHNIK only | Live order-level |
| V_P_MIC_COMMON_MEDIACOMM | 14 | 2,005 | TEST_AA_ID (NOT MEDIA — misleading name) | TECHNIK only | Tiny — purpose ambiguous |
| **V_P_MIC_COMM** | 14 | **0** | ACTIVE_ORDER_AA_ID | TECHNIK only | **VESTIGIAL — empty dead twin of ORDER_COMM** |

**Key findings refute the original PDF framing:**

1. **PDF claim "V_P_MIC_COMM = general; V_P_MIC_ORDER_COMM = categorized" is REFUTED.** Both views have identical schemas (verified via re-run of §9.2). V_P_MIC_COMM is fully empty (0 rows); V_P_MIC_ORDER_COMM is the live order-level view (14K rows). They are dead-twin / live-twin structural duplicates, not "general vs categorized."
2. **PDF claim "V_P_MIC_COMMON_MEDIACOMM has no FK and is reusable common library" is partially REFUTED.** The view DOES have a FK column (TEST_AA_ID) — it's not FK-less. The 2K row count *is* consistent with a canned-text library, but only if the FK points to library-entry records rather than real tests. Two unresolved interpretations (canned-library vs. older-variant); requires PHI-safe sampling to distinguish. Defer until needed.
3. **PDF "MEDIACOMM" suffix in V_P_MIC_COMMON_MEDIACOMM is misleading** — the schema is test-grain (TEST_AA_ID), not media-grain.
4. **Three author-column conventions across the family** — schema inconsistency:
   - TECHNIK only: V_P_MIC_COMM (vestigial), V_P_MIC_ORDER_COMM, V_P_MIC_COMMON_MEDIACOMM
   - TECH_ID + TECHNIK: V_P_MIC_TESTCOMM, V_P_MIC_ISOCOMM, V_P_MIC_MEDIACOMM
   - TECHNIK_ID + TECHNIK (no TECH_ID): V_P_MIC_THERAPYCOMM (stands alone)

**Total comment volume across the 6 active views: ~11.78M rows** — substantially more than V_P_LAB_INTERNAL_NOTE's 2.6M (SoftMic is comment-heavy).

**Cross-module navigation**: comments → V_P_MIC_* parent → V_P_MIC_ACTIVE_ORDER.AA_ID → ACTIVE_AA_ID → V_P_LAB_ORDER. Two-hop minimum to reach the SoftLab order from any comment view.

CLAUDE.md updated with full SoftMic comment family section under "SoftMic (Microbiology) Views — Detail."

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
