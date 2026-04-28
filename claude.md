# SCC Soft Computer LIS — Data Dictionary Reference

Source: SCC Soft Computer data dictionaries (SoftLab, SoftBank, SoftMic, Instruments, SoftAR).
Database: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production. All date/time columns are Oracle DATE type unless noted.

---

## Naming Conventions

| Prefix | Meaning |
|--------|---------|
| `V_P_LAB_*` | SoftLab patient/transactional data (orders, specimens, results) |
| `V_S_LAB_*` | SoftLab setup/reference data (clinics, doctors, tests, workstations) |
| `V_P_BB_*` | SoftBank (Blood Bank) patient/transactional data |
| `V_S_BB_*` | SoftBank setup/reference data |
| `V_P_MIC_*` | SoftMic (Microbiology) patient/transactional data |
| `V_S_MIC_*` | SoftMic setup/reference data |
| `V_P_BCC_*` | Blood Culture Contamination reporting |
| `V_P_ARE_*` | SoftAR (Accounts Receivable) patient/transactional data |
| `V_S_ARE_*` | SoftAR setup/reference data |
| `V_GTT_ARE_*` | SoftAR global temporary tables (internal) |
| `V_S_INST_*` | Instrument interface definitions |
| `AA_ID` | Internal primary key (NUMBER 14) — used for all joins between SoftLab/SoftBank/SoftMic views |
| `*INTN` | Internal primary key (NUMBER) — used in SoftAR views (e.g., CCINTN, ITINTN, TSTINTN) |
| `ID` | Human-readable code/number (varies by entity) |

### SoftAR Column Prefixes
SoftAR views use abbreviated column-name prefixes instead of full names:

| Prefix | View | Example |
|--------|------|---------|
| `CC*` | V_S_ARE_CCI | CCINTN, CCCPT1 |
| `CPT*` | V_S_ARE_CPTTABLE | CPTCODE, CPTDESC |
| `TST*` | V_S_ARE_TEST | TSTCODE, TSTDESC |
| `IT*` | V_P_ARE_ITEM | ITINTN, ITCPTCD |
| `BE*` | V_P_ARE_BILLERROR | BEINTN, BERDESC |
| `MOD*` | V_S_ARE_MODIFIER | MODCODE, MODDESC |

Common SoftAR suffixes: `*INTN` = internal number (PK), `*STAT` = status (0=active), `*CREATDTM`/`*EDITDTM` = audit timestamps, `*CREATBY`/`*EDITBY` = audit user.

### Deprecated Columns
Many views have `*DEPRECATED` columns (e.g., `ORDERED_DATEDEPRECATED`). Always use the modern `*_DT` equivalent instead (e.g., `ORDERED_DT`).

---

## Core Entity Relationships (SoftLab)

```
V_P_LAB_PATIENT          (AA_ID)
    └─► V_P_LAB_STAY     (AA_ID, PATIENT_AA_ID → PATIENT.AA_ID)
            └─► V_P_LAB_ORDER   (AA_ID, STAY_AA_ID → STAY.AA_ID)
                    ├─► V_P_LAB_ORDERED_TEST  (AA_ID, ORDER_AA_ID → ORDER.AA_ID)
                    ├─► V_P_LAB_TEST_RESULT   (AA_ID, ORDER_AA_ID → ORDER.AA_ID)
                    └─► V_P_LAB_TUBE          (AA_ID, ORDER_AA_ID → ORDER.AA_ID,
                                                       SPECIMEN_AA_ID → SPECIMEN.AA_ID)

V_P_LAB_SPECIMEN         (AA_ID, PATIENT_AA_ID → PATIENT.AA_ID)
    └─► V_P_LAB_TUBE     (SPECIMEN_AA_ID → SPECIMEN.AA_ID)
            └─► V_P_LAB_SPECIMEN_BARCODE  (TUBE_AA_ID → TUBE.AA_ID)

V_P_LAB_ORDERED_TEST joined to V_P_LAB_TEST_RESULT:
    ot.ORDER_AA_ID = tr.ORDER_AA_ID
    AND ot.TEST_ID = tr.GROUP_TEST_ID
    AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID

V_P_LAB_CANCELLATION fans out to FOUR possible parents (discriminated
union — exactly one FK is non-null per row):
    .ORDERED_TEST_AA_ID      → V_P_LAB_ORDERED_TEST.AA_ID     (test-level cancel)
    .TEST_RESULT_AA_ID       → V_P_LAB_TEST_RESULT.AA_ID      (result-level cancel)
    .SPECIMEN_AA_ID          → V_P_LAB_SPECIMEN.AA_ID         (specimen-level cancel)
    .ORDERING_PATTERN_AA_ID  → V_P_LAB_ORDERING_PATTERN.AA_ID (standing-order cancel)
INNER JOIN on a single FK silently misses the other three categories.
```

### Blood Bank (SoftBank) Relationships
```
V_P_BB_BB_Order   (ORDERNO — unique order number)
    ├─► V_P_BB_Result  (ORDERNO → BB_Order.ORDERNO)
    └─► V_P_BB_Test    (ORDERNO → BB_Order.ORDERNO)

V_P_BB_Result links to V_P_BB_Test via:
    V_P_BB_Result.TEST_RESULT → V_P_BB_Test.AA_ID
```

### Lab ↔ Blood Bank Cross-Link
`V_P_LAB_ORDERED_TEST.ORDER_NO` matches `V_P_BB_BB_Order.ORDERNO` (both VARCHAR2 11).

---

## Collection Location Codes

Collection location codes (used in `V_P_LAB_SPECIMEN.COLLECTION_LOCATION`) follow a structured naming pattern:

### Facility Prefixes
| Code | Facility |
|------|----------|
| T | Temple University Hospital |
| J | Jeanes Hospital |
| C | Chestnut Hill Hospital |
| E | Episcopal Hospital |
| F | Fox Chase Cancer Center |
| W | Women and Families Hospital |
| N | (Unknown facility) |

### Location Suffixes
| Code | Meaning |
|------|---------|
| 1 | Inpatient |
| 2 | Outpatient |
| 4 | (TBD - user will provide later) |

### Common Collection Locations
- **T1, T2, T4** — Temple (inpatient, outpatient, other)
- **J1, J2** — Jeanes (inpatient, outpatient)
- **C1, C2** — Chestnut Hill (inpatient, outpatient)
- **E1** — Episcopal (inpatient)
- **F1, F2** — Fox Chase (inpatient, outpatient)
- **W1, W2** — Women and Families (inpatient, outpatient)
- **N1** — Unknown facility (inpatient)

---

## Cross-Cutting Query Rules

These rules apply to every query — also documented in `field_reference.md`. Read both files before writing a new query.

### Valid MRN Filter (mandatory on every query touching patient identity)

Real Temple patient MRNs always match `^E[0-9]+$` (E followed by digits). Other prefixes (TX, EX, ZZ, etc.) are test/fake patients seeded into the system. Any query that joins `V_P_LAB_PATIENT` or `V_P_ARE_PERSON` must include:

```sql
AND REGEXP_LIKE(p.ID, '^E[0-9]+$')  -- Valid MRNs only
```

(Use the appropriate alias and column — `pt.ID` for `V_P_LAB_PATIENT`, `PTMRN` for `V_P_ARE_PERSON`.) Skip only when the explicit goal is to find fake/test patients, in which case invert the predicate.

### SoftAR Money Fields Are Stored in Cents

Every monetary column in SoftAR (`ITPRICE`, `ITBAL`, `INCHARGE`, `INDUEAMT`, `VTCHARGE`, `TRAMT`, etc.) is stored as integer cents — divide by 100 for dollars when displaying.

---

## Frequently Used Views — Full Column Detail

### V_P_LAB_PATIENT — Patient data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 23 | Medical Record Number (MRN) |
| SOCIAL_SECURITY | VARCHAR2 23 | SSN |
| LAST_NAME | VARCHAR2 50 | Last name |
| FIRST_NAME | VARCHAR2 80 | First name |
| MIDDLE_INITIAL | VARCHAR2 27 | Middle initial |
| SUFFIX | VARCHAR2 11 | Name suffix |
| TITLE | VARCHAR2 11 | Title |
| DOB_DT | DATE | Date of birth (use instead of DATE_OF_BIRTHDEPRECATED) |
| SEX | VARCHAR2 1 | Patient sex |
| RACE | VARCHAR2 40 | Patient race |
| MARITAL_STATUS | VARCHAR2 1 | Marital status |
| STREET_LINE1 | VARCHAR2 64 | Address line 1 |
| STREET_LINE2 | VARCHAR2 64 | Address line 2 |
| CITY | VARCHAR2 40 | City |
| STATE | VARCHAR2 3 | State |
| ZIP | VARCHAR2 11 | Zip code |
| TEL | VARCHAR2 20 | Phone |
| EMPLOYER | VARCHAR2 50 | Employer |

### V_P_LAB_STAY — Stay/Visit information

**51 columns total** — grouped here by category. Volume: ~6.5K rows/day, ~1.46 stays per patient over 7 days. **Critical caveat: `ADMISSION_DT` can be in the FUTURE** for pre-scheduled outpatient visits — see notes below.

#### Identity & Patient

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| PATIENT_AA_ID | NUMBER 22 | FK → V_P_LAB_PATIENT.AA_ID |
| MRNNUM | VARCHAR2 23 | MRN — denormalized from V_P_LAB_PATIENT.ID. Lets queries skip the PATIENT join when only MRN is needed |
| BILLING | VARCHAR2 23 | **Epic CSN** (Contact Serial Number) — encounter identifier from Epic HIS. **Unique per stay, never null** (validated 7-day sample: 45,975 stays / 45,975 distinct CSNs / 0 nulls). Safe to use as a unique join key |
| MOTHER_BILLING | VARCHAR2 23 | Mother's CSN for newborn stays. **Caveat: mostly defaults to the stay's own BILLING for non-newborn stays** — only carries a *different* CSN on actual newborn-mother linkages |
| EXTERNAL_VISIT_NUM | VARCHAR2 32 | External-system visit identifier (often blank for outpatient) |
| HIS_VISIT_NUM | VARCHAR2 32 | HIS visit identifier (often blank for outpatient; populated for inpatient HIS-fed stays) |

#### Dates

| Column | Type | Description |
|--------|------|-------------|
| ADMISSION_DT | DATE | Admission timestamp (canonical). **Can be in the FUTURE** for pre-scheduled outpatient visits posted from Epic in advance — observed up to 5 months ahead. Naive date-range filters silently include scheduled-but-not-yet-occurred stays |
| ADMISSION_DATE | DATE | Duplicate of ADMISSION_DT in samples (both DATE type, both midnight on outpatient stays). Pick `ADMISSION_DT` |
| ADMISSION_TIME | NUMBER 22 | Time component as integer; `0` for stays without specific admit time |
| DISCHARGE_DT | DATE | Discharge timestamp. NULL when discharge hasn't happened |
| DISCHARGE_DATE | DATE | Duplicate of DISCHARGE_DT |
| DISCHARGE_TIME | NUMBER 22 | Time component; `-1` is the "not set" sentinel |

#### Doctors

| Column | Type | Description |
|--------|------|-------------|
| DOCTOR_ID | VARCHAR2 15 | Primary doctor (FK by code → V_S_LAB_DOCTOR.ID). **Workhorse field** — populated on outpatient stays where ADMITTING/CONSULTING are blank |
| ADMITTING_DOCTOR_ID | VARCHAR2 15 | Admitting doctor (FK by code → V_S_LAB_DOCTOR.ID). Populated for inpatient stays |
| CONSULTING_DOCTOR_ID | VARCHAR2 15 | Consulting doctor (FK by code → V_S_LAB_DOCTOR.ID). Populated for inpatient stays |

#### Location

| Column | Type | Description |
|--------|------|-------------|
| CLINIC_ID | VARCHAR2 15 | Ordering ward/clinic (FK by code → V_S_LAB_CLINIC.ID) |
| ROOM | VARCHAR2 7 | Room (inpatient only — empty for outpatient stays) |
| BED | VARCHAR2 3 | Bed (inpatient only) |

#### Patient Type & Classification

| Column | Type | Description |
|--------|------|-------------|
| HIS_PATIENT_TYPE | VARCHAR2 1 | HIS patient type. Observed enum (7-day sample): `O` (Outpatient, 87%), `E` (Emergency, 7%), `I` (Inpatient, 2.6%), blank (2.7%), `N` (Newborn/Non-patient, 0.5%), `H` (rare, 0.007%) |
| HIS_PATIENT_SUBTYPE | VARCHAR2 1 | Patient subtype (often blank in current data) |
| ADMISSION_TYPE | VARCHAR2 1 | Admission type code — observed `'A'`. **NOT a duplicate of `ADM_TYPE`** despite the similar name — both populated with different values |
| ADM_TYPE | VARCHAR2 1 | Different admission classification — observed `'R'` |
| ADMITTED_FROM_HIS | VARCHAR2 15 | HIS admit-source code (often blank for outpatient) |

#### Insurance

| Column | Type | Description |
|--------|------|-------------|
| INSURANCE1_ID | VARCHAR2 15 | Primary insurance (FK by code → V_S_LAB_INSURANCE.ID). Often blank at stay level (insurance lives on order) |
| INSURANCE2_ID | VARCHAR2 15 | Secondary insurance |
| INSURANCE3_ID | VARCHAR2 15 | Tertiary insurance |
| MEDICAL_SERVICE_ID | VARCHAR2 5 | Medical service (FK by code → V_S_LAB_MEDICAL_SERVICE.ID). Often blank — same pattern as on V_P_LAB_ORDER |

#### Diagnosis

| Column | Type | Description |
|--------|------|-------------|
| DIAGNOSIS1_ID | VARCHAR2 11 | Primary diagnosis code (often blank for outpatient lab visits) |
| DIAGNOSIS2_ID | VARCHAR2 11 | Secondary diagnosis code |
| DIAGNOSIS3_ID | VARCHAR2 11 | Tertiary diagnosis code |
| DIAGNOSIS_TEXT | VARCHAR2 80 | **Free-text diagnosis description — workhorse field**. Often populated where the structured ID columns are blank. PHI-adjacent |
| DIAGNOSIS_CODING_STANDARD | VARCHAR2 1 | ICD-9 vs ICD-10 indicator (often blank in samples) |

#### Workflow Flags (all VARCHAR2 1)

| Column | Description |
|--------|-------------|
| ADMIT_FLAG | **Documented as "Admitted flag" but observed always `'N'` in 7-day data — appears unused/vestigial in current operations.** Even on the 1,199 inpatient (`HIS_PATIENT_TYPE='I'`) stays. Don't filter on `'Y'`; infer admitted state from `HIS_PATIENT_TYPE='I'` instead |
| DISCHARGE_FLAG | Same — always `'N'`. Infer discharge state from `DISCHARGE_DT IS NOT NULL` |
| ADMIT_OUTP_FLAG | Outpatient admit flag — observed `'N'` in samples |
| DELETED_FLAG | Soft-deletion flag. Most queries should filter `DELETED_FLAG = 'N'` to exclude deleted records |
| ACTIVE_FLAG | CHAR 1. Observed `'R'` (not Y/N) — has its own enum (likely Routine/Released/Resulted) |
| RESULT_CHANGED_FLAG | Result-amendment indicator at the stay level |
| DISCH_REP_PRINTED | Discharge report printed |
| JUST_POSTED_HIS_FLAG | Just-posted-from-HIS indicator (`'Y'` on freshly-imported stays from Epic) |

#### Free Text & Other

| Column | Type | Description |
|--------|------|-------------|
| COMMENTS | CLOB 4000 | Stay-level comments (PHI-adjacent) |
| MSPQ | CLOB 4000 | Medicare Secondary Payor Questionnaire response |
| CONTACT_PHONE | VARCHAR2 20 | Stay-specific contact phone (often blank; distinct from patient's phone) |
| CONTACT_PHONE_EXT | VARCHAR2 11 | Phone extension |
| GENETICS_VISIT_STATUS | VARCHAR2 1 | Genetics-specific visit status |
| ACCIDENT_CODE | VARCHAR2 1 | Injury/accident-related visit code |
| SURGERY | VARCHAR2 12 | Surgery indicator/code (observed single-char `'O'` despite VARCHAR2 12) |

#### Empty / Vestigial (DATA_LENGTH = 0 — confirms billing is in SoftAR, not here)

`TOTAL_CHARGES` (col 14), `TOTAL_PAYMENTS` (col 16), `PATIENT_BAL` (col 19). All financial slots — schema placeholders never written. SoftAR owns the financial domain via V_P_ARE_VISIT.

**Notes:**

- **`ADMISSION_DT` can be in the FUTURE** — pre-scheduled outpatient visits are posted from Epic in advance with future ADMISSION_DT (observed up to ~5 months ahead). For "actual past visits", filter `ADMISSION_DT <= SYSDATE` in addition to your start date. For "completed visits", check `DISCHARGE_DT IS NOT NULL`. For "actual lab work happened in window", use a downstream timestamp like `V_P_LAB_ORDER.ORDERED_DT` or `V_P_LAB_TEST_RESULT.VERIFIED_DT`.
- **`ADMIT_FLAG` and `DISCHARGE_FLAG` are vestigial** — observed always `'N'` even on inpatient stays. Don't trust them as filters; derive admit/discharge state from `HIS_PATIENT_TYPE` and `DISCHARGE_DT IS NOT NULL`.
- **`BILLING` (Epic CSN) is unique per stay and never null** — safe as a join key. This is what links V_P_LAB_MISCEL_INFO.OWNER_ID → V_P_LAB_STAY.BILLING.
- **`MOTHER_BILLING` defaults to BILLING** — does NOT reliably identify newborns. Only carries a different CSN on real newborn-mother linkages; use carefully.
- **`MRNNUM` denormalized** — saves the V_P_LAB_PATIENT join when only MRN is needed.
- **`ADMISSION_DATE` ≈ `ADMISSION_DT`** — both DATE type, both populated, appear duplicated in samples. Same for DISCHARGE pair.
- **`ADMISSION_TYPE` and `ADM_TYPE` are NOT duplicates** despite similar names — different enums, both populated.
- **`DOCTOR_ID` is the outpatient workhorse**; `ADMITTING_DOCTOR_ID` and `CONSULTING_DOCTOR_ID` activate for inpatient.
- **`DIAGNOSIS_TEXT` is the workhorse for outpatient**; structured `DIAGNOSIS1_ID` etc. are sparse.
- **`DELETED_FLAG`**: filter `'N'` to exclude soft-deleted stays from reports.
- **Outpatient is dominant** (87%); inpatient is a small slice (2.6%). Plan queries accordingly.

### V_P_LAB_ORDER — Order data

89 columns total — grouped here by category. The full column list is authoritative as of 2026-04-27 discovery; vestigial / never-populated columns (`DATA_LENGTH = 0`) are listed but not detailed.

#### Identity & Routing

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK (NOT NULL) |
| ID | VARCHAR2 11 | Order number (matches V_P_BB_BB_Order.ORDERNO and V_P_ARE_VISIT.VTORGORDNUM for cross-module joins) |
| STAY_AA_ID | NUMBER 22 | FK → V_P_LAB_STAY.AA_ID |
| BILLING | VARCHAR2 23 | Epic CSN — denormalized from V_P_LAB_STAY.BILLING (same identifier; lets you join to AR/Epic without going through Stay) |
| ACTIVE_FLAG | CHAR 1 | Active flag (Y/N) |
| ORDER_TYPE | CHAR 1 | Order type code |
| PATIENT_TYPE | CHAR 1 | Patient type code |
| ORIGIN | VARCHAR2 15 | How the order was created — observed values: `HIS.POCT` (Point-of-Care via HIS interface) on POC orders. Useful classifier for HIS-vs-direct order entry |
| ORDERING_CLINIC_ID | VARCHAR2 15 | Ordering ward/clinic (FK by code → V_S_LAB_CLINIC.ID) |
| COLLECT_CENTER_ID | VARCHAR2 11 | Collection center (FK by code → V_S_LAB_COLL_CENTER.ID) |
| MEDICAL_SERVICE_ID | VARCHAR2 5 | Medical service (FK by code → V_S_LAB_MEDICAL_SERVICE.ID) |
| STUDY_ID | VARCHAR2 5 | Study code (FK by code → V_S_LAB_STUDY.ID) |
| ENVIRONMENT | NUMBER 22 | Environment bitmask — observed `2048` (= 2^11) on POC orders. Not a free numeric value; encodes test environment / module flags |
| ENVIRONMENT_MIXED | NUMBER 22 | Mixed-environment count or marker (varies 0/1/2 in samples) |
| HOLD_STATUS | NUMBER 22 | Hold status — observed values are 9-digit numbers (e.g. 105655429), so this looks like an internal reference key rather than an enum/status code. Semantics not yet confirmed |

#### Dates & Times

The numeric / DATE triple pattern (same as V_P_LAB_TUBE, V_P_LAB_CANCELLATION):

| Column | Type | Description |
|--------|------|-------------|
| ORDERED_DATE | NUMBER 22 | Order date as YYYYMMDD integer |
| ORDERED_TIME | NUMBER 22 | Order time as HHMM integer (leading zero stripped because NUMBER) |
| ORDERED_DT | DATE | Ordering date/time (canonical — prefer this) |
| COLLECT_DATE | NUMBER 22 | To-be-collected date as YYYYMMDD integer |
| COLLECT_TIME | NUMBER 22 | To-be-collected time as HHMM integer |
| COLLECT_DT | DATE | To-be-collected date/time (canonical) |
| COLLECT_DT_NO_TIME | CHAR 1 | Y/N — whether the collect time is unknown / date-only |
| AO_DT | DATE | Auto-Order timestamp (mirrors ORDERED_DT on POC samples; may differ on add-ons / cycling orders) |
| ACC_DT | DATE | Accession timestamp (mirrors COLLECT_DT on POC samples; may differ when accessioning happens after collection) |

#### People

| Column | Type | Description |
|--------|------|-------------|
| REQUESTING_DOCTOR_ID | VARCHAR2 15 | Requesting doctor (FK by code → V_S_LAB_DOCTOR.ID) |
| ORDERING_TECH_ID | VARCHAR2 16 | Ordering technologist (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |
| ORDERING_TECHNIK | VARCHAR2 16 | **Duplicate of ORDERING_TECH_ID** — legacy German spelling preserved alongside Anglo. Same value in samples. Pick one; expect them to match |

#### Insurance

| Column | Type | Description |
|--------|------|-------------|
| INSURANCE1_ID | VARCHAR2 15 | Primary insurance (FK by code → V_S_LAB_INSURANCE.ID) |
| INSURANCE2_ID | VARCHAR2 15 | Secondary insurance (FK by code → V_S_LAB_INSURANCE.ID) |
| INSURANCE3_ID | VARCHAR2 15 | Tertiary insurance (FK by code → V_S_LAB_INSURANCE.ID) |
| FAILED_PAYOR | VARCHAR2 15 | Payor for order — supersedes deprecated V_P_LAB_PAYOR view. Populated when payor selection failed/needed override |

#### Priority & Cancellation

| Column | Type | Description |
|--------|------|-------------|
| PRIORITY | CHAR 1 | Ordering priority (S=Stat, R=Routine, T=Timed) |
| TESTS_CANCEL | VARCHAR2 1 | Order-level cancellation summary flag — see notes below. Pure Y/N (validated 3-month sample); ~7.8% of orders are 'Y' |
| VERIFIED | VARCHAR2 1 | Verified flag (Y/N) — ~98.5% of orders end Y in steady state |

#### Workflow Flags (all VARCHAR2 1, Y/N)

| Column | Description |
|--------|-------------|
| BBTEST | Blood bank test ordered (~3.6% Y) |
| BACTITEST | Micro test ordered (~5.8% Y) |
| HOMECARE | Homecare flag — schema slot exists but **observed always 'N'** in 1-month sample (rarely or never populated in this deployment) |
| NO_CHARGE | No-charge flag — observed always 'N' (rarely populated) |
| PRE_OP | Pre-op flag — observed always 'N' (rarely populated) |
| AUTOREPT | Auto-report flag |
| JOINPREV | Join-previous flag |
| MIXEDPRIORS | Mixed-priorities flag |
| TESTSTOCALL | Tests-to-call flag |
| TESTS_WRKLOAD | Tests-workload flag |
| LIFETHREAT | Life-threatening flag |
| CALLPREDEF | Call-predefined flag |
| CALL_SPEC | Call-specimen flag |
| CALL_ORDER | Call-order flag |
| CALLED | Called flag |
| MIN_VOLUME_FLAG | Minimum-volume flag |
| POSTED | Posted flag |
| ACYYY2 | (Internal) |

#### Reporting State

| Column | Type | Description |
|--------|------|-------------|
| R_RPT, T_RPT, D7_RPT, D_RPT, F_RPT, ID_RPT | VARCHAR2 1 | Report-status flags (Y/N) for various report formats. F_RPT = 'Y' on POC samples while siblings = 'N' — likely "final report sent" |
| CHAPTERS_TO_REPORT | NUMBER 22 | Bitmask of chapters to report |
| REPORTED_CHAPTERS | NUMBER 22 | Bitmask of reported chapters |
| REPORTED_CHPTS_PERM | NUMBER 22 | Permanent reported-chapters bitmask |
| RES_CHANGES_IN_PERM_REPORT | NUMBER 22 | Result-changes-in-permanent-report flag/count |

#### Result-Range Flags (all VARCHAR2 1)

| Column | Description |
|--------|-------------|
| PANIC_LOW / PANIC_HIGH | Panic range bounds applied flag |
| ABNORMAL_LOW / ABNORMAL_HIGH | Abnormal range bounds applied flag |
| PERCENT_DELTA / ABSOLUTE_DELTA | Delta-check flags |
| ABSURD_LOW / ABSURD_HIGH | Absurd range bounds applied flag |

#### Free Text

| Column | Type | Description |
|--------|------|-------------|
| NOTES | CLOB 4000 | Order-level notes (PHI-adjacent) |
| COMMENTS | CLOB 4000 | Order-level comments (PHI-adjacent; distinct from NOTES) |
| ACCSREQ | VARCHAR2 40 | Accession-request text |

#### CSReq / Externals

| Column | Type | Description |
|--------|------|-------------|
| CSREQ_AA_NSID | VARCHAR2 20 | CSReq namespace ID |
| CSREQ_AA_UID | VARCHAR2 200 | CSReq universal ID |
| CSREQ_AA_UID_TYPE | VARCHAR2 8 | CSReq UID type |
| CSREQ_AA_UIDTYPE | VARCHAR2 8 | CSReq UID type (duplicate column — name variant) |
| ACUUU_0 / ACUUU_1 / ACUUU_2 | VARCHAR2 15 | Three secondary identifier slots (purpose unconfirmed; empty in POC samples) |

#### Empty / Vestigial (DATA_LENGTH = 0 — placeholder columns, never written)

`RECEIVING_DOC1_ID`, `RECEIVING_DOC2_ID`, `RECEIVING_DOC3_ID`, `RECEIVING_DOC4_ID`, `RECEIVING_DOC5_ID`, `READY_FOR_FINAL_KEY`, `CANCEL_REASON`, `PRIORITY_REASON`, `LAST_REPORT`. Don't use these in queries — they're schema slots without storage.

**Notes:**
- **Active table**: ~190K orders/month observed in 1-month sample.
- **`TESTS_CANCEL` semantics** (validated against `V_P_LAB_ORDERED_TEST.CANCELLED_FLAG` over 1 month):
  - `'Y'` → "all tests on this order are cancelled" (98.5% of Y rows; the order is effectively a fully-cancelled shell). ~1.5% of Y rows drift (some / no tests actually cancelled) — flag is denormalized and slightly lazy.
  - `'N'` → "at least one test is NOT cancelled" — but **3.8% of N orders still have *partial* cancellations**. `TESTS_CANCEL = 'N'` is NOT equivalent to "no cancellations".
  - For correctness-critical filters (cancellation reports), join `V_P_LAB_ORDERED_TEST.CANCELLED_FLAG` directly instead of trusting this flag.
  - Fast filter for "exclude fully-cancelled orders" → `WHERE TESTS_CANCEL = 'N'` is the typical idiom and is what most TAT queries in this repo use.
- **`BILLING` = Epic CSN** — same identifier as `V_P_LAB_STAY.BILLING`, denormalized to the order. Queries that just need CSN + order number can stay at this level.
- **`ORDERING_TECH_ID` and `ORDERING_TECHNIK`** are duplicate columns; pick one (usually `ORDERING_TECH_ID`) and expect both to match.
- **`HOMECARE`, `NO_CHARGE`, `PRE_OP`** are documented but observed always `'N'` in current operations — schema slots that aren't being populated. Don't filter expecting `'Y'` rows.

### V_P_LAB_ORDERED_TEST — Ordered test data

**75 columns total** — grouped here by category. Volume: ~13K rows/day, ~2 orderables per order. The orderable-test layer between `V_P_LAB_ORDER` and `V_P_LAB_TEST_RESULT` (each row = one orderable group test placed on the order).

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID |
| ORDER_NO | VARCHAR2 11 | Order number (matches V_P_BB_BB_Order.ORDERNO) |
| TEST_ID | VARCHAR2 5 | Test code (FK by code → V_S_LAB_TEST_GROUP.ID) |
| TEST_TYPE | CHAR 1 | Test classification: `G` = group/panel, `I` = individual |
| COUNTER | NUMBER 22 | Iteration counter for cycling/standing orders (1 = first/only) |
| OPARENT_ORDER | VARCHAR2 11 | Parent order number for cycling/standing-order children. Empty for routine orders |
| ORDER_SORT | NUMBER 22 | Display position within the parent order |
| SECONDARY_ID | VARCHAR2 40 | Secondary identifier |
| LOINC_CODE | VARCHAR2 40 | LOINC code (denormalized; useful for HL7/ELR) |
| TEST_NAME | VARCHAR2 59 | Test name (denormalized — skip V_S_LAB_TEST_GROUP join when only displaying) |
| REPORTED_TEST_NAME | VARCHAR2 30 | Display name for the test on reports |

#### Cross-System Test Mappings

| Column | Type | Description |
|--------|------|-------------|
| REFERENCE_TEST_ID | VARCHAR2 40 | Reference-lab's test code (when test is sent out) |
| CLIENT_TEST_ID | VARCHAR2 15 | Client/customer test code mapping |
| BBANK_TEST_ID | VARCHAR2 5 | Blood-bank test code (cross-link to SoftBank) |
| HIS_DEPARTMENT_ID | VARCHAR2 5 | HIS source department code |

#### Dates & Times (numeric/DATE triple pattern; `-1` is the "not set" sentinel)

| Column | Type | Description |
|--------|------|-------------|
| ORDERING_DATE / ORDERING_TIME / ORDERING_DT | NUMBER / NUMBER / DATE | Order placement timestamp — prefer `ORDERING_DT` |
| COLLECTED_DATE / COLLECTED_TIME / COLLECTED_DT | NUMBER / NUMBER / DATE | Collection timestamp — prefer `COLLECTED_DT` |
| RECEIVED_DATE / RECEIVED_TIME / RECEIVED_DT | NUMBER / NUMBER / DATE | First-received timestamp — prefer `RECEIVED_DT` |
| RECEIPT_DATE / RECEIPT_TIME / RECEIPT_DT | NUMBER / NUMBER / DATE | Receipt-confirmation timestamp — usually duplicates `RECEIVED_*`, but can diverge for auto-verified flows (different `RECEIPT_TECH`) |
| TAT | NUMBER 22 | **EXPECTED TAT (SLA target) from test setup, NOT measured TAT.** Same foot-gun as on V_P_LAB_TEST_RESULT — compute measured TAT from date arithmetic |

#### People

| Column | Type | Description |
|--------|------|-------------|
| TECH_ID | VARCHAR2 16 | Ordering technologist (FK by code → V_S_LAB_PHLEBOTOMIST.ID). Holds system codes like `'RBS'` (Rules-Based System) for auto-reflexed orderables |
| SIGNING_DOCTOR_ID | VARCHAR2 15 | Authorizing doctor (FK by code → V_S_LAB_DOCTOR.ID) |
| DOCTOR_ID | VARCHAR2 15 | Requesting doctor (FK by code → V_S_LAB_DOCTOR.ID) |
| REPORTING_DOCTOR1_ID / REPORTING_DOCTOR2_ID / REPORTING_DOCTOR3_ID / REPORTING_DOCTOR4_ID | VARCHAR2 15 | Up to four reporting doctors (FK by code → V_S_LAB_DOCTOR.ID). Empty for routine orderables |
| REPORTING_DOC_TYPE | VARCHAR2 4000 | Reporting-doctor type metadata (parallel to the 4 ID slots) |
| COLLECTED_TECH | VARCHAR2 16 | Collecting tech (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |
| RECEIVED_TECH | VARCHAR2 16 | Receiving tech — first-receipt user |
| RECEIPT_TECH | VARCHAR2 16 | Receipt-confirmation tech — usually matches `RECEIVED_TECH`; can be `AUTOV` (auto-verifier) for system-driven flows |
| REFLEXED_BY | VARCHAR2 5 | Source test code that triggered the reflex (when this is a reflex orderable) |
| REFLEXED_BY_SEQ | NUMBER 22 | Sequence position in the reflex chain |

#### Workstations & Locations

| Column | Type | Description |
|--------|------|-------------|
| WORKSTATION_ID | VARCHAR2 5 | Ordering workstation (FK by code → V_S_LAB_WORKSTATION.ID) |
| CLINIC_ID | VARCHAR2 15 | Ordering ward/clinic (FK by code → V_S_LAB_CLINIC.ID) |
| MEDICAL_SERVICE_ID | VARCHAR2 5 | Medical service (FK by code → V_S_LAB_MEDICAL_SERVICE.ID). **Often empty in samples — `ORDERING_SERVICE_ID` carries the live data instead** |
| ORDERING_SERVICE_ID | VARCHAR2 15 | Ordering service identifier — values like `LAB`, `HIS.POCT`. Workhorse field; populated where `MEDICAL_SERVICE_ID` is blank |
| COLLECTION_CENTER_ID | VARCHAR2 11 | Collection center (FK by code → V_S_LAB_COLL_CENTER.ID; denormalized from V_P_LAB_ORDER) |
| TEST_LOCATION | VARCHAR2 4 | Performing facility code (e.g., `TUH`, `JNS`, `CH`) |
| COLLECTION_LOCATION | VARCHAR2 11 | Collection-event location code |
| RECEIPT_LOCATION | VARCHAR2 11 | Receipt-event location code |

#### Priority & Triage

| Column | Type | Description |
|--------|------|-------------|
| PRIORIY | CHAR 1 | **Priority (TYPO — schema-preserved misspelling).** Populated and matches `PRIORITY`. Pick one |
| PRIORITY | CHAR 1 | Priority — values: `R` (Routine, ~67%), `S` (Stat, ~25%), `T` (Timed, ~8.6%), `U` (~0.001% — undocumented value, ignore unless you specifically need it) |
| TRIAGE_STATUS | VARCHAR2 40 | **Empty in all 91K rows over 7 days — fully vestigial in current operations.** Don't filter on it |

#### Cancellation, Reflex, and State Flags

| Column | Type | Description |
|--------|------|-------------|
| CANCELLED_FLAG | NUMBER 22 | Canceled flag — pure 0/1 binary (0 = active ~92%, 1 = cancelled ~8%). The orderable-level cancellation rate; cancellations cascade to ~6 component result rows each, which is why V_P_LAB_TEST_RESULT shows ~50% Canceled state |
| REDUNDANT_FLAG | NUMBER 22 | Redundant orderable flag |
| ABSORBED_FLAG | NUMBER 22 | Test absorbed into another orderable |
| REFLEXED_FLAG | NUMBER 22 | This orderable was generated by reflex (1 = yes) |
| IS_REFLEXED | NUMBER 22 | Reflex indicator (parallel to REFLEXED_FLAG; set together) |
| IS_OADDON | NUMBER 22 | Outpatient add-on indicator |
| FOREIGN_BBANK_FLAG | NUMBER 22 | Foreign blood-bank product flag |
| FOREIGN_BBANK_UNITS | NUMBER 22 | Foreign blood-bank unit count |
| ELR_REPORTABLE | VARCHAR2 1 | ELR-reportable flag (Y/N) |
| DO_NOT_SEND_TO_HIS | VARCHAR2 1 | HIS suppression flag — set Y on billing-shell orderables (e.g., U/A Billable Test) |
| PRINT_AS_ORDERED | NUMBER 22 | Print-as-ordered flag — 1 for primary orders, 0 for reflex-generated |

#### Reflex Detail (the rich reflex-tracking chain)

| Column | Type | Description |
|--------|------|-------------|
| REFLEX_RULE_ID | VARCHAR2 5 | Reflex rule that triggered this orderable (FK to RBS rule setup) |
| RFLX_COMPONENT | VARCHAR2 5 | Source component test that triggered the reflex (e.g., `UBLD` for blood reflex on UA) |
| RFLX_COMP_RES | VARCHAR2 40 | Result value of the source component (e.g., `'Negative'`) |
| RFLX_COMP_LOINC | VARCHAR2 40 | LOINC code of the source component |
| RFLX_RESULT | VARCHAR2 40 | Propagated result value |
| RFLX_RESULT_LOINC | VARCHAR2 40 | Propagated result LOINC |
| RES_HANDLING | VARCHAR2 5 | Result handling code |
| RESULT_HANDLING | VARCHAR2 5 | **Duplicate of RES_HANDLING** (legacy column; values match in samples) |
| REFLEX_ORDER | VARCHAR2 11 | Source order# that triggered the reflex (often empty in routine reflex flows — value is back-derivable via REFLEXED_BY + ORDER_AA_ID linkage) |

#### Billing & Add-on

| Column | Type | Description |
|--------|------|-------------|
| BILL_TYPE | NUMBER 22 | Billing type code. Dict says `0=none, 1=Bill Only, 3=No Charge` — but **only `0` appears in 7-day data (100% of rows)**. Codes 1/3 are documented but rare/unused. Treat as effectively constant |
| ADDON_REASON | VARCHAR2 240 | Free-text reason for add-on tests. PHI-adjacent if populated |

**Notes:**

- **Volume**: ~13K rows/day, ~2 orderables per order. Cross-checks with V_P_LAB_ORDER (~6.4K orders/day × 2 = ~13K orderables) and V_P_LAB_TEST_RESULT (~13K orderables × ~12 components = ~162K result rows).
- **`PRIORIY` and `PRIORITY` are TRUE duplicates** — both populated, both match. The misspelled column survives from a schema-rename that kept the original. Pick `PRIORITY` for new queries.
- **`RECEIVED_*` and `RECEIPT_*` are *near-duplicates*** but can diverge — `RECEIVED_TECH=SCC` with `RECEIPT_TECH=AUTOV` was observed for auto-verified POC results. Use `RECEIVED_DT` for "specimen first received" workflows; `RECEIPT_DT` is essentially the same timestamp with a confirmation step layered on.
- **`-1` is the "not set" sentinel** for the numeric `*_DATE`/`*_TIME` columns when the corresponding event hasn't happened yet (`COLLECTED_DATE=-1` for not-yet-collected). The DATE column is NULL in those cases. Predicates filtering by date should not need to handle `-1` if they use the `*_DT` column.
- **`MEDICAL_SERVICE_ID` is often empty; `ORDERING_SERVICE_ID` is the live workhorse** for "what service ordered this" — values like `LAB`, `HIS.POCT`. Emphasize `ORDERING_SERVICE_ID` in queries.
- **`TAT` column = expected SLA, not measured** — same foot-gun as V_P_LAB_TEST_RESULT.
- **`BILL_TYPE` is effectively always 0** — the documented `1` (Bill Only) and `3` (No Charge) values exist in schema but didn't appear in 7-day data.
- **`PRIORITY = 'U'` exists** as a rare value (1 row in 7 days) — undocumented in SCC dictionaries. Negligible volume but a known gap if filtering on `PRIORITY IN ('S','R','T')`.
- **`TRIAGE_STATUS` is fully vestigial** in current operations (empty in all rows).
- **Reflex tracking is rich** — `IS_REFLEXED=1` rows carry source rule, source component code, source component LOINC, and source component result. Useful for reflex-policy auditing.
- **Auto-RBS as the actor**: `TECH_ID='RBS'` on auto-reflexed rows; `TECH_ID='SCC'` on HIS-imported orderables. Don't expect a person ID for these.

### V_P_LAB_TEST_RESULT — Test result data

**242 columns total** — grouped here by category. Volume: ~162K rows/day, ~5M/month, ~60M/year. Heavy panel-fanout (one panel order → ~24 component result rows). Stick to ≤7 day windows for full-row dumps and ≤1 month for aggregates; index access via `TEST_DT` is essentially mandatory.

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID |
| ORDER_ID | VARCHAR2 11 | Order number — denormalized from V_P_LAB_ORDER.ID. Lets queries display the human-readable order# without joining ORDER |
| TEST_ID | VARCHAR2 5 | Individual test code, component-level (FK by code → V_S_LAB_TEST.ID) |
| GROUP_TEST_ID | VARCHAR2 5 | Group/orderable test code (FK by code → V_S_LAB_TEST_GROUP.ID; matches V_P_LAB_ORDERED_TEST.TEST_ID) |
| ORGANIZATION_AA_ID | NUMBER 22 | FK → organization (mostly empty — populated for send-out / external tests) |
| INTERPRETER_AA_ID | NUMBER 22 | FK → interpreter (empty for routine results; populated for path-reviewed) |
| PATHREVIEW_AA_ID | NUMBER 22 | FK → pathology review (when applicable) |

#### Result Content

| Column | Type | Description |
|--------|------|-------------|
| RESULT | VARCHAR2 40 | Result value (text — may be 'PRELIM' / 'POS' / numeric / etc.). Note: micro tests can show `RESULT='PRELIM'` even when `STATE='Final'` (multiple Final rows over time as cultures progress) |
| STATE | VARCHAR2 9 | Result state — **active values: `Pending` → `Final` (or `Corrected`) | `Canceled`**. The dict-listed value `Verified` doesn't appear in 7-day data; treat as inactive. ~50% of recent rows are `Canceled` (panel-fanout from cancellations) — most reports filter `STATE IN ('Final', 'Corrected')` |
| STATUS | VARCHAR2 12 | Empty on the live row — vestigial here, use STATE. Note: the same column on V_P_LAB_TEST_RESULT_HISTORY IS populated (range classification snapshot at mod time: Normal/AbnormalHigh/AbnormalLow/etc.) — see V_P_LAB_TEST_RESULT_HISTORY for that enum |
| RESULT_STATUS | CHAR 1 | Empty in samples — vestigial, use STATE |
| PRIORITY | CHAR 1 | Priority (S=Stat, R=Routine, T=Timed) |
| UNITS | VARCHAR2 80 | Test units at resulting |
| ATUNITS | VARCHAR2 80 | At-result units (often duplicates UNITS) |
| ATRANGELOW / ATRANGEHIGH / ATRANGENORM | VARCHAR2 | At-result reference ranges |
| LOW_RANGES / HIGH_RANGES | VARCHAR2 32 | Reference range bounds |
| NORMAL_RANGE | VARCHAR2 256 | Reference range display string |
| ABNORMAL_FLAGS | VARCHAR2 4000 | Abnormal flag string |
| AFLAGS4 | VARCHAR2 4000 | Additional flags string |
| SECONDARY_ID | VARCHAR2 40 | Secondary identifier |
| TEST_TYPE | CHAR 1 | Test type code |
| LOINC_CODE | VARCHAR2 40 | LOINC code for the test (denormalized; useful for HL7/ELR) |
| TEST_NAME | VARCHAR2 59 | Test name (denormalized — skip V_S_LAB_TEST join when only displaying) |
| REPORTED_TEST_NAME | VARCHAR2 30 | Display name for the test on the report |
| INTERPRET_MSG / TEST_INFO_MSG / DELTA_CHECK_FAIL_MSG | VARCHAR2 5 | Reference codes to message templates |
| COMMENTS | CLOB 4000 | Test result comments (PHI-adjacent free text) |
| SPECIMEN_TYPE | VARCHAR2 8 | Specimen type |

#### Dates & Times (numeric/DATE triple pattern continues)

| Column | Type | Description |
|--------|------|-------------|
| TEST_DATE / TEST_TIME / TEST_DT | NUMBER / NUMBER / DATE | Testing timestamp (instrument run time) — prefer `TEST_DT` |
| VERIFIED_DATE / VERIFIED_TIME / VERIFIED_DT | NUMBER / NUMBER / DATE | Verification timestamp — prefer `VERIFIED_DT` |
| COLLECT_DATE / COLLECT_TIME / COLLECT_DT | NUMBER / NUMBER / DATE | Collection timestamp — prefer `COLLECT_DT` |
| RECEIVE_DATE / RECEIVE_TIME / RECEIVE_DT | NUMBER / NUMBER / DATE | Receipt timestamp — prefer `RECEIVE_DT` |
| REFLEX_DATE / REFLEX_TIME / REFLEX_DT | NUMBER / NUMBER / DATE | Reflex timestamp — prefer `REFLEX_DT` |
| UNVERIFIED_DATE / UNVERIFIED_TIME / UNVERIFIED_DT | NUMBER / NUMBER / DATE | Result-rollback timestamp (when a verified result was un-verified). Useful for amendment audits |
| PLATE_DT | DATE | Plating timestamp (microbiology — when specimen was plated for culture). Mirrors RECEIVE_DT in observed micro samples |
| TO_BE_COLLECT_DT | DATE | Scheduled collection time |
| TAT | NUMBER 22 | **EXPECTED TAT from test setup, NOT measured TAT.** Reading this column gives you the SLA target, not the actual elapsed time. Compute measured TAT from `VERIFIED_DT - RECEIVE_DT` (or analogous date arithmetic) |
| DELTA_TIME_RANGE | NUMBER 22 | Delta-check time-window setting |

#### People

| Column | Type | Description |
|--------|------|-------------|
| TECH_ID | VARCHAR2 16 | Technologist code — usage varies by test type. For micro batch results, observed as a workstation/role code (e.g. `'OTHCX'`) rather than a personal ID. For chemistry/heme, expected to hold the actual tech ID |
| TECHNIK_ID | VARCHAR2 16 | **Duplicate of TECH_ID** (legacy German "Techniker" naming). Empty in micro samples; populated elsewhere. Pick one; expect them to match |
| REVIEWER_ID | VARCHAR2 16 | Reviewer code (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |
| UNVERIFIED_TECH | VARCHAR2 16 | Tech who un-verified (rolled back) the result |
| PLATE_TECH | VARCHAR2 16 | Tech who plated the specimen (microbiology) — often the *real* tech identity for micro results |
| PERFORMED_BY | VARCHAR2 5 | Performing-tech short code |

#### Workstations & Locations (with duplicate-column caveats)

| Column | Type | Description |
|--------|------|-------------|
| ORDERING_WORKSTATION_ID | VARCHAR2 5 | Ordering workstation (FK by code → V_S_LAB_WORKSTATION.ID) |
| TESTING_WORKSTATION_ID | VARCHAR2 5 | Testing/performing workstation (FK by code → V_S_LAB_WORKSTATION.ID) |
| TEST_PERFORMING_DEPT | VARCHAR2 5 | Performing department |
| PERFORMING_DEPARTMENT | VARCHAR2 5 | **Duplicate of TEST_PERFORMING_DEPT** (legacy column) |
| TEST_PERFORMING_LOCATION | VARCHAR2 4 | Performing facility (e.g. `TUH`, `JNS`) |
| LOCATION | VARCHAR2 4 | **Duplicate of TEST_PERFORMING_LOCATION** (legacy column) |
| SER_OWNERID | VARCHAR2 5 | Series owner ID |

#### Workflow State Flags (all VARCHAR2 1, Y/N unless noted)

| Column | Description |
|--------|-------------|
| `VERIFIED_FLAG` | Result was signed off / posted. **Persists `'Y'` even after cancellation** — NOT derived from STATE. Use `STATE IN ('Final','Corrected')` for "actually-final results"; `VERIFIED_FLAG = 'N'` for "currently-pending" only when paired with non-Canceled state |
| `SPEC_COLLECTED` | Specimen collected (~94% Y in 7-day sample) |
| `SPEC_RECEIVED` | Specimen received (CHAR 1, ~93% Y in 7-day sample) |
| `SPECIMEN_OVERDUE` | Specimen-overdue flag |
| `WORKSHEETED_FLAG` | Worksheeted |
| `DOWNLOADED_FLAG` | Downloaded to instrument |
| `EDITED_FLAG` | Result edited |
| `POSTED_FLAG` | Posted |
| `REPORTED_FLAG` | Reported |
| `BILLED_FLAG` | Billed |
| `CREDITED_FLAG` | Credited |
| `RERUN_FLAG` | Rerun performed |
| `REFLEX_TEST` / `REFLEX_TEST_ID` | Reflex test flag + parent test code |
| `SERIES_TEST` | Series test flag |
| `RESULT_NOT_CHANGED` | Result unchanged on re-result |
| `IS_AUTORESULTED_WITH_DEFAULT` | Auto-resulted with default value |
| `IS_AUTOVERIFIED_RESULT` | Auto-verified |
| `CALCULATED` | Result is calculated from other tests |
| `WORKFLAG` | Workflow flag |
| `REPORT_TO_HIS` | Report to HIS flag |
| `DONT_SEND_TO_HIS` | Don't send to HIS |
| `TEST_REPORTED` | Test was reported |
| `ABNORMAL_TEST_REPORT` | Abnormal-test report flag |
| `HIDDEN_RESULT` | Hidden result |
| `HIDE_IN_QUERY_CALLIST` | Hide in query call list |
| `D7_REPORTED` / `D_REPORTED` / `T_REPORTED` / `F_REPORTED` | Report status flags (Final-Report sent on `F_REPORTED='Y'`) |
| `INFECTIOUS_TEST` | Infection-control flag |
| `BACI_TEST` | Bactiology/micro flag |
| `MICRO_BILLING_TEST` | Micro-billing flag |
| `PRICE_FROM_RESULT` | Price-from-result flag |
| `SEPARATE_TUBE` | Requires separate tube |
| `SPEC_PLATED_FLAG` | NUMBER 22 — specimen-plated indicator (micro) |
| `PANIC_AS_TOXIC` | Panic-as-toxic interpretation flag |
| `NUMBER_OF_REQUESTED_SPECIMENS` | NUMBER 22 |

#### Result-Range Flags (all VARCHAR2 1, set when result triggers the range)

| Column | Description |
|--------|-------------|
| PANIC_LOW / PANIC_HIGH | Panic range hit (low/high) |
| ABNORMAL_LOW / ABNORMAL_HIGH | Abnormal range hit |
| ABSURD_LOW / ABSURD_HIGH | Absurd range hit |
| PERCENT_DELTA / ABSOLUTE_DELTA | Delta-check fail flags |
| PANIC_REPEATED | NUMBER 22 — panic-repeat counter |
| PANIC_REPEATED_MSG | VARCHAR2 7 — panic-repeat message |
| PANIC_REPEATED_ORDER | VARCHAR2 11 — order# of repeat |

#### Reference Lab

| Column | Type | Description |
|--------|------|-------------|
| PERFORMING_LAB | VARCHAR2 1 | Y = resulted at reference lab. Only ~0.3% of recent rows are Y. **Has NULLs (~0.02%)** — use `COALESCE(PERFORMING_LAB, 'N') <> 'Y'` for inclusive non-send-out filtering |
| REFERENCE_LAB_ID | VARCHAR2 20 | Reference lab identifier |
| REFLAB_TEST_CODE | VARCHAR2 30 | Reference-lab's test code |
| REF_LAB | VARCHAR2 1 | Send-out flag (older Y/N) |
| ATREFLAB / ATREFLABID | VARCHAR2 / VARCHAR2 20 | At-result reference-lab markers |
| REFLAB_INTERP_FLAG / REFLAB_INTERP_FLAG_NAME / REFLAB_INTERP_FLAG_CS / REFLAB_INTERP_FLAG_CSV | VARCHAR2 | Reference-lab interpretation flag + coding-system metadata |
| REFLAB_INTERP_FLAG_NAME_CS / REFLAB_INTERP_FLAG_NAME_CSV | VARCHAR2 | (additional CS variants) |

#### Performing Organization (denormalized — populated for send-outs)

Two parallel column blocks (legacy duplication): `PERFORMING_ORG_*` (cols 167–194) and `PERF_ORG_*` (cols 195–222), each carrying full org address, MD info, and namespace identifiers. **Both blocks are entirely empty for in-house tests** in observed samples; populated when results come from an external performing org. Within each block: `*_ORG_NAME`, `*_ORG_CLIA`, `*_ORG_ADDR1/ADDR2/CITY/STATE/ZIP/COUNTY/COUNTRY/PHONE`, plus performing-MD `*_MD_LNAME/FNAME/MNAME/PREFIX/SUFFIX/PROSUFFIX/AANSID/AAUID/AAUID_TYPE/AFNSID/AFUID/AFUID_TYPE`. `PERFORMING_ORG_CLIA` and `PERF_ORG_CLIA` may be populated for in-house results (own CLIA stamp). Treat the two blocks as redundant; pick one for queries.

#### Interpreter (denormalized — empty for routine results)

Two parallel blocks: `P_R_I_*` (cols 223–231) and `PRI_*` (cols 232–240) for "Principal Reviewing Interpreter." Each holds `*_LNAME/FNAME/MNAME/PREFIX/SUFFIX/PROSUFFIX/AANSID/AAUID/AAUID_TYPE`. Empty in routine samples; populated for path-reviewed/interpreted results. Treat as duplicates — pick one.

#### Reporting & QC State

| Column | Type | Description |
|--------|------|-------------|
| QC_TIME_VIOLATE / BAD_QC_RESULT / QC_TRUE_LOCK / QC_CHECK_ORDER_PRESENT / QC_AT_RESULTING / QC_AT_VERIFICATION / QC_AT_FINAL | VARCHAR2 1 | QC checkpoint flags |
| QC_STATUS | NUMBER 22 | QC overall status code |
| TOURNAROUND_VIOLAT | VARCHAR2 1 | TAT-violated flag (note: schema name has the typo `TOURNAROUND` not `TURNAROUND`) |
| EXCLUDE_FROM_TAT_GRP_CALC | VARCHAR2 1 | **Important for TAT reports** — exclude this row from TAT group calculations |
| EXCLUDE_FROM_TAT_STAT | VARCHAR2 1 | Exclude from TAT statistics |
| WORKLOAD_FOR_DRG / WORKLOAD_FOR_STATS | VARCHAR2 1 | Workload counters |
| NOT_CALLABLE_TEST / NOT_REPORT_TEST | VARCHAR2 1 | Calling/reporting suppression |
| PATH_REVIEW_REQUESTED / PATH_REVIEW_DONE / PATH_REVIEW_REQ_POSIT / DNR_WITHOUT_PATH_REVIEW / SPECIAL_BILL_FOR_PATH | VARCHAR2 1 | Pathology review workflow flags |
| FLAG_NRAD_NEW_RESULT / FLAG_NRAD_REPORTED | VARCHAR2 1 | NRAD (non-radiology?) flagging |
| ORDER_SORT / PATHREVIEW_SORT | NUMBER 22 | Sort positions |
| PROMPT_TYPE | VARCHAR2 1 | Prompt type |

#### Observation / Identification metadata (HL7-style)

| Column | Type | Description |
|--------|------|-------------|
| OBSERVATION_METHOD / OBS_METHOD | VARCHAR2 20 | Observation method code (duplicate columns) |
| OBS_METHOD_NAME / OBS_METHOD_CS / OBS_METHOD_CSV | VARCHAR2 | Method name + coding-system pair |
| OBS_METHOD_NAME_CS / OBS_METHOD_NAME_CSV | VARCHAR2 | (additional CS variants) |
| UNITS_NAME / UNITS_NAME_CS / UNITS_NAME_CSV | VARCHAR2 | Units coded-element triple |
| AAUTH_NAMESPACE_ID / AAUTH_UNI_ID / AAUTH_UNI_ID_TYPE | VARCHAR2 | Assigning authority namespace + universal ID |
| IDENT_TYPE_CODE | VARCHAR2 5 | Identifier type code |
| ADDRESS_TYPE | VARCHAR2 3 | Address type code |
| ATFLAGS / ATUNITS / etc. | VARCHAR2 | At-time-of-result snapshot fields |

#### Empty / Vestigial (DATA_LENGTH = 0 — placeholder columns, never written)

`HIDE_RES_IN_CALLIST` (col 98), `RESULT_SENT_TO_HL7` (col 160). Don't use in queries.

**Notes:**

- **Volume**: ~162K rows/day, ~5M/month. Stick to ≤7 days for full-row dumps.
- **`VERIFIED_FLAG` semantics** (validated 7-day data):
  - `'Y'` for any signed-off result row including ones later cancelled (553K Canceled rows have `VERIFIED_FLAG='Y'` in 7-day sample).
  - `'N'` only for `STATE='Pending'` (1,215 rows, ~0.1%).
  - Use `VERIFIED_FLAG='N' AND SPEC_RECEIVED='Y'` for "received but not yet verified" (the pending-test pattern).
  - Don't use `VERIFIED_FLAG='Y'` as a "show me final results" filter — it includes cancellations.
- **`STATE` distribution** (7-day sample, ~1.14M rows):
  - `Final`: 51% — verified results
  - `Canceled`: 49% — **massive panel-fanout from cancellations**, one cancellation event spawns N component-result rows in Canceled state
  - `Pending`: 0.1% — awaiting verification
  - `Corrected`: 0.07% — amended results
  - `Verified`: not observed (treat as inactive)
  - **Standard "real results" filter: `STATE IN ('Final', 'Corrected')`** — without it, queries are contaminated with ~50% cancellation noise.
- **`TAT` is the SLA target, not measured TAT** — sample shows `TAT=72` (target minutes from setup) on a Final-state row whose actual elapsed time was different. Do not use this column for TAT performance reporting; compute from date arithmetic.
- **Duplicate-column legacy** — pick one of each pair (values match in practice):
  - `TECH_ID` ↔ `TECHNIK_ID`
  - `TEST_PERFORMING_DEPT` ↔ `PERFORMING_DEPARTMENT`
  - `TEST_PERFORMING_LOCATION` ↔ `LOCATION`
  - `OBSERVATION_METHOD` ↔ `OBS_METHOD`
  - `PERFORMING_ORG_*` block ↔ `PERF_ORG_*` block (entire 28-col duplication)
  - `P_R_I_*` block ↔ `PRI_*` block
  - `PERFORMING_ORG_CLIA` ↔ `PERF_ORG_CLIA`
- **Micro vs. chemistry caveat**: in micro batch results, `TECH_ID/TECHNIK_ID` may be a workstation/role code while the actual tech is in `PLATE_TECH`. In chemistry, expect personal IDs in `TECH_ID`/`TECHNIK_ID`.
- **`PERFORMING_LAB` has NULLs** (~0.02%) — use `COALESCE(PERFORMING_LAB,'N')` for inclusive non-send-out filtering.
- **`ORDER_ID` denormalization** — order number is on the result row; skip the V_P_LAB_ORDER join when only the human-readable order# is needed.
- **Micro results** can show `RESULT='PRELIM'` with `STATE='Final'` — multiple Final rows over time as the culture progresses.

**Instrument TAT Analysis Note:** For analyzer/instrument turn-around time, use `TEST_DT` (when instrument ran the test) in combination with `RECEIVE_DT` and `VERIFIED_DT`:
- `RECEIVE_DT` → `TEST_DT` = Time waiting for instrument
- `TEST_DT` → `VERIFIED_DT` = Time from instrument run to verification
- `TESTING_WORKSTATION_ID` identifies which analyzer/instrument ran the test

### V_P_LAB_TEST_RESULT_HISTORY — Test result modification history

**36 columns total** — child of `V_P_LAB_TEST_RESULT`, one row per modification event. Volume: ~236 amendments/day, ~7K rows / 30 days, ~80K rows/year. Base table: `LAB.LAB_ATEST_HISTORY`. ~98.7% of amended results have exactly one amendment in a 30-day window; 1.2% have 2 amendments, 0.1% have 3, none have 4+ (measured chain length, not absolute over a result's lifetime).

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ATEST_AA_ID | NUMBER 22 | FK → V_P_LAB_TEST_RESULT.AA_ID. Base-table column is `ATEST_ATESTHIST` |

#### Modification metadata

| Column | Type | Description |
|--------|------|-------------|
| MOD_DATE / MOD_TIME / MOD_DT | VARCHAR2 / VARCHAR2 / DATE | Modification timestamp (use `MOD_DT`). Numeric pair stored as VARCHAR2 here, not NUMBER as in most other views |
| MOD_TECH | VARCHAR2 16 | Tech who made the modification. **Often a different person from the original verifier** (validated in test-env spot check) |
| MOD_REASON | VARCHAR2 239 | Free-text narrative entered by the amender. **Sparsely populated (~46% of rows)** — half of amendments carry no reason. PHI-adjacent (can carry clinical context like "Patient expired") |
| TYPE | VARCHAR2 11 | **Application-level enum, no DB-side FK** — SCC's compiled binary decides valid values, the database doesn't enforce them. **Verified exhaustive over the full table** (10-year, ~971K rows): `RMOD` 70.6% (Result-value modification — value-change events), `DMOD` 29.3% (non-value edit — range/comment/calc-component trigger; standalone DMODs on Final results have 0/1939 prev_diff_curr in a 30-day sample), `REVMOD` 0.05% (review-related, ~20–130 rows/year). The 30-day RMOD/DMOD ratio (~59/41) is steeper than lifetime because recent years run hotter on DMOD. **No other TYPE value has ever been written.** Note: SCC client's Result Comments → History tab uses different display tags (`RMOD`/`FMOD`) that don't equal this column — see "SCC client History-tab display" subsection below |

#### Prior-state snapshot (the "before" values)

| Column | Type | Description |
|--------|------|-------------|
| PREV_RESULT | VARCHAR2 40 | **The value before this modification.** 100% populated even on non-value edits — must *compare values* to detect "value changed", not null-check. Carries sentinels: `'.'` = cancelled (CLAUDE.md cancellation rule), `'See Comment'` = actual value lives in PREV_COMMENT |
| PREV_COMMENT | CLOB 4000 | Snapshot of the prior comment text. Carries the actual prior value when `PREV_RESULT='See Comment'`. PHI-dense free text |
| UNITS | VARCHAR2 80 | Units snapshot (~79% populated) |
| RANGE_NORMAL / RANGE_LOW / RANGE_HIGH | VARCHAR2 256/32/32 | Reference range snapshot (~64–70% populated) |
| ABNORMAL_FLAGS | VARCHAR2 4000 | Flag string snapshot (~26% populated — sparse) |
| STATUS | VARCHAR2 12 | **Range classification snapshot** — `Normal` ~40%, blank ~34%, `AbnormalHigh` ~10%, `AbnormalLow` ~9%, `Abnormal` ~3%, `PanicHigh` ~3%, `PanicLow` ~2%, `Panic` <0.1%. **Different enum from V_P_LAB_TEST_RESULT.STATE.** Notably populated here while documented as vestigial on the live result table |
| QC_STATUS | NUMBER 22 | QC overall status snapshot |
| TESTING_WORKSTATION_ID | VARCHAR2 5 | Performing workstation snapshot (~76% populated) |
| POSTED_FLAG | CHAR 1 | Posted indicator snapshot (~53% populated) |
| ISPOSTEDINFO_PRESENT | NUMBER 22 | Posted-info presence flag |
| IS_AUTORESULTED_WITH_DEFAULT | VARCHAR2 1 | Auto-result-with-default flag |
| REFLABID | VARCHAR2 20 | Reference-lab id (~99.9% populated — likely empty-string default rather than real ref-lab IDs; verify with `REFLABID IS NOT NULL AND REFLABID <> ''` predicate before use) |

#### Verification triple snapshot

| Column | Type | Description |
|--------|------|-------------|
| VER_DATE / VER_TIME / VER_DT / VER_TECH | VARCHAR2 / VARCHAR2 / DATE / VARCHAR2 | Verification timestamp + tech, snapshotted at mod time. **This is the ORIGINAL verification** — not the post-amendment one. SCC's report engine pulls from these for the on-print correction notice |

#### Resulting triple snapshot

| Column | Type | Description |
|--------|------|-------------|
| RES_DATE / RES_TIME / RES_DT / RES_TECH | VARCHAR2 / VARCHAR2 / DATE / VARCHAR2 | Resulting timestamp + tech, snapshotted at mod time. RES_TECH ~88% populated; rest near 100% |

#### Vestigial / effectively-vestigial

`INTERPRET_MSG` (0%), `INTERPRETER_AA_ID` (0%), `PANIC_REPEATED_MSG` (0%), `PANIC_REPEATED_ORDER` (0%), `ORGANIZATION_AA_ID` (0.16% — 11 of 7,085 rows). Don't use in queries.

**Notes:**

- **Index access path**: composite index `(ATEST_AA_ID, MOD_DT, AA_ID)` (base-table columns `ATEST_ATESTHIST, ATH_MODDT, AA_ID`). The FK to the result row is the leading column. Lookups by `ATEST_AA_ID` are fast (clean range scan); date-only window scans use index skip-scan, which is fine on this small table but would be slower on a larger one.
- **No FK on `TYPE`** — application-level enum. SCC's compiled binary decides valid values; the database doesn't enforce them. Implication: future SCC versions could emit new TYPE values without schema change. The 1-year enum sample (RMOD/DMOD/REVMOD) is informative, not guaranteed exhaustive forever.
- **`PREV_RESULT` is 100% populated even on non-value edits** — comparing PREV_RESULT to either the next history row's PREV_RESULT or the current `tr.RESULT` is the correct way to detect actual value changes. Null-checks won't work.
- **`PREV_COMMENT` carries real prior values** for narrative-style results where PREV_RESULT='See Comment'. Surface it whenever you'd expose PREV_RESULT.
- **`MOD_TECH` ≠ original `VER_TECH`/`RES_TECH` is common** — the amender is often a different person than the original verifier (validated in test-env spot check).
- **Per-view TYPE enums** — `V_P_LAB_ACT_HISTORY` and `V_P_LAB_TUBE_HISTORY` use `MODCOM` only; the RMOD/DMOD/REVMOD vocabulary is specific to test result history.
- **TYPE values are empirically-decoded only** — no `V_S_*` lookup maps them to human descriptions. The closest-named candidate (`V_S_GCM_CORRECTIONDICT`) turned out to be a typo/spell-check dictionary, unrelated.

#### Corrected-result print-notice behavior (chemistry / general reports)

When a result is corrected, SCC's chemistry/general report engine prints a one-line correction notice in the form:

> `Corrected result; previously reported as {h.PREV_RESULT} on {h.VER_DT date} at {h.VER_DT time} by {h.VER_TECH}`

Verified by test-env amendment + cross-search against `V_S_LAB_CANNED_MESSAGE.TEXT`, `tr.COMMENTS`, `h.MOD_REASON`, `h.PREV_COMMENT`, and `V_P_LAB_INTERNAL_NOTE.NOTE_TEXT` — none of those carry this exact template. Conclusion: **the chemistry/general correction notice is hard-coded in SCC's report engine binary**, generated at print time from history-row fields. The data fields it reads are exposed exactly as documented above (`h.PREV_RESULT`, `h.VER_DT`, `h.VER_TECH`).

Note that the printed timestamp is the **original verification time** (`h.VER_DT`), not the amendment time (`h.MOD_DT`). And the printed tech is the **original verifier** (`h.VER_TECH`), not the amender (`h.MOD_TECH`).

Microbiology reports use a *different* notice ("This is a corrected report. Previously reported as:") — that one IS stored in `V_S_LAB_CANNED_MESSAGE` under IDs `&CORR` and `}CORR` (categories `MICI` and `MICT`). Two correction-notice templates exist in this deployment: hard-coded for chemistry/general, canned-message-driven for microbiology.

#### Sibling live-row signals on V_P_LAB_TEST_RESULT

Two columns on the live result row indicate the result has been amended (verified in test env):

- `tr.STATE = 'Corrected'` — status flipped from Final/Pending
- `tr.EDITED_FLAG = 'Y'` — corresponds to the `E` indicator in the SCC client's status column

Both fire on a freshly-amended row. They're effectively redundant for routine corrections; could diverge on edge cases (e.g., a Final result that got tweaked without flipping STATE).

`tr.UNVERIFIED_DT` is also set on amendment, but for atomic amendments (un-verify and re-verify in the same SCC client action) it equals `tr.VERIFIED_DT` — so the gap is zero in those cases. Only useful as a divergence signal for non-atomic amendments.

#### SCC client History-tab display vs. database TYPE

The SCC client's Result Comments dialog has a History tab whose Tag column is a **client-side display label, NOT the database `TYPE` value**. A single `TYPE='RMOD'` database row renders as **two** History-tab entries — one per "half" of the row:

| UI tag | UI text template | Source fields on the DB row |
|--------|------------------|------------------------------|
| `RMOD` | `Previous value was {PREV_RESULT} {UNITS} , verified by {VER_TECH} at {HH:MI} on {MM/DD/YYYY}.` | snapshot half: `PREV_RESULT`, `UNITS`, `VER_TECH`, `VER_DT` (the before-state) |
| `FMOD` | `Revised: Comment was added, verified by {MOD_TECH} at {HH:MI} on {MM/DD/YYYY}` | action half: `MOD_TECH`, `MOD_DT`, plus a populated `MOD_REASON` ("Comment was added" is the client's narrative for "MOD_REASON exists"). The "verified by" wording is misleading — that's actually the *amender*, not a verifier |

Verified empirically against a `TEST_ID='GLU'` corrected result on 2026-04-24 (`ATEST_AA_ID=690477560`): the History tab showed two entries (`RMOD` at 23:07 + `FMOD` at 23:27); the database had **one row** (`TYPE='RMOD'`, `MOD_DT=23:27`, `VER_DT=23:07`). See `setup/test_result_history_probe.sql` §24, §30, §30b.

Implications:
- **Don't expect `FMOD` to appear in the database.** It never has and never will — full-table re-survey returned zero rows in any year 2016–2026.
- **Queries grouping by `TYPE` will show fewer "events" than the History tab does** for users counting UI lines. If you need the UI-grade event count, render two output rows per database row in the same RMOD-snapshot/FMOD-action split.
- **Other database TYPEs (`DMOD`, `REVMOD`) likely have their own client-side display labels too**, but these haven't been characterized — only the RMOD→{RMOD,FMOD} split is verified.

#### Reference query

[orders/corrected_results_audit.sql](orders/corrected_results_audit.sql) shows the canonical join pattern: use `LEAD()` over `(PARTITION BY ATEST_AA_ID ORDER BY MOD_DT)` to compute the "new value" at each amendment from the next chronological PREV_RESULT (falling back to current `tr.RESULT` for the latest amendment). Falsely null-checking PREV_RESULT to detect value changes is wrong — see the `RESULT_VALUE_CHANGED` flag in that query for the correct approach using `DECODE()` for null-safe equality.

#### Outstanding verification

- DMOD specific cause — calculated-test component triggers vs comment-only edits vs range edits. The 30-day correlation (DMOD-on-Final = 0% prev_diff_curr) confirms it's a non-value class but doesn't isolate which sub-cause.
- REVMOD semantics — ~446 rows lifetime (2016–2026), ~20–130/year, too rare to characterize beyond "rare review-related modification."
- DMOD and REVMOD client-side display labels — only the RMOD→{RMOD,FMOD} History-tab split is verified. DMOD and REVMOD likely render with their own labels (and possibly their own split patterns) but haven't been characterized.

### V_P_LAB_PENDING_RESULT — Pending test results

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| TEST_ID | VARCHAR2 5 | Test ID (FK by code → V_S_LAB_TEST_GROUP.ID) |
| SPEC_COLLECTED | VARCHAR2 1 | Specimen collected flag (Y/N) |
| SPEC_RECEIVED | VARCHAR2 1 | Specimen received flag (Y/N) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID |
| TO_BE_COLLECT_DT | DATE | Scheduled collection date/time |

**Note:** This view is for tracking pending/scheduled specimen collections, not finalized results.

### V_P_LAB_SPECIMEN — Specimen data

**72 columns total** — grouped here by category. Volume: ~9.5K rows/day, ~10.5 specimens per patient/week, ~1.5 specimens per order. **`COLLECTION_DT` is a workflow timestamp (no future-scheduling like `V_P_LAB_STAY.ADMISSION_DT`).** Note: ~14 columns are vestigial (DATA_LENGTH = 0) — listed at the bottom but unusable.

#### Identity & Linkage

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| PATIENT_AA_ID | NUMBER 22 | FK → V_P_LAB_PATIENT.AA_ID |
| RECUR_AA_ID | NUMBER 22 | FK → recurring/standing-order pattern (when this specimen comes from a recurring order) |
| RECUR_SORT | NUMBER 22 | Sort position within the recurring pattern |
| SPECIMEN_RECOLLECT_AA_ID | NUMBER 22 | FK → another V_P_LAB_SPECIMEN.AA_ID (when this specimen is a recollection) |

**Note**: there is **no direct ORDER_AA_ID FK on this view** — the link from specimen to order goes through `V_P_LAB_TUBE.ORDER_AA_ID`. The `ORDER_AA_ID` and `ORDER_SORT` columns on this view are vestigial (DATA_LENGTH = 0).

#### Dates & Times (numeric/DATE triple pattern)

| Column | Type | Description |
|--------|------|-------------|
| COLLECTION_DATE / COLLECTION_TIME / COLLECTION_DT | NUMBER / NUMBER / DATE | Collection timestamp — prefer `COLLECTION_DT`. **Never future-dated** (workflow timestamp, not a planning timestamp) |
| RECEIVE_DATE / RECEIVE_TIME / RECEIVE_DT | NUMBER / NUMBER / DATE | Specimen receipt timestamp — `-1` is the "not set" sentinel for the numeric pair |
| RECEIVE_TECH | VARCHAR2 16 | Tech who received the specimen (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |
| COLL_END_DATE / COLL_END_TIME | NUMBER 22 | End-of-collection-window pair (for interval collections) |
| ASSIGNED_DT | DATE | When the specimen was assigned to a phleb. **Observed empty** in 7-day data |

#### Type, Draw, Source

| Column | Type | Description |
|--------|------|-------------|
| SPECIMEN_TYPE | VARCHAR2 12 | Specimen type. Often blank on pre-collection rows (populates at collection time) |
| DRAW_TYPE | VARCHAR2 8 | Draw type. Observed enum (7-day, 66.4K rows): `D` (default/nurse, 45%), `V` (venous, 30%), blank (25%), `A` (arterial, 0.006% — likely blood gas), `URINE` (1 row, anomaly). **Strong correlation: every `D` row has `NURSE_COLL=1` and every non-`D` row has `NURSE_COLL=0`** — `DRAW_TYPE='D'` is a perfect predictor of nurse-collect |
| SOURCE | VARCHAR2 15 | Source code |
| SITE | VARCHAR2 255 | Site description (free text) |
| DRAW_SITE | VARCHAR2 255 | Draw site description |
| SOURCE_SITE | VARCHAR2 256 | Source site (HL7-style coded element) |
| SOURCE_SITE_MOD | VARCHAR2 256 | Source-site modifier |
| TYPE | VARCHAR2 256 | HL7-style type code |
| TYPE_MOD | VARCHAR2 256 | Type modifier |
| ADDITIVE | VARCHAR2 256 | Tube additive |
| BACTI_SPEC | VARCHAR2 1 | Bacteriology specimen flag |
| CAPILLARY | CHAR 1 | Capillary draw flag |
| VENIPUNCTURE | CHAR 1 | Venipuncture flag — **derived from `DRAW_TYPE`**: `Y` when `DRAW_TYPE='V'`, `N` when `DRAW_TYPE='D'` |
| URINE | VARCHAR2 0 | Vestigial (DATA_LENGTH = 0) |

#### Collection State Flags (all VARCHAR2 1, Y/N unless noted)

| Column | Description |
|--------|-------------|
| IS_COLLECTED | Collected (Y=94.3%, N=5.7% in 7-day sample) |
| IS_COLLECTED_BOOL | NUMBER 22 — numeric mirror of `IS_COLLECTED` (`0`/`1` vs `N`/`Y`) |
| IS_CANCELLED | Cancelled (Y=6.4%, N=93.6%) |
| SPEC_CANCEL | VARCHAR2 1 — possibly redundant with `IS_CANCELLED`; not yet semantically separated |
| IS_MICRO | Micro specimen (Y=6.5%, N=93.5%) |
| IS_RECEIVED | CHAR 1 — received flag |
| **NURSE_COLL** | NUMBER 22 — **HL7 OBR[11] flag — authoritative nurse-vs-lab collect signal.** `1` = nurse-collect (OBR[11]='O', 45% in 7-day sample), `0` = lab/phleb-collect (OBR[11]='L', 55%). Per SCC docs (KB 13803, KB 23096). Use as primary classifier — supersedes any inference based on COLLECTION_PHLEB_ID, V_S_LAB_PHLEBOTOMIST.NURSE flag, or SoftID role behavior |

#### Collector / Assignment

| Column | Type | Description |
|--------|------|-------------|
| COLLECTION_PHLEB_ID | VARCHAR2 16 | Collecting phlebotomist (FK by code → V_S_LAB_PHLEBOTOMIST.ID). **The only populated phleb identifier** — populated on 97.1% of specimens. Holds generic role codes like `PHLEB` (default phlebotomist) or `NUR` (nurse) when no individual is recorded |
| ASSIGNED_TO_PHLEB | VARCHAR2 16 | Schema-documented "phleb-this-specimen-was-assigned-to" field, but **observed always NULL in 7-day data (0/66,384)**. Vestigial in current operations — the documented "intent vs. actual" distinction with COLLECTION_PHLEB_ID does not hold in practice |
| ASSIGNED_BY_TECH | VARCHAR2 16 | Tech who did the assigning. Likely also empty (paired with ASSIGNED_TO_PHLEB) |
| ASSIGNED_ROUTE_CLASS | VARCHAR2 15 | Route class for the assignment. Likely empty |
| ASSIGNED_DT | DATE | When assigned. Observed empty |

#### Volume

| Column | Type | Description |
|--------|------|-------------|
| COLLECTION_VOLUME | NUMBER 22 | Planned collection volume. `-1` is the "not specified" sentinel |
| COLLECTED_VOLUME | NUMBER 22 | Actual collected volume (populates after collection) |
| SPEC_EXPECTED_VOLUME | NUMBER 22 | Expected volume from test setup (e.g., 100, 270, 450 mL) |
| SPEC_EXPECTED_VOLUME_UNITS | VARCHAR2 80 | Expected-volume units (e.g., `mL`) |
| DRAW_UNITS | VARCHAR2 80 | Draw units |

#### Workflow & Tracking

| Column | Type | Description |
|--------|------|-------------|
| COLLECTION_LOCATION | VARCHAR2 15 | Depot/facility code at collection (T1, J1, etc.). Populates at collection time |
| COLLECTION_PRIORITY | CHAR 1 | Specimen-level priority — values: `R` (Routine), `S` (Stat) — distinct from order priority |
| COLLECTION_INSTRUCTION | VARCHAR2 8 | Collection instruction code. Can hold a test ID (e.g., `TNIH`) for test-specific collection notes |
| COLLECTION_LIST | NUMBER 22 | Collection list number |
| COLLECTION_MODULE | VARCHAR2 30 | Collection module |
| CURRENT_LOCATION | VARCHAR2 15 | Current specimen tracking location |
| CONTAINERS_NUM | NUMBER 22 | Number of containers |
| FLAGS | NUMBER 22 | Flag bitmask |

#### Free Text & Quality (256-char fields, populated post-collection)

| Column | Type | Description |
|--------|------|-------------|
| CONDITION | VARCHAR2 256 | Specimen condition (e.g., HEMOLYZED, CLOTTED) |
| QUALITY | VARCHAR2 256 | Specimen quality |
| ROLE | VARCHAR2 256 | Role code |

#### Empty / Vestigial (DATA_LENGTH = 0 — schema slots, never written)

`CALL_VERIFIED`, `IS_INTERVAL_COL`, `IS_LABELLED`, `ORDER_AA_ID`, `ORDER_SORT`, `PLATE_DATE`, `PLATE_DT`, `PLATE_FLAG`, `PLATE_TIME`, `PLATE_TECH`, `REQUEST_CALL`, `SHOTS_NUMBER`, `URINE`, `WORKSHEET_ID`, `WRKPOS_NUM`, `WORKSTATION_ID`, `EXEC_PRIORITY`. Don't use these in queries — they're schema slots without storage. Notably:
- `ORDER_AA_ID` here is empty (link is on `V_P_LAB_TUBE.ORDER_AA_ID`)
- All five `PLATE_*` columns are empty (plating data lives on `V_P_LAB_TEST_RESULT.PLATE_DT/PLATE_TECH`)

**Notes:**

- **Volume**: ~9.5K specimens/day, ~1.5 specimens per order, ~10.5 specimens per patient/week (inflated by inpatient daily-draw cohorts).
- **`COLLECTION_DT` is a workflow timestamp** — no future-scheduling like `V_P_LAB_STAY.ADMISSION_DT`. Safe to use for date-range filters without `<= SYSDATE` guards.
- **`ASSIGNED_TO_PHLEB` is operationally vestigial** — never populated in 7-day data. The dict's previous "intent vs. actual" framing was wrong; `COLLECTION_PHLEB_ID` is the only populated phleb identifier.
- **`DRAW_TYPE='D'` ⇔ `NURSE_COLL=1`** — perfect 1:1 correspondence in 7-day data. Either field is a valid nurse-collect classifier; both come from the same Epic OBR[11] signal.
- **`DRAW_TYPE` enum**: `D` (default/nurse, 45%), `V` (venous, 30%), blank (25%), `A` (arterial, rare), `URINE` (anomaly). Note 25% blank rate.
- **`VENIPUNCTURE` is derived from `DRAW_TYPE`** (`Y` when `V`, `N` when `D`) — redundant flag.
- **Pre-collection vs. post-collection populated fields** — for uncollected specimens (`IS_COLLECTED='N'`), most workflow fields are blank: `SPECIMEN_TYPE`, `COLLECTION_LOCATION`, `COLLECTED_VOLUME`, `RECEIVE_DT`, `CONDITION`, `QUALITY`, etc. These populate as the specimen progresses through the workflow.
- **`-1` sentinel** — used in `COLLECTION_VOLUME`, `RECEIVE_DATE`, `RECEIVE_TIME` for "not set" (consistent with V_P_LAB_ORDERED_TEST pattern).
- **`COLLECTION_PHLEB_ID = 'PHLEB'`** is the SCC generic "default phlebotomist" role code, not a real person. Pre-collection specimens commonly carry this generic assignment.

### V_P_LAB_TUBE — Ordered specimen / tube info

**33 columns total** — bridges V_P_LAB_ORDER and V_P_LAB_SPECIMEN. Volume: ~9.1K rows/day, ~1.04 tubes per specimen, ~1.5 tubes per order, **3.68% are aliquots** (PARENT_TUBE_AA_ID populated).

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID. **This is the canonical specimen→order linkage** (the column of the same name on V_P_LAB_SPECIMEN is vestigial) |
| SPECIMEN_AA_ID | NUMBER 22 | FK → V_P_LAB_SPECIMEN.AA_ID |
| PARENT_TUBE_AA_ID | NUMBER 22 | FK → parent V_P_LAB_TUBE.AA_ID (for aliquots/splits). **Use this for aliquot detection — `IS_ALIQUOTED` flag is vestigial** |

#### Tube Identity

| Column | Type | Description |
|--------|------|-------------|
| TUBE_TYPE | VARCHAR2 8 | Tube type code. **80+ distinct values** observed in 7-day data: color codes (GREEN 22%, LAVENDER 16%, GOLD 5.3%, BLUE, GRAY, PNK, etc.), POC virtual (20%), specialty (URPRSV, HEPSYR, MICSTER, MICBLCLT, BLUPLAS), aliquot-marked variants (`*ALQ`/`*AQ` suffix). **Includes literal text value `'NULL'` (5.1%, 3,223 rows) — distinct from database NULL.** Predicates: `WHERE TUBE_TYPE = 'NULL'` for the text vs `WHERE TUBE_TYPE IS NULL` for the database null |
| TUBE_NAME | VARCHAR2 23 | Display name (often lowercase, e.g. `'poc'`). More descriptive than `TUBE_TYPE`; may not exactly mirror the type code |
| TUBE_SUBTYPE | VARCHAR2 8 | Tube subtype |
| TUBE_CAPACITY | NUMBER 22 | Capacity (likely µL — POC virtual tubes show 1000 = 1mL) |
| SPECIMEN_VOLUME | NUMBER 22 | Actual specimen volume |

#### Receipt Workflow

| Column | Type | Description |
|--------|------|-------------|
| RECEIPT_DT | DATE | Receipt date/time (canonical — prefer this) |
| SPECIMEN_RECEIPT_DATE | NUMBER 22 | Receipt date (numeric YYYYMMDD) |
| SPECIMEN_RECEIPT_TIME | NUMBER 22 | Receipt time (numeric HHMM) |
| SPECIMEN_RECEIPT_TECH | VARCHAR2 16 | Receipt tech (FK by code → V_S_LAB_PHLEBOTOMIST.ID). `AUTOV` for auto-verifier system flows (recurring system-user across views) |
| SPECIMEN_RECEIPT_LOCATION | VARCHAR2 11 | Receipt location code |
| DELIVERY_LOCATION | VARCHAR2 20 | Delivery location code |
| PROCESSING_INSTRUCTION | VARCHAR2 8 | Processing instruction code |

#### Shipping & Temperature

| Column | Type | Description |
|--------|------|-------------|
| SHIPPING_CONTAINER | VARCHAR2 8 | Shipping container code |
| TEMPERATURE | CHAR 1 | Temperature code. Observed enum: blank (72%), `A` (Ambient, 25%), `R` (Refrigerated, 2.5%), `F` (Frozen, 0.8%). **Most tubes have no temperature recorded** |
| TEMPERATURE_SHIPPING_ID | CHAR 1 | Shipping temperature code |
| TEMPERATURE_SHIPPING_VALUE | NUMBER 22 | Shipping temperature value |

#### Priority

| Column | Type | Description |
|--------|------|-------------|
| EXEC_PRIORITY | CHAR 1 | Execution priority. Enum: `R` (Routine, 67%), `S` (Stat, 25%), `T` (Timed, 8%); rare `U` (1 row) and blank (12 rows). Same R/S/T pattern as other priority fields |

#### Workflow Flags (all NUMBER 22 — 0/1 numeric, NOT VARCHAR2 Y/N)

| Column | Description |
|--------|-------------|
| `IS_LABELLED` | Labelled flag — meaningful signal: 70% labelled, 30% not. Useful for received-but-not-labeled exception reports |
| `IS_MICRO` | Micro specimen — 6.2% Y. Cross-validates V_P_LAB_SPECIMEN's IS_MICRO=6.5% |
| `IS_DISCARDED` | Discarded — rarely set (0.05% of tubes). Real but tiny signal |
| `FAKE_SPECIMEN_TUBE` | Fake/placeholder — 5.1% of tubes. Independent of `TUBE_TYPE='FAKE1'` (the type-code naming) |
| `IS_ALIQUOTED` | **VESTIGIAL — never set in 7-day data** (0% of 63,625 rows). Use `PARENT_TUBE_AA_ID IS NOT NULL` to detect aliquots |
| `IS_ROBOTIC` | **VESTIGIAL — never set in 7-day data**, despite the system having robotic instruments. Don't trust as an automation indicator |
| `TUBE_PURPOSE` | CHAR 1 — **VESTIGIAL — 100% blank** in 7-day data. Schema slot, never populated |

#### Other

| Column | Type | Description |
|--------|------|-------------|
| LIST_NUMBER | NUMBER 22 | Collection list number — shared across tubes in the same list |
| FLAGS | NUMBER 22 | Flag bitmask — observed `0` in samples |
| COMMENTS | CLOB 4000 | Tube comments |

#### Empty / Vestigial (DATA_LENGTH = 0 — schema slots, never written)

`SPECIMEN_SORT` (col 12), `TUBES_SORT` (col 14). Don't use in queries.

**Notes:**

- **Volume**: ~9.1K tubes/day; ~1.04 tubes per specimen, ~1.5 tubes per order, **3.68% aliquot rate** (PARENT_TUBE_AA_ID populated).
- **Aliquot detection**: use `PARENT_TUBE_AA_ID IS NOT NULL`, NOT `IS_ALIQUOTED` (vestigial).
- **`IS_ROBOTIC` and `TUBE_PURPOSE` are vestigial** in current operations — don't filter on them.
- **Three "vestigial" flags** (`IS_ALIQUOTED`, `IS_ROBOTIC`, `TUBE_PURPOSE`) compose a notable schema-vs-reality gap pattern matching prior discoveries (cf. `ASSIGNED_TO_PHLEB`, `ADMIT_FLAG`, etc.).
- **`TUBE_TYPE = 'NULL'` is a literal text value** (3,223 rows / 5.1%) — distinct from database NULL. Avoid the `IS NULL` vs `= 'NULL'` confusion.
- **`AUTOV` recurs as `SPECIMEN_RECEIPT_TECH`** — same auto-verifier system-user we saw on V_P_LAB_ORDERED_TEST. Global system identity, not view-specific.
- **POC tubes carry minimal data** — virtual tubes have no volume, no parent, no temperature, no shipping; only basic receipt metadata.
- **Column names corrected vs. earlier dictionary**: use `SPECIMEN_RECEIPT_TECH` (not `RECEIPT_TECH`), `SPECIMEN_RECEIPT_LOCATION` (not `RECEIPT_LOC`), `DELIVERY_LOCATION` (not `DELIVERY_LOC`).
- `RECEIPT_DT` (DATE) is the canonical timestamp; `SPECIMEN_RECEIPT_DATE`/`SPECIMEN_RECEIPT_TIME` are the separate numeric date/time components.

### V_P_LAB_MISCEL_INFO — Patient/Stay/Order additional data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| OWNER_ID | VARCHAR2 23 | Owner identifier (joins to V_P_LAB_STAY.BILLING) |
| PATIENT_DATA | VARCHAR2 1 | Flag: record is patient-level data |
| STAY_DATA | VARCHAR2 1 | Flag: record is stay-level data |
| ORDER_DATA | VARCHAR2 1 | Flag: record is order-level data |
| SUB_ID | VARCHAR2 20 | Sub-identifier / field label (e.g., 'Exp Disch') |
| ID | VARCHAR2 20 | Secondary identifier |
| ADD_DATE | NUMBER 22 | Added date (numeric YYYYMMDD format) |
| ADD_TIME | NUMBER 22 | Added time (numeric HHMM format) |
| ADD_DT | DATE | Added date/time (Oracle DATE) |
| ADD_TECH | VARCHAR2 16 | Added by technologist |
| VALUE | VARCHAR2 39 | Stored value |

**Notes:**
- This is a key-value style table for miscellaneous HIS data attached to patients, stays, or orders.
- Join to stays via `OWNER_ID = V_P_LAB_STAY.BILLING`.
- `SUB_ID` acts as the field name/label; `VALUE` holds the data.
- Use `PATIENT_DATA`, `STAY_DATA`, `ORDER_DATA` flags to identify the entity level.

### V_P_LAB_INTERNAL_NOTE — Internal notes (multi-owner)

**14 columns total** — multi-owner notes table covering patient/stay/order/tube/result-level narrative, prompt responses, and reschedule/cancellation context. Volume: ~975 notes/day, 2.6M total rows over ~10 years (earliest 2016-05). Base table: `LAB.LAB_INTERNAL_NOTE`. **Not a discriminated union** — the five owner FK columns are layered hierarchically, not exclusive (~28% of rows have multiple FKs populated, almost always order + tube together).

#### Identity & Owner FKs

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID. **Workhorse FK — populated on 99.98% of rows.** Base-table column is `ACT_NOTES` |
| TUBE_AA_ID | NUMBER 22 | FK → V_P_LAB_TUBE.AA_ID. **Secondary — populated on ~28% of rows, almost always alongside ORDER_AA_ID.** Strongly correlated with `NOTE_CATEGORY = 'S'`. Base-table column is `TUBE_NOTES` |
| TEST_RESULT_AA_ID | NUMBER 22 | FK → V_P_LAB_TEST_RESULT.AA_ID. Sparsely populated (~0.07%). Base-table column is `ATEST_NOTES` |
| PATIENT_AA_ID | NUMBER 22 | FK → V_P_LAB_PATIENT.AA_ID. **Effectively vestigial** — populated on 3 of 2.6M rows. Base-table column is `PAT_NOTES` |
| STAY_AA_ID | NUMBER 22 | FK → V_P_LAB_STAY.AA_ID. **Effectively vestigial** — populated on 2 of 2.6M rows. Base-table column is `PLAB_NOTES` |
| RECUR_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDERING_PATTERN.AA_ID. **Vestigial** — 0 of 2.6M rows. Base-table column is `RECUR_NOTES` |

#### Note content & metadata

| Column | Type | Description |
|--------|------|-------------|
| NOTE_TEXT | VARCHAR2 | Note content (PHI-adjacent free text). 100% populated |
| NOTE_CATEGORY | CHAR 1 | Category enum. Verified distribution: `I` (Internal — HIS prompt responses) ~73%, `S` (Specimen — reschedule/tube-level narrative) ~27%, `A` and `R` 2 rows each (observed-but-edge-case). 100% populated |
| NOTE_TECH | VARCHAR2 16 | User who entered the note. **`HIS` (system identity for the HIS interface) dominates at 71.1%** — majority of internal notes are HIS-generated, not user-entered. Remaining 29% spread across ~1,930 distinct users (3-letter initials like `FFL`, `CCR` and longer codes like `CJONES`, `SMCCO`). 100% populated |
| NOTE_DATE / NOTE_TIME / NOTE_DATETIME | NUMBER / NUMBER / DATE | Standard SCC numeric/DATE triple. Use `NOTE_DATETIME` for date predicates. 100% populated |
| NOTE_CANMSG | VARCHAR2 | **Canned-message reference, pipe-prefix convention** — values like `\|R`, `\|RRES`, `\|Y001`, `\|YPLI`, `\|YPRF` reference IDs in `V_S_LAB_CANNED_MESSAGE`. Two prefix families: `\|Y***` (prompt-response codes, e.g., responses to "TS:Is There a Prepare Order for Surgery?") and `\|R*` (Reschedule-related). Populated on ~17% of rows. Single-line canned-codes |

**Notes:**

- **Hierarchical, not exclusive**: practical join pattern for "all notes on an order" is just `JOIN ON note.ORDER_AA_ID = o.AA_ID` — that catches ~all rows (99.98%). Filtering on `TEST_RESULT_AA_ID` or `STAY_AA_ID` would miss almost everything because those FKs are sparse-to-vestigial.
- **`NOTE_CATEGORY='S'` ⇔ `TUBE_AA_ID IS NOT NULL`** correlates strongly (both ~27% of rows) — Specimen-category notes are the tube-level subset.
- **`NOTE_TECH='HIS'` is the singular system persona** — only 2 of the typical SCC system-identity codes (`HIS`, `SCC`, `AUTOV`, `RBS`) are present in this table, and `HIS` accounts for ~99% of the system-generated rows.
- **`NOTE_CANMSG` is a join key into `V_S_LAB_CANNED_MESSAGE`** — strip or preserve the `|` prefix as needed; SCC's canned-message ID convention treats the `|` as part of the message ID itself (see V_S_LAB_CANNED_MESSAGE notes). The pipe-prefixed canned messages are single-line short codes used as enum-like references.
- **Index access**: every owner FK has its own composite index `(<FK>, NOTE_DT, AA_ID)` — including the vestigial ones. Lookups by any owner level are fast (FK is leading column). Schema is forward-compatible: even unused FKs are indexed in case they get populated later.

#### Sample uses observed

- HIS prompt responses (`NOTE_CATEGORY='I'`, `NOTE_TECH='HIS'`): "TS:Is There a Prepare Order for Surgery?->No", "RCL:Transfusion Indications->Hb < 7…"
- Reschedule narratives (`NOTE_CATEGORY='S'`, real user as NOTE_TECH): "Patient Unavailable; Test rescheduled. Collection has been rescheduled at MM/DD/YYYY HH:MM"
- Cancellation context: "do this later", "Patient is a difficult stick, unable to collect specimen"
- Correction-notice text is **not** stored here (verified by direct text search) — chemistry/general correction notices are hard-coded in SCC's report engine; microbiology correction notices live in `V_S_LAB_CANNED_MESSAGE`.

#### Vestigial

`PATIENT_AA_ID`, `STAY_AA_ID`, `RECUR_AA_ID` are functionally unused in this deployment despite being indexed.

### V_P_LAB_TUBEINFO — Specimen tube info (denormalized)

**13 columns total** — convenience denormalized view bridging tubes to patient demographics for barcode-trace and specimen-lookup workflows. Volume: ~9.8K rows/day. **Treat as a display-convenience view, NOT a source of truth** — several "key" denormalized fields are sparsely populated.

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_ID | VARCHAR2 11 | Order number |
| BARCODE | VARCHAR2 31 | Specimen barcode. **NULL on ~28.7% of rows** in 7-day data (19,765 of 68,824). Filter `WHERE BARCODE IS NOT NULL` for barcoded-only. **Unique when populated** — perfect 1:1 with non-null rows, safe as a join key |
| COLLECTION_DT | DATE | Collection date/time |
| COLLECTION_PHLEB | VARCHAR2 16 | Collecting phlebotomist — **sparsely populated**; for reliable collector identity use `V_P_LAB_SPECIMEN.COLLECTION_PHLEB_ID` (97.1% populated) |
| SPECIMEN_TYPE | VARCHAR2 12 | Specimen type — **frequently empty** even on physical tubes. For reliable specimen type, use `V_P_LAB_SPECIMEN.SPECIMEN_TYPE` |
| TUBE_TYPE | VARCHAR2 8 | Tube type code (matches V_P_LAB_TUBE.TUBE_TYPE) |
| LAST_NAME | VARCHAR2 50 | Patient last name (denormalized from V_P_LAB_PATIENT) |
| FIRST_NAME | VARCHAR2 80 | Patient first name |
| MIDDLE_INITIAL | VARCHAR2 27 | Patient middle initial — usually empty |
| SEX | VARCHAR2 1 | Patient sex — reliably populated |
| DATE_OF_BIRTH | DATE | Patient date of birth — reliably populated |
| MRN | VARCHAR2 23 | Medical record number — reliably populated |

**Notes:**
- **Volume**: ~9.8K rows/day; 1 row per tube. Cohort cross-validates with V_P_LAB_SPECIMEN (6,290 distinct MRNs/week vs SPECIMEN's 6,289).
- **Higher row count than V_P_LAB_TUBE** (~9.8K vs ~9.1K daily) because this filters on `COLLECTION_DT` (when collected) while TUBE filters on `RECEIPT_DT` (when received). Tubes that are collected but not yet received appear here first.
- **`BARCODE` is unique-when-populated**: 49,059 distinct barcodes across 49,059 non-null rows in the 7-day sample. Safe as a join key with `IS NOT NULL` guard. The 28.7% null rate is the gotcha.
- **Reliable demographics** (LAST/FIRST_NAME, SEX, DOB, MRN) — these denormalize cleanly. Use this view if you need patient context attached to a tube without the V_P_LAB_PATIENT join.
- **Unreliable specimen/collector data**: `BARCODE`, `SPECIMEN_TYPE`, `COLLECTION_PHLEB` are sparse. Don't use this view as the source of truth for those fields — use V_P_LAB_SPECIMEN / V_P_LAB_SPECIMEN_BARCODE instead.
- **Barcode-trace queries** that join on BARCODE should expect ~28.7% of recent tubes to fall out due to null barcode. If the goal is "all tubes with patient context," use V_P_LAB_TUBE → V_P_LAB_SPECIMEN → V_P_LAB_PATIENT instead.

### V_P_LAB_SPECIMEN_BARCODE — Tube barcode

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TUBE_AA_ID | NUMBER 14 | FK → V_P_LAB_TUBE.AA_ID |
| ORDER_ID | VARCHAR2 11 | LIS order number |
| CODE | VARCHAR2 31 | Barcode / identifier value |
| SOURCE | CHAR 1 | Source: L=SoftLab, H=HIS, P=SoftPath, R=SoftRad, B=SoftBank, W=SoftMic |
| CODE_TYPE | CHAR 1 | Type: S=Specimen id, B=Barcode, O=Order number |
| RECORDING_DT | DATE | Date/time recorded |

### V_P_LAB_TUBE_LOCATION — Specimen tracking history

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TUBE_AA_ID | NUMBER 14 | FK → V_P_LAB_TUBE.AA_ID |
| STATUS_DESCRIPTION | VARCHAR2 50 | Status: Collected, Transit, Run on Instrument, Resulted, Ordering |
| ARRIVED_DT | DATE | Arrived date/time (timestamp for this tracking event) |
| REGISTERED_BY | VARCHAR2 16 | Tech who performed the action |
| COMMENT_TEXT | VARCHAR2 | Location/tech info (e.g., "R: TIMM by TSB at 02/18/2026 11:05") |
| DEPOT | VARCHAR2 | Facility code (T1, J1, etc.) |
| TYPE_DESCRIPTION | VARCHAR2 | Tube type description |
| TRAY_ID | VARCHAR2 20 | Automation tray ID |
| CARRIER_ID | VARCHAR2 20 | Automation carrier ID |
| LINE_CODE | VARCHAR2 10 | Automation line code |
| OUTLET_CODE | VARCHAR2 10 | Automation outlet code |

**Note:** This table tracks specimen location events including collection, transit between facilities, instrument processing, and final results. The STATUS_DESCRIPTION field is key for identifying transit events (specimens physically moved between locations).

### V_P_LAB_TEST_TO_TUBE — Container receiving information

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| RESULT_AA_ID | NUMBER 14 | FK → V_P_LAB_TEST_RESULT.AA_ID |
| TUBE_AA_ID | NUMBER 14 | FK → V_P_LAB_TUBE.AA_ID |

**Note:** Links test results to the physical tube/container that was used. Join through this view to trace from a result back to its specimen tube.

### V_P_LAB_SPECIMEN_TUBE — Specimen tube info (combined specimen + tube)

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TUBE_AA_ID | NUMBER 14 | FK → V_P_LAB_TUBE.AA_ID |
| SPECIMEN_AA_ID | NUMBER 14 | FK → V_P_LAB_SPECIMEN.AA_ID |

**Note:** Bridges tubes to specimens. Used in specimen counting queries (e.g., SCC_Sample_Eval) to navigate from test results through tubes to distinct specimens: `V_P_LAB_TEST_TO_TUBE.TUBE_AA_ID → V_P_LAB_SPECIMEN_TUBE.TUBE_AA_ID → V_P_LAB_SPECIMEN.AA_ID`.

### V_P_LAB_CANCELLATION — Cancelled test/order/specimen records

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| CANCELLATION_DATE | NUMBER 22 | Cancellation date as YYYYMMDD integer |
| CANCELLATION_TIME | NUMBER 22 | Cancellation time as HHMM integer (leading zero stripped because NUMBER — e.g., `713` = 07:13, `2013` = 20:13) |
| CANCELLATION_DT | DATE | Cancellation timestamp (canonical — prefer over the numeric DATE/TIME pair) |
| TECH_ID | VARCHAR2 16 | Cancelling user (FK → V_S_LAB_PHLEBOTOMIST.ID) |
| REASON | VARCHAR2 1024 | Free-text cancellation reason — see notes |
| ORDERED_TEST_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDERED_TEST.AA_ID (set when an entire ordered test is cancelled) |
| SPECIMEN_AA_ID | NUMBER 22 | FK → V_P_LAB_SPECIMEN.AA_ID (set when a specimen is cancelled) |
| TEST_RESULT_AA_ID | NUMBER 22 | FK → V_P_LAB_TEST_RESULT.AA_ID (set when an individual test result is cancelled) |
| ORDERING_PATTERN_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDERING_PATTERN.AA_ID (set when a standing-order pattern is cancelled) |
| CODE | VARCHAR2 10 | Categorical reason code — schema slot exists but **completely unused in this deployment** (0 of 1.5M rows populated in 3-month sample). REASON is the only classification field actually written. |

**Notes:**
- Active table: ~60.7M rows since 2016-04-27, ~17K cancellations/day.
- **The four FK columns form a discriminated union — exactly one is populated per row** (`ORDERED_TEST_AA_ID` OR `SPECIMEN_AA_ID` OR `TEST_RESULT_AA_ID` OR `ORDERING_PATTERN_AA_ID`); the other three are NULL. The populated FK identifies *what level* was cancelled.
  - **Implication for joins:** `INNER JOIN ... ON pcanc.TEST_RESULT_AA_ID = tr.AA_ID` matches only result-level cancellations and silently skips order-, specimen-, and pattern-level rows. Fine for "cancelled results" reports, wrong for "cancelled orders" reports — for those, join on `ORDERED_TEST_AA_ID` or use `V_P_LAB_ORDERED_TEST.CANCELLED_FLAG`.
  - ~98% of distinct `TEST_RESULT_AA_ID` values have exactly one cancellation row (1:1 in the typical case — joins won't inflate row counts).
- **`REASON` is free text with a partial canned vocabulary**, not an enum:
  - **Canned templates** (top by volume in 3-month sample): "Test Not Performed. Specimen Never Received", "Patient Discharge", "Specimen not collected. Tests not performed", "Patient refused collection.", "Duplicate request.", "Specimen not received", "No sample received.", "Patient is a difficult stick…", "Clotted specimen, test cannot be performed.", "Patient Unavailable; Test rescheduled.", "Wrong Test Ordered.", "Questionable results/new specimen requested.", "Quantity not sufficient.", "Hemolyzed sample".
  - **System-generated**: `RBS_TRGC_CANC` (Rules-Based System trigger), `NOT_COLLECTED_TUBE_COMMENT` (workflow auto-cancel), "Test was canceled by calculation".
  - **Audit-style**: "Cancelled by LASTNAME, FIRSTNAME" appears thousands of times across hundreds of distinct names — system-prepended audit text, not a human-entered reason.
  - **Severe normalization issues**: case variants ("Duplicate" / "duplicate" / "DUPLICATE" / "Dup" / "DUP" / "duplicae" / "Dupp"), trailing-space variants of the same canned reason, embedded RN names and patient context.
  - **For grouping/reporting**: normalize at minimum with `TRIM(UPPER(REASON))` and accept that semantic buckets (e.g., "Duplicate" of any form) need fuzzy/regex bucketing. `CODE` would be the cleaner key but it is empty here.
- **PHI caveat**: `REASON` frequently contains nurse names, patient behaviors ("AMA", "expired", "discharged"), clinical context, and free-form narrative. Treat as PHI-adjacent free text — never paste into shared docs or external tools.

### V_S_LAB_COLL_CENTER — Multisite ordering locations / collection centers

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 11 | Collection center code (joins to V_P_LAB_ORDER.COLLECT_CENTER_ID) |
| SITE | VARCHAR2 5 | Site/facility grouping code (e.g., TEMPLE, JEANES, FOX CHASE) |

**Note:** Used in SCC pivot reports (SCC_Orders_Eval, SCC_Sample_Eval) to group order/specimen volumes by site. The `ID` column maps to `V_P_LAB_ORDER.COLLECT_CENTER_ID`; the `SITE` column provides the higher-level facility grouping for reporting.

### V_S_LAB_CLINIC — Clinic / ordering location setup

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 15 | Clinic code |
| NAME | VARCHAR2 100 | Clinic name |
| ORD_LOCATION_ID | VARCHAR2 15 | Ordering location / collection center ID — the authoritative facility grouping in practice |
| FACILITY | VARCHAR2 20 | Hospital code — NOTE: often blank/null in this system; use ORD_LOCATION_ID instead |
| ACTIVE | VARCHAR2 1 | Active flag (Y/N) |
| BILLING | VARCHAR2 23 | Billing number |
| LICENSE | VARCHAR2 11 | License number |
| SERVICE_TYPE | VARCHAR2 30 | Type of service |
| DOCTOR_ID | VARCHAR2 15 | House physician |
| STREET1–2, CITY, STATE, ZIP, PHONE1, FAX, EMAIL | various | Contact info |

### V_S_LAB_DOCTOR — Doctor setup

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 15 | Doctor ID |
| LAST_NAME | VARCHAR2 50 | Last name |
| FIRST_NAME | VARCHAR2 80 | First name |
| MIDDLE_NAME | VARCHAR2 50 | Middle name |
| TITLE | VARCHAR2 50 | Title |
| CLINIC_ID | VARCHAR2 15 | Main clinic code |
| ACTIVE | VARCHAR2 1 | Active flag (Y/N) |
| TYPE | VARCHAR2 3 | Type: G=DoctorGroup, I=Institution, N=Non staff, S=Staff, T=Temporary |
| SECONDARY_ID | VARCHAR2 15 | Secondary ID |

### V_S_LAB_PHLEBOTOMIST — Collector/phlebotomist setup

| Column | Type | Description |
|--------|------|-------------|
| ID | VARCHAR2 16 | Collector code (matches V_P_LAB_TUBEINFO.COLLECTION_PHLEB, V_P_LAB_TUBE.RECEIPT_TECH, etc.) |
| LAST_NAME | VARCHAR2 51 | Last name |
| FIRST_NAME | VARCHAR2 51 | First name |
| MIDDLE_NAME | VARCHAR2 31 | Middle name |
| STREETI | VARCHAR2 | Street address |
| CITY | VARCHAR2 | City |
| STATE | VARCHAR2 | State |
| ZIP | VARCHAR2 | ZIP |
| PHONE | VARCHAR2 | Phone |
| SSN | VARCHAR2 | SSN |
| NOTES | VARCHAR2 | Notes |
| NURSE | VARCHAR2 1 | Nurse flag (Y/N) — identifies nursing-staff collectors vs. phlebotomists/other |
| ACTIVE | VARCHAR2 1 | Active flag (Y/N) |

**Collector-type decoding:**
- Table mixes individual-user records and generic "role" codes. Generic codes observed: `NUR` (NURSINGSTAFF COLLECTED, NURSE=Y), `PHLEB` (DEFAULT PHLEBOTOMIST, NURSE=N), `PHY` (PHYSICIAN COLLECTED), `PAT` (PATIENT COLLECTED), `UNK` (UNKNOWN COLLECTOR), `SCC` (SCC TESTING ONLY, ACTIVE=N).
- **Full roster is only 57 rows** (10 NURSE=Y, 47 NURSE=N, 56 ACTIVE=Y, 1 ACTIVE=N) — this is not a sample, it is the entire table. **Do NOT treat this as the authoritative collector list** — the real collector workforce appears to flow through Epic/HIS and bypasses this table. Only ~9% of the roster shows up in `V_P_IDN_LOG` monthly, and zero of the 10 NURSE=Y users have SoftID activity.
- `NURSE='Y'` flag IS accurate where populated (Q5 confusion matrix: zero mismatches) — but populated for ~2% of actual collectors. Use as a narrow high-confidence overlay, never as the primary classifier.
- Primary collector classification should come from `V_P_IDN_LOG` behavior + ID name patterns + HIS pass-through detection (see memory `project_unknown_collector_three_signals.md`).
- For collector-type reporting when NURSE flag IS present: Nurse (NURSE='Y'), Other/Generic (ID in `PAT`/`PHY`/`UNK`/`PHLEB`), Phlebotomist (everything else).

### V_S_LAB_LOCATION — Location definition

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| ID | VARCHAR2 7 | Location code |
| NAME | VARCHAR2 60 | Location name |
| DESCRIPTION | VARCHAR2 236 | Location description |
| STREET1 | VARCHAR2 64 | Address line 1 |
| STREET2 | VARCHAR2 64 | Address line 2 |
| CITY | VARCHAR2 40 | City |
| STATE | VARCHAR2 3 | State |
| ZIP | VARCHAR2 11 | Zip code |
| PHONE | VARCHAR2 20 | Phone number |
| FAX | VARCHAR2 20 | Fax number |
| CLIA | VARCHAR2 11 | CLIA number |
| SITE | VARCHAR2 5 | Site code |
| CONTACT | VARCHAR2 47 | Contact name |
| REF_LAB | NUMBER 22 | Reference lab flag |
| REF_ACCOUNT | VARCHAR2 32 | Reference account |
| REF_NOTINTERFACED | NUMBER 22 | Not interfaced flag |
| SENDING_APP | VARCHAR2 20 | Sending application |
| SENDING_FACITILY | VARCHAR2 20 | Sending facility (note: misspelled in database) |
| RECEIVING_APP | VARCHAR2 20 | Receiving application |
| RECEIVING_FACILITY | VARCHAR2 20 | Receiving facility |
| TRANS_FORMAT | VARCHAR2 0 | Transmission format |
| REF_DIALCOM | NUMBER 0 | Reference dialcom |
| IS_FIL | NUMBER 0 | Is file flag |
| PERFORMING_LAB_ID | VARCHAR2 20 | Performing lab ID |
| INTERP_MAN_RES | VARCHAR2 1 | Interpretation manual result flag |
| ADDRTYPE | NUMBER 3 | Address type |
| NAMETYPE | CHAR 1 | Name type |
| COUNTY | VARCHAR2 30 | County |
| COUNTRY | VARCHAR2 30 | Country |
| TELCOM | VARCHAR2 80 | Telecom |
| TELTYPE | VARCHAR2 3 | Telephone type |
| FAXCOM | VARCHAR2 80 | Fax communication |
| NAMEAA | VARCHAR2 20 | Name AA |
| SENDFAC | VARCHAR2 20 | Send facility |
| MD | VARCHAR2 15 | MD code |
| DEPOT | NUMBER 0 | Depot |

**Note:** This view does NOT have an ACTIVE or TYPE column. SENDING_FACITILY is intentionally misspelled in the database (should be SENDING_FACILITY).

### V_S_LAB_TEST_GROUP — Group/orderable test setup

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 5 | Group test code (matches V_P_LAB_ORDERED_TEST.TEST_ID, V_P_LAB_TEST_RESULT.GROUP_TEST_ID) |
| GTNAME_UPPER | VARCHAR2 | Group test name (uppercase) |
| SERIES_TEST | VARCHAR2 1 | Series test flag (Y/N) |
| ANALIZE_COMPS_TOGETHER | VARCHAR2 1 | Analyze components together flag (Y/N) |
| FL_SEND_OUT | VARCHAR2 1 | Send-out flag (Y/N) |
| FL_PRINT_AS_ORDERED | VARCHAR2 1 | Print as ordered flag (Y/N) |
| FL_LAST_LEVEL | VARCHAR2 1 | Last-level flag (Y/N) — indicates test is a leaf/final level in test hierarchy |
| FL_EXPAND_IN_REQ_FORM | VARCHAR2 1 | Expand in request form flag (Y/N) |
| TEST_PREFIX | VARCHAR2 | Test prefix |
| TEST_COUNT | NUMBER | Number of component tests in this group |
| SERIES_LEVEL | NUMBER | Series level (0 = not a series) |
| ACTIVE | VARCHAR2 1 | Active flag (Y/N) |

**Notes:**
- Most group tests have `SERIES_TEST = 'N'`, all flag columns = `'N'`, and `TEST_COUNT = 0` / `SERIES_LEVEL = 0`.
- `FL_LAST_LEVEL = 'Y'` appears on most tests — indicates the test is a terminal/leaf node.
- `ACTIVE` values include `'Y'` and `'N'` — use to filter current orderable tests.
- Component tests within a group are defined in `V_S_LAB_TEST_COMPONENT`.

### V_S_LAB_TEST_COMPONENT — Components of a group test

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TEST_AA_ID | NUMBER 14 | FK → V_S_LAB_TEST_GROUP.AA_ID (parent group test) |
| TEST_SORT | NUMBER 10 | Sort/display order of component within group |
| TEST_ID | VARCHAR2 5 | Group test code (same as V_S_LAB_TEST_GROUP.ID) |
| TEST_NAME | VARCHAR2 59 | Group test name (the parent, not the component) |
| COMPONENT | VARCHAR2 5 | Component test code (FK → V_S_LAB_TEST.ID) |
| TEST_CODE | VARCHAR2 5 | Test code (same as COMPONENT in practice) |
| TEST_PREFIX | CHAR 1 | Test prefix |
| SERIES_TIME | NUMBER 10 | Series time |

**Notes:**
- Join to group: `TEST_AA_ID → V_S_LAB_TEST_GROUP.AA_ID`.
- Join to individual test: `COMPONENT → V_S_LAB_TEST.ID` to get analyte names/details.
- `TEST_ID` and `TEST_NAME` refer to the **parent group**, not the component.
- `COMPONENT` and `TEST_CODE` are identical in practice.

### V_S_LAB_DEPARTMENT — Department definition

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 7 | Department code (joins to V_S_LAB_TEST.DEPARTMENT_ID, V_S_LAB_WORKSTATION.DEPARTMENT_ID) |
| NAME | VARCHAR2 60 | Department name (e.g., CHEMISTRY, HEMATOLOGY, COAGULATION, BLOOD BANK) |
| LOCATION_ID | VARCHAR2 7 | FK → V_S_LAB_LOCATION.ID (facility where this department exists) |
| DESCRIPTION | VARCHAR2 236 | Description |
| TYPE | CHAR 1 | Department type |
| DPTYPE | CHAR 1 | DP type (D in practice) |
| OWNER | VARCHAR2 7 | Owner |
| DPOWNER | VARCHAR2 7 | DP owner |
| EXCLUDED_FROM_CYCLING | VARCHAR2 1 | Excluded from cycling flag |
| MEDICAL_DIRECTOR | VARCHAR2 15 | Medical director |
| EXCLUDED_FROM_BILLING | VARCHAR2 1 | Excluded from billing flag |
| PERFORMED_BY | VARCHAR2 5 | Performed by |
| APPROACHING_MSG | VARCHAR2 7 | Approaching message |
| OVERDUE_MSG | VARCHAR2 7 | Overdue message |

**Notes:**
- Departments are per-facility — e.g., TCHEM (TUH Chemistry), JCHEM (JNS Chemistry), FCHEM (FC Chemistry).
- `LOCATION_ID` identifies the facility: TUH, JNS, FC, EPC, CH, WFH, NE, ADL, TQUC, TQUH, TVIA, THST, etc.
- Section names in NAME: CHEMISTRY, COAGULATION, HEMATOLOGY, POINT OF CARE, REFERENCE LAB, BLOOD BANK, URINALYSIS, MICROBIOLOGY, IMMUNOLOGY, MOLECULAR, PATHOLOGY, CYTOLOGY, VIROLOGY, HLA, BILLING, PHLEBOTOMY, RESEARCH.

### V_S_LAB_WORKSTATION — Workstation definition

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 7 | Workstation code (joins to V_S_LAB_TEST.WORKSTATION_ID) |
| NAME | VARCHAR2 60 | Workstation name |
| DEPARTMENT_ID | VARCHAR2 7 | FK → V_S_LAB_DEPARTMENT.ID |
| LOCATION_ID | VARCHAR2 7 | FK → V_S_LAB_LOCATION.ID (facility) |
| DESCRIPTION | VARCHAR2 236 | Description |
| BARCODE_USED | CHAR 1 | Barcode used flag |
| BARCODE_TYPE | VARCHAR2 4000 | Barcode type |
| BARCODE_LENGHT | NUMBER 5 | Barcode length (misspelled in DB) |
| DEAD_SPACE_VOLUME | NUMBER 10 | Dead space volume |
| DELIVERY_LOCATION | VARCHAR2 20 | Delivery location |
| REF_LAB | NUMBER 5 | Reference lab flag (1 = reference lab workstation) |
| WS_ROCHE_AUTOMATION | VARCHAR2 1 | Roche automation flag |
| STABILITY_PRN | VARCHAR2 79 | Stability PRN |

**Notes:**
- `LOCATION_ID` → V_S_LAB_LOCATION.ID gives the facility for "Labs Performing Test".
- `REF_LAB = 1` identifies reference lab workstations (send-outs).
- `BARCODE_LENGHT` is intentionally misspelled in the database.

### V_S_LAB_TEST_ENVIRONMENT — Test-to-workstation mapping

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TEST_ID | VARCHAR2 5 | Test code (FK → V_S_LAB_TEST.ID) |
| WORKSTATION_ID | VARCHAR2 5 | Workstation code (FK → V_S_LAB_WORKSTATION.ID) |
| ENVIRONMENT | VARCHAR2 3 | Environment code |

**Notes:**
- Many-to-many mapping: one test can be performed at multiple workstations/locations.
- Join chain for "Labs Performing Test": TEST_ENVIRONMENT.WORKSTATION_ID → V_S_LAB_WORKSTATION.LOCATION_ID → V_S_LAB_LOCATION.SITE.

### V_S_LAB_TEST_GROUP_SPECIMEN — Group test specimen/tube requirements

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TEST_AA_ID | NUMBER 14 | FK → V_S_LAB_TEST_GROUP.AA_ID |
| TEST_SORT | NUMBER 10 | Sort order |
| SAMPLE_TYPE | VARCHAR2 12 | Sample/specimen type code (FK → V_S_LAB_SPECIMEN.ID) |
| NUMBER_OF_SAMPLES | NUMBER 10 | Number of samples needed |
| SHIPPING_VOLUME | NUMBER 10 | Shipping volume |
| UNITS | VARCHAR2 40 | Volume units |
| SHIPPING_CONTAINER | VARCHAR2 8 | Shipping container type |
| SHIPPING_TEMPERATURE | CHAR 1 | Shipping temperature |
| TESTS_TO_DISPLAY | VARCHAR2 79 | Tests to display |
| TEST_ID | VARCHAR2 5 | Test ID |
| TEST_NAME | VARCHAR2 59 | Test name |

**Notes:**
- Join: `TEST_AA_ID → V_S_LAB_TEST_GROUP.AA_ID`.
- `SAMPLE_TYPE → V_S_LAB_SPECIMEN.ID` to get human-readable tube NAME.

### V_S_LAB_SPECIMEN — Specimen tube type definitions

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER | PK |
| ID | VARCHAR2 8 | Tube type code (NOT NULL) |
| NAME | VARCHAR2 50 | Tube name (e.g., "Gold SST", "Purple EDTA") (NOT NULL) |
| ACTIVE | VARCHAR2 1 | Active flag |
| CATEGORY | VARCHAR2 1 | Category (NOT NULL) |
| DRAW_UNITS | VARCHAR2 40 | Draw units |
| DRAW_TYPE | VARCHAR2 8 | Draw type |
| ALIQUTING_TUBE | VARCHAR2 8 | Aliquoting tube type |
| PROCESSING_CONTAINER | VARCHAR2 1 | Processing container flag |
| DELIVERY_RACK | VARCHAR2 10 | Delivery rack |
| CAPACITY | VARCHAR2 | Capacity |
| MIN_VOLUME | VARCHAR2 | Minimum volume |
| HAZARD | VARCHAR2 15 | Hazard info |
| TYPE_SOURCE | VARCHAR2 12 | Type source |
| TYPE_MODIFIER | VARCHAR2 12 | Type modifier |
| ROBOTIC | VARCHAR2 | Robotic flag |
| ADDITIVES_PRESERVATIVES | VARCHAR2 9 | Additives/preservatives |

**Notes:**
- `ID` matches `V_S_LAB_TEST_GROUP_SPECIMEN.SAMPLE_TYPE` and `V_S_LAB_TEST_SPECIMEN.COLLECTION_CONTAINER`.
- `NAME` is the human-readable tube description for the compendium.

### V_S_LAB_TEST_SPECIMEN — Test specimen/container requirements (per test/workstation)

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| TEST_AA_ID | NUMBER 14 | FK → V_S_LAB_TEST.AA_ID |
| TEST_SORT | NUMBER 10 | Sort order |
| TEST_ID | VARCHAR2 5 | Test code |
| WORKSTATION_ID | VARCHAR2 5 | Workstation code (container can vary by workstation) |
| TEST_NAME | VARCHAR2 59 | Test name |
| PATIENT_TYPE | CHAR 1 | Patient type |
| COLLECTION_CONTAINER | VARCHAR2 8 | Container code (FK → V_S_LAB_SPECIMEN.ID) |
| COLLECT_SEPARATELY | VARCHAR2 1 | Collect separately flag |
| RUN_ON_COLLECTION | VARCHAR2 1 | Run on collection flag |
| COLLECT_INSTR | VARCHAR2 8 | Collection instructions |
| PROCESSING_CONTAINER | VARCHAR2 8 | Processing container code |
| EXTRA_TUBES | NUMBER 10 | Extra tubes needed |
| PROCESS_SEPARATELY | VARCHAR2 1 | Process separately flag |
| PROCESS_INSTR | VARCHAR2 8 | Processing instructions |
| AGE | NUMBER 10 | Age threshold |
| AGE_UNIT | CHAR 1 | Age unit |
| VOLUME | NUMBER 10 | Required volume |
| ADD_UP_VOLUME | NUMBER 10 | Additive volume |

**Notes:**
- Maps tests to collection containers at the **test + workstation** level (more granular than group specimen).
- `COLLECTION_CONTAINER → V_S_LAB_SPECIMEN.ID` for tube name lookup.
- Same test may have different containers at different workstations (e.g., PTSEC uses BLUE at most sites but BLUPLAS at TCOAG).
- Use as fallback when `V_S_LAB_TEST_GROUP_SPECIMEN` has no rows for a group test.

### V_S_LAB_TUBE_CAPACITY — Tube type capacity/volume specs

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER | PK |
| CAPACITY | NUMBER | Tube capacity |
| MIN_VOLUME | NUMBER | Minimum volume |
| VOL_COMMENT | VARCHAR2 79 | Volume comment |
| SPECIMEN_ID | VARCHAR2 8 | FK → V_S_LAB_SPECIMEN.ID (NOT NULL) |
| CAPACITY_100 | NUMBER | Capacity (×100) |
| MIN_VOLUME_100 | NUMBER | Minimum volume (×100) |

**Notes:**
- Child of `V_S_LAB_SPECIMEN` — provides capacity/volume specs per tube type.
- Not a container name lookup table — use `V_S_LAB_SPECIMEN` for tube names.

### V_S_LAB_TERMINAL — Device/terminal registration per collection center

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| COLL_CENTER_ID | VARCHAR2 11 | FK → V_S_LAB_COLL_CENTER.ID (collection center this device belongs to) |
| TERMINAL | VARCHAR2 7 | Device/terminal ID (per-PC or per-device short code) |
| NAME | VARCHAR2 51 | Device description / long name |
| FORCEBYTERM | VARCHAR2 | "Force by terminal" flag |

**Notes:**
- This IS the device-level registry — one row per physical PC/terminal, each mapped to a `COLL_CENTER_ID`.
- **Do NOT confuse with `V_S_LAB_SPTR_SETUP.TERMINAL`** — that column stores *location* codes (T1, J1, F1, etc.), not device IDs. To compare specimen-tracking setup between two devices, look up each device's `COLL_CENTER_ID` here first, then feed those values into `V_S_LAB_SPTR_SETUP.TERMINAL`.

### V_S_LAB_SPTR_SETUP — Specimen tracking setup (per terminal)

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| POSITION | VARCHAR2 | Row position / ordering within the terminal's tracking screen |
| SETUP_OPTION | NUMBER 22 | Setup option code |
| LOCATION | CHAR 1 | Location code |
| CONTAINER | VARCHAR2 8 | Container type restriction |
| LOC_DEPT_WRKSTN | VARCHAR2 | Location / department / workstation scope |
| TERMINAL | VARCHAR2 11 | Scope for this setup row — per SCC manual, may be **(a)** a specific terminal ID (FK → V_S_LAB_TERMINAL.TERMINAL), **(b)** an OL/CC / Region code (FK → V_S_LAB_COLL_CENTER.ID — e.g., T1, J1, F1, C1, TREM, QUEST), or **(c)** `*` for global. Most rows in practice are OL/CC-scoped. |
| STATUS | VARCHAR2 8 | Specimen status filter for this row |
| PLACE | VARCHAR2 11 | Place code (FK → V_S_LAB_SPTR_STOP.PLACE) |
| TYPE | CHAR 1 | Setup type |
| ACTIONS | VARCHAR2 29 | Actions enabled on this setup row |
| HIDE | VARCHAR2 1 | Hide flag (Y/N) — controls whether this row is hidden at this location |

**Notes:**
- **`TERMINAL` column is the scope key** — can be a specific device ID (FK → V_S_LAB_TERMINAL.TERMINAL), an OL/CC code (FK → V_S_LAB_COLL_CENTER.ID like T1, J1, F1, TREM, QUEST), or `*` for global. In practice most rows are OL/CC-scoped.
- **Diagnosing a "broken" terminal (per SCC manual workflow):**
  1. Find the PC's actual terminal ID (SoftLab client Help → About, or INI/registry on the PC — not stored in the DB).
  2. Verify in `V_S_LAB_TERMINAL` that the ID is registered to the correct `COLL_CENTER_ID`.
  3. Query `V_S_LAB_SPTR_SETUP WHERE TERMINAL = <id>` — returns device-specific overrides (often empty).
  4. Query `V_S_LAB_SPTR_SETUP WHERE TERMINAL = <coll_center_id>` — returns the OL/CC-scoped rows the device inherits.
  5. Also include `TERMINAL = '*'` rows for globally-scoped stops.
  6. If two PCs share COLL_CENTER_ID and neither has device-specific rows, SPTR is identical and the broken-vs-working difference is outside SCC (client INI, printer/scanner drivers, hostname-derived terminal ID misregistration, etc.).
- Fix path if setup IS missing: SoftLab → Specimen Tracking Setup → Specimen Setup tab (F7 Edit), use **Copy Group / Find > Copy** to clone a known-good terminal's rows onto the broken one.
- Join `V_S_LAB_SPTR_SETUP.PLACE = V_S_LAB_SPTR_STOP.PLACE` to get specimen status/location rules for a place.
- Confirmed location codes in production: Temple (T1–T7), Jeanes (J1–J2), Fox Chase (F1–F3), Chestnut Hill (C1–C2), Episcopal (E1), Women & Families (W1–W2), instruments (TREM), reference labs (QUEST), plus service-area codes (EACT, ECLIN, TACC1, etc.).

### V_S_LAB_SPTR_STOP — Specimen tracking stop/place definition

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| SPECIMEN_STATUS | VARCHAR2 8 | Specimen status code this stop applies to |
| SPECIMEN_LOCATION | CHAR 1 | Specimen location code |
| PLACE | VARCHAR2 11 | Place code (unique stop identifier) |
| DESCRIPTION | VARCHAR2 29 | Stop description |
| ACTIONS | VARCHAR2 29 | Default actions at this stop |
| PHYSICAL_LOCATION_TYPE | CHAR 1 | Physical location type |
| PHYSICAL_LOCATION_CODE | VARCHAR2 7 | Physical location code |
| TIME_LIMIT | VARCHAR2 | Max allowed time at this stop |
| SORT | VARCHAR2 5 | Sort order |
| NEXT_STATUS | VARCHAR2 8 | Next specimen status (workflow transition) |
| NEXT_LOCATION | CHAR 1 | Next specimen location |
| NEXT_PLACE | VARCHAR2 11 | Next place in workflow |
| CONTAINER_TYPE | VARCHAR2 8 | Container type restriction |
| WORKSTATION | VARCHAR2 | Workstation at this stop |
| LIST_AVAILABLE | VARCHAR2 1 | List-available flag (Y/N) |
| NEW_LIST_DAILY | CHAR 1 | New-list-daily flag |
| REMOTE_RECEIVING_ONLY | VARCHAR2 1 | Remote-receiving-only flag |
| WORKSTATION_IS_IN_TYPE | CHAR 1 | Workstation-in-type flag |

**Notes:**
- Defines the specimen-tracking workflow: each PLACE has a specimen status + location and points to the NEXT_STATUS/NEXT_LOCATION/NEXT_PLACE.
- Join via `V_S_LAB_SPTR_SETUP.PLACE = V_S_LAB_SPTR_STOP.PLACE` to link a terminal's setup rows to the workflow rules.

### V_S_LAB_SPTR_LOCATION — Specimen tracking location codes

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| POSITION | CHAR 1 | Sort position |
| CODE | CHAR 1 | Location code (single character) |
| DESCRIPTION | VARCHAR2 29 | Location description |
| HELP | VARCHAR2 7 | Help text |
| LOOKUP | VARCHAR2 7 | Lookup key |
| LOCATION_COMMENT | VARCHAR2 29 | Comment |

### V_S_LAB_SPTR_STATUS — Specimen tracking status codes

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| POSITION | VARCHAR2 8 | Sort position |
| CODE | VARCHAR2 8 | Status code |
| DESCRIPTION | VARCHAR2 29 | Status description |
| NOT_UNIQUE_WARNING_FLAG | CHAR 1 | Not-unique-warning flag |

### V_S_LAB_TEST — Individual/component test setup

Large table (100+ columns). Key columns grouped by category below.

#### Identity & Classification

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK (NOT NULL) |
| ID | VARCHAR2 5 | Test code (matches V_P_LAB_TEST_RESULT.TEST_ID) |
| NAME | VARCHAR2 55 | Test name |
| NAME_UPPER | VARCHAR2 236 | Test name (uppercase) |
| NAME_REPORTABLE | VARCHAR2 | Reportable name |
| ACTIVE | CHAR 1 | Active flag |
| TYPE | VARCHAR2 1 | Test type |
| SECONDARY_ID | VARCHAR2 46 | Secondary identifier |
| THIRD_ID | VARCHAR2 46 | Third identifier |
| LOINC | VARCHAR2 46 | LOINC code |
| BARCODE | NUMBER 10 | Barcode number |
| RESULT_TYPE | VARCHAR2 | Result type |
| METHODOLOGY | CHAR 1 | Methodology code |
| METHOD_CODE | VARCHAR2 11 | Method code |
| WORKSTATION_ID | VARCHAR2 5 | Default workstation |
| DEPARTMENT_ID | VARCHAR2 5 | Default department |
| LOCATION_ID | VARCHAR2 | Default location |
| CONTAINER_ID | VARCHAR2 | Container ID (ref lab/aliquot containers, NOT collection tubes — use V_S_LAB_TEST_GROUP_SPECIMEN or V_S_LAB_TEST_SPECIMEN for collection containers) |
| SPEC_TYPE | VARCHAR2 | Specimen type |
| INDIVIDUAL | CHAR 1 | Individual test flag |

#### Units, Calculation & Precision

| Column | Type | Description |
|--------|------|-------------|
| UNITS | VARCHAR2 80 | Result units |
| PRECISION | NUMBER | Decimal precision |
| PRECISION_POSITIVE | CHAR 1 | Positive precision flag |
| CALCULATE | VARCHAR2 239 | Calculation formula |
| SIGN_FIGURES | NUMBER | Significant figures |

#### QC Flags (VARCHAR2 1)

| Column | Description |
|--------|-------------|
| QC_DISPLAY_WARNING | Display QC warning |
| QC_TRUE_LOCK | True lock on QC failure |
| QC_CHK_ORDER | Check QC at order |
| QC_AT_RESULT | Check QC at result |
| QC_AT_VERIFICATION | Check QC at verification |
| QC_AT_FINAL | Check QC at final |
| QC_INVENTORY | QC inventory check |
| QC_TIME_CHART | QC time chart |

#### Feature Flags (all VARCHAR2 1)

| Column | Description |
|--------|-------------|
| FL_REF_RANGES | Has reference ranges |
| FL_AGE_RANGES | Has age-based ranges |
| FL_NOT_IN_TAT_CALC | Exclude from TAT calculation |
| FL_NOT_IN_TAT_STAT | Exclude from TAT statistics |
| FL_NOT_IN_CALL | Exclude from call list |
| FL_CAN_ORDER_STAT | Can order as stat |
| FL_CAN_ORDER_URGENT | Can order as urgent |
| FL_CAN_ORD_INDIV | Can order individually |
| FL_MEDICARE_EXPER | Medicare experiment flag |
| FL_REFRANGECASTDNC | Reference range cast dance (?) |
| FL_AUTOEXPIRY | Auto-expiry enabled |
| FL_AUTOREPORTABLE | Auto-reportable |
| FL_AUTORESULT | Auto-result enabled |
| FL_HIDDEN | Hidden from ordering |
| FL_HIDDEN_FOR_CALL | Hidden from call list |
| FL_DIAG_REQ_AT_ORD | Diagnosis required at order |
| FL_PRICE_IN_BILL | Show price in bill |
| FL_PRICE_IN_RES | Show price in result |
| FL_PROOF | Proof flag |
| FL_DONOTREPORT | Do not report |
| FL_RES_NECESS_AT_ORD | Result necessary at order |
| FL_NO_EXTRA_CHARGE | No extra charge |
| FL_USE_FOR_PATH | Use for pathology |
| FL_PRINT_MEDIA_LABEL | Print media label |
| FL_PRINT_MIC_TEST_LABEL | Print micro test label |
| FL_SPLIT_TEST_ON_REP | Split test on report |
| FL_PATH_REVIEW | Path review required |
| FL_PATH_REVIEW_ABN | Path review on abnormal |
| FL_PATH_REVIEW_PANIC | Path review on panic |
| FL_PATH_REVIEW_RANGE | Path review on range |
| FL_ELR_RESULT_REPORTABLE | ELR result reportable |
| FL_ELR_ORDER_REPORTABLE | ELR order reportable |
| FL_ENFORCE_RESULT_PRECISION | Enforce result precision |
| FL_DO_NOT_MERGE_ST_ORDERS | Do not merge standing orders |
| FL_MANUAL_MERGE_DO_NOT_MERGE | Manual merge — do not merge |
| FL_CALL_NURSE_PANIC | Call nurse on panic |
| FL_PAT_REW_ON_MIC_POS | Patient review on micro positive |
| FL_DISPL_PROMPT_CYCL_TESTS | Display prompt for cycling tests |
| FL_PRIMARY_CERT | Primary certification |
| FL_CATEGORY | Category flag |
| FL_ASSIGN_COLLECTING | Assign collecting flag |
| FL_IS_FOREIGN_BBANK_PRODUCT | Foreign blood bank product |
| HOLD_AUTOVERIFY | Hold auto-verify |
| HOLD_AUTOVERIFICATION | Hold auto-verification |
| INDICATE_AS_REPORTABLE | Indicate as reportable |
| IS_PRINT_LAB_PROMPT_RESULT | Print lab prompt result |
| IS_NUM_OF_SPECIMENS | Number of specimens flag |

#### CPT / Billing Codes

| Column | Type | Description |
|--------|------|-------------|
| CPT_BASIC_CODE_1–8 | VARCHAR2 | CPT basic codes (up to 8) |
| CPT_ALTERNATE_CODE_1–8 | VARCHAR2 | CPT alternate codes (up to 8) |
| CPT_EXP_DATE_1–8 | VARCHAR2 | CPT expiration dates (up to 8) |
| BILLING_CODE_1–8 | VARCHAR2 | Billing codes (up to 8) |
| FEE | VARCHAR2 | Fee amount |

#### Specimen & Shipping

| Column | Type | Description |
|--------|------|-------------|
| VOLUME | NUMBER | Required volume |
| ADD_UP_VOLUME | NUMBER 10 | Additive volume |
| DRAW_UNITS | VARCHAR2 | Draw units |
| SPECIMEN_DRAW_TYPE | VARCHAR2 | Specimen draw type |
| COLLECTION_CONTAINER | VARCHAR2 | Collection container |
| SHIPPING_TEMP | VARCHAR2 | Shipping temperature |
| SHIPPING_CONTAINER | VARCHAR2 | Shipping container |
| SHIPPING_UNITS | VARCHAR2 46 | Shipping units |
| SHIPPING_VOLUME | NUMBER 10 | Shipping volume |
| REFLAB_TEMP | CHAR | Reference lab temperature |
| EXTERNAL_TEMP | CHAR | External temperature |
| EXTRAMURAL_TEMP | CHAR | Extramural temperature |
| INTRAMURAL_TEMP | CHAR | Intramural temperature |
| MIN_VOL_ANALYSIS | NUMBER 10 | Minimum volume for analysis |

#### TAT Limits

| Column | Type | Description |
|--------|------|-------------|
| TAT_STAT | NUMBER 5 | TAT limit — stat priority |
| TAT_URGENT | NUMBER 5 | TAT limit — urgent priority |
| TAT_TIMED | NUMBER 5 | TAT limit — timed/routine priority |
| DELTA_TIME_RANGE | NUMBER 5 | Delta time range |

#### Result Ranges (all NUMBER)

| Column | Description |
|--------|-------------|
| NORMAL_FLOW / NORMAL_FHIGH | Normal range — female (low/high) |
| NORMAL_MLOW / NORMAL_MHIGH | Normal range — male (low/high) |
| PANIC_FLOW / PANIC_FHIGH | Panic range — female (low/high) |
| PANIC_MLOW / PANIC_MHIGH | Panic range — male (low/high) |
| ABSURD_FLOW / ABSURD_FHIGH | Absurd range — female (low/high) |
| ABSURD_MLOW / ABSURD_MHIGH | Absurd range — male (low/high) |
| DELTA_F_NORM / DELTA_F_HIGH | Delta — female (normal/high) |
| DELTA_A_LOW / DELTA_A_NORM / DELTA_A_HIGH | Delta — all (low/normal/high) |
| GAP_STAT_WEIGHT | Gap stat weight |

#### Range Messages (all VARCHAR2 5)

| Column | Description |
|--------|-------------|
| MES_ABNORMAL_LOW / MES_ABNORMAL_HIGH | Message for abnormal result |
| MES_PANIC_LOW / MES_PANIC_HIGH | Message for panic result |
| MES_ABSURD_LOW / MES_ABSURD_HIGH | Message for absurd result |
| MES_TEST_COMMENT | Test comment message |

#### Labels, Reporting & Misc

| Column | Type | Description |
|--------|------|-------------|
| LBL_TEXT_1–3 | VARCHAR2 | Label text lines |
| RLAB_REP_TID | VARCHAR2 | Reference lab report TID |
| RLAB_TST_TYPE | VARCHAR2 | Reference lab test type |
| RLAB_RANGE | VARCHAR2 | Reference lab range |
| FREQUENCY | VARCHAR2 | Testing frequency |
| KEYPAD | VARCHAR2 | Keypad code |
| RESULT_KEYPAD | VARCHAR2 5 | Result keypad |
| MIC_REV_KEYPAD | VARCHAR2 5 | Micro review keypad |
| DELTA | VARCHAR2 | Delta check code |
| DELTA_DT_UNIT | NUMBER | Delta date unit |
| CALL_SIGNIF | VARCHAR2 | Call significance |
| COMMAND | VARCHAR2 79 | Command/macro |
| DEFAULT_RESULT | VARCHAR2 46 | Default result value |
| DEFAULT_SOURCE | VARCHAR2 | Default source |
| MESSAGE_FORMULARY | VARCHAR2 5 | Message formulary code |
| OBSERVATION_METHOD | VARCHAR2 | Observation method |
| COMMENTS_AND_TAGS | VARCHAR2 | Comments and tags |
| TRC_THRE | VARCHAR2 | Trace threshold (?) |

**Notes:**
- `FL_NOT_IN_TAT_CALC = 'Y'` excludes a test from TAT calculations — important for TAT reports.
- `TAT_STAT`, `TAT_URGENT`, `TAT_TIMED` define expected TAT limits per priority.
- Range columns (PANIC, ABSURD, NORMAL) are split by sex: `*_FLOW`/`*_FHIGH` (female), `*_MLOW`/`*_MHIGH` (male).
- CPT_BASIC_CODE_1–8 are **NOT populated** in this system. Use `V_S_ARE_BILLRULES.BRCPTCODE` (joined via `BRTSTCODE = test component ID`) as the authoritative CPT source.
- Many FL_ flags are `'N'` by default. Key flags for reporting: `FL_NOT_IN_TAT_CALC`, `FL_AUTOREPORTABLE`, `FL_HIDDEN`, `FL_DONOTREPORT`.
- Join to group tests via `V_S_LAB_TEST_COMPONENT` (component → group relationship).

### V_S_LAB_CANNED_MESSAGE — Canned message setup (cross-module shared)

**10 columns total** — the SoftLab view layer over SCC's cross-module canned-message store. Volume: 9,144 rows / 2,418 distinct message IDs, ~3.78 lines per message on average. Base table: `LAB.HLSYS_MESSAGE` (the `HLSYS_` prefix denotes a cross-module SCC system table — other modules likely have their own views over the same base table).

#### Columns

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER | PK |
| ID | VARCHAR2 | Message identifier. **Special-character first-character convention** distinguishes system-reserved messages from user-defined: see ID-prefix table below. Base-table column is `MESID` |
| LINE_NUMBER | NUMBER | 0-based line number for multi-line templates. ~45% of messages are single-line (LINE_NUMBER=0 only); ~55% span 2+ lines, with a long tail to 52 lines. Always concatenate by LINE_NUMBER order to assemble full text. Base-table column is `MESLINENO` |
| TEXT | VARCHAR2 | Message text content. May be display text ("Ref.Range not available.") OR SCC's expression/scripting language (`$A:=@MPV->"AGE"/365.25;`, `MATCH("PERFORMED",$@MDIFP)?$@SEGM:$@SEGA`) — the script-language rows are part of SCC's macro/template engine, not human-readable narrative. 100% populated |
| ACTIVE | VARCHAR2 1 | Y/N. ~85% active, ~15% inactive |
| EXP_DATE / EXP_DT | NUMBER / DATE | Expiration date (numeric pair + DATE). ~23% of rows are past their EXP_DT. ACTIVE and EXP_DT are independent dimensions (some active rows have past expiration dates and vice versa). Base-table column is `MESEXDT` |
| NEW_LINE | VARCHAR2 1 | Newline indicator. The only column with any nulls (~16% blank); rest are 100% populated |
| CATEGORY | VARCHAR2 | Category enum — see distribution table below |
| DISCARD_CONTAINER | VARCHAR2 | Discard-container marker (100% populated, semantics unverified) |

#### CATEGORY enum (verified, 18 values)

Top buckets (CATEGORY / row_count / distinct messages / avg lines):

| CATEGORY | Rows | Messages | Avg lines | Notes |
|----------|------|----------|-----------|-------|
| OTHER | 3450 | 979 | 3.5 | Generic / uncategorized — biggest bucket |
| TEST | 2742 | 366 | 7.5 | Test-related canned text. Longest avg messages — narrative-heavy |
| RESUL | 2250 | 693 | 3.2 | Result-related (canned result narratives, panic-call templates) |
| MICI | 260 | 108 | 2.4 | Microbiology Internal/Interim. Holds `&CORR` — micro corrected-report notice |
| MICT | 167 | 102 | 1.6 | Microbiology Test. Holds `}CORR` — alternate micro corrected-report notice |
| REPO | 101 | 26 | 3.9 | Report format |
| OECAN | 36 | 36 | 1.0 | Order-entry cancellation. Single-line each |
| MICD / PHREC / RNG / SPEC / ORDER / MICOE / PHCAN / MICM / STAY / INSUR / OESCH | 1–27 each | <30 each | varies | Edge categories |

Top 3 (OTHER, TEST, RESUL) cover ~93% of rows. Domain-prefix families:
- **MIC*** — Microbiology subcategories (5 categories): MICI, MICT, MICD, MICOE, MICM
- **PH*** — Phlebotomy/Patient: PHREC (Recall), PHCAN (Cancel)
- **STAY**, **INSUR**, **OESCH** — minimal-row edge categories

#### ID prefix convention (system-reserved vs user-defined)

Special-character first character marks system-reserved messages — confirmed pattern across ~31% of rows (~43% of distinct message IDs):

| Prefix | Rows | Distinct messages | Use |
|--------|------|-------------------|-----|
| `@` | 2,250 | 693 | Largest system family. `@CRR` lives here (corrected-result call-back notice) |
| `&` | 260 | 108 | `&CORR` lives here (microbiology corrected-report notice) |
| `}` | 167 | 102 | `}CORR` lives here (alternate microbiology corrected-report notice) |
| `\|` | 136 | 127 | Single-line short codes referenced by `V_P_LAB_INTERNAL_NOTE.NOTE_CANMSG` (`\|R`, `\|RRES`, `\|Y001`, `\|YPLI`, etc.) |
| `#` | 27 | 10 | Smaller system family |
| `{` | 11 | 7 | Smaller system family |

Alphanumeric-prefix IDs (~69% of rows) are user-defined. Notably:
- `T` prefix: 2,742 rows / 366 messages — corresponds heavily with the TEST category
- Numeric prefixes (`1`, `2`, `3`) and rare letters (`X`, `Q`, `O`, `Y`, `Z`) are tail edge cases

#### Indexes (base table HLSYS_MESSAGE)

- `HLSYS_MESSAGE_AA_ID_PK` (UNIQUE) — `AA_ID`
- `HLSYS_MESIDEXP_UNIQ` (UNIQUE) — `(MESID, MESEXDT, MESLINENO)` — composite unique on (ID, expiration date, line number). Same logical message ID can be stored across multiple expiration windows (each version carries its own LINE_NUMBER lines) — this is how SCC versions canned templates over time
- `HLSYS_MESID_INDEX` (NONUNIQUE) — `(MESID, AA_ID)` — for fast lookups by message ID

#### Notes

- **Cross-module shared**: the `HLSYS_` base-table prefix means this is a global SCC resource, not SoftLab-specific. The BloodBank module has its own canned-message setup (`Y_Canned_Message` in legacy SCC docs, `V_S_BB_Y_Canned_Message` in the modern view layer) over a separate base table.
- **TEXT can be either narrative or expression-language** — when filtering for human-readable messages, expect to see SCC macro syntax (`$@VAR`, `$A:=...`, `MATCH(...)?...:...`) mixed in with display strings.
- **Versioning via composite UNIQUE**: the same `ID` + `LINE_NUMBER` can appear multiple times if the rows have different `EXP_DT` values. To get the currently-active version of a multi-line message, filter on `ACTIVE='Y' AND (EXP_DT IS NULL OR EXP_DT >= SYSDATE)` and ORDER BY `LINE_NUMBER`.
- **Join key from V_P_LAB_INTERNAL_NOTE**: `note.NOTE_CANMSG` carries the full pipe-prefixed ID (`|R`, `|RRES`, etc.) — verify whether the `|` is preserved or stripped on the canned-message side before joining.
- **Two correction-notice families coexist** in this deployment: chemistry/general uses a hard-coded template (not stored here); microbiology uses canned messages (`&CORR` / `}CORR` here). See V_P_LAB_TEST_RESULT_HISTORY notes for the full correction-notice landscape.

---

## Blood Bank (SoftBank) Views — Detail

### V_P_BB_BB_Order — Blood bank order

**45 columns total** — central entry point of the SoftBank module. Volume: ~287 orders/day (~4.5% of SoftLab volume). **80% of rows are patient-linked (`ORDER_TYPE='P'`) with a matching V_P_LAB_ORDER; 20% are inventory orders (`ORDER_TYPE='I'`) with NO V_P_LAB_ORDER cross-link.** No DATA_LENGTH=0 vestigial columns — BB schema is leaner than SoftLab.

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDERNO | VARCHAR2 11 | Order number — unique per row (perfect 1:1 in 30-day data). For `ORDER_TYPE='P'` rows, cross-links to `V_P_LAB_ORDER.ID` and `V_P_LAB_ORDERED_TEST.ORDER_NO`. For `ORDER_TYPE='I'` rows, no SoftLab match exists |
| MRN | VARCHAR2 23 | Medical record number — populated for `ORDER_TYPE='P'`; may be blank/placeholder on inventory orders |
| LINKEDORDERNO | VARCHAR2 11 | Linked order number (e.g., for crossmatch tied to a Type & Screen) |
| AUXILIARY_ORDERNO | VARCHAR2 50 | Secondary order identifier (longer than ORDERNO; possibly external system reference) |
| HOLLISTERNO | VARCHAR2 15 | Hollister number (specimen-tracking external ID) |

#### Order Type — critical for query design

| Column | Type | Description |
|--------|------|-------------|
| ORDER_TYPE | CHAR 1 | **The live order-type field.** Observed enum (30-day): `P` = Patient (80%, has matching V_P_LAB_ORDER), `I` = Inventory/non-patient (20%, no SoftLab cross-link — donor processing, unit operations, QC, etc.) |
| ORDERTYPE | CHAR 1 | **VESTIGIAL — blank in all 8,622 rows over 30 days.** Documented schema slot, never populated. Don't filter on it |
| PATIENTTYPE | CHAR 1 | **VESTIGIAL — blank in all rows.** Schema slot, not written |

**Critical join implication:** `INNER JOIN V_P_LAB_ORDER ON V_P_LAB_ORDER.ID = V_P_BB_BB_Order.ORDERNO` silently excludes 20% of BB activity (the inventory orders). For all-BB-activity queries, use `LEFT JOIN` or filter explicitly on `ORDER_TYPE`.

#### Dates

| Column | Type | Description |
|--------|------|-------------|
| REQUESTEDDT | DATE | When the order was requested |
| COLLECTEDDT | DATE | When the specimen was collected |
| RECEIVEDDT | DATE | When the lab received the specimen |
| TO_BE_COLLECTEDDT | DATE | Scheduled collection time |
| REPORTDT | DATE | When the report was generated |
| OUTDATEDT | DATE | When the order data goes stale (typically 3 days from collection — matches BB sample testing window) |
| HISTORY_REVIEWDT | DATE | When the patient's BB history was reviewed (often blank on routine orders) |

#### People

| Column | Type | Description |
|--------|------|-------------|
| REQUESTING_PHYSICIAN | VARCHAR2 15 | Requesting physician (FK by code → V_S_LAB_DOCTOR.ID) |
| PHLEBOTOMIST | VARCHAR2 16 | Collecting phleb. May hold real tech codes or system identities like `AUTOV` (auto-verifier) — same recurring system-user pattern as on SoftLab views |
| HISTORY_REVIEW_TECH | VARCHAR2 16 | Tech who performed history review (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |
| REPORT_TO0, REPORT_TO1, REPORT_TO2, REPORT_TO3 | VARCHAR2 15 | Up to four report-to doctors (FK by code → V_S_LAB_DOCTOR.ID). Often blank on routine orders |
| REPORT_TO_TYPE | RAW(4) | **4-byte binary** packing the type/role of each of the 4 REPORT_TO slots. Many SQL clients display this as Java byte-array memory addresses (`[B@xxxxxxxx`); to inspect actual bytes use `RAWTOHEX(REPORT_TO_TYPE)` or `DUMP(REPORT_TO_TYPE)` |

#### Location & Routing

| Column | Type | Description |
|--------|------|-------------|
| DEPOT | VARCHAR2 11 | Site/facility code. Observed 13-value enum (matches V_P_LAB_SPECIMEN.COLLECTION_LOCATION facility convention): `T1`/`T2`/`T4` (Temple), `J1`/`J2` (Jeanes), `C1`/`C2` (Chestnut Hill), `W1`/`W2` (W&F), `F1`/`F2` (Fox Chase), `E1` (Episcopal), `N1` (unknown). Temple alone is ~52% of BB volume |
| WARD | VARCHAR2 15 | Ward code (e.g., `CICU`, `7NTH`, `TED`, `TUHCT`) — FK by code → V_S_LAB_CLINIC.ID likely |
| MEDICALSERVICE | VARCHAR2 5 | Medical service code — sparsely populated (same pattern as on SoftLab views) |
| STUDY | VARCHAR2 5 | Research study code (FK by code → V_S_LAB_STUDY.ID) |
| COLLECTIONMODULE | VARCHAR2 30 | Collection origin marker — observed values: `LAB` (lab-collected), `SoftID.ANDR` (SoftID Android mobile app collection), blank |

#### State & Priority

| Column | Type | Description |
|--------|------|-------------|
| PRIORITY | CHAR 1 | Order priority. **Encoded as numeric digits stored as CHAR**: `0`, `4` observed in samples — DIFFERENT enum from SoftLab's S/R/T. Full enum needs further probe |
| STATUS | CHAR 1 | Overall order status — observed values: `R`, blank. Full enum TBD |
| CANCELLED_STATUS | CHAR 1 | Cancellation status — sparsely populated |
| ORDER_STATUS_FLAG | CHAR 1 | Additional status flag — sparsely populated |
| MAIN_SPEC_TYPE | VARCHAR2 8 | Main specimen tube type — observed: `PNK` (Pink/EDTA, typical for type & screen), `'NULL'` (literal text — NOT database NULL — same gotcha as `V_P_LAB_TUBE.TUBE_TYPE='NULL'`). Use `WHERE MAIN_SPEC_TYPE = 'NULL'` for the literal vs `IS NULL` for database null |
| DIAGNOSIS | VARCHAR2 80 | Free-text diagnosis description (PHI-adjacent if populated) |

#### Internal sorting / option keys

| Column | Type | Description |
|--------|------|-------------|
| OTSPAUX_OPTKEY, OTHOLN_OPTKEY | NUMBER 22 | Internal SCC option keys. **Mirror the row's AA_ID exactly** in observed samples — likely self-reference defaults for sort/lookup |
| OTREQ_OPTKEY | NUMBER 22 | Internal request-option key — observed `0` in samples |
| PTS_ORDER | NUMBER 22 | Patient Transfusion Service order ordinal (auto-increment-style, distinct per row) |
| PTS_ORDER_SORT | NUMBER 22 | PTS sort priority offset (small ± numbers: `0`, `-2`, `-4`, `-5` observed) |
| UTS_ORDER, UTS_ORDER_SORT | NUMBER 22 | Unit Transfusion Service order + sort. Blank for patient orders; populated for unit/donor work |

#### Other Flags

| Column | Type | Description |
|--------|------|-------------|
| REPORT_FLAGS | NUMBER 22 | Report flag bitmask — `199` observed as a default across all sampled rows |
| ENVIRONMENT0, ENVIRONMENT1 | NUMBER 22 | Two environment bitmasks (BB has two vs SoftLab's single ENVIRONMENT). Both `0` in routine patient samples |

**Notes:**

- **Volume**: ~287 BB orders/day, ~4.5% of SoftLab order volume. ~3K distinct patients/month, ~2.2 patient-orders per patient.
- **`ORDER_TYPE='P'` ⇔ matching V_P_LAB_ORDER** — perfect 1:1 correlation in 30-day data. Always use this filter (or rely on the inner join) for patient-context BB queries; use `LEFT JOIN` or filter `ORDER_TYPE='I'` for inventory/donor work.
- **`ORDERTYPE` and `PATIENTTYPE` are vestigial** — always blank. Don't confuse with `ORDER_TYPE` (the live one).
- **`PRIORITY` uses numeric digit codes**, NOT SoftLab's S/R/T letters. Treat as a separate enum.
- **`MAIN_SPEC_TYPE = 'NULL'`** is a literal text value on some rows, not database NULL — same gotcha as on V_P_LAB_TUBE.
- **`REPORT_TO_TYPE` is RAW(4)** — use `RAWTOHEX()` or `DUMP()` to inspect the 4-byte packed type bitmask.
- **`OUTDATEDT`** = collection + ~3 days; reflects the BB sample testing window. Useful for "still-valid sample" filters.
- **`COLLECTIONMODULE`** distinguishes lab-collected (`LAB`) from mobile-collected (`SoftID.ANDR`) orders. Useful classifier for collection-method analysis.
- **`AUTOV` recurs** as `PHLEBOTOMIST` — same auto-verifier system identity from prior discoveries (V_P_LAB_TUBE, V_P_LAB_ORDERED_TEST).

### V_P_BB_Result — Blood bank test result

**57 columns total** — child of V_P_BB_Test. Volume: ~473 result rows/day over a 30-day window (14,187 rows). ~1.54 results per Test row, ~1.92 results per Order. No DATA_LENGTH=0 vestigial columns.

**Naming correction from prior dictionary:** the positional result slots are named `RESULT0`, `RESULT1`, …, `RESULT23` (single-digit, 0-indexed — 24 slots). The earlier doc said `RESULT01–RESULT23` which was incorrect.

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| TEST_RESULT | NUMBER 22 | **FK → V_P_BB_Test.AA_ID** (counterintuitive name — this is the parent-test FK, not result content) |
| ORDERNO | VARCHAR2 11 | Order number — denormalized from V_P_BB_BB_Order |
| ALT_BILLINGNO | VARCHAR2 23 | Alternate billing identifier (width matches Epic CSN shape; **direct equivalence to STAY.BILLING not yet verified**) |
| RESULTNO | NUMBER 22 | Sequential result number within parent |
| ROOT_RESULTNO | NUMBER 22 | Root result number — paired with `VERSION` for amendment tracking (semantics inferred from naming; not directly verified) |
| VERSION | NUMBER 22 | Version/iteration counter for amended results (inferred from naming) |
| SPECIMENNO | NUMBER 22 | Specimen number FK (observed `0` in samples — population unknown) |

#### Result Content

| Column | Type | Description |
|--------|------|-------------|
| CODE | VARCHAR2 5 | **Result-row component code — distinct from V_P_BB_Test.CODE.** A single Test row can produce multiple Result rows, each with its own component CODE. **Verified** by direct Test↔Result join (V2): see "Test→Result component mapping" table below |
| RESULT0 ... RESULT23 | VARCHAR2 2 | Positional reaction-grade slots, 0-indexed (24 positions total). Verified that different test types use different position subsets in a 5-row sample (NCABO uses 3, ABORH uses ~6, AS3 uses 0–1). Values observed include `0`, `4+`, `NEG`, etc. **Slot-to-reaction mapping per CODE is not documented and would require additional verification per code** |
| INTERPRETATION0 | VARCHAR2 5 | Short interpretation code. Observed values include `A` in 5-row sample. **Semantic mapping NOT verified across population** |
| INTERPRETATION1 | VARCHAR2 5 | Second interpretation slot. Observed values include `POS`, `NEG` in 5-row sample. **Semantic mapping NOT verified across population** |
| AUTOINT | RAW(2) | 2-byte binary auto-interpretation code. Displays as Java byte-array (`[B@xxxxxxxx`) in many SQL clients; use `RAWTOHEX(AUTOINT)` to inspect actual bytes. **Verified low-cardinality enum** (V4): only 3 distinct values across 14,193 rows, 0 NULLs. Functions as a tri-state flag despite the 2-byte capacity. Specific byte-value semantics still unverified |
| RESULT_COMMENT | VARCHAR2 26 | Comment field — only 26 characters wide (much shorter than V_P_LAB_TEST_RESULT's CLOB COMMENTS). Observed blank in 5-row sample |

#### Dates

| Column | Type | Description |
|--------|------|-------------|
| REQUESTEDDT | DATE | When result was requested |
| RESULTEDDT | DATE | When the result was posted |
| REVIEWDT | DATE | First review timestamp. **Use `REVIEWDT IS NOT NULL` for "actually reviewed" filtering — NOT `STATUS='C'`** (see Notes) |
| SUP_REVIEWDT | DATE | Supervisory review timestamp |
| FIRST_REPORTEDDT | DATE | First report date/time |
| BILLINGDT | DATE | Billing date/time |

#### People (three-tier review chain)

| Column | Type | Description |
|--------|------|-------------|
| TECH | VARCHAR2 16 | Resulting tech (FK by code → V_S_LAB_PHLEBOTOMIST.ID). Pairs with `RESULTEDDT` |
| REVIEW_TECH | VARCHAR2 16 | First-review tech. Pairs with `REVIEWDT` |
| SUP_REVIEW_TECH | VARCHAR2 16 | Supervisory-review tech. Pairs with `SUP_REVIEWDT` |

Three-tier review chain: TECH (writes result) → REVIEW_TECH (reviews) → SUP_REVIEW_TECH (supervisor confirms). Supervisory review appears rare in samples.

#### Workstations

| Column | Type | Description |
|--------|------|-------------|
| ORDERED_WORKSTATION | VARCHAR2 15 | Workstation where result was ordered (sampled values: TBB, TORT2) |
| PERFORMING_WORKSTATION | VARCHAR2 15 | Performing workstation (blank in 5-row sample) |

#### State & Flags

| Column | Type | Description |
|--------|------|-------------|
| STATUS | CHAR 1 | Result status. **Verified enum** over 30 days: `C` (85.3%), `N` (14.7%). **Verified semantics (V1):** `STATUS='N'` ⇔ `REVIEWDT IS NULL` (100% of N rows have no review). `STATUS='C'` does NOT mean reviewed — only ~55% of C rows have REVIEWDT populated. C is set when the result is finalized/posted; review can come later (or not at all). Don't use STATUS to filter for "reviewed" — use `REVIEWDT IS NOT NULL` |
| CANCELLED_STATUS | CHAR 1 | Cancellation status. Sample values include `C` and `R`; **full enum cardinality NOT yet probed** |
| FLAG | CHAR 1 | Generic flag — semantics unverified |
| RELATION | CHAR 1 | Relation flag — semantics unverified |
| BILLING_ACTIVE | CHAR 1 | Billing-active flag |
| REPORT_FLAGS | NUMBER 22 | Report flag bitmask. Observed values: `575` (most), `63` — same recurring column across BB views |

#### QC / Factors

| Column | Type | Description |
|--------|------|-------------|
| QC_RACK | VARCHAR2 5 | QC rack identifier (e.g., `TUHQC`) — links result to QC batch tracking |
| SYSTEM_FACTOR | NUMBER 22 | System factor (observed `0` in 5-row sample; semantics unverified) |
| USER_FACTOR | NUMBER 22 | User factor (observed `0` and `1` in 5-row sample; semantics unverified) |

#### Test → Result component fanout (verified V2/V3)

V_P_BB_Test rows can produce 1 to 9 V_P_BB_Result rows. Verified mappings over 30 days:

| Parent Test CODE | Result CODEs | Fanout |
|------------------|--------------|--------|
| (most codes — ABID, ABORH directly-ordered, DATC3, DATIG, DATP, E, FYA, FYB, JKA, KELL, NCABO, RETYP, XMAHG, XMASS, XMIS, etc.) | (same CODE as Test) | **1:1** |
| TS3 | ABORH, AS3 | 1:2 |
| NCORD | CRH, CABO | 1:2 |
| NHEEL | HABO, HRH | 1:2 |
| CORD | CRH, CDAT, CABO | 1:3 |
| STDA | SABRH, DABRH, DNUM | 1:3 |
| HEEL | NEO, HRH, HDAT, HABO | 1:4 |
| UNIT1 | CULT, HEMOL, CLERK, APPER | 1:4 |
| **PRET1** | DATC3, ICTER, DATP, AS3, DATIG, ABORH, CLERK, HEMOL | **1:8** |
| **TRX1** | HEMOL, PATH, ICTER, CLERK, AS3, DATIG, ABORH, DATP, DATC3 | **1:9** (largest) |

**Notes:**

- **Volume**: ~473 result rows/day; 14,187 rows over 30 days.
- **`TEST_RESULT` is the FK to V_P_BB_Test.AA_ID** — counterintuitive name, but the column name on this view is the parent-test pointer, not the result content.
- **`RESULT0`–`RESULT23` slot semantics differ per CODE.** Each test type uses its own subset of positions. Slot-to-reaction mapping per code not yet documented.
- **Result-row CODE differs from parent Test CODE.** Verified Test→Result mappings in the table above. Multi-component tests (TS3, CORD, HEEL, PRET1, TRX1, etc.) generate one Result row per component, each with its own CODE.
- **`STATUS` enum semantics (V1 verified)**:
  - `STATUS='N'` (14.7%) → REVIEWDT IS NULL in 100% of cases. N = pending review / not finalized.
  - `STATUS='C'` (85.3%) → REVIEWDT populated in only ~55% of cases. **C does NOT mean reviewed** — it likely means "Complete/finalized" with review tracked separately.
  - **For "actually-reviewed results" filtering, use `REVIEWDT IS NOT NULL`, NOT `STATUS='C'`.**
- **`AUTOINT` (V4 verified)**: 2-byte RAW always populated (0 NULLs); only 3 distinct values across 14,193 rows. Functions as a tri-state enum despite the 2-byte capacity. Specific byte values still unverified — use `RAWTOHEX(AUTOINT)` to inspect.
- **3-tier review chain**: TECH/REVIEW_TECH/SUP_REVIEW_TECH paired with RESULTEDDT/REVIEWDT/SUP_REVIEWDT.
- **Result-side ORDERNO 7,389 distinct over 30 days** vs 8,622 BB orders → 1,233 BB orders generate no Result rows (mostly inventory orders).
- **Largest fanouts are workup tests**: TRX1 (Transfusion Reaction, 1:9) and PRET1 (Pre-Transfusion 1, 1:8) share most components — DATC3, DATIG, DATP, AS3, ABORH, CLERK, HEMOL appear on both. TRX1 adds PATH; PRET1 adds ICTER.

#### Outstanding verification work

These hypotheses are NOT yet directly verified — flagged so future query authors know:

- **`RESULT0`-`RESULT23` slot-to-reaction mapping per CODE** — would require per-code sampling or SCC test setup table inspection.
- **`INTERPRETATION0`/`INTERPRETATION1` semantic meanings** — only seen in 5 sample rows; need population-wide cardinality probe.
- **`CANCELLED_STATUS` full enum** — only `C` and `R` seen in samples; full distinct-value probe not run.
- **`AUTOINT` byte-value meanings** — known to be 3 distinct values; specific values and what they map to require RAWTOHEX inspection plus correlation with other fields.
- **`ROOT_RESULTNO`/`VERSION` amendment-chain semantics** — inferred from naming.
- **`ALT_BILLINGNO` ↔ Epic CSN equivalence** — width matches but no direct verification.
- **`SPECIMENNO`** — observed `0` in samples; FK target unknown.
- **`SYSTEM_FACTOR`/`USER_FACTOR`** — observed `0`/`1` in samples; calculation purpose unverified.

### V_P_BB_Test — Blood bank test

**24 columns total** — child entity of V_P_BB_BB_Order. Volume: ~308 tests/day, ~1.25 tests per BB order. Most BB orders generate exactly one test row; the >1.0 average is driven by the TS3-with-NCABO reflex pattern. No DATA_LENGTH=0 vestigial columns.

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORD_TEST | NUMBER 22 | **Canonical FK → V_P_BB_BB_Order.AA_ID** (numeric). Use this for joins to BB_Order — more efficient than ORDERNO string match |
| ORD_TEST_SORT | NUMBER 22 | Position within parent order (0-based; small integers observed: 0, 1, 7) |
| ORDERNO | VARCHAR2 11 | Order number — denormalized string copy of `V_P_BB_BB_Order.ORDERNO` for convenience. Same value works for cross-module joins to V_P_LAB_ORDER.ID |
| TESTNO | NUMBER 22 | Sequential test number within the order (1-based) |
| HIS_ITEMNO | NUMBER 22 | HIS item identifier — observed `0` (default) on all sampled rows; likely populated only for HIS-feed-originated tests |
| SELUN_TEST | NUMBER 22 | "Selected Unit" reference — blank for routine tests; populated when the test is tied to a specific unit (e.g., crossmatch) |
| SELUN_TEST_SORT | NUMBER 22 | Position within selected-unit context |

#### Test Identification

| Column | Type | Description |
|--------|------|-------------|
| CODE | VARCHAR2 5 | Actual test code performed. Top values (30-day, 9,254 rows): `TS3` (48%, Type & Screen), `RETYP` (18%, Re-typing), `NCABO` (12%), `ABORH` (10%, ABO/Rh), then small-volume codes (XMAHG, ABID, XMIS, CORD/NCORD, DATP, antigen typings). Top 4 codes account for 88% of BB activity |
| ORDEREDCODE | VARCHAR2 5 | Originally-ordered test code. **Pattern**: `ORDEREDCODE = CODE` when the test was directly ordered (e.g., ABORH, TS3); `ORDEREDCODE` is blank when the test is a system-generated component/reflex of a parent panel (e.g., NCABO is generated under ~24% of TS3 orders as an ABO-discrepancy reflex). Same pattern as `V_P_LAB_TEST_RESULT.GROUP_TEST_ID` vs `TEST_ID` |

#### State

| Column | Type | Description |
|--------|------|-------------|
| STATUS | CHAR 1 | Test status. Observed enum (30-day, 9,254 rows): blank (87%), `N` (13%, likely "New/unreleased"). Other values not seen — likely most tests just have NULL once finalized |
| FLAG | CHAR 1 | Generic flag — observed blank in samples |
| CANCELLED_STATUS | CHAR 1 | Cancellation status — sparsely populated |
| TEST_TYPE | CHAR 1 | **VESTIGIAL — blank in all 9,254 rows over 30 days.** Documented schema slot, never populated. Same pattern as V_P_BB_BB_Order's ORDERTYPE/PATIENTTYPE |
| REPORT_FLAGS | NUMBER 22 | Report flag bitmask — varies by test type (e.g., `575` for most, `63` for TS3) |

#### Dates

| Column | Type | Description |
|--------|------|-------------|
| REQUESTEDDT | DATE | When the test was requested (workhorse field) |
| REQUESTDT | DATE | **Unused in 30-day samples — vestigial duplicate of REQUESTEDDT.** Don't filter on it |
| RELEASEDDT | DATE | When the test was released — blank for in-flight tests |

#### People

| Column | Type | Description |
|--------|------|-------------|
| PHYSICIAN | VARCHAR2 15 | Requesting physician (FK by code → V_S_LAB_DOCTOR.ID) |
| AUTHPHYSICIAN | VARCHAR2 15 | Authorizing physician — distinct from PHYSICIAN. Same pattern as V_P_LAB_ORDERED_TEST's SIGNING_DOCTOR_ID vs DOCTOR_ID |
| RELEASING_TECH | VARCHAR2 16 | Tech who released the test result (FK by code → V_S_LAB_PHLEBOTOMIST.ID) |

#### Other

| Column | Type | Description |
|--------|------|-------------|
| FINAL_INTERPRETATION | VARCHAR2 26 | Free-text interpretation; blank for in-flight tests |
| MEDICAL_SERVICE | VARCHAR2 5 | Medical service code. **Naming note**: this view uses `MEDICAL_SERVICE` (with underscore), but V_P_BB_BB_Order uses `MEDICALSERVICE` (no underscore). Cross-view joins must use the right column name per view |
| WARD | VARCHAR2 15 | Ward code (FK by code → V_S_LAB_CLINIC.ID); same namespace as on BB_Order (TED, CICU, EHED, TUHPAT, etc.) |

**Notes:**

- **Volume**: ~308 BB tests/day; ~1.25 tests per BB order on average.
- **`ORD_TEST` is the canonical FK to V_P_BB_BB_Order.AA_ID** (numeric). `ORDERNO` is a denormalized string copy. Both work for joining to BB_Order; `ORD_TEST` is more efficient.
- **1,208 BB orders over 30 days have ZERO V_P_BB_Test rows** — these are mostly inventory orders (`ORDER_TYPE='I'` on V_P_BB_BB_Order) where ~70% generate no test rows. The remaining ~30% of inventory orders DO generate test rows (donor processing, QC).
- **`TEST_TYPE` is fully vestigial** — never populated. Don't filter on it.
- **`STATUS` only takes one non-blank value (`N`)** in observed data. Most tests are blank-status (probably "released/done"). Don't infer state from STATUS alone — use `RELEASEDDT IS NOT NULL` for "released" filtering.
- **`REQUESTDT` is unused** — `REQUESTEDDT` is the workhorse date. Two date-named columns where only one carries data (same dual-column pattern as on V_P_BB_BB_Order).
- **`ORDEREDCODE` blank ⇒ system-generated component**. NCABO (1,088 rows) appears under ~24% of TS3 orders (4,443 TS3s) as an ABO-discrepancy reflex — confirmed by the blank `ORDEREDCODE`.
- **Top 4 test codes account for 88% of BB activity**: TS3 (Type & Screen), RETYP (Re-type), NCABO (component), ABORH (ABO/Rh).
- **`MEDICAL_SERVICE` (underscore) vs V_P_BB_BB_Order.MEDICALSERVICE (no underscore)** — the same logical field has different physical names across BB views. Watch out on cross-view joins.

### V_P_BB_Patient — Blood bank patient demographics

**36 columns total** (verified 2026-04-28 by `view_deep_probe.sql`). Wraps base table `BBANK_PATIENT` (which uses P-prefix column names: PLNAME, PFNAME, PDOB, PSDX, PTSTAMP, etc.). Volume: ~611K total patient rows; ~3K patients/30 days have records modified (`STAMP_DATE`-based — ~103 patient-record modifications/day).

#### Identity & Names (always populated unless noted)

| Column | Type | Notes |
|--------|------|-------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| MRN | VARCHAR2 23 | Medical record number — 100% populated, UNIQUE-indexed (BBANK_PMRNUM_UNIQ) |
| SSN | VARCHAR2 23 | Social security number — 100% populated; indexed (BBANK_PSSNUM_INDEX) |
| MPI | VARCHAR2 23 | Master Patient Index identifier — 100% populated |
| LAST_NAME | VARCHAR2 35 | Last name — 100% populated; composite-indexed (BBANK_PNAME_INDEX) |
| FIRST_NAME | VARCHAR2 31 | First name — 100% populated; composite-indexed |
| MIDDLE_NAME | VARCHAR2 31 | **Middle initial, not full middle name.** Avg length 1.015 chars across the cohort — the column name is misleading. The system stores `'J'` not `'JAMES'` for ~98.5% of patients |
| SOUNDEX | VARCHAR2 4 | Phonetic name code — 100% populated. **Heavily indexed** with 3 separate indexes (BBANK_PSDX_INDEX alone, BBANK_PSDXDOB_INDEX with DOB+TOB, BBANK_PSDXSSN_INDEX with SSN). BB does first-class phonetic patient lookup |
| TITLE | VARCHAR2 11 | **VESTIGIAL — 0% populated** in 30-day sample |
| SUFFIX | VARCHAR2 11 | Sparsely populated (0.06%); rarely used |

#### Identifier-shape columns (mostly vestigial)

| Column | Type | Notes |
|--------|------|-------|
| MOTHER_MRN | VARCHAR2 23 | **Sparsely real** — 92 distinct values across 3,084 rows (1 placeholder + ~91 real). Only ~3% of patients (newborns) have a real mother's MRN; the rest hold a 1-char placeholder. Filter `LENGTH(MOTHER_MRN) > 1` to find real linkages |
| NEXT_MRN | VARCHAR2 23 | **VESTIGIAL** — 100% populated but with a single placeholder value (1 distinct, 1-char). Schema slot, not used for real next-MRN tracking |
| AUXILIARY_MRN | VARCHAR2 23 | **VESTIGIAL** — same as NEXT_MRN: 1 distinct constant placeholder. Schema slot, not used |
| PDF | VARCHAR2 23 | **VESTIGIAL — 0% populated** |
| CHARTNO | VARCHAR2 32 | Sparsely populated (0.78%) — rare external chart-number cases |
| EXTERNALID | VARCHAR2 32 | **VESTIGIAL — 0% populated** |
| CLIENTID | VARCHAR2 15 | **VESTIGIAL — 0% populated** |
| CASENO | VARCHAR2 5 | **VESTIGIAL — 0% populated** |
| SITE | VARCHAR2 5 | **VESTIGIAL — 0% populated across all 611K rows** (verified, not just 30-day cohort). Prior dict claim that SITE was a real field was incorrect |

#### Demographics

| Column | Type | Notes |
|--------|------|-------|
| DOBDT | DATE | Date of birth (note: **`DOBDT` not `DOB_DT`** — different naming from V_P_LAB_PATIENT.DOB_DT) — 100% populated |
| DOD | DATE | Date of death — **0% populated in 30-day sample**. Either rarely used in this deployment, or only populated for actually-deceased patients (none in recent cohort) |
| SEX | CHAR 1 | 100% populated |
| RACE | VARCHAR2 40 | ~99.7% populated |

#### Blood-bank-specific (current and historical typing)

| Column | Type | Notes |
|--------|------|-------|
| ABO | VARCHAR2 2 | Current ABO type — 95.7% populated |
| RH | CHAR 1 | Current Rh factor — 95.7% (paired with ABO) |
| HISTORICAL_ABO | VARCHAR2 2 | Historical ABO from prior encounter — 17% populated |
| HISTORICAL_RH | CHAR 1 | Historical Rh — 17% populated (paired) |
| HISTORICAL_ABORHDT | DATE | When historical type was recorded — 17% populated |

#### Workflow / Audit

| Column | Type | Notes |
|--------|------|-------|
| STAMP_DATE | DATE | Last-modified timestamp — 100% populated; **indexed** (BBANK_PTSTAMP_INDEX). **Use this as the windowing column** for any time-bound query against V_P_BB_Patient |
| LAST_DISCHARGE_DATE | DATE | **VESTIGIAL — 0% populated** |
| REPORT_FLAGS | NUMBER 22 | Bitmask, 100% populated; same recurring column across BB module |
| FLAGS | NUMBER 22 | Generic flag bitmask, 100% populated |

#### Internal SCC Option Keys (always populated, internal-use)

`PMRNMO_OPTKEY`, `PMRNEXT_OPTKEY`, `PMRAUX_OPTKEY`, `PPATID_OPTKEY` — all NUMBER 22, 100% populated. Internal SCC sort/lookup keys (similar pattern to V_P_BB_BB_Order's OPTKEY columns); not query-useful for typical reports.

**Notes:**

- **Volume sizing:** ~611K total patients (cumulative, multi-year), ~103 patient-record modifications/day (`STAMP_DATE`-bounded). Much smaller than result tables.
- **`STAMP_DATE` is the canonical windowing column** — indexed via `BBANK_PTSTAMP_INDEX`. Date predicates on `STAMP_DATE` use the index efficiently.
- **`MIDDLE_NAME` stores middle INITIALS** despite the column name — avg length 1.015 chars. Don't expect full names.
- **Of 10 identifier-shaped columns, 3 are real (MRN, SSN, MPI), 2 are sparsely real (MOTHER_MRN ~3% real, CHARTNO 0.78%), and 5 are entirely vestigial (NEXT_MRN/AUXILIARY_MRN as placeholder constants; PDF/EXTERNALID/CLIENTID/CASENO/TITLE/SITE all 0%).** The schema is much wider than the operationally-used field set.
- **MOTHER_MRN newborn-detection filter:** `WHERE LENGTH(MOTHER_MRN) > 1` finds the ~3% of patients with real mother-MRN linkages (the rest carry a 1-char placeholder).
- **Phonetic lookup is a first-class operation in BB.** Three indexes use SOUNDEX (alone, with DOB+TOB, with SSN). Patient-name search queries should consider Soundex-based fuzzy matching, not just `LIKE '%LASTNAME%'`.
- **Base table `BBANK_PATIENT` uses different column names** than the view (P-prefix on most fields). Direct base-table queries need the underlying name (e.g., `PLNAME` not `LAST_NAME`).
- **`PTOB` (time of birth) exists in the base table but is not exposed by V_P_BB_Patient.** Newborn time-of-birth precision (relevant for transfusion eligibility) is recorded in BBANK_PATIENT but not visible through the view.

**Outstanding verification work:**

- **`DOD` semantics**: 0% in 30-day cohort, but might be populated for deceased patients on full table. Probe `SELECT COUNT(DOD) FROM V_P_BB_Patient` (full table, no date filter) to confirm.
- **Placeholder value for NEXT_MRN, AUXILIARY_MRN, MOTHER_MRN**: known to be 1 character but actual character not yet captured (would need a non-PHI-leaking sample query, e.g., `SELECT NEXT_MRN, COUNT(*) FROM V_P_BB_Patient GROUP BY NEXT_MRN HAVING COUNT(*) > 1000`)

### V_P_BB_Unit — Blood unit

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| UNITNO | VARCHAR2 18 | Eye-readable donation number |
| BAR_CODE_UNITNO | VARCHAR2 18 | Barcoded donation number |
| UNIT_PRODUCT | VARCHAR2 5 | Product code |
| ABO | VARCHAR2 2 | ABO |
| RH | CHAR 1 | Rh |
| LOCATION | VARCHAR2 5 | Location |
| SITE | VARCHAR2 5 | Site |
| SOURCE | VARCHAR2 5 | Supplier |
| STATUS | CHAR 1 | Status |
| COLLECTIONDT | DATE | Collection/creation date/time |
| RECEIVEDDT | DATE | Received date/time |
| EXPIRATIONDT | DATE | Expiration date/time |
| FINAL_STATUSDT | DATE | Final status date/time |

### V_P_BB_Action — Blood bank action (transfusion actions, crossmatch, etc.)

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDERNO | VARCHAR2 11 | Order number |
| CODE | VARCHAR2 5 | Action code |
| STATUS | CHAR 1 | Status |
| AMOUNT | NUMBER 5 | Amount |
| TECH | VARCHAR2 16 | Technologist |
| SITE | VARCHAR2 5 | Site |
| WARD | VARCHAR2 15 | Ordering ward |
| PHYSICIAN | VARCHAR2 15 | Requesting physician |
| STATUSDT | DATE | Status date/time |
| REQUESTDT | DATE | Request date/time |

---

## SoftAR (Accounts Receivable) Views — Detail

### SoftAR Entity Relationships
```
V_P_ARE_VISIT  (VTINTN — visit PK)
    └─► V_P_ARE_ITEM  (ITVTINTN → VISIT.VTINTN)
            └─► V_S_ARE_CCI  (ITCCITINTN → CCI.CCINTN — system-flagged CCI edit)

V_P_ARE_ITEM.ITCPTCD → V_S_ARE_CPTTABLE.CPTCODE
V_P_ARE_ITEM.ITTSTCODE → V_S_ARE_TEST.TSTCODE
V_S_ARE_CCI.CCCPT1 / CCCPT2 → V_S_ARE_CPTTABLE.CPTCODE
V_S_ARE_CCI.CCPYOCODE → V_S_ARE_PAYOR (payor-specific CCI rules)
V_S_ARE_BILLRULES.BRTSTCODE → V_S_ARE_TEST.TSTCODE
V_S_ARE_BILLRULES.BRCPTCODE → V_S_ARE_CPTTABLE.CPTCODE
V_S_ARE_BILLRULES.BRPYOCODE → V_S_ARE_PAYOR (payor-specific billing rules)
V_S_ARE_BILLRULES.BRCCIMOD → V_S_ARE_MODIFIER.MODCODE (configured CCI override modifier)

V_P_ARE_VISIT.VTORGORDNUM → V_P_LAB_ORDER.ID  (cross-links AR visit to SoftLab order)
V_P_ARE_BILLERROR.BERVTINTN → V_P_ARE_VISIT.VTINTN  (billing errors are visit-level)
V_P_ARE_BILLERROR.BERCODE → V_S_ARE_ARERROR.ERRCODE  (error definition lookup; use NVL(BERCODE,'IN75'))
```

### V_P_ARE_VISIT — Visit data

| Column | Type | Description |
|--------|------|-------------|
| VTINTN | NUMBER | PK — visit internal number (NOT NULL) |
| VTREFNO | VARCHAR2 19 | Invoice/reference number (NOT NULL) |
| VTPTINTN | NUMBER | FK → Patient internal number (NOT NULL) |
| VTSTINTN | NUMBER | FK → Stay internal number |
| VTREFDOC | VARCHAR2 15 | Referring doctor code |
| VTFCLTY | VARCHAR2 15 | Facility |
| VTDEPOT | VARCHAR2 11 | Depot/site |
| VTREGION | VARCHAR2 1 | Region |
| VTCILNSDT | DATE | Client send date |
| VTFILNSDT | DATE | File send date |
| VTDOCTOR | VARCHAR2 15 | Doctor code |
| VTADMDOC | VARCHAR2 15 | Admitting doctor code |
| VTPLINTN | NUMBER | FK → Policy internal number |
| VTACINTN | NUMBER | FK → Account internal number (NOT NULL) |
| VTPTTYPE | VARCHAR2 1 | Patient type |
| VTAUTHNO | VARCHAR2 30 | Authorization number |
| VTAUTHDTM | DATE | Authorization date/time |
| VTAUTHUSR | VARCHAR2 16 | Authorization user |
| VTDUNLVL | NUMBER | Dunning level |
| VTPRNBIL | NUMBER | Print bill flag |
| VTHOLDTILL | DATE | Hold until date |
| VTSRVDT | DATE | Service date |
| VTPOSTDT | DATE | Post date |
| VTVERDT | DATE | Verification date |
| VTINVDT | DATE | Invoice date (NULL = never invoiced) |
| VTFBDT | DATE | First bill date (NULL = never billed) |
| VTLBDT | DATE | Last bill date |
| VTFPMTDT | DATE | First payment date |
| VTLPMTDT | DATE | Last payment date |
| VTLACTDT | DATE | Last activity date |
| VTCHARGE | NUMBER | Charge amount |
| VTPAID | NUMBER | Paid amount |
| VTADJUST | NUMBER | Adjustment amount |
| VTBDEBTDTM | DATE | Bad debt date/time |
| VTCOLAGN | VARCHAR2 5 | Collection agency |
| VTBDEBAMT | NUMBER | Bad debt amount |
| VTBDEBREC | NUMBER | Bad debt recovered |
| VTSTAT | NUMBER | Status (NOT NULL): 0=pending, 1=active/normal, 2=held/blocked, 3=no-charge/cancelled, 4=other |
| VTCREATDTM | DATE | Created date/time |
| VTEDITDTM | DATE | Last edited date/time |
| VTCREATBY | VARCHAR2 16 | Created by user |
| VTEDITBY | VARCHAR2 16 | Last edited by user |
| VTFLAGS | NUMBER | Flags |
| VTPCAREDOC | VARCHAR2 15 | Primary care doctor |
| VTAUTHBY | VARCHAR2 31 | Authorized by |
| VTPLINTN2 | NUMBER | FK → Policy internal number 2 |
| VTPLINTN3 | NUMBER | FK → Policy internal number 3 |
| VTTYPE | NUMBER | Visit type (NOT NULL) |
| VTWARD | VARCHAR2 15 | Ward |
| VTACCSEQ | VARCHAR2 3 | Accession sequence |
| VTREADY | NUMBER | Ready flag (NOT NULL): 0=ready to bill, 1=not ready (visit unbilled) |
| VTRSLTSTS | NUMBER | Result status (NOT NULL) |
| VTPBDT | DATE | PB date |
| VTAGECLOSEDT | DATE | Age close date (NOT NULL) |
| VTORGORDNUM | VARCHAR2 19 | Original order number / accession number |
| VTHOLDRES | NUMBER | Hold reason |
| VTKIND | VARCHAR2 1 | Kind |

### V_S_ARE_CCI — CCI (Correct Coding Initiative) edit pairs

| Column | Type | Description |
|--------|------|-------------|
| CCINTN | NUMBER | PK — internal number |
| CCPYOCODE | VARCHAR2 15 | Payor code (CCI rules can be payor-specific) |
| CCCPT1 | VARCHAR2 11 | CPT column 1 code |
| CCCPT2 | VARCHAR2 11 | CPT column 2 code |
| CCERRCODE | VARCHAR2 5 | Error code |
| CCEFFDT | DATE | Effective date |
| CCEXPDT | DATE | Expiration date |
| CCFLAG | NUMBER | Modifier indicator: 0=not allowed, 1=allowed, 9=N/A |
| CCSTAT | NUMBER | Status (0 = active) |
| CCCREATDTM | DATE | Created date/time |
| CCEDITDTM | DATE | Last edited date/time |
| CCCREATBY | VARCHAR2 16 | Created by user |
| CCEDITBY | VARCHAR2 16 | Last edited by user |

### V_S_ARE_CPTTABLE — CPT code reference

| Column | Type | Description |
|--------|------|-------------|
| CPTINTN | NUMBER | PK — internal number |
| CPTCODE | VARCHAR2 11 | CPT/HCPCS code |
| CPTDESC | VARCHAR2 79 | Code description |
| CPTVER | VARCHAR2 11 | Version |
| CPTSTAT | NUMBER | Status (0 = active) |
| CPTCREATDTM | DATE | Created date/time |
| CPTEDITDTM | DATE | Last edited date/time |
| CPTCREATBY | VARCHAR2 16 | Created by user |
| CPTEDITBY | VARCHAR2 16 | Last edited by user |
| CPTBEGDT | DATE | Begin/effective date |
| CPTEXPDT | DATE | Expiration date |

### V_S_ARE_TEST — AR test setup

| Column | Type | Description |
|--------|------|-------------|
| TSTINTN | NUMBER | PK — internal number |
| TSTCODE | VARCHAR2 15 | AR test code |
| TSTSYSCODE | VARCHAR2 5 | System module code (value is 'LAB' for SoftLab — NOT a test code; use TSTCODE to match V_S_LAB_TEST.ID) |
| TSTDESC | VARCHAR2 59 | Test description |
| TSTNOTAX | NUMBER | No tax flag |
| TSTTAXRATE | NUMBER | Tax rate |
| TSTBEGDT | DATE | Begin/effective date |
| TSTEXPDT | DATE | Expiration date |
| TSTNOBILL | NUMBER | No bill flag |
| TSTISGRP | NUMBER | Is group test flag |
| TSTNCOMP | NUMBER | Number of components |
| TSTSTAT | NUMBER | Status (0 = active) |
| TSTCREATDTM | DATE | Created date/time |
| TSTEDITDTM | DATE | Last edited date/time |
| TSTCREATBY | VARCHAR2 16 | Created by user |
| TSTEDITBY | VARCHAR2 16 | Last edited by user |
| TSTBILLWHEN | NUMBER | Bill-when rule |
| TSTINCOUTCHARGE | NUMBER | Include outreach charge |
| TSTID0–TSTID3 | VARCHAR2 15 | Additional identifier fields |
| TSTTYPE | NUMBER | Test type |
| TSTEXP | NUMBER | Expiration setting |
| TSTFREQ | NUMBER | Frequency setting |
| TSTRESULT | NUMBER | Result setting |
| TSTMEASURE | VARCHAR2 5 | Unit of measure |
| TSTSECONDID | VARCHAR2 40 | Secondary identifier |
| TSTTHIRDID | VARCHAR2 40 | Third identifier |
| TSTWRKST | VARCHAR2 5 | Workstation |
| TSTMODULE | VARCHAR2 5 | Module code |

### V_S_ARE_MODIFIER — CPT modifier reference

| Column | Type | Description |
|--------|------|-------------|
| MODINTN | NUMBER | PK — internal number |
| MODCODE | VARCHAR2 | Modifier code (e.g., 59, XE, XP, XS, XU, 26, TC) |
| MODDESC | VARCHAR2 | Modifier description |
| MODVER | VARCHAR2 | Version |
| MODSTAT | NUMBER | Status (0 = active) |
| MODCREATDTM | DATE | Created date/time |
| MODEDITDTM | DATE | Last edited date/time |
| MODCREATBY | VARCHAR2 | Created by user |
| MODEDITBY | VARCHAR2 | Last edited by user |
| MODINTERNAL | NUMBER | Internal flag |
| MODTYPE | NUMBER | Modifier type: 0=general, 1=repeat test (91), 2=component (26/TC/CD/CE), 3=CCI override (59/76/77), 4=teaching (GC) |

### V_S_ARE_BILLRULES — Billing rules (per test/payor/CPT)

| Column | Type | Description |
|--------|------|-------------|
| BRINTN | NUMBER | PK — internal number |
| BRTSTCODE | VARCHAR2 15 | AR test code (FK → V_S_ARE_TEST.TSTCODE) |
| BRSYSCODE | VARCHAR2 5 | System code |
| BRPYOCODE | VARCHAR2 15 | Payor code (rules are payor-specific) |
| BRBILCLASS | VARCHAR2 5 | Billing class |
| BRPTTYPE | VARCHAR2 1 | Patient type |
| BRNOBILL | NUMBER | No bill flag: 0=normal (bill CPT), 1=Free, 2=Split to Components, 3=Bill to PRIV, 4=Bill to Secondary, 5=Bill to Ward, 6=Bill to Specified |
| BRSPLIT | NUMBER | Split flag |
| BRCPTCODE | VARCHAR2 11 | CPT/HCPCS code |
| BRMODCODE0 | VARCHAR2 5 | Default modifier 0 |
| BRMODCODE1 | VARCHAR2 5 | Default modifier 1 |
| BRMODCODE2 | VARCHAR2 5 | Default modifier 2 |
| BRMODCODE3 | VARCHAR2 5 | Default modifier 3 |
| BRBEGDT | DATE | Begin/effective date |
| BREXPDT | DATE | Expiration date |
| BRREVDT | DATE | Review date |
| BRSTAT | NUMBER | Status (0 = active) |
| BRCREATDTM | DATE | Created date/time |
| BREDITDTM | DATE | Last edited date/time |
| BRCREATBY | VARCHAR2 16 | Created by user |
| BREDITBY | VARCHAR2 16 | Last edited by user |
| BRCHARGECODE | VARCHAR2 11 | Charge code |
| BRONCANCELED | NUMBER | On-canceled flag |
| BRREGION | VARCHAR2 1 | Region |
| BRRESPAYOR | VARCHAR2 15 | Responsible payor |
| BRREPMOD | VARCHAR2 5 | Repeat test modifier |
| BRORDEREDAS | VARCHAR2 15 | Ordered-as code |
| BRREPOPT | NUMBER | Repeat option |
| BRWARD | VARCHAR2 15 | Ward |
| BRFCLTY | VARCHAR2 15 | Facility |
| BRDGNTYPE | VARCHAR2 5 | Diagnosis type |
| BRCCIMOD | VARCHAR2 5 | CCI override modifier (applied when CCI edit allows modifier) |

### V_P_ARE_ITEM — Billing line item

| Column | Type | Description |
|--------|------|-------------|
| ITINTN | NUMBER | PK — internal number |
| ITTSTCODE | VARCHAR2 15 | AR test code (FK → V_S_ARE_TEST.TSTCODE) |
| ITSYSCODE | VARCHAR2 5 | System code |
| ITSRVDT | DATE | Service date (from) |
| ITSRVDTTO | DATE | Service date (to) |
| ITPRICE | NUMBER | Price (stored in cents — divide by 100 for dollars) |
| ITTAXAMT | NUMBER | Tax amount |
| ITGROSS | NUMBER | Gross amount |
| ITACCAMT | NUMBER | Account amount |
| ITBAL | NUMBER | Balance (stored in cents — divide by 100 for dollars) |
| ITUNITS | NUMBER | Units |
| ITVTINTN | NUMBER | FK → Visit internal number |
| ITPTINTN | NUMBER | FK → Patient internal number |
| ITINEXT | NUMBER | Insurance extension |
| ITCPTCD | VARCHAR2 11 | CPT/HCPCS code |
| ITCPTMOD0 | VARCHAR2 5 | CPT modifier 0 |
| ITCPTMOD1 | VARCHAR2 5 | CPT modifier 1 |
| ITCPTMOD2 | VARCHAR2 5 | CPT modifier 2 |
| ITCPTMOD3 | VARCHAR2 5 | CPT modifier 3 |
| ITPLACE | VARCHAR2 5 | Place of service |
| ITSRVTYPE | VARCHAR2 15 | Service type |
| ITDGNCODE0 | VARCHAR2 11 | Diagnosis code 0 (primary) |
| ITDGNCODE1 | VARCHAR2 11 | Diagnosis code 1 |
| ITDGNCODE2 | VARCHAR2 11 | Diagnosis code 2 |
| ITDGNCODE3 | VARCHAR2 11 | Diagnosis code 3 |
| ITSTAT | NUMBER | Status (0 = active) |
| ITCREATDTM | DATE | Created date/time |
| ITEDITDTM | DATE | Last edited date/time |
| ITCREATBY | VARCHAR2 16 | Created by user |
| ITEDITBY | VARCHAR2 16 | Last edited by user |
| ITFLAGS | NUMBER | Flags |
| ITCHARGECD | VARCHAR2 11 | Charge code |
| ITDESC | VARCHAR2 79 | Item description |
| ITFREQSTAT | NUMBER | Frequency limit status (0=ok; non-zero=flagged — always 0 in practice) |
| ITMEDNECSTAT | NUMBER | Medical necessity status (0=ok; non-zero=flagged — always 0 in practice) |
| ITABN | NUMBER | ABN status: 0=N(ok), 1=Y, 2=U(unknown), 3=P, 4=R, 5=W, 6=X, 7=S |
| ITCCITINTN | NUMBER | CCI link — points to the column-1 (grouped) item's ITINTN, NOT to V_S_ARE_CCI.CCINTN. When populated and <> 0, this item is the subordinate (column 2) in a CCI pair. |
| ITMODFLAG | NUMBER | Modifier flag: 0=none, 1=payable with modifier (CCI override allowed), >1=not allowed |
| ITBQNT | NUMBER | Billed quantity |
| ITUNITPRICE | NUMBER | Unit price |
| ITNCREASON | NUMBER | No charge reason |
| ITTPPMT | NUMBER | Third-party payment |
| ITPTPMT | NUMBER | Patient payment |
| ITOTHPMT | NUMBER | Other payment |
| ITTPADJ | NUMBER | Third-party adjustment |
| ITPTADJ | NUMBER | Patient adjustment |
| ITOTHADJ | NUMBER | Other adjustment |
| ITFCLTY | VARCHAR2 15 | Facility |
| ITINFO | VARCHAR2 32 | Additional info |
| ITDEPCODE | VARCHAR2 15 | Department code |
| ITWRKST | VARCHAR2 5 | Workstation |
| ITTYPE | NUMBER | Item type |
| ITOUTCOME | VARCHAR2 4 | Outcome |
| ITREQDCCODE | VARCHAR2 15 | Requesting doctor code |
| ITPERFDCCODE | VARCHAR2 15 | Performing doctor code |
| ITWARD | VARCHAR2 15 | Ward |
| ITGRANTNO | VARCHAR2 25 | Grant number |

### V_P_ARE_BILLERROR — Billing errors (visit-level)

| Column | Type | Description |
|--------|------|-------------|
| BEINTN | NUMBER(14) | PK — internal number (NOT NULL) |
| BERVTINTN | NUMBER(14) | FK → V_P_ARE_VISIT.VTINTN |
| BERCODE | VARCHAR2 5 | Error code (typically empty in practice) |
| BERDESC | VARCHAR2 1023 | Error description (primary useful field) |
| BERDTM | DATE | Error date/time (NOT NULL) |
| BEFLAGS | NUMBER(2) | Flags (NOT NULL) |
| BEORDER | VARCHAR2 19 | Order number (typically empty in practice) |
| BEJBINTN | NUMBER(14) | Job internal number |
| BEREDTDTM | DATE | Edit date/time |
| BECNT | NUMBER(5) | Count |

**Notes:**
- BILLERROR is visit-level, not item-level. Join on `BERVTINTN → VTINTN`.
- There is no item-level FK (no `BEITINTN` column).
- `BERCODE` and `BEORDER` are typically empty — `BERDESC` carries the error detail. Use `BERDESC` for raw error text.
- `BERDTM` date generally matches the visit service date (`VTSRVDT`).
- Most billing errors are non-blocking warnings — ~267K visits with errors still got invoiced and billed.
- Uninvoiced visits (`VTINVDT IS NULL`) have **zero items** in `V_P_ARE_ITEM` — they are visit shells only.
- Common error categories on uninvoiced visits: invoice-when restriction (components not yet resulted), review needed, auto-split leftovers, invalid/missing payor, frequency limit, workstation-facility mismatch.
- When `BERCODE` is NULL, SCC treats it as error code `'IN75'` (not billed/invoiced) — look up in `V_S_ARE_ARERROR`.
- Do NOT pre-filter errors by `ERRACTION` — even Warning-level errors can block bill delivery. Show all errors and let the user assess.

### V_P_ARE_AUDITTRAIL — Field-level change audit log

| Column | Type | Description |
|--------|------|-------------|
| ATINTN | NUMBER 22 | PK — audit entry internal number |
| ATTABLE | VARCHAR2 20 | Entity/table that was changed (e.g., 'Item', 'Visit', 'Invoice', 'Account') |
| ATROWINTN | NUMBER 22 | FK — internal number of the changed row (e.g., ITINTN for Item, VTINTN for Visit) |
| ATDESC | NVARCHAR2 4000 | Description of the change |
| ATUSER | VARCHAR2 16 | User who made the change (e.g., 'scc' = system, user IDs for manual changes) |
| ATDATE | DATE | Date/time of the change |
| ATFIELD | VARCHAR2 30 | Specific field that was changed (e.g., 'itcptmod0', 'itunits', 'vtstat') |
| ATOLD | NVARCHAR2 4000 | Previous value |
| ATNEW | NVARCHAR2 4000 | New value |
| ATPRNTINTN | NUMBER 22 | Parent internal number |

**Notes:**
- Field-level audit trail — each row represents one field change on one record.
- `ATTABLE` values include: `Gp_insur` (most common), `VisitProc`, `Visit`, `Account`, `Trans`, `Invoice`, `Problem`, `Item`, `Batch`, `VisitDiag`, `VprItLink`, `Test`, `ActionToInform`, `Person`, `Payor`, `Trtype`, `ArCfg`.
- **Item (V_P_ARE_ITEM) tracked fields:** `itunits` (~143K), `itccitintn` (~31K), `itcptmod0` (~26K), `itinfo` (~25K), `itwrkst` (~7K), `itdepcode` (~2K), `itsrvdt`/`itsrvdtto` (~2K each), `itward` (~2K), `itreqdccode`, `itabn`.
- **Modifier audit:** Join `ATROWINTN → V_P_ARE_ITEM.ITINTN` WHERE `ATTABLE = 'Item'` AND `ATFIELD = 'itcptmod0'` to get who added/changed a modifier and when.
- `V_P_ARE_AUDITTRAILTECH` has identical structure — likely captures system/automated changes vs user-initiated changes.

### V_S_ARE_ARERROR — AR error code definitions

| Column | Type | Description |
|--------|------|-------------|
| ERRCODE | VARCHAR2 5 | Error code (PK — e.g., 'IN75') |
| ERRDESC | VARCHAR2 | Error description |
| ERRACTION | NUMBER | Action: 0=Abort, 1=Skip, 2=Warning, 3=Ignore, 4=Drop Item, 5=Hold, 6=Split, 7=Split Warn, 8=Hold And Bill Client |
| ERRCORCODE | VARCHAR2 | Corrective action code |
| ERRGRP | NUMBER | Error group: 0=Invoicing, 1=Billing, 2=Other, 3=Posting, 4=Remittance |

**Notes:**
- This is the lookup table for `V_P_ARE_BILLERROR.BERCODE`. Join: `err.ERRCODE = NVL(be.BERCODE, 'IN75')`.
- `ERRACTION` nominal severity: 0=Abort, 1=Skip, 4=Drop Item, 5=Hold, 6=Split, 8=Hold & Bill Client are formally blocking; 2=Warning and 7=Split Warn are nominally non-blocking but **can still prevent bill delivery** at the Billing stage (e.g., STXER/Warning at Billing blocked bill generation in practice).
- `ERRGRP` identifies which pipeline stage raised the error: 0=Invoicing, 1=Billing, 2=Other, 3=Posting, 4=Remittance.
- Default error `'IN75'` is applied when `BERCODE` is NULL (visit never invoiced/billed).
- Common unbilled patterns discovered: NOMOD/Skip at Billing (missing CCI modifier — invoiced, not billed), IN24/Skip at Invoicing (payor criteria unmet — not invoiced), STXER/Warning at Billing (patient data syntax error — invoiced, not billed), or no AR visit at all (order never crossed from SoftLab to SoftAR).

### V_P_ARE_INVOICE — Invoice data

| Column | Type | Description |
|--------|------|-------------|
| ININTN | NUMBER | PK — internal number |
| INVTINTN | NUMBER | FK → V_P_ARE_VISIT.VTINTN |
| INEXT | NUMBER | Insurance extension (matches ITINEXT — links invoice to item) |
| INSTAT | NUMBER | Status: 0=active (`INV_ACTIVE`), non-zero=inactive |
| INLBDT | DATE | Last bill date (NULL = not yet billed) |
| INFBDT | DATE | First bill date |
| INBILLTO | VARCHAR2 | Bill-to payor code (FK → V_S_ARE_PAYOR.PYOCODE) |
| INCHARGE | NUMBER | Charge amount (stored in cents — divide by 100 for dollars) |
| INDUEAMT | NUMBER | Due/balance amount (stored in cents — divide by 100 for dollars) |
| INSTBILNO | VARCHAR2 | Stay billing number |

**Notes:**
- Join to items via `INVTINTN = ITVTINTN AND INEXT = ITINEXT`.
- `INSTAT = 0` means the invoice is active (comment in SCC code: `INV_ACTIVE`).
- All monetary columns stored in cents.

### V_P_ARE_TRANS — Transaction data

| Column | Type | Description |
|--------|------|-------------|
| TRINTN | NUMBER | PK — internal number |
| TRVTINTN | NUMBER | FK → V_P_ARE_VISIT.VTINTN (NULL for account-level transactions) |
| TRACINTN | NUMBER | FK → V_P_ARE_ACCOUNT.ACINTN |
| TRINEXT | NUMBER | Insurance extension (matches ITINEXT) |
| TRTTCODE | VARCHAR2 | Transaction type code (FK → V_S_ARE_TRTYPE.TTCODE; e.g., 'INV') |
| TRPYOCODE | VARCHAR2 | Payor code |
| TRAMT | NUMBER | Transaction amount (stored in cents — divide by 100 for dollars) |
| TRSTAT | NUMBER | Status: 2=posted, other=not posted |
| TRDT | DATE | Transaction date |
| TRPOSTDTM | DATE | Posted date/time (NULL = not posted) |
| TRBTINTN | NUMBER | FK → Batch internal number (FK → V_P_ARE_JOBS.JBBTINTN) |
| TRTYPE | NUMBER | Transaction type (2=distribution — excluded in some reports) |
| TRBLKTRINTN | NUMBER | FK → linked/block transaction TRINTN |
| TRCMPTRINTN | NUMBER | Companion transaction TRINTN |
| TRCREATDTM | DATE | Created date/time |
| TRCREATBY | VARCHAR2 16 | Created by user |

**Notes:**
- Join to items via `TRVTINTN = ITVTINTN AND TRINEXT = ITINEXT`.
- `TRTTCODE = 'INV'` identifies invoicing transactions.
- `TRVTINTN IS NULL` indicates account-level transactions (no visit link).
- All monetary columns stored in cents.

### V_S_ARE_TRTYPE — Transaction type setup

| Column | Type | Description |
|--------|------|-------------|
| TTINTN | NUMBER | PK — internal number |
| TTCODE | VARCHAR2 | Transaction type code (e.g., 'INV', 'PMT', 'ADJ') |
| TTKIND | NUMBER | Kind: 0=Charge, 1=Payment, 2=Adjustment, 3=Action |
| TTWROFF | NUMBER | Write-off flag: 1=write-off transaction, NULL or other=not |
| TTTYPE | NUMBER | Type (used in billing-per-day: 2=positive units, 21=negative units) |

**Notes:**
- Join to transactions via `TRTTCODE = TTCODE`.
- `TTKIND` is the primary classification for reporting (charges vs payments vs adjustments).

### V_S_ARE_PAYOR — Payor setup

| Column | Type | Description |
|--------|------|-------------|
| PYOINTN | NUMBER | PK — internal number |
| PYOCODE | VARCHAR2 15 | Payor code |
| PYOCLASS | VARCHAR2 | Payor class (billing classification) |
| PYOTYPE | NUMBER | Payor type: 0=Insurance, 1=Client, 2=Self-Pay, 3=Collection, 4=Undetermined |
| PYOSTAT | NUMBER | Status (0 = active) |

### V_P_ARE_PERSON — AR patient demographics

| Column | Type | Description |
|--------|------|-------------|
| PTINTN | NUMBER | PK — internal number |
| PTMRN | VARCHAR2 | Medical record number |
| PTLNAME | VARCHAR2 | Last name |
| PTFNAME | VARCHAR2 | First name |
| PTMNAME | VARCHAR2 | Middle name |
| PTDOB | DATE | Date of birth |

**Notes:**
- This is the SoftAR patient view (separate from V_P_LAB_PATIENT).
- Join to visit via `PTINTN = VTPTINTN`.

### V_P_ARE_ACCOUNT — Account data

| Column | Type | Description |
|--------|------|-------------|
| ACINTN | NUMBER | PK — internal number |
| ACPTINTN | NUMBER | FK → V_P_ARE_PERSON.PTINTN |
| ACCLTINTN | NUMBER | FK → V_S_ARE_CLIENT.CLTINTN |
| ACTYPE | NUMBER | Account type: 1=Client, other=Non-Client |

**Notes:**
- Join to visit via `ACINTN = VTACINTN`.
- `ACTYPE = 1` identifies client (outreach) accounts.

### V_P_ARE_STAY — AR stay data

| Column | Type | Description |
|--------|------|-------------|
| STINTN | NUMBER | PK — internal number |
| STBILNO | VARCHAR2 | Stay billing number |
| STWARD | VARCHAR2 | Ward code |

**Notes:**
- Join to visit via `STINTN = VTSTINTN`.
- Separate from V_P_LAB_STAY (SoftLab).

### SCC SoftAR Built-in Functions (reference only)

| Function | Description |
|----------|-------------|
| `ARE_GetVisitProceduresList(VTINTN)` | Returns concatenated order#/test list for a visit |
| `ARE_GetItemDoc(ITINTN, field)` | Returns doctor code for an item (e.g., `'vprreqdccode'` for requesting doctor) |
| `ARE_GetCollectionTime(ITINTN)` | Returns collection time for an item |
| `DiffSysMod(mod0-3, mod0-3)` | Compares two sets of 4 modifiers; returns 0 if identical |
| `GetPmtPayors(ININTN)` | Returns payment payor list for an invoice |
| `GetSysDate()` | Returns current system date (SCC wrapper around SYSDATE) |
| `parsephone(phone)` | Formats a phone number for display |
| `EmptyToChar(value)` | Returns NULL if value is empty (parameter helper) |
| `AdjustDate(value)` | Converts parameter value to DATE |

**Note:** These are SCC server-side PL/SQL functions available in the SoftAR schema. They work in SCC's report engine but may not be callable from external connections.

---

## SoftMic (Microbiology) Views — Detail

### V_S_MIC_ORGANISM — Organism setup/reference

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK |
| ID | VARCHAR2 7 | Organism code |
| NAME_SHORT | VARCHAR2 31 | Short name |
| NAME | VARCHAR2 59 | Full organism name (e.g., "STAPHYLOCOCCUS AUREUS") |
| SECONDARY_ID | VARCHAR2 7 | Secondary identifier |
| INFECTIOUS_ORG | CHAR 1 | Infectious organism flag |
| SNOMED | VARCHAR2 18 | SNOMED code |
| ACTIVE | VARCHAR2 1 | Active flag (Y/N) |
| IS_CLASS | VARCHAR2 1 | Is-class flag |
| MULTIPLE_RESIST | NUMBER 22 | Multiple resistance flag |
| NO_DAYS_FOR_NOSO | NUMBER 22 | Days for nosocomial classification |

#### Classification Flag Columns (all VARCHAR2 1)

| Column | Description |
|--------|-------------|
| Q_VIRUS | Virus flag |
| R_FUNGI | Fungus flag |
| O1VIRUS | Virus flag (alternate, CHAR 1) |
| A_GRAMPOS | Gram-positive bacteria |
| B_GRAMNEG | Gram-negative bacteria |
| C_GRAMVAR | Gram-variable bacteria |
| N_COCUS | Coccus morphology |
| O_BACILLUS | Bacillus morphology |
| STANDARDDEVIATIONRULES | Standard deviation rules flag |
| AUTOORDERSENSITIVITYTEST | Auto-order sensitivity test flag |
| SUPPRESSFROMREPORTING | Suppress from reporting flag |

#### Sensitivity Panel Flags (all VARCHAR2 1)

Single-letter columns (S, T, U, V, W, X, Y, Z, A1–Z1, D–P, F_0–F_9, ZZ1, ZZ2) are sensitivity panel assignment flags.

#### Alternate Organism Codes

| Column | Type | Description |
|--------|------|-------------|
| ALTORG_0–3 | VARCHAR2 7 | Alternate organism codes |
| O1ALTORG_0–3 | VARCHAR2 7 | Additional alternate organism codes |
| SECID_OPTKEY | VARCHAR2 | Secondary ID option key |

**Notes:**
- Genus and species are not stored separately — parse from `NAME` using `REGEXP_SUBSTR`.
- Organism type is derived from classification flags (`Q_VIRUS`, `R_FUNGI`, `A_GRAMPOS`, `B_GRAMNEG`, `C_GRAMVAR`).
- Yeasts (e.g., Candida) fall under `R_FUNGI`.

---

## Instrument Interface Views — Detail

### V_S_INST_INSTRUMENT — Instrument interface definitions

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 | Instrument code (e.g., TREM, TCEPH, TALIN) |
| NAME | VARCHAR2 | Instrument name (e.g., "Remisol", "Cepheid GeneXpert", "Alinity i") |
| ACTIVE | VARCHAR2 1 | Status: Y=Active, A=Active (auto-service/server), N=Inactive |
| ORD_WORKSTATION_ID | VARCHAR2 | Ordering workstation code (FK → V_S_LAB_WORKSTATION.ID) |
| RES_WORKSTATION_ID | VARCHAR2 | Result workstation code (FK → V_S_LAB_WORKSTATION.ID) |
| INSTR_IDL | VARCHAR2 | Instrument IDL (often matches ID) |
| LISTN_NAME | VARCHAR2 | Listener/driver name (e.g., GenInst, astmGen, genref, phoresis, clinitek) |
| PORT_NAME | VARCHAR2 | Connection string (serial port, TCP socket, or config reference) |
| TEMPLATE_ID | VARCHAR2 | Template workstation ID |
| CHAPTER | VARCHAR2 | Chapter code |
| CREATE_DATE | NUMBER | Creation date (YYYYMMDD format, stored as number) |
| MOD_DATE | NUMBER | Last modified date (YYYYMMDD format, stored as number) |
| DATA_FILE | VARCHAR2 | Data file name |
| DIR_LSTN | VARCHAR2 | Listener directory |
| DIR_NAME | VARCHAR2 | Interface directory path (e.g., I/TREM, I/QUEST, I/AUTO) |
| INST_DEP_1 | VARCHAR2 | Dependency 1 (related instrument/process) |
| INST_DEP_2 | VARCHAR2 | Dependency 2 |
| FLAGS | BLOB | Binary flags (internal) |
| LOADL_FILE | VARCHAR2 | Load file (e.g., dbildl for bi-directional instruments) |
| MAX_CUP | NUMBER | Max cup/position number |
| MAX_SEQ | NUMBER | Max sequence number |
| MAX_TORDER | NUMBER | Max test orders |
| MAX_TRAY | NUMBER | Max tray number |
| TRACE_FILE | VARCHAR2 | Trace/log file name |
| VALIDATE_MRN_AT_POSTING | VARCHAR2 1 | Validate MRN at posting (Y/N) |
| VALIDATE_BILL_AT_POSTING | VARCHAR2 1 | Validate billing at posting (Y/N) |
| INSTRUMENT_TYPE | VARCHAR2 | Instrument type/department: CHEMISTRY, HEMATOLOGY, MICROBIOLOGY, HIS |
| INSTRUMENT_FLAG | VARCHAR2 | Instrument flag: BI_MSG, BI_NO_MSQ, BI_NO_LDL, UNI_NO_LDL, UNI_LDL |
| FL0–FL71_* | VARCHAR2 1 | Feature flags (Y/N) — 70+ boolean flags controlling instrument behavior |

**Notes:**
- `INSTRUMENT_TYPE` categorizes the interface: `CHEMISTRY`, `HEMATOLOGY`, `MICROBIOLOGY` are lab analyzers; `HIS` covers system infrastructure (ADT, order entry, billing, ESB, auto-reporting, label servers, etc.).
- `ACTIVE = 'A'` is used for auto-services/servers (auto-reporting, tracking, RBS, label servers, monitoring); `'Y'` for standard active instruments; `'N'` for inactive/retired.
- `INSTRUMENT_FLAG` values: `BI_MSG` = bidirectional with messages, `BI_NO_MSQ` = bidirectional no message queue, `BI_NO_LDL` = bidirectional no load list, `UNI_NO_LDL` = unidirectional no load list, `UNI_LDL` = unidirectional with load list.
- `CREATE_DATE` and `MOD_DATE` are stored as NUMBER in YYYYMMDD format (not Oracle DATE type).
- `LOADL_FILE = 'dbildl'` indicates the instrument supports bi-directional download.
- `PORT_NAME` contains connection info: serial ports (`/dev/tty*`), TCP sockets (`:host:port ID`), config file references, or "see [other instrument]" cross-references for instruments sharing a middleware connection (e.g., Remisol).
- Many analyzers share a middleware connection (e.g., multiple Beckman AU/DxC/Access instruments route through a single Remisol interface like TREM, JREM, EREM, FREM, WFREM).
- Reference lab interfaces (Quest, Viracor, HistoTrac) use `LISTN_NAME = 'genref'` and `DIR_NAME` like `I/QUEST`, `I/TVCOR`, `I/HIST`.
- `ORD_WORKSTATION_ID` and `RES_WORKSTATION_ID` link to V_S_LAB_WORKSTATION for mapping instruments to SoftLab workstations.

---

## Not Found in Dictionaries

| View | Notes |
|------|-------|
| V_P_IDN_LOG | SoftID scan/event log. Columns: AA_ID (NUMBER 22), SITE_ID (5), USER_ID (51), ROLE_ID (15), PHLEB_ID (51), EVENT (31), PATIENT_ID (23), SPECIMEN_ID (13), WARD_ID (15), DEVICE_ID (51), TERMINAL_ID (5), MESSAGE (2048), LOG_DT/LOG_DT_SERVER/LOG_DT_UTC/LOG_DT_DEV (DATE). **Validated facts:** `ROLE_ID` DOES resolve cleanly to `V_S_IDN_ROLE.ID` (every observed value matched except one blank/NULL-ish string). Values include both ward codes (TUH7E, JNS3C, CHH4S, AOH1C...) and functional codes (RNBLD, RNNONBLD, RNEDALL, *PCALL). `ROLE_ID` is populated on **every event type except `LoginToSoftID`** — it's a reliable role signal across all events, not just `RoleSelection`. `PHLEB_ID` is the collector-identity join key (matches `V_P_LAB_TUBEINFO.COLLECTION_PHLEB`); `USER_ID` is a different value — validated that zero collectors match via `USER_ID` when `PHLEB_ID` doesn't. `EVENT` enum observed: UploadCollection, LabelPrinted, CollectionListDownload, RoleSelection, PatientCollectionQuery, LoginToSoftID, LogOffFromSoftID, MicroSourceSiteUpdated, PatientMismatch, KeyedPatientCollectionQuery, SpecimenMismatch. Canonical nurse-role list (from `V_S_IDN_ROLE` by NAME): `RNBLD`, `RNNONBLD`, `RNEDALL` — but in observed monthly data, essentially only `RNBLD` fires (135K events/month vs. 0 for the others). Use IN-list for classification, never pattern matching — `TUHBLD` ("TUH Bleeding Time") would be a false positive on any `%BLD` pattern. |
| V_P_GCM_OTESTRESULT | GCM (likely General Communication Module) test results table with columns GP_OTR_*. Appears to be for Cytogenetics/Pathology results based on column names (KTYPE, KARYOTYPE, ABNCH, METACELLS, INTERCELLS, etc.). Table exists but is **empty in production** — not useful for standard lab TAT queries. Use V_P_LAB_TEST_RESULT instead. |
| V_P_GCM_QUEUEMSG / V_P_GCM_MOMCALL / V_P_GCM_QUEUE / V_P_GCM_QUEUEPAR | GCM HIS↔LIS interface queue/message tables. Schema looks promising for raw HL7 storage (`GP_QUEM_MSG` CLOB, `GP_MOMCALL_MESSAGE` BLOB, ORDNUM/HISNUM/LISNUM keys, MOM event/status fields), but **all are empty in this deployment** — including the underlying `LAB.GP_QUEUEMSG` / `LAB.GP_MOMCALL` base tables. HL7 messages are not persisted in Oracle here, so raw OBR[11] cannot be retrieved from these views. Use `V_P_LAB_SPECIMEN.NURSE_COLL` (LIS-stored OBR[11]) for nurse-vs-lab collect classification instead. |
| SoftID (IDN) family | 18 views: `V_P_IDN_LOG`, `V_LAB_IDN_ROUTE`, `V_S_IDN_ASSIGN`, `V_S_IDN_DEVICE_OPTION`, `V_S_IDN_DOMAIN`, `V_S_IDN_DOMAIN_{CANMSG,LBLFMT,MESSAGE,PARAM,PRNMODEL,SOUND}`, `V_S_IDN_FOLDER`, `V_S_IDN_ROLE`, `V_S_IDN_ROLE_{FOLDER,PARAM,ROUTE,TEST,TUBE}`. SoftID is SCC's specimen-ID / barcode-scanning module. Key views: `V_S_IDN_ROLE` (AA_ID, DOMAIN_ID, ID, NAME + timestamps) and `V_S_IDN_ASSIGN` (AA_ID, TECH_ID, ROLE_AA_ID, IS_ACTIVE, USER_LOGIN_ID, ROLE_ID). **Roles are ward-scoped, not job-scoped** — do not use for Nurse/Phleb classification (see memory `project_softid_role_model.md`). For collector-type, use `V_S_LAB_PHLEBOTOMIST.NURSE`. |
| USER_COMPARISON_SCAN / _SUMMARY / _VALUES | Custom (non-SCC) views — no `V_` prefix. Likely hospital-built reporting views; not part of SoftID or standard SCC modules. |
| V_S_GCM_{GROSSCANNED,IMGSCANNEDCAT,SCANNER} | Pathology grossing/imaging module (same `GCM` family as the empty `V_P_GCM_OTESTRESULT`). Not relevant for blood-bank / chemistry / specimen-collection queries. |

---

## Complete View Reference (328+ views, including SoftAR)

### SoftLab — Patient/Transactional (V_P_LAB_*)
| View | Description |
|------|-------------|
| V_P_LAB_ACT_HISTORY | Order history information |
| V_P_LAB_ALIQUOTING_ACTION | Aliquoting actions |
| V_P_LAB_ASSIGNMENT | Specimens assigned to collection list |
| V_P_LAB_ATEST_SORT | Internal view — do not use standalone |
| V_P_LAB_AUXILIARY_DOCTOR | Auxiliary doctor information |
| V_P_LAB_BILLING_EVENT | Billing events |
| V_P_LAB_CALL | Call history information |
| V_P_LAB_CALL_DOCUM | Call request documentation |
| V_P_LAB_CALL_INTNOTE | Call internal note |
| V_P_LAB_CALL_REQUEST | Call request information |
| V_P_LAB_CALL_TEST | Test in call request |
| V_P_LAB_CANCELLATION | Canceled test information |
| V_P_LAB_COLLECTION_LIST | Collection list data |
| V_P_LAB_DIAGNOSIS | Order-test diagnosis information |
| V_P_LAB_FBUNIT_INFO | Foreign Blood Bank unit information |
| V_P_LAB_FBUNIT_STATUS | Foreign Blood Bank unit status |
| V_P_LAB_INSURANCE | Patient insurance data |
| V_P_LAB_INTERNAL_NOTE | Internal notes (patient/stay/order/specimen/result) |
| V_P_LAB_MESSAGE | Comments |
| V_P_LAB_MISCEL_INFO | Patient/Stay/Order additional data |
| V_P_LAB_ORDER | Order data |
| V_P_LAB_ORDERED_TEST | Ordered test data |
| V_P_LAB_ORDERED_TEST_CHILD | Cycling ordered tests |
| V_P_LAB_ORDERED_TEST_COMPONENT | Link between ordered test and test component |
| V_P_LAB_ORDERING_PATTERN | Recurring order pattern data |
| V_P_LAB_ORDER_ABN | ABN form signed status |
| V_P_LAB_ORDTEST_REPORTTO | Ordered test report-to data |
| V_P_LAB_PATHOLOGY_REVIEW | Pathology review data |
| V_P_LAB_PATIENT | Patient data |
| V_P_LAB_PAT_HISTORY | Patient history information |
| V_P_LAB_PAT_KNOWNAS | Patient known-as history |
| V_P_LAB_PAYOR | Payor for order — deprecated, use ORDER.FAILED_PAYOR |
| V_P_LAB_PENDING_RESULT | Pending test results only |
| V_P_LAB_PERF_ORGANIZATION | Performing organization |
| V_P_LAB_PLAB_HISTORY | Stay history information |
| V_P_LAB_PRINTED_LABELS | Printed labels |
| V_P_LAB_PROMPT_TEST | Prompt test results |
| V_P_LAB_RBS_RULE | Triggered RBS rules in the order |
| V_P_LAB_RECUR_REPORTTO | Recurring order report-to data |
| V_P_LAB_REOCCURRING_COLLECTION | Standing order collection info |
| V_P_LAB_REPORT | Printed report information |
| V_P_LAB_RESULT_INTERPRETER | Principal result interpreter |
| V_P_LAB_SPECIMEN | Specimen data |
| V_P_LAB_SPECIMEN_ATTS | Additional specimen information |
| V_P_LAB_SPECIMEN_BARCODE | Tube barcode |
| V_P_LAB_SPECIMEN_QUALITY | Specimen quality |
| V_P_LAB_SPECIMEN_TRACKING_LIST | Specimen tracking list |
| V_P_LAB_SPECIMEN_TUBE | Specimen tube info (combined specimen + tube) |
| V_P_LAB_STAY | Stay information |
| V_P_LAB_TASK_LIST | Tasklist creation parameters |
| V_P_LAB_TASK_LIST_ITEM | Orders/specimens in tasklist |
| V_P_LAB_TEST_DIAGNOSIS | Test diagnosis information |
| V_P_LAB_TEST_RESULT | Test result data |
| V_P_LAB_TEST_RESULT_HISTORY | Test result modification history |
| V_P_LAB_TEST_RESULT_QC | Test result QC information |
| V_P_LAB_TEST_TO_TUBE | Container receiving information |
| V_P_LAB_TUBE | Ordered specimen / tube info |
| V_P_LAB_TUBEINFO | Specimen tube info |
| V_P_LAB_TUBE_HISTORY | Specimen tube history |
| V_P_LAB_TUBE_LOCATION | Specimen tracking history |

### SoftLab — Setup/Reference (V_S_LAB_*)
| View | Description |
|------|-------------|
| V_S_LAB_ACTION | Workstation switching actions |
| V_S_LAB_ALERT | Deprecated — does not exist |
| V_S_LAB_CANNED_MESSAGE | Canned message setup |
| V_S_LAB_CASES | Cases (ESO) setup |
| V_S_LAB_CLEANUPRULES | Cleanup rules |
| V_S_LAB_CLINIC | Clinic setup |
| V_S_LAB_CLINIC_ASSOCIATE | Clinic associated doctors |
| V_S_LAB_CODES_TRANSLATION | Codes translation setup |
| V_S_LAB_COLL_CENTER | Multisite ordering locations / collection centers |
| V_S_LAB_DEFINITIONS | Settings-definitions setup |
| V_S_LAB_DEF_INSTR_COLL | Collection instruction definitions |
| V_S_LAB_DEF_INSTR_PROC | Collection procedure definitions |
| V_S_LAB_DEF_MESS_CATEGORY | Canned message category definitions |
| V_S_LAB_DEF_PATIENT_TYPE | Patient type |
| V_S_LAB_DEF_SPECIMEN_TYPES | Specimen type definitions |
| V_S_LAB_DEPARTMENT | Department definition |
| V_S_LAB_DIAGNOSIS | Diagnosis setup |
| V_S_LAB_DOCTOR | Doctor setup |
| V_S_LAB_DOCTORS_GROUP | Doctor group setup |
| V_S_LAB_DOCTOR_ASSOCIATE | Doctor associated clinics |
| V_S_LAB_DOCTOR_HIS | Doctor HIS account definition |
| V_S_LAB_DOC_AUTHORIZATION | Deprecated — does not exist |
| V_S_LAB_ENVIRONMENT | Testing environment definitions |
| V_S_LAB_ENVSELECTION | Environment selection |
| V_S_LAB_HIS_ACCOUNT | HIS account depot setup |
| V_S_LAB_HIS_MAPPING | HIS mapping setup |
| V_S_LAB_INSTRUMENT_GROUP | Instrument group setup |
| V_S_LAB_INSURANCE | Insurance setup |
| V_S_LAB_ISOLATION | Deprecated — does not exist |
| V_S_LAB_KEYPAD | Keypad definition |
| V_S_LAB_LBL_SETUP | Label printing setup |
| V_S_LAB_LOCATION | Location definition |
| V_S_LAB_LOCATION_ACCOUNT | Reference lab location account |
| V_S_LAB_LOINC | LOINC setup |
| V_S_LAB_MEDICAL_SERVICE | Medical service setup |
| V_S_LAB_METHODOLOGY | Available methodologies |
| V_S_LAB_MISC_TAGS | Tags for misc records |
| V_S_LAB_ONLY_DEPARTMENT | Subset of DEPARTMENT |
| V_S_LAB_ONLY_LOCATION | Subset of LOCATION |
| V_S_LAB_ONLY_SPECIMEN | Subset of SPECIMEN |
| V_S_LAB_ONLY_WORKSTATION | Subset of WORKSTATION |
| V_S_LAB_ORDPATTERN | Ordering pattern definition |
| V_S_LAB_PHLEBOTOMIST | Phlebotomist setup |
| V_S_LAB_PHLEB_CLASR_ITEM | Route items in class of routes |
| V_S_LAB_PHLEB_CLASS_ROUTE | Classes of routes setup |
| V_S_LAB_PHLEB_ROUTE | Phlebotomist route setup |
| V_S_LAB_PRECISION_RULE | Multi-level precision rules |
| V_S_LAB_PRIOR_REASON | Priority reason |
| V_S_LAB_PROGRAM | Deprecated — does not exist |
| V_S_LAB_RBSRRULE | RBS setup |
| V_S_LAB_REDIRECTION | Workstation redirection setup |
| V_S_LAB_REGION | Multisite regions setup |
| V_S_LAB_REPORT_DESTINATION | Ward/doctor report destination |
| V_S_LAB_REPORT_FORMAT | Deprecated — use REPORT_SETUP |
| V_S_LAB_REPORT_SETUP | Query and report format setup |
| V_S_LAB_REPORT_SETUP_ITEM | Report setup items |
| V_S_LAB_RV_RBS_ACTION | RBS action |
| V_S_LAB_RV_RBS_ACTION_PARAM | RBS action parameter |
| V_S_LAB_RV_RBS_COND | RBS condition line |
| V_S_LAB_RV_RBS_COND_ATTR | RBS condition attribute |
| V_S_LAB_RV_RBS_FOLDER | RBS folder |
| V_S_LAB_RV_RBS_RULE | RBS rule |
| V_S_LAB_RV_WLIST | Triage worklist template |
| V_S_LAB_RV_WLIST_ITEM | Triage worklist item |
| V_S_LAB_SALESPERSON | Salesperson info |
| V_S_LAB_SETUP_TRNSL | Insurance codes translation |
| V_S_LAB_SNOMEDCT | Snomed CT (compatibility) |
| V_S_LAB_SNOMEDREL | Snomed CT relationships (compatibility) |
| V_S_LAB_SPECIMEN | Specimen tube types setup |
| V_S_LAB_SPECIMEN_ATTS | Specimen attributes |
| V_S_LAB_SPECQUAL | Specimen quality setup |
| V_S_LAB_SPTR_LOCATION | Specimen tracking locations |
| V_S_LAB_SPTR_SETUP | Specimen tracking setup |
| V_S_LAB_SPTR_STATUS | Specimen tracking status |
| V_S_LAB_SPTR_STOP | Specimen tracking stop |
| V_S_LAB_STUDY | Study setup |
| V_S_LAB_TAGSETUP | Tag setup |
| V_S_LAB_TAT_LIMIT | TAT limit — deprecated |
| V_S_LAB_TEMPERATURE | Specimen temperature setup |
| V_S_LAB_TEMPLATE | Templates setup |
| V_S_LAB_TEMPLATE_GROUP | Template group setup |
| V_S_LAB_TEMPLATE_GROUP_ALL | Deprecated — use TEMPLATE_GROUP |
| V_S_LAB_TEMPLATE_ITEM | Items (tests/workstations) in template |
| V_S_LAB_TEMPLATE_QC | QC specimen params in template |
| V_S_LAB_TEMPLATE_ST | SC specimen params in template |
| V_S_LAB_TERMINAL | Terminals in collection centers |
| V_S_LAB_TEST | Individual test setup |
| V_S_LAB_TEST_BILL_CODE | Deprecated — billing is in AR |
| V_S_LAB_TEST_COMPONENT | Components of a group test |
| V_S_LAB_TEST_DIAGNOSIS | Test allowed/not-allowed diagnoses |
| V_S_LAB_TEST_ENVIRONMENT | Test definition by environment/workstation |
| V_S_LAB_TEST_FORMULARY | Test formulary setup |
| V_S_LAB_TEST_GROUP | Group test setup |
| V_S_LAB_TEST_GROUP_SPECIMEN | Group test specimen handling |
| V_S_LAB_TEST_GRP_SHIPPING_TEMP | Deprecated — use TEST_GRP_SH_TEMP |
| V_S_LAB_TEST_GRP_SH_TEMP | Group test shipping temperature |
| V_S_LAB_TEST_HIS | HIS test setup |
| V_S_LAB_TEST_LEGALSOURCE | Micro test source definitions |
| V_S_LAB_TEST_METHODOLOGY | Test methodology |
| V_S_LAB_TEST_MICLINKTESTS | Micro test associated tests |
| V_S_LAB_TEST_MICPOSRESULT | Positive/negative result checking |
| V_S_LAB_TEST_MICSRCCAT | Micro source categories |
| V_S_LAB_TEST_MICSTAIN | Stain-isolate checking |
| V_S_LAB_TEST_RANGE | Test result ranges |
| V_S_LAB_TEST_SHIPPING_TEMP | Test shipping temperature |
| V_S_LAB_TEST_SPECIMEN | Test specimen information |
| V_S_LAB_TEST_SYNONYM | Test synonym definitions |
| V_S_LAB_TEST_TEMPERATURE | Specimen handling setup |
| V_S_LAB_TEST_VALUE | Test result values |
| V_S_LAB_TRFILTER_ITEM | Location/department/workstation codes |
| V_S_LAB_TUBE_CAPACITY | Tube type containers |
| V_S_LAB_UNIVERSALID | Universal ID setup |
| V_S_LAB_WORKSTATION | Workstation definition |
| V_S_LAB_WORKSTATION_GROUP | Workstation group setup |
| V_S_RAW_VALUES | Cytology/Pathology unit values |

### SoftBank — Patient/Transactional (V_P_BB_*)
| View | Description |
|------|-------------|
| V_P_BB_Action | Transfusion/crossmatch actions |
| V_P_BB_BB_Exception | Exceptions |
| V_P_BB_BB_Order | Blood bank orders |
| V_P_BB_Blood_Specimen | Blood specimens |
| V_P_BB_Charge | Charges |
| V_P_BB_Comment_Line | Free text comment lines |
| V_P_BB_Emergency_Unit | Emergency unit issues |
| V_P_BB_Nurse_Observation | Nurse observations |
| V_P_BB_Patient | Patient demographics (BB) |
| V_P_BB_Patient_Anti | Patient antibodies/antigens |
| V_P_BB_Patient_Comment | Stay comments |
| V_P_BB_Patient_Extended | Extended patient demographics |
| V_P_BB_Patient_HLA | Patient HLA data |
| V_P_BB_Patient_Message | Patient special messages |
| V_P_BB_Patient_Patient | Patient-to-patient links |
| V_P_BB_Patient_Stay | Patient stays (BB) |
| V_P_BB_Patient_Transfusion | Transfusion records |
| V_P_BB_Patient_Unit | Patient-to-unit links |
| V_P_BB_Patient_Vital | Patient vital signs |
| V_P_BB_Product_Order | Product orders |
| V_P_BB_QC_Rack | QC racks |
| V_P_BB_QC_Reagent | QC reagents |
| V_P_BB_QC_Reagent_In_Rack | QC reagents in racks |
| V_P_BB_QC_Result | QC test results |
| V_P_BB_QC_Test | QC tests |
| V_P_BB_RX_Product | Supplies |
| V_P_BB_Remote_Unit_History | Remote unit history |
| V_P_BB_ReportDestination | Report destinations |
| V_P_BB_Result | Test results |
| V_P_BB_Selected_Unit | Selected units for patients |
| V_P_BB_Selun_Instruction | Selected unit instructions |
| V_P_BB_Test | Tests |
| V_P_BB_Transfusion_Vital | Transfusion-to-vitals links |
| V_P_BB_Unit | Blood units |
| V_P_BB_UnitExtData | Unit external data |
| V_P_BB_Unit_Anti | Unit antibodies/antigens/attributes |
| V_P_BB_Unit_Instruction | Unit instructions |
| V_P_BB_Unit_Lbl | Unit labels |
| V_P_BB_Unit_Segment | Unit segments |
| V_P_BB_Unit_Segment_Link | Unit-to-segment links |
| V_P_BB_Unit_Unit | Unit-to-unit links |
| V_P_BB_Vital_Ref | Vital signs reference links |
| V_P_BB_Worksheet | Worksheets |
| V_P_BB_Worksheet_Element | Worksheet elements |
| V_P_BB_X_BBWild | General purpose record |
| V_P_BB_X_Counter | Internal counters |
| V_P_BB_X_Version | Version control |

### SoftBank — Setup (V_S_BB_*)
| View | Description |
|------|-------------|
| V_S_BB_QC_Template | QC test template |
| V_S_BB_QC_Template_Element | QC template element |
| V_S_BB_Y_Action | Action setup |
| V_S_BB_Y_Action_ExtId | Supplier external id setup |
| V_S_BB_Y_Antibody | Antibody setup |
| V_S_BB_Y_Antigen | Antigen setup |
| V_S_BB_Y_Bl_Prd_Attribute | Blood product attribute setup |
| V_S_BB_Y_Blood_Alt_ABORh | Alternative ABO/Rh for blood product |
| V_S_BB_Y_Blood_ExtId | Blood product supplier external id |
| V_S_BB_Y_Blood_Neo_ABORh | Neonatal ABO/Rh for blood product |
| V_S_BB_Y_Blood_Product | Blood product setup |
| V_S_BB_Y_Blood_SpcMsg | Patient special messages for blood product |
| V_S_BB_Y_Canned_Message | Canned message setup |
| V_S_BB_Y_Charge | Charge setup |
| V_S_BB_Y_Coll_Facility_Prefix | ISBT collection facility prefixes |
| V_S_BB_Y_Collection_Facility | Collection facility setup |
| V_S_BB_Y_Diagnosis | DRG setup |
| V_S_BB_Y_Diagnosis_ICD | ICD setup |
| V_S_BB_Y_Discard | Discard reason setup |
| V_S_BB_Y_Exception | Exception setup |
| V_S_BB_Y_Instruction | Instruction setup |
| V_S_BB_Y_Instruction_SpcMsg | Instruction special messages |
| V_S_BB_Y_Interpretation | Test interpretation setup |
| V_S_BB_Y_Medical_Services | Medical service setup |
| V_S_BB_Y_Nurse | Nurse setup |
| V_S_BB_Y_Patient_Type | Patient type setup |
| V_S_BB_Y_Phlebotomist | Phlebotomist setup |
| V_S_BB_Y_Physician | Physician setup |
| V_S_BB_Y_QC_Reagent | QC reagent setup |
| V_S_BB_Y_QC_Reagent_Site | QC reagent site links |
| V_S_BB_Y_Special_Message | Patient message setup |
| V_S_BB_Y_Stock_Level | Stock level setup |
| V_S_BB_Y_Supplier | Supplier setup |
| V_S_BB_Y_Surgical_Procedure | Surgical procedure setup |
| V_S_BB_Y_Test | Test setup |
| V_S_BB_Y_Test_Logic_Table | Test logic tables |
| V_S_BB_Y_Test_Phase | Test phase interpretation |
| V_S_BB_Y_Test_Phase_Group | Test phase value groups |
| V_S_BB_Y_Transfusion_Reaction | Transfusion reaction setup |
| V_S_BB_Y_Unit_Attribute | Unit attribute setup |
| V_S_BB_Y_Unit_Condition | Unit condition setup |
| V_S_BB_Y_Unit_Location | Unit location setup |
| V_S_BB_Y_Ward | Ward setup |
| V_S_BB_Y_Worksheet | Worksheet setup |
| V_S_BB_Y_Workstation | Workstation setup |

### SoftMic — Microbiology (V_P_MIC_* / V_S_MIC_* / V_P_BCC_*)
| View | Description |
|------|-------------|
| V_P_BCC_FREQUENCY | Contamination frequencies by ward |
| V_P_BCC_GROUP_VIOLATIONS | BCC group violations report |
| V_P_BCC_ORGANISM_VIOLATIONS | BCC organism violations report |
| V_P_MIC_ACTIVE_ORDER | Micro orders |
| V_P_MIC_COMM | Micro order comments |
| V_P_MIC_COMMON_MEDIACOMM | Common media comments |
| V_P_MIC_ISOCOMM | Isolate comments |
| V_P_MIC_ISOLATE | Isolate information |
| V_P_MIC_MEDIA | Media information |
| V_P_MIC_MEDIACOMM | Media comments |
| V_P_MIC_ORDER_COMM | Order comments |
| V_P_MIC_PATHREVIEW | Micro pathology review |
| V_P_MIC_SENSI | Drug sensitivity results |
| V_P_MIC_TEST | Micro test information |
| V_P_MIC_TESTCOMM | Test comments |
| V_P_MIC_TEST_REPORTTO | Test report-to data |
| V_P_MIC_THERAPYCOMM | Drug comments |
| V_P_TMP_EPI_ORDERS | Temporary orders for BCC report |
| V_S_MIC_ACTION | Actions |
| V_S_MIC_ALTERNATIVE_ORGANISMS | Organism alternatives |
| V_S_MIC_ASSOCIATED_RULE | Rule-organism-drug links |
| V_S_MIC_DRUG | Drug definitions |
| V_S_MIC_DRUG_CLASS | Drug-class links |
| V_S_MIC_EPIREP | Epidemiology report |
| V_S_MIC_EPI_OPTIONS | Epi report options |
| V_S_MIC_EPI_VALUES | Epi report values |
| V_S_MIC_MEDIA | Media definitions |
| V_S_MIC_ORGANISM | Organism setup |
| V_S_MIC_ORGANISM_CLASS | Organism-class links |
| V_S_MIC_PANEL | Panel definitions |
| V_S_MIC_PANEL_ITEM_VALUES | Panel component values |
| V_S_MIC_PROCESS | Process definitions |
| V_S_MIC_RULE | Micro rules |
| V_S_MIC_RULES | Micro rules (alt) |
| V_S_MIC_SOURCE | Source definitions |
| V_S_MIC_SPECIMEN_PROCEDURE | Specimen procedure definitions |
| V_S_MIC_WORKLIST | Worklist setup |
| V_S_MIC_WORKLIST_AUTORES | Worklist auto-results |
| V_S_MIC_WORKLIST_DEPART | Worklist departments |
| V_S_MIC_WORKLIST_DEP_QUERY | Worklist department queries |
| V_S_MIC_WORKLIST_MEDIA | Worklist media |
| V_S_MIC_WORKLIST_PANEL | Worklist panels |
| V_S_MIC_WORKLIST_SPEC_PROC | Worklist specimen procedures |
| V_S_MIC_WORKLIST_SRC_CAT | Worklist source categories |
| V_S_MIC_WORKLIST_STUDY_TST | Worklist study tests |
| V_S_MIC_WORKLIST_TEST | Worklist tests |
| V_S_MIC_WORKLIST_WORKST | Worklist workstations |

### Instruments (V_S_INST_* / V_S_ERROR_TBL)
| View | Description |
|------|-------------|
| V_S_ERROR_TBL | Translation code error/warning records |
| V_S_INST_ADJUST_TBL | Result adjustment rules |
| V_S_INST_CONVERSION_TBL | Instrument field conversion rules |
| V_S_INST_INSTRUMENT | Instrument parameters |
| V_S_INST_PARAMETERS | Instrument interface parameters |
| V_S_INST_PARAM_DESC | Available parameter descriptions |
| V_S_INST_ROBOTIC_INSTR | Robotic instrument codes |
| V_S_INST_ROBOTIC_ROUTES | Robotic routes (instrument-to-stop) |
| V_S_INST_ROBOTIC_STOPS | Robotic stops |
| V_S_INST_TRANS_TBL | Instrument translation table |
| V_S_INST_WORKSTATIONS | Workstations filtered for instruments |

### SoftAR — Patient/Transactional (V_P_ARE_*)
| View | Description |
|------|-------------|
| V_P_ARE_ACCOUNT | Account data |
| V_P_ARE_ACTIVITY | Activity data |
| V_P_ARE_AUDITTRAIL | Audit trail |
| V_P_ARE_AUDITTRAILTECH | Audit trail (tech) |
| V_P_ARE_BATCH | Batch processing |
| V_P_ARE_BILLERROR | Billing errors |
| V_P_ARE_CLAIM | Claims |
| V_P_ARE_CLAIMREGISTER | Claim register |
| V_P_ARE_CLTPOL | Client policy |
| V_P_ARE_CMNT | Comments |
| V_P_ARE_CREDITDISTR | Credit distribution |
| V_P_ARE_CREDITS | Credits |
| V_P_ARE_CUSTOMDATA | Custom data fields |
| V_P_ARE_DATAREPOSITORY | Data repository |
| V_P_ARE_DEPOSIT | Deposits |
| V_P_ARE_DETTRANS | Detail transactions |
| V_P_ARE_DL3MAXPRS | DL3 max prices |
| V_P_ARE_DLNREDPRS | DLN reduced prices |
| V_P_ARE_EMPLOYER | Employer data |
| V_P_ARE_FINPERIOD | Financial period |
| V_P_ARE_GLREGISTER | GL register |
| V_P_ARE_GUARANTOR | Guarantor data |
| V_P_ARE_HIPP_* | HIPAA EDI segment views (AK1–AK9, AMT, BPR, CAS, CLP, etc.) |
| V_P_ARE_INTNAUDIT | Internal audit |
| V_P_ARE_INVOICE | Invoices |
| V_P_ARE_INVTRACE | Invoice trace |
| V_P_ARE_ITEM | Billing line items |
| V_P_ARE_ITEMREGISTER | Item register |
| V_P_ARE_IWSUPDATE | IWS update |
| V_P_ARE_JOBERRORS | Job errors |
| V_P_ARE_JOBOUTPUTS | Job outputs |
| V_P_ARE_JOBS | Jobs |
| V_P_ARE_LOADTMP | Load temp |
| V_P_ARE_MONTHCLOSELOG | Month close log |
| V_P_ARE_OVERPAIDITEMS | Overpaid items |
| V_P_ARE_PERSON | Person data |
| V_P_ARE_POLICY | Policy data |
| V_P_ARE_POSTINGTRACE | Posting trace |
| V_P_ARE_POSTREGISTER | Post register |
| V_P_ARE_POSTREGTOTALS | Post register totals |
| V_P_ARE_PROBLEM | Problem tracking |
| V_P_ARE_PROCCOMP | Procedure components |
| V_P_ARE_RECURRJOBS | Recurring jobs |
| V_P_ARE_REFERRENCES | References |
| V_P_ARE_REFLABTREND | Reference lab trend |
| V_P_ARE_REFPROC | Reference procedures |
| V_P_ARE_RMTBATCH | Remittance batch |
| V_P_ARE_RMTBATCHADJ | Remittance batch adjustments |
| V_P_ARE_RMTCLAIM | Remittance claim |
| V_P_ARE_RMTCLAIMADJ | Remittance claim adjustments |
| V_P_ARE_RMTCLAIMAMT | Remittance claim amounts |
| V_P_ARE_RMTCLAIMDATE | Remittance claim dates |
| V_P_ARE_RMTCLAIMMIA | Remittance claim MIA |
| V_P_ARE_RMTCLAIMMOA | Remittance claim MOA |
| V_P_ARE_RMTERROR | Remittance errors |
| V_P_ARE_RMTFILE | Remittance files |
| V_P_ARE_RMTITEM | Remittance items |
| V_P_ARE_RMTITEMADJ | Remittance item adjustments |
| V_P_ARE_RMTITEMAMT | Remittance item amounts |
| V_P_ARE_RMTITEMDATE | Remittance item dates |
| V_P_ARE_RMTITEMLQ | Remittance item LQ |
| V_P_ARE_SCCSECUSER | SCC security user |
| V_P_ARE_STATPERIOD | Statistical period |
| V_P_ARE_STATUSREGISTER | Status register |
| V_P_ARE_STAY | Stay data (AR) |
| V_P_ARE_SUBITEM | Sub-items |
| V_P_ARE_TOTAL | Totals |
| V_P_ARE_TQUEUE | Transaction queue |
| V_P_ARE_TQUEUEITEM | Transaction queue items |
| V_P_ARE_TRANS | Transactions |
| V_P_ARE_TRANSTRACE | Transaction trace |
| V_P_ARE_UPDEVENTLOG | Update event log |
| V_P_ARE_VISIT | Visit data |
| V_P_ARE_VISITAUTH | Visit authorization |
| V_P_ARE_VISITDIAG | Visit diagnoses |
| V_P_ARE_VISITEXTADVCODES | Visit external advance codes |
| V_P_ARE_VISITPROC | Visit procedures |
| V_P_ARE_VPRITLINK | Visit-to-item links |

### SoftAR — Setup/Reference (V_S_ARE_*)
| View | Description |
|------|-------------|
| V_S_ARE_ABNMODIFIER | ABN modifier setup |
| V_S_ARE_ABNQUALIFIER | ABN qualifier setup |
| V_S_ARE_ACTIONTOINFORM | Action-to-inform setup |
| V_S_ARE_ACTIVITYDEF | Activity definitions |
| V_S_ARE_ACTRESULTDEF | Activity result definitions |
| V_S_ARE_ALTERVISIT | Alternate visit setup |
| V_S_ARE_ARCFG | AR configuration |
| V_S_ARE_ARCFGEXD | AR configuration extended |
| V_S_ARE_ARERROR | AR error definitions |
| V_S_ARE_AREXCEPTION | AR exception definitions |
| V_S_ARE_BATCHLAYOUT | Batch layout setup |
| V_S_ARE_BILENTITY | Billing entity setup |
| V_S_ARE_BILLFMT | Bill format setup |
| V_S_ARE_BILLRULES | Billing rules |
| V_S_ARE_CCI | CCI (Correct Coding Initiative) edit pairs |
| V_S_ARE_CLIENT | Client setup |
| V_S_ARE_CLIENT_ANNEX | Client annex data |
| V_S_ARE_CLTDOCTOR | Client doctor links |
| V_S_ARE_COLAGNCY | Collection agency |
| V_S_ARE_COMMISSION | Commission setup |
| V_S_ARE_COMMISSIONTERM | Commission terms |
| V_S_ARE_COMPBILL | Composite billing |
| V_S_ARE_CORRACTION | Corrective action setup |
| V_S_ARE_CORRACTIVITY | Corrective activity setup |
| V_S_ARE_CPTTABLE | CPT/HCPCS code reference |
| V_S_ARE_DENIAL | Denial reason setup |
| V_S_ARE_DEPARTMENT | Department setup (AR) |
| V_S_ARE_DEPOTPLACE | Depot/place setup |
| V_S_ARE_DIAGCPT | Diagnosis-to-CPT mapping |
| V_S_ARE_DIAGNOSIS | Diagnosis setup (AR) |
| V_S_ARE_DIAGNOSISTYPE | Diagnosis type setup |
| V_S_ARE_DICT_IK304 | EDI dictionary IK304 |
| V_S_ARE_DICT_IK403 | EDI dictionary IK403 |
| V_S_ARE_DICT_IK501 | EDI dictionary IK501 |
| V_S_ARE_DICT_IK502 | EDI dictionary IK502 |
| V_S_ARE_DICT_STC01_1 | EDI dictionary STC01 (1) |
| V_S_ARE_DICT_STC01_2 | EDI dictionary STC01 (2) |
| V_S_ARE_DICT_TA105 | EDI dictionary TA105 |
| V_S_ARE_DISCOUNT | Discount setup |
| V_S_ARE_DOCNUM | Document number setup |
| V_S_ARE_DOCTOR | Doctor setup (AR) |
| V_S_ARE_ELIGIBILITY | Eligibility setup |
| V_S_ARE_EXTADVCODES | External advance codes |
| V_S_ARE_FACILITY | Facility setup |
| V_S_ARE_FACNUM | Facility number setup |
| V_S_ARE_FCLTPAYORREDIR | Facility payor redirection |
| V_S_ARE_FCLTYRVU | Facility RVU setup |
| V_S_ARE_FINCLASS | Financial class setup |
| V_S_ARE_FORMAT | Format setup |
| V_S_ARE_FORMATTRAIL | Format trail |
| V_S_ARE_FREQLIMITS | Frequency limits |
| V_S_ARE_GLDATAFIELD | GL data field setup |
| V_S_ARE_GLDATAMAP | GL data mapping |
| V_S_ARE_GLJOURNALFIELD | GL journal field setup |
| V_S_ARE_GLJOURNALREC | GL journal record |
| V_S_ARE_GLTRANSMAP | GL transaction mapping |
| V_S_ARE_GROUPID | Group ID setup |
| V_S_ARE_GRPRULES | Group rules |
| V_S_ARE_HL7TRTABLE | HL7 translation table |
| V_S_ARE_INSUR | Insurance setup (AR) |
| V_S_ARE_ITEMCONFIG | Item configuration |
| V_S_ARE_LOOKUPSETTINGS | Lookup settings |
| V_S_ARE_MESSAGE | Message setup |
| V_S_ARE_MODIFIER | Modifier setup |
| V_S_ARE_ORDERCONSCRIT | Order consolidation criteria |
| V_S_ARE_OVERLAPPEDTEST | Overlapped test setup |
| V_S_ARE_PATIENTTYPE | Patient type setup (AR) |
| V_S_ARE_PAYOR | Payor setup |
| V_S_ARE_PAYORREDIR | Payor redirection |
| V_S_ARE_PRICE | Price setup |
| V_S_ARE_PROVNUM | Provider number setup |
| V_S_ARE_RALTERVISIT | Reverse alternate visit |
| V_S_ARE_RBS | Rules-based system (AR) |
| V_S_ARE_REFLABCODES | Reference lab codes |
| V_S_ARE_REFLECTICD | Reflex ICD |
| V_S_ARE_REMARKCODE | Remark code setup |
| V_S_ARE_REVCODE | Revenue code setup |
| V_S_ARE_RITEMCONFIG | Reverse item configuration |
| V_S_ARE_ROCC | ROCC setup |
| V_S_ARE_RPTLINK | Report link setup |
| V_S_ARE_RVU | RVU (Relative Value Unit) setup |
| V_S_ARE_SALEMAN | Salesman setup |
| V_S_ARE_SPECIALTY | Specialty setup |
| V_S_ARE_SRVPLACE | Service place setup |
| V_S_ARE_SRVTYPE | Service type setup |
| V_S_ARE_SYSTEMS | Systems setup |
| V_S_ARE_TAGDEF | Tag definitions |
| V_S_ARE_TAGENUM | Tag enumeration |
| V_S_ARE_TAXONOMY | Taxonomy setup |
| V_S_ARE_TEST | AR test setup |
| V_S_ARE_TESTVER | Test version |
| V_S_ARE_TRCLASS | Transaction class |
| V_S_ARE_TRTYPE | Transaction type |
| V_S_ARE_TSTCOMP | Test component setup |
| V_S_ARE_TSTCOMPVER | Test component version |
| V_S_ARE_TSTGRP | Test group setup |
| V_S_ARE_WARD | Ward setup (AR) |
| V_S_ARE_WRKDEPFCLTY | Workstation/department/facility links |
| V_S_ARE_XSLTRANSFORM | XSL transform setup |
| V_S_ARE_ZIPSETUP | ZIP code setup |

### Request Form (V_S_RFSETUP_*)
| View | Description |
|------|-------------|
| V_S_RFSETUP_RFCLINIC | Request form clinic setup |
| V_S_RFSETUP_RFDOC | Request form doctor setup |
| V_S_RFSETUP_RFMES | Request form comments |
