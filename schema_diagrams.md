# SCC Soft Computer LIS — Schema Diagrams

Visual relationship maps for the [SCC data dictionary](claude.md). Render in VS Code with the Mermaid Preview extension, or any Markdown viewer that supports Mermaid.

Each diagram shows **PK + FK + key filter columns only** — for full column detail and operational caveats, consult [claude.md](claude.md). Annotations highlight the gotchas most likely to bite a query author (sentinel values, vestigial flags, cancellation fan-out, etc.).

**Diagrams in this file:**
1. [Core SoftLab Patient-Data Chain](#1-core-softlab-patient-data-chain)
2. [Cancellation Fan-Out](#2-cancellation-fan-out-discriminated-union)
3. [SoftAR Billing Module](#3-softar-billing-module)
4. [Blood Bank Module (SoftBank)](#4-blood-bank-module-softbank)
5. [Cross-Module Bridges (Lab ↔ BB ↔ AR)](#5-cross-module-bridges)

---

## 1. Core SoftLab Patient-Data Chain

The everyday join graph for clinical / TAT / specimen queries. Shows how a patient's lab work flows from encounter → order → orderable → result, with parallel specimen → tube → barcode tracking.

```mermaid
erDiagram
    V_P_LAB_PATIENT ||--o{ V_P_LAB_STAY : "has stays"
    V_P_LAB_STAY ||--o{ V_P_LAB_ORDER : "has orders"
    V_P_LAB_ORDER ||--o{ V_P_LAB_ORDERED_TEST : "has orderables"
    V_P_LAB_ORDER ||--o{ V_P_LAB_TEST_RESULT : "has results"
    V_P_LAB_ORDER ||--o{ V_P_LAB_TUBE : "has tubes"
    V_P_LAB_PATIENT ||--o{ V_P_LAB_SPECIMEN : "has specimens"
    V_P_LAB_SPECIMEN ||--o{ V_P_LAB_TUBE : "packaged in"
    V_P_LAB_TUBE ||--o{ V_P_LAB_SPECIMEN_BARCODE : "labeled with"
    V_P_LAB_TEST_RESULT ||--o{ V_P_LAB_TEST_TO_TUBE : "via"
    V_P_LAB_TEST_TO_TUBE }o--|| V_P_LAB_TUBE : "links to"

    V_P_LAB_PATIENT {
        NUMBER AA_ID PK
        VARCHAR ID "MRN must match E digits"
        VARCHAR LAST_NAME
        VARCHAR FIRST_NAME
        DATE DOB_DT
        VARCHAR SEX
    }
    V_P_LAB_STAY {
        NUMBER AA_ID PK
        NUMBER PATIENT_AA_ID FK
        VARCHAR BILLING "Epic CSN unique never null"
        VARCHAR MRNNUM "denormalized MRN"
        VARCHAR CLINIC_ID FK
        VARCHAR HIS_PATIENT_TYPE "O E I N H"
        DATE ADMISSION_DT "MAY BE FUTURE"
    }
    V_P_LAB_ORDER {
        NUMBER AA_ID PK
        VARCHAR ID "Order# C plus 9 digits"
        NUMBER STAY_AA_ID FK
        VARCHAR BILLING "Epic CSN denorm"
        DATE ORDERED_DT
        CHAR PRIORITY "S R T"
        VARCHAR TESTS_CANCEL "Y all canceled N has active"
    }
    V_P_LAB_ORDERED_TEST {
        NUMBER AA_ID PK
        NUMBER ORDER_AA_ID FK
        VARCHAR TEST_ID FK
        CHAR TEST_TYPE "G group I individual"
        NUMBER CANCELLED_FLAG "0 active 1 cancelled"
        DATE ORDERING_DT
    }
    V_P_LAB_TEST_RESULT {
        NUMBER AA_ID PK
        NUMBER ORDER_AA_ID FK
        VARCHAR TEST_ID FK
        VARCHAR GROUP_TEST_ID FK
        VARCHAR STATE "Pending Final Corrected Canceled"
        VARCHAR RESULT
        DATE TEST_DT
        DATE VERIFIED_DT
        VARCHAR ORDER_ID "denorm order number"
    }
    V_P_LAB_SPECIMEN {
        NUMBER AA_ID PK
        NUMBER PATIENT_AA_ID FK
        DATE COLLECTION_DT
        NUMBER NURSE_COLL "1 nurse 0 lab OBR11"
        VARCHAR DRAW_TYPE "D V A"
        VARCHAR COLLECTION_PHLEB_ID "97pct populated"
        VARCHAR IS_COLLECTED "Y N"
    }
    V_P_LAB_TUBE {
        NUMBER AA_ID PK
        NUMBER ORDER_AA_ID FK
        NUMBER SPECIMEN_AA_ID FK
        NUMBER PARENT_TUBE_AA_ID FK "self-ref aliquot"
        VARCHAR TUBE_TYPE
        DATE RECEIPT_DT
    }
    V_P_LAB_SPECIMEN_BARCODE {
        NUMBER AA_ID PK
        NUMBER TUBE_AA_ID FK
        VARCHAR CODE
        CHAR CODE_TYPE "B barcode S spec O order"
    }
    V_P_LAB_TEST_TO_TUBE {
        NUMBER AA_ID PK
        NUMBER RESULT_AA_ID FK
        NUMBER TUBE_AA_ID FK
    }
```

**Operational notes**
- **MRN filter is mandatory** on every query touching `PATIENT.ID` — `REGEXP_LIKE(p.ID, '^E[0-9]+$')` excludes test/fake patients
- **`STATE IN ('Final', 'Corrected')` is the standard "real result" filter** — half of recent `V_P_LAB_TEST_RESULT` rows are `Canceled` (panel fan-out)
- **`VERIFIED_FLAG` persists 'Y' through cancellation** — don't use as a "final results" filter; use `STATE` instead
- **`tr.TAT` is the SLA target from setup, NOT measured TAT** — compute measured TAT from `VERIFIED_DT - RECEIVE_DT`
- **`ADMISSION_DT` can be in the FUTURE** — Epic posts pre-scheduled visits up to ~5 months ahead. Use downstream timestamps (`ORDERED_DT`, `VERIFIED_DT`) for "actual work" date filtering
- **`V_P_LAB_SPECIMEN.ORDER_AA_ID` is vestigial** — use `V_P_LAB_TUBE.ORDER_AA_ID` for the specimen→order link
- **`OT ↔ TR` join uses three columns**: `ot.ORDER_AA_ID = tr.ORDER_AA_ID AND ot.TEST_ID = tr.GROUP_TEST_ID AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID`
- **Filter `sb.CODE_TYPE = 'B'`** for barcodes (vs `'S'` specimen-id, `'O'` order#)

---

## 2. Cancellation Fan-Out (Discriminated Union)

`V_P_LAB_CANCELLATION` has FOUR FK columns — exactly one is non-null per row. The populated FK identifies what level was cancelled. **Joining only one FK silently skips the other three categories.**

```mermaid
erDiagram
    V_P_LAB_ORDERED_TEST ||--o{ V_P_LAB_CANCELLATION : "test-level cancel"
    V_P_LAB_TEST_RESULT ||--o{ V_P_LAB_CANCELLATION : "result-level cancel"
    V_P_LAB_SPECIMEN ||--o{ V_P_LAB_CANCELLATION : "specimen-level cancel"
    V_P_LAB_ORDERING_PATTERN ||--o{ V_P_LAB_CANCELLATION : "standing-order cancel"

    V_P_LAB_CANCELLATION {
        NUMBER AA_ID PK
        DATE CANCELLATION_DT
        VARCHAR REASON "free text not enum"
        VARCHAR TECH_ID "FK PHLEBOTOMIST.ID"
        NUMBER ORDERED_TEST_AA_ID "FK or NULL"
        NUMBER TEST_RESULT_AA_ID "FK or NULL"
        NUMBER SPECIMEN_AA_ID "FK or NULL"
        NUMBER ORDERING_PATTERN_AA_ID "FK or NULL"
        VARCHAR CODE "vestigial 0pct populated"
    }
```

**Operational notes**
- **Exactly one FK populated per row** — the other three are NULL. The populated FK is the discriminator.
- **`INNER JOIN` on `TEST_RESULT_AA_ID`** matches only result-level cancellations (~98% are 1:1 with results — won't inflate row counts). Fine for "cancelled results" reports, **wrong for "cancelled orders" reports**.
- For order-level cancellation reporting, join on `ORDERED_TEST_AA_ID` or use `V_P_LAB_ORDERED_TEST.CANCELLED_FLAG = 1`.
- **`REASON` is free text with a partial canned vocabulary** — top values include "Test Not Performed. Specimen Never Received", "Patient Discharge", "Duplicate request.", and many case/whitespace variants. Normalize with `TRIM(UPPER(REASON))` for grouping.
- **`CODE` field is empty (0%)** in this deployment — schema slot, never written.
- **PHI caveat**: `REASON` frequently contains nurse names, patient context, free narrative. Treat as PHI-adjacent.
- ~60.7M rows since 2016, ~17K cancellations/day.

---

## 3. SoftAR Billing Module

Visit → Item → CCI/Billrules chain for billing analytics. Visits link back to SoftLab via `VTORGORDNUM = V_P_LAB_ORDER.ID`.

```mermaid
erDiagram
    V_P_ARE_PERSON ||--o{ V_P_ARE_ACCOUNT : "has accounts"
    V_P_ARE_ACCOUNT ||--o{ V_P_ARE_VISIT : "has visits"
    V_P_ARE_VISIT ||--o{ V_P_ARE_ITEM : "has items"
    V_P_ARE_VISIT ||--o{ V_P_ARE_INVOICE : "has invoices"
    V_P_ARE_VISIT ||--o{ V_P_ARE_TRANS : "has transactions"
    V_P_ARE_VISIT ||--o{ V_P_ARE_BILLERROR : "has errors"
    V_S_ARE_CCI ||--o{ V_P_ARE_ITEM : "system flagged CCI"
    V_S_ARE_CCI }o--|| V_S_ARE_CPTTABLE : "col1 col2 CPTs"
    V_P_ARE_ITEM }o--|| V_S_ARE_CPTTABLE : "ITCPTCD"
    V_P_ARE_ITEM }o--|| V_S_ARE_TEST : "ITTSTCODE"
    V_S_ARE_TEST ||--o{ V_S_ARE_BILLRULES : "billing rules"
    V_S_ARE_PAYOR ||--o{ V_S_ARE_BILLRULES : "payor specific"
    V_S_ARE_MODIFIER ||--o{ V_S_ARE_BILLRULES : "BRCCIMOD override"
    V_P_ARE_BILLERROR }o--|| V_S_ARE_ARERROR : "BERCODE = ERRCODE"
    V_P_ARE_TRANS }o--|| V_S_ARE_TRTYPE : "TRTTCODE"

    V_P_ARE_VISIT {
        NUMBER VTINTN PK
        VARCHAR VTREFNO "invoice number"
        NUMBER VTPTINTN FK
        NUMBER VTACINTN FK
        VARCHAR VTORGORDNUM "= V_P_LAB_ORDER.ID"
        DATE VTSRVDT "service date"
        DATE VTINVDT "NULL = uninvoiced"
        DATE VTLBDT "last bill date"
        NUMBER VTSTAT "0 1 2 3 4"
        NUMBER VTREADY "0 ready 1 not"
    }
    V_P_ARE_ITEM {
        NUMBER ITINTN PK
        NUMBER ITVTINTN FK
        VARCHAR ITCPTCD "CPT code"
        VARCHAR ITTSTCODE "AR test code"
        NUMBER ITPRICE "in cents"
        NUMBER ITBAL "in cents"
        NUMBER ITCCITINTN "CCI link col1 ITINTN"
        VARCHAR ITCPTMOD0 "modifier slot 0"
        NUMBER ITSTAT "0 active"
    }
    V_S_ARE_CCI {
        NUMBER CCINTN PK
        VARCHAR CCPYOCODE "payor"
        VARCHAR CCCPT1 "column 1 CPT"
        VARCHAR CCCPT2 "column 2 CPT"
        NUMBER CCFLAG "0 not allowed 1 allowed 9 NA"
        DATE CCEFFDT
        DATE CCEXPDT
    }
    V_S_ARE_BILLRULES {
        NUMBER BRINTN PK
        VARCHAR BRTSTCODE FK
        VARCHAR BRPYOCODE FK
        VARCHAR BRCPTCODE
        VARCHAR BRCCIMOD "CCI override modifier"
        VARCHAR BRMODCODE0 "default mod 0"
        DATE BRBEGDT
        DATE BREXPDT
    }
    V_P_ARE_INVOICE {
        NUMBER ININTN PK
        NUMBER INVTINTN FK
        NUMBER INEXT "matches ITINEXT"
        NUMBER INSTAT "0 active"
        DATE INLBDT "NULL not billed"
        VARCHAR INBILLTO "payor"
        NUMBER INCHARGE "in cents"
    }
    V_P_ARE_BILLERROR {
        NUMBER BEINTN PK
        NUMBER BERVTINTN FK
        VARCHAR BERCODE "NULL means IN75"
        VARCHAR BERDESC "primary error text"
        DATE BERDTM
    }
```

**Operational notes**
- **All money fields are stored in cents** — divide by 100 for dollars (`ITPRICE`, `ITBAL`, `INCHARGE`, `INDUEAMT`, `VTCHARGE`, `TRAMT`)
- **PK convention is `*INTN`** in SoftAR (not `AA_ID`); status flags use `*STAT = 0` for active
- **`ITCCITINTN` points to col-1 ITEM.ITINTN** (not `V_S_ARE_CCI.CCINTN`) when populated and non-zero — the column-1 row is the parent of the column-2 row in a CCI pair
- **`V_P_ARE_BILLERROR` is visit-level, not item-level** — join on `BERVTINTN = VTINTN`. When `BERCODE` is NULL, treat as `'IN75'` for `V_S_ARE_ARERROR` lookup
- **Uninvoiced visits** (`VTINVDT IS NULL`) have **zero items** in `V_P_ARE_ITEM` — visit shells only
- **Cross-module link** to SoftLab: `V_P_ARE_VISIT.VTORGORDNUM = V_P_LAB_ORDER.ID`

---

## 4. Blood Bank Module (SoftBank)

Order → Result → Test, plus units, actions (transfusions/crossmatch), and patient demographics. Joins to SoftLab via `ORDERNO = V_P_LAB_ORDER.ID`.

```mermaid
erDiagram
    V_P_BB_Patient ||--o{ V_P_BB_BB_Order : "has orders"
    V_P_BB_BB_Order ||--o{ V_P_BB_Result : "has results"
    V_P_BB_BB_Order ||--o{ V_P_BB_Test : "has tests"
    V_P_BB_Result }o--|| V_P_BB_Test : "TEST_RESULT = Test.AA_ID"
    V_P_BB_BB_Order ||--o{ V_P_BB_Action : "has actions"
    V_P_BB_Patient ||--o{ V_P_BB_Patient_Transfusion : "transfusions"
    V_P_BB_Patient ||--o{ V_P_BB_Patient_Stay : "BB stays"
    V_P_BB_Patient ||--o{ V_P_BB_Patient_Unit : "linked units"
    V_P_BB_Unit ||--o{ V_P_BB_Patient_Unit : "linked patients"
    V_P_BB_Unit ||--o{ V_P_BB_Selected_Unit : "selected for use"
    V_P_BB_Unit ||--o{ V_P_BB_Unit_Segment : "segments"

    V_P_BB_BB_Order {
        NUMBER AA_ID PK
        VARCHAR ORDERNO "= V_P_LAB_ORDER.ID (P-type only)"
        VARCHAR MRN
        CHAR ORDER_TYPE "P=patient 80pct I=inventory 20pct"
        VARCHAR REQUESTING_PHYSICIAN
        VARCHAR DEPOT "site T1 J1 etc"
        DATE REQUESTEDDT
        DATE COLLECTEDDT
        DATE RECEIVEDDT
        DATE OUTDATEDT "collection + 3d sample window"
        DATE REPORTDT
    }
    V_P_BB_Result {
        NUMBER AA_ID PK
        NUMBER TEST_RESULT FK "FK to BB_Test.AA_ID counterintuitive name"
        VARCHAR ORDERNO
        VARCHAR CODE "component code differs from parent Test.CODE"
        CHAR STATUS "C=finalized 85pct N=pending 15pct (C does NOT mean reviewed)"
        DATE RESULTEDDT
        DATE REVIEWDT "use IS NOT NULL for actually reviewed"
        DATE FIRST_REPORTEDDT
    }
    V_P_BB_Test {
        NUMBER AA_ID PK
        NUMBER ORD_TEST FK "canonical NUMBER FK to BB_Order.AA_ID"
        VARCHAR ORDERNO "string copy denorm"
        VARCHAR CODE "TS3 RETYP NCABO ABORH etc"
        VARCHAR ORDEREDCODE "= CODE for direct orders blank for reflex components"
        CHAR STATUS
        VARCHAR FINAL_INTERPRETATION
        DATE REQUESTEDDT
        DATE RELEASEDDT
    }
    V_P_BB_Patient {
        NUMBER AA_ID PK
        VARCHAR MRN "UNIQUE indexed"
        VARCHAR SOUNDEX "phonetic 3 indexes first-class lookup"
        VARCHAR LAST_NAME
        VARCHAR FIRST_NAME
        VARCHAR MIDDLE_NAME "stores INITIALS despite name avg len 1.015"
        DATE DOBDT "no underscore vs LAB_PATIENT.DOB_DT"
        VARCHAR ABO "blood type 95.7pct"
        CHAR RH
        VARCHAR HISTORICAL_ABO "17pct populated"
        DATE STAMP_DATE "indexed - use for windowing"
        CHAR SEX
    }
    V_P_BB_Unit {
        NUMBER AA_ID PK
        VARCHAR UNITNO "donation number"
        VARCHAR UNIT_PRODUCT
        VARCHAR ABO
        CHAR RH
        VARCHAR LOCATION
        CHAR STATUS
        DATE EXPIRATIONDT
    }
    V_P_BB_Action {
        NUMBER AA_ID PK
        VARCHAR ORDERNO FK
        VARCHAR CODE "action code"
        CHAR STATUS
        VARCHAR TECH
        DATE STATUSDT
        DATE REQUESTDT
    }
```

**Operational notes**
- **Cross-module join key is `ORDERNO`** (VARCHAR2 11) — matches `V_P_LAB_ORDER.ID` exactly. **Only `ORDER_TYPE='P'` (patient, ~80%) BB orders have a matching Lab order; `ORDER_TYPE='I'` (inventory, ~20%) do not** — INNER JOIN to V_P_LAB_ORDER silently drops the inventory side
- **`V_P_BB_Result.TEST_RESULT` is an FK to `V_P_BB_Test.AA_ID`** (not test result content; counterintuitive naming)
- **`V_P_BB_Test.ORD_TEST` is the canonical NUMBER FK to `V_P_BB_BB_Order.AA_ID`** — more efficient than the ORDERNO string-match
- **STATUS enums are view-specific:**
  - V_P_BB_Test: blank (87%) / `N` (13%) — `N` likely "in-flight unreleased"
  - V_P_BB_Result: `C` (85%) / `N` (15%) — `C` is "finalized" but **NOT necessarily reviewed**; use `REVIEWDT IS NOT NULL` for actually-reviewed filtering
- **Multi-component test fanout** — one V_P_BB_Test row can produce multiple V_P_BB_Result rows with different CODEs:
  - `TS3` → `ABORH` + `AS3` (1:2)
  - `CORD` → `CRH` + `CABO` + `CDAT` (1:3); `NCORD` → `CRH` + `CABO` (1:2, no CDAT)
  - `HEEL` → 4 components; `STDA`/`UNIT1` → 3-4
  - `PRET1` → 8 components; `TRX1` → 9 components (largest fanout — Transfusion Reaction workup)
- **V_P_BB_Patient is built for phonetic lookup** — SOUNDEX has 3 dedicated indexes (alone, with DOB+TOB, with SSN). Patient name searches should consider Soundex-based fuzzy matching, not just `LIKE`
- **Vestigial columns observed across BB views** (verified via deep-probe):
  - V_P_BB_BB_Order: `ORDERTYPE`, `PATIENTTYPE` (always blank — distinct from `ORDER_TYPE`)
  - V_P_BB_Test: `TEST_TYPE` (always blank)
  - V_P_BB_Patient: `SITE`, `DOD`, `LAST_DISCHARGE_DATE`, `PDF`, `EXTERNALID`, `CLIENTID`, `TITLE`, `CASENO` (all 0%); `NEXT_MRN`/`AUXILIARY_MRN` are placeholder constants
- **V_P_BB_Patient.MOTHER_MRN is sparsely real** — ~3% of patients (newborns) have a real mother's MRN; the rest carry a 1-char placeholder. Filter `LENGTH(MOTHER_MRN) > 1` to find real linkages
- **V_P_BB_Patient base-table column naming differs** — view exposes friendly names; base table `BBANK_PATIENT` uses P-prefix (PLNAME, PFNAME, PDOB, PSDX, PTSTAMP, etc.). `PTOB` (time of birth) exists in base but **not in the view**

---

## 5. Cross-Module Bridges

How a single patient encounter spans Lab, Blood Bank, and AR via shared identifiers.

```mermaid
erDiagram
    V_P_LAB_ORDER ||--o{ V_P_BB_BB_Order : "ORDER.ID = ORDERNO (P-type only)"
    V_P_LAB_ORDER ||--o{ V_P_ARE_VISIT : "ORDER.ID = VTORGORDNUM"
    V_P_LAB_ORDERED_TEST ||--o{ V_P_BB_BB_Order : "OT.ORDER_NO = ORDERNO (P-type only)"
    V_P_LAB_STAY ||--o{ V_P_LAB_MISCEL_INFO : "STAY.BILLING = OWNER_ID"

    V_P_LAB_STAY {
        NUMBER AA_ID PK
        VARCHAR BILLING "Epic CSN"
        VARCHAR HIS_PATIENT_TYPE
    }
    V_P_LAB_ORDER {
        NUMBER AA_ID PK
        VARCHAR ID "Order# = ORDERNO = VTORGORDNUM"
        VARCHAR BILLING "Epic CSN denorm of STAY.BILLING"
    }
    V_P_LAB_ORDERED_TEST {
        NUMBER AA_ID PK
        VARCHAR ORDER_NO "matches BB.ORDERNO"
    }
    V_P_BB_BB_Order {
        NUMBER AA_ID PK
        VARCHAR ORDERNO "= V_P_LAB_ORDER.ID"
        VARCHAR MRN
    }
    V_P_ARE_VISIT {
        NUMBER VTINTN PK
        VARCHAR VTORGORDNUM "= V_P_LAB_ORDER.ID"
        VARCHAR VTREFNO "AR invoice number"
    }
    V_P_LAB_MISCEL_INFO {
        NUMBER AA_ID PK
        VARCHAR OWNER_ID "= V_P_LAB_STAY.BILLING"
        VARCHAR SUB_ID "field label"
        VARCHAR VALUE "field value"
    }
```

**Operational notes**
- **Three identifier shapes worth knowing:**
  1. **Order number** (`V_P_LAB_ORDER.ID`, VARCHAR2 11, format `C` + 9 digits) — matches `V_P_BB_BB_Order.ORDERNO` and `V_P_ARE_VISIT.VTORGORDNUM` exactly
  2. **Epic CSN** (`V_P_LAB_STAY.BILLING`, VARCHAR2 23, ~9-digit numeric) — denormalized to `V_P_LAB_ORDER.BILLING`. Unique per stay, never null
  3. **AR invoice number** (`V_P_ARE_VISIT.VTREFNO`) — separate from CSN, internal to billing
- **`V_P_LAB_MISCEL_INFO` is keyed by Epic CSN** (`OWNER_ID = STAY.BILLING`) — used to attach arbitrary HIS-pushed metadata to a stay (e.g., expected discharge date)
- **One Epic CSN can produce multiple lab orders** (each with its own `V_P_LAB_ORDER.ID`); each lab order maps 1:1 to at most one BB order and 1:1 to at most one AR visit
- **Same `BILLING` value lives on both `STAY` and `ORDER`** — same identifier, denormalized for query convenience. Querying for CSN context can stop at either level
- **Lab ↔ BB cross-link only fires for `ORDER_TYPE='P'`** — ~80% of BB orders link back to a SoftLab order (patient-context). The other ~20% are inventory orders (`ORDER_TYPE='I'`: donor processing, unit operations, QC) with no Lab counterpart. INNER JOIN on ORDERNO silently drops the inventory side; use LEFT JOIN or filter `ORDER_TYPE` explicitly

---

## Update procedure

When discoveries change schema understanding (column additions, FK corrections, new gotchas), update [claude.md](claude.md) for the column detail and **also reflect the change here** if it affects the visual relationship map. Keep the diagrams focused — don't add columns just because they exist; add them only if a query author would benefit from seeing them next to the relationship arrows.
