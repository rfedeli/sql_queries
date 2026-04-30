# SCC Soft Computer LIS — Schema Diagrams

Visual relationship maps for the [SCC data dictionary](claude.md). Render in VS Code with the Mermaid Preview extension, or any Markdown viewer that supports Mermaid.

Each diagram shows **PK + FK + key filter columns only** — for full column detail and operational caveats, consult [claude.md](claude.md). Annotations highlight the gotchas most likely to bite a query author (sentinel values, vestigial flags, cancellation fan-out, etc.).

**Diagrams in this file:**
1. [Core SoftLab Patient-Data Chain](#1-core-softlab-patient-data-chain)
2. [Cancellation Fan-Out](#2-cancellation-fan-out-discriminated-union)
3. [SoftAR Billing Module](#3-softar-billing-module)
4. [Blood Bank Module (SoftBank)](#4-blood-bank-module-softbank)
5. [Cross-Module Bridges (Lab ↔ BB ↔ AR)](#5-cross-module-bridges)
6. [SoftLab Test Setup / Compendium Hierarchy](#6-softlab-test-setup--compendium-hierarchy)
7. [Specimen Tracking (SPTR) Cluster](#7-specimen-tracking-sptr-cluster)
8. [Order Decorator Reference Graph](#8-order-decorator-reference-graph)
9. [Microbiology (SoftMic) Cluster — preliminary](#9-microbiology-softmic-cluster--preliminary)
10. [Instrument Interface Map](#10-instrument-interface-map)
11. [Order Lifecycle Timeline](#11-order-lifecycle-timeline)

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

## 6. SoftLab Test Setup / Compendium Hierarchy

The configuration tables that drive what tests can be ordered, what tubes they require, and where they're performed. Read top-down: a `TEST_GROUP` (orderable like `CMP`) is composed of `TEST` components (Na, K, Cl…); each side carries its own specimen-requirement and workstation-mapping tables.

```mermaid
erDiagram
    V_S_LAB_TEST_GROUP ||--o{ V_S_LAB_TEST_COMPONENT : "has components"
    V_S_LAB_TEST ||--o{ V_S_LAB_TEST_COMPONENT : "appears as"
    V_S_LAB_TEST_GROUP ||--o{ V_S_LAB_TEST_GROUP_SPECIMEN : "tube requirements"
    V_S_LAB_TEST_GROUP_SPECIMEN }o--|| V_S_LAB_SPECIMEN : "SAMPLE_TYPE"
    V_S_LAB_TEST ||--o{ V_S_LAB_TEST_SPECIMEN : "per workstation tube"
    V_S_LAB_TEST_SPECIMEN }o--|| V_S_LAB_SPECIMEN : "COLLECTION_CONTAINER"
    V_S_LAB_SPECIMEN ||--o{ V_S_LAB_TUBE_CAPACITY : "capacity specs"
    V_S_LAB_TEST ||--o{ V_S_LAB_TEST_ENVIRONMENT : "performed at"
    V_S_LAB_TEST_ENVIRONMENT }o--|| V_S_LAB_WORKSTATION : "WORKSTATION_ID"
    V_S_LAB_WORKSTATION }o--|| V_S_LAB_DEPARTMENT : "DEPARTMENT_ID"
    V_S_LAB_WORKSTATION }o--|| V_S_LAB_LOCATION : "LOCATION_ID"
    V_S_LAB_DEPARTMENT }o--|| V_S_LAB_LOCATION : "LOCATION_ID"

    V_S_LAB_TEST_GROUP {
        NUMBER AA_ID PK
        VARCHAR ID "orderable code matches OT.TEST_ID"
        VARCHAR GTNAME_UPPER
        NUMBER TEST_COUNT "may be 0 even with components"
        VARCHAR FL_LAST_LEVEL "Y leaf"
        VARCHAR ACTIVE
    }
    V_S_LAB_TEST_COMPONENT {
        NUMBER AA_ID PK
        NUMBER TEST_AA_ID FK "to TEST_GROUP.AA_ID"
        VARCHAR COMPONENT FK "to TEST.ID by code"
        NUMBER TEST_SORT
    }
    V_S_LAB_TEST {
        NUMBER AA_ID PK
        VARCHAR ID "component code matches TR.TEST_ID"
        VARCHAR NAME
        VARCHAR LOINC
        VARCHAR WORKSTATION_ID "default"
        VARCHAR DEPARTMENT_ID "default"
        NUMBER TAT_STAT "SLA target stat"
        NUMBER TAT_URGENT
        NUMBER TAT_TIMED
        VARCHAR FL_NOT_IN_TAT_CALC "Y exclude"
        VARCHAR ACTIVE
    }
    V_S_LAB_TEST_GROUP_SPECIMEN {
        NUMBER AA_ID PK
        NUMBER TEST_AA_ID FK "to TEST_GROUP.AA_ID"
        VARCHAR SAMPLE_TYPE FK "to SPECIMEN.ID by code"
        NUMBER NUMBER_OF_SAMPLES
        NUMBER SHIPPING_VOLUME
        VARCHAR UNITS
    }
    V_S_LAB_TEST_SPECIMEN {
        NUMBER AA_ID PK
        NUMBER TEST_AA_ID FK "to TEST.AA_ID"
        VARCHAR WORKSTATION_ID "container varies by ws"
        VARCHAR COLLECTION_CONTAINER FK "to SPECIMEN.ID by code"
        NUMBER VOLUME
        NUMBER EXTRA_TUBES
    }
    V_S_LAB_SPECIMEN {
        NUMBER AA_ID PK
        VARCHAR ID "tube type code"
        VARCHAR NAME "Gold SST Purple EDTA etc"
        VARCHAR DRAW_TYPE
        VARCHAR CATEGORY
    }
    V_S_LAB_TUBE_CAPACITY {
        NUMBER AA_ID PK
        VARCHAR SPECIMEN_ID FK "to SPECIMEN.ID by code"
        NUMBER CAPACITY
        NUMBER MIN_VOLUME
    }
    V_S_LAB_TEST_ENVIRONMENT {
        NUMBER AA_ID PK
        VARCHAR TEST_ID FK "to TEST.ID by code"
        VARCHAR WORKSTATION_ID FK "to WORKSTATION.ID by code"
        VARCHAR ENVIRONMENT
    }
    V_S_LAB_WORKSTATION {
        NUMBER AA_ID PK
        VARCHAR ID
        VARCHAR NAME
        VARCHAR DEPARTMENT_ID FK
        VARCHAR LOCATION_ID FK
        NUMBER REF_LAB "1 = ref lab workstation"
    }
    V_S_LAB_DEPARTMENT {
        NUMBER AA_ID PK
        VARCHAR ID "TCHEM JCHEM etc"
        VARCHAR NAME "CHEMISTRY HEMATOLOGY etc"
        VARCHAR LOCATION_ID FK
    }
    V_S_LAB_LOCATION {
        NUMBER AA_ID PK
        VARCHAR ID "TUH JNS FC etc"
        VARCHAR NAME
        VARCHAR SITE
        VARCHAR CLIA
        NUMBER REF_LAB "1 = external ref lab"
        NUMBER REF_NOTINTERFACED "1 = not interfaced"
    }
```

**Operational notes**
- **Two-tier test model**: `TEST_GROUP` is what gets *ordered* (e.g., `CMP`); `TEST` is what gets *resulted* (component analytes). The bridge is `V_S_LAB_TEST_COMPONENT`. `V_P_LAB_ORDERED_TEST.TEST_ID` matches `TEST_GROUP.ID`; `V_P_LAB_TEST_RESULT.TEST_ID` matches `TEST.ID` (with `GROUP_TEST_ID` carrying the parent).
- **Specimen requirements live on TWO tables** with different granularity:
  - `V_S_LAB_TEST_GROUP_SPECIMEN` — at the **orderable** level, lists all tubes needed for the panel as a whole
  - `V_S_LAB_TEST_SPECIMEN` — at the **test + workstation** level, lets one component require different containers at different sites (e.g., PTSEC uses BLUE most places but BLUPLAS at TCOAG)
- **Use `TEST_GROUP_SPECIMEN` first; fall back to `TEST_SPECIMEN`** when a group has no rows in the group-level table — common for individual-orderable tests where the only spec is at the component level.
- **Tube name lookup** always goes through `V_S_LAB_SPECIMEN` (ID → NAME). `V_S_LAB_TUBE_CAPACITY` is for capacity / min-volume specs only — not a name lookup.
- **`TEST_ENVIRONMENT` is a many-to-many bridge** — a single test can be performed at multiple workstations across facilities. Used to answer "which labs perform test X" by chaining `TEST_ENVIRONMENT.WORKSTATION_ID → V_S_LAB_WORKSTATION.LOCATION_ID → V_S_LAB_LOCATION.SITE`.
- **Ref-lab tests are identified two ways**: `V_S_LAB_LOCATION.REF_LAB = 1` (external lab as a location) and `V_S_LAB_WORKSTATION.REF_LAB = 1` (the workstation that represents the send-out destination). Filter `REF_NOTINTERFACED = 1` to find non-interfaced (paper-result) ref labs.
- **TAT columns on `V_S_LAB_TEST` are SLA targets** (`TAT_STAT`, `TAT_URGENT`, `TAT_TIMED`) — not measured TAT. Same foot-gun as on the transactional `tr.TAT`. Always compute measured TAT from date arithmetic.
- **`FL_NOT_IN_TAT_CALC = 'Y'` excludes a test from TAT reports** — important filter for measured-TAT analytics so configuration-excluded tests don't skew aggregates.
- **CPT codes are NOT here** — `V_S_LAB_TEST.CPT_BASIC_CODE_1..8` columns are unpopulated in this deployment. Use `V_S_ARE_BILLRULES.BRCPTCODE` (joined via `BRTSTCODE = V_S_LAB_TEST.ID`) for authoritative CPT.

---

## 7. Specimen Tracking (SPTR) Cluster

The configuration that drives the per-terminal Specimen Tracking screens, plus the runtime events recorded in `V_P_LAB_TUBE_LOCATION`. Used for diagnosing "broken terminal" support tickets where one PC sees different SPTR options than another at the same site.

```mermaid
erDiagram
    V_S_LAB_COLL_CENTER ||--o{ V_S_LAB_TERMINAL : "has terminals"
    V_S_LAB_COLL_CENTER ||--o{ V_S_LAB_SPTR_SETUP : "OL/CC scoped"
    V_S_LAB_TERMINAL ||--o{ V_S_LAB_SPTR_SETUP : "device-specific"
    V_S_LAB_SPTR_SETUP }o--|| V_S_LAB_SPTR_STOP : "PLACE"
    V_S_LAB_SPTR_STOP }o--|| V_S_LAB_SPTR_STATUS : "SPECIMEN_STATUS"
    V_S_LAB_SPTR_STOP }o--|| V_S_LAB_SPTR_LOCATION : "SPECIMEN_LOCATION"
    V_P_LAB_TUBE ||--o{ V_P_LAB_TUBE_LOCATION : "tracking events"

    V_S_LAB_COLL_CENTER {
        NUMBER AA_ID PK
        VARCHAR ID "T1 J1 F1 TREM QUEST etc"
        VARCHAR SITE "TEMPLE JEANES etc"
    }
    V_S_LAB_TERMINAL {
        NUMBER AA_ID PK
        VARCHAR COLL_CENTER_ID FK
        VARCHAR TERMINAL "device id"
        VARCHAR NAME "long device description"
    }
    V_S_LAB_SPTR_SETUP {
        NUMBER AA_ID PK
        VARCHAR TERMINAL "polymorphic 3 modes"
        VARCHAR PLACE FK
        VARCHAR LOC_DEPT_WRKSTN
        VARCHAR STATUS
        VARCHAR ACTIONS
        VARCHAR HIDE "Y N"
        NUMBER SETUP_OPTION
    }
    V_S_LAB_SPTR_STOP {
        NUMBER AA_ID PK
        VARCHAR PLACE "stop identifier"
        VARCHAR DESCRIPTION
        VARCHAR SPECIMEN_STATUS FK
        VARCHAR SPECIMEN_LOCATION FK
        VARCHAR NEXT_PLACE "self-ref next stop"
        VARCHAR NEXT_STATUS
        VARCHAR NEXT_LOCATION
        VARCHAR TIME_LIMIT
    }
    V_S_LAB_SPTR_STATUS {
        NUMBER AA_ID PK
        VARCHAR CODE
        VARCHAR DESCRIPTION
    }
    V_S_LAB_SPTR_LOCATION {
        NUMBER AA_ID PK
        VARCHAR CODE "single char"
        VARCHAR DESCRIPTION
    }
    V_P_LAB_TUBE_LOCATION {
        NUMBER AA_ID PK
        NUMBER TUBE_AA_ID FK
        VARCHAR STATUS_DESCRIPTION "Collected Transit etc"
        DATE ARRIVED_DT
        VARCHAR REGISTERED_BY
        VARCHAR DEPOT
        VARCHAR TRAY_ID
        VARCHAR CARRIER_ID
    }
```

**Operational notes**
- **`V_S_LAB_SPTR_SETUP.TERMINAL` is polymorphic — three modes:**
  1. A specific device ID → `V_S_LAB_TERMINAL.TERMINAL` (device-specific override; rare in practice)
  2. An OL/CC code → `V_S_LAB_COLL_CENTER.ID` (e.g., `T1`, `J1`, `F1`, `TREM`, `QUEST` — most rows live here)
  3. Literal `*` → globally-scoped fallback
  Resolution: a device inherits its OL/CC rows + global rows + any device-specific overrides. Device-specific rows take precedence.
- **`V_S_LAB_SPTR_STOP` self-references via `NEXT_PLACE` / `NEXT_STATUS` / `NEXT_LOCATION`** — defines the workflow chain (where a specimen goes after this stop). Not drawn on the diagram (renderer doesn't support self-refs cleanly); resolve manually with `b.PLACE = a.NEXT_PLACE`.
- **Diagnostic workflow for "broken terminal" tickets** (per SCC manual):
  1. Get the PC's terminal ID from SoftLab client (Help → About) — not stored in the DB.
  2. `V_S_LAB_TERMINAL` — confirm registered with the right `COLL_CENTER_ID`.
  3. `V_S_LAB_SPTR_SETUP WHERE TERMINAL = <device id>` — device-specific rows (often empty).
  4. `V_S_LAB_SPTR_SETUP WHERE TERMINAL = <coll_center_id>` — OL/CC-inherited rows.
  5. `V_S_LAB_SPTR_SETUP WHERE TERMINAL = '*'` — global rows.
  6. If two PCs share `COLL_CENTER_ID` and neither has device-specific rows, SPTR config is identical — the problem is outside SCC (client INI, hostname mis-registration, printer drivers, etc.).
- **`V_P_LAB_TUBE_LOCATION` is the runtime event log** — one row per tracking event (`Collected`, `Transit`, `Run on Instrument`, `Resulted`, `Ordering`). Filter `STATUS_DESCRIPTION = 'Transit'` to find specimens physically moved between facilities.
- **`TRAY_ID` / `CARRIER_ID` / `LINE_CODE` / `OUTLET_CODE`** are populated for automation-line events (Roche/Beckman track-routed specimens) — useful for instrument-routing audits.

---

## 8. Order Decorator Reference Graph

The lookup tables that resolve the `*_ID` code columns on `V_P_LAB_ORDER`. Each edge is a join-by-code (the order column holds the code value, the lookup view's `ID` column is the match target).

```mermaid
erDiagram
    V_P_LAB_ORDER }o--|| V_S_LAB_CLINIC : "ORDERING_CLINIC_ID"
    V_P_LAB_ORDER }o--|| V_S_LAB_COLL_CENTER : "COLLECT_CENTER_ID"
    V_P_LAB_ORDER }o--|| V_S_LAB_DOCTOR : "REQUESTING_DOCTOR_ID"
    V_P_LAB_ORDER }o--|| V_S_LAB_PHLEBOTOMIST : "ORDERING_TECH_ID"
    V_P_LAB_ORDER }o--|| V_S_LAB_INSURANCE : "INSURANCE1/2/3 + FAILED_PAYOR"
    V_P_LAB_ORDER }o--|| V_S_LAB_STUDY : "STUDY_ID"
    V_S_LAB_CLINIC }o--|| V_S_LAB_COLL_CENTER : "ORD_LOCATION_ID"
    V_S_LAB_CLINIC }o--|| V_S_LAB_DOCTOR : "house DOCTOR_ID"
    V_S_LAB_DOCTOR }o--|| V_S_LAB_CLINIC : "main CLINIC_ID"

    V_P_LAB_ORDER {
        NUMBER AA_ID PK
        VARCHAR ID "Order#"
        VARCHAR ORDERING_CLINIC_ID FK
        VARCHAR COLLECT_CENTER_ID FK
        VARCHAR REQUESTING_DOCTOR_ID FK
        VARCHAR ORDERING_TECH_ID FK
        VARCHAR INSURANCE1_ID FK
        VARCHAR INSURANCE2_ID FK
        VARCHAR INSURANCE3_ID FK
        VARCHAR FAILED_PAYOR FK
        VARCHAR STUDY_ID FK
    }
    V_S_LAB_CLINIC {
        VARCHAR ID PK "by code"
        VARCHAR NAME
        VARCHAR ORD_LOCATION_ID FK "authoritative facility"
        VARCHAR FACILITY "often blank use ORD_LOCATION_ID"
        VARCHAR DOCTOR_ID FK "house physician"
        VARCHAR ACTIVE
    }
    V_S_LAB_COLL_CENTER {
        VARCHAR ID PK "by code T1 J1 etc"
        VARCHAR SITE "facility grouping"
    }
    V_S_LAB_DOCTOR {
        VARCHAR ID PK "by code"
        VARCHAR LAST_NAME
        VARCHAR FIRST_NAME
        VARCHAR CLINIC_ID FK "main clinic"
        CHAR TYPE "G I N S T"
        VARCHAR ACTIVE
    }
    V_S_LAB_PHLEBOTOMIST {
        VARCHAR ID PK "by code"
        VARCHAR LAST_NAME
        VARCHAR FIRST_NAME
        VARCHAR NURSE "Y nurse role"
        VARCHAR ACTIVE
    }
    V_S_LAB_INSURANCE {
        VARCHAR ID PK "by code"
    }
    V_S_LAB_STUDY {
        VARCHAR ID PK "by code"
    }
```

**Operational notes**
- **All FKs in this graph are by code**, not numeric `AA_ID` — the lookup PKs are `ID` (varchar code) and the order columns hold the matching code value. `JOIN V_S_LAB_DOCTOR d ON d.ID = o.REQUESTING_DOCTOR_ID`.
- **`V_S_LAB_CLINIC.ORD_LOCATION_ID` is the authoritative facility grouping**, not `FACILITY` (which is often blank). Resolves to `V_S_LAB_COLL_CENTER.ID`.
- **`V_S_LAB_DOCTOR.TYPE` enum**: `G`=Doctor Group, `I`=Institution, `N`=Non-staff, `S`=Staff, `T`=Temporary.
- **`V_S_LAB_PHLEBOTOMIST` is a 57-row table** — does NOT cover the full collector workforce. ~9% of active collectors have rows here; most flow through Epic/HIS and bypass the table. Don't treat it as the authoritative collector roster — see the project memories on the three-signal collector classifier.
- **`V_S_LAB_PHLEBOTOMIST.NURSE = 'Y'` is accurate where populated**, but populated for ~2% of actual collectors. Use as a narrow high-confidence overlay, never as the primary nurse-vs-phleb classifier — for that, prefer `V_P_LAB_SPECIMEN.NURSE_COLL` (HL7 OBR[11]).
- **Generic phleb codes** in `V_S_LAB_PHLEBOTOMIST.ID`: `PHLEB` (default phlebotomist), `NUR` (nursing-staff), `PHY` (physician), `PAT` (patient), `UNK` (unknown), `SCC` (system testing only). These are role markers, not real users.
- **`V_P_LAB_STAY` and `V_P_LAB_ORDERED_TEST` carry their own copies of these `*_ID` columns** — same code-FK pattern. The ordered-test layer often has the live data when `V_P_LAB_ORDER`'s column is blank (e.g., `MEDICAL_SERVICE_ID` mostly empty on ORDER, populated as `ORDERING_SERVICE_ID` on ORDERED_TEST).

---

## 9. Microbiology (SoftMic) Cluster — preliminary

> ⚠️ **Preliminary diagram — relationships inferred from view names; not directly verified.** Most MIC FK columns are not yet documented at the column level in the dictionary. Treat this as a starting point for query design; verify joins with discovery probes before relying on them in production reports.

```mermaid
erDiagram
    V_P_MIC_ACTIVE_ORDER ||--o{ V_P_MIC_TEST : "has tests"
    V_P_MIC_TEST ||--o{ V_P_MIC_ISOLATE : "yields isolates"
    V_P_MIC_ISOLATE ||--o{ V_P_MIC_SENSI : "drug sensitivities"
    V_P_MIC_TEST ||--o{ V_P_MIC_MEDIA : "plated on"
    V_P_MIC_TEST ||--o{ V_P_MIC_TESTCOMM : "test comments"
    V_P_MIC_ISOLATE ||--o{ V_P_MIC_ISOCOMM : "isolate comments"
    V_P_MIC_SENSI ||--o{ V_P_MIC_THERAPYCOMM : "drug comments"
    V_P_MIC_MEDIA ||--o{ V_P_MIC_MEDIACOMM : "media comments"
    V_P_MIC_ISOLATE }o--|| V_S_MIC_ORGANISM : "organism code"
    V_P_MIC_SENSI }o--|| V_S_MIC_DRUG : "drug code"
    V_P_MIC_TEST }o--|| V_S_MIC_SOURCE : "source code"
    V_S_MIC_ORGANISM ||--o{ V_S_MIC_ORGANISM_CLASS : "class links"
    V_S_MIC_DRUG ||--o{ V_S_MIC_DRUG_CLASS : "class links"

    V_S_MIC_ORGANISM {
        NUMBER AA_ID PK
        VARCHAR ID
        VARCHAR NAME "STAPHYLOCOCCUS AUREUS etc"
        VARCHAR NAME_SHORT
        VARCHAR SNOMED
        CHAR INFECTIOUS_ORG
        VARCHAR Q_VIRUS "classification flags"
        VARCHAR R_FUNGI
        VARCHAR A_GRAMPOS
        VARCHAR B_GRAMNEG
        VARCHAR C_GRAMVAR
        VARCHAR ACTIVE
    }
```

**Operational notes (preliminary)**
- **Verification needed for all FK columns** — the join keys for `V_P_MIC_TEST → V_P_MIC_ACTIVE_ORDER`, `V_P_MIC_ISOLATE → V_P_MIC_TEST`, `V_P_MIC_SENSI → V_P_MIC_ISOLATE`, etc. are inferred from naming conventions, not directly probed. Run a discovery probe before writing production queries.
- **Organism type is derived from classification flags** on `V_S_MIC_ORGANISM`, not a single TYPE column: `Q_VIRUS` / `O1VIRUS` (virus), `R_FUNGI` (fungus, includes yeasts like Candida), `A_GRAMPOS` / `B_GRAMNEG` / `C_GRAMVAR` (gram stain), `N_COCUS` / `O_BACILLUS` (morphology).
- **Genus / species are not stored separately** — parse from `V_S_MIC_ORGANISM.NAME` with `REGEXP_SUBSTR` if needed.
- **Sensitivity panel flags** on `V_S_MIC_ORGANISM` (single-letter columns S, T, U, V, W, X, Y, Z, A1–Z1, etc.) determine which drug panels apply to that organism — schema-heavy but undocumented at column level.
- **Cross-link to SoftLab**: micro orders share the same `V_P_LAB_ORDER` ancestry as chem/heme orders — micro-flagged orders carry `V_P_LAB_ORDER.BACTITEST = 'Y'`. Component results land in `V_P_LAB_TEST_RESULT` like normal; the MIC views overlay culture / isolate / sensitivity detail on top.
- **Cancellation fan-out applies to micro tests too** — see diagram #2; `V_P_LAB_CANCELLATION.ORDERED_TEST_AA_ID` covers cancelled cultures.

---

## 10. Instrument Interface Map

How interfaced analyzers (chemistry, hematology, micro, molecular) and HIS infrastructure connect to the SoftLab workstation / department / location hierarchy. Each `V_S_INST_INSTRUMENT` row is a configured driver / interface.

```mermaid
erDiagram
    V_S_INST_INSTRUMENT }o--|| V_S_LAB_WORKSTATION : "ORD/RES_WORKSTATION_ID"
    V_S_LAB_WORKSTATION }o--|| V_S_LAB_DEPARTMENT : "DEPARTMENT_ID"
    V_S_LAB_WORKSTATION }o--|| V_S_LAB_LOCATION : "LOCATION_ID"
    V_S_INST_INSTRUMENT ||--o{ V_S_INST_PARAMETERS : "config params"
    V_S_INST_INSTRUMENT ||--o{ V_S_INST_TRANS_TBL : "field translations"
    V_S_INST_INSTRUMENT ||--o{ V_S_INST_CONVERSION_TBL : "conversion rules"
    V_S_INST_INSTRUMENT ||--o{ V_S_INST_ADJUST_TBL : "result adjust rules"
    V_S_INST_PARAMETERS }o--|| V_S_INST_PARAM_DESC : "param description"

    V_S_INST_INSTRUMENT {
        NUMBER AA_ID PK
        VARCHAR ID "TREM TCEPH TALIN etc"
        VARCHAR NAME "Remisol Cepheid Alinity etc"
        VARCHAR ACTIVE "Y A N"
        VARCHAR ORD_WORKSTATION_ID FK "where orders route"
        VARCHAR RES_WORKSTATION_ID FK "where results post"
        VARCHAR INSTRUMENT_TYPE "CHEMISTRY HEMATOLOGY MICRO HIS"
        VARCHAR INSTRUMENT_FLAG "BI_MSG BI_NO_MSQ UNI_LDL etc"
        VARCHAR LISTN_NAME "GenInst astmGen genref etc"
        VARCHAR PORT_NAME "tty TCP socket or middleware ref"
        VARCHAR DIR_NAME "I/TREM I/QUEST I/AUTO etc"
        VARCHAR LOADL_FILE "dbildl = bidirectional"
    }
    V_S_LAB_WORKSTATION {
        VARCHAR ID PK
        VARCHAR NAME
        VARCHAR DEPARTMENT_ID FK
        VARCHAR LOCATION_ID FK
        NUMBER REF_LAB
    }
```

**Operational notes**
- **Two workstation FKs from a single instrument row** — `ORD_WORKSTATION_ID` (where orders route for the analyzer) and `RES_WORKSTATION_ID` (where results post). They often match for direct analyzers; they diverge for middleware-routed instruments. Diagram collapses both into one edge for renderer simplicity; both columns are listed in the entity body.
- **`ACTIVE = 'A'` (not `'Y'`)** for auto-services and server processes (auto-reporting, RBS, label servers, monitoring). Standard active analyzers use `'Y'`. `'N'` = retired / inactive.
- **`INSTRUMENT_TYPE = 'HIS'` rows are NOT analyzers** — they're system-infrastructure interfaces (ADT, order entry, billing, ESB, auto-reporting, label servers). Filter these out for analyzer-only queries: `WHERE INSTRUMENT_TYPE IN ('CHEMISTRY','HEMATOLOGY','MICROBIOLOGY')`.
- **Middleware shared-connection pattern**: many physical analyzers route through one logical interface row. Beckman AU / DxC / Access at TUH all flow through `TREM` (Remisol). Same pattern at JNS (`JREM`), Episcopal (`EREM`), Fox Chase (`FREM`), W&F (`WFREM`). Use `PORT_NAME` and `INST_DEP_1` / `INST_DEP_2` to spot middleware dependencies.
- **Reference-lab interfaces** use `LISTN_NAME = 'genref'` and `DIR_NAME` like `I/QUEST`, `I/TVCOR`, `I/HIST` — separate Quest, Viracor, HistoTrac connections.
- **`LOADL_FILE = 'dbildl'`** indicates bidirectional download (LIS → instrument). Unidirectional instruments (results-only) have a different `LOADL_FILE` or none.
- **Date columns are stored as YYYYMMDD NUMBER, not Oracle DATE** — `CREATE_DATE` and `MOD_DATE` need `TO_DATE(TO_CHAR(CREATE_DATE), 'YYYYMMDD')` for date arithmetic.
- **Satellite tables** (`V_S_INST_PARAMETERS`, `V_S_INST_TRANS_TBL`, `V_S_INST_CONVERSION_TBL`, `V_S_INST_ADJUST_TBL`) hold per-instrument configuration — most query work doesn't touch them.

---

## 11. Order Lifecycle Timeline

How an order's timestamps progress from placement to reported result, and where each `*_DT` column lives. Useful for picking the right column for a given TAT measurement and for spotting where cancellations interrupt the chain.

```mermaid
flowchart LR
    O["ORDERED_DT<br/>order placed<br/><i>ORDER, ORDERED_TEST</i>"]
    C["COLLECT_DT<br/>specimen drawn<br/><i>SPECIMEN.COLLECTION_DT,<br/>ORDERED_TEST, TEST_RESULT</i>"]
    R["RECEIVE_DT<br/>specimen received<br/><i>TUBE.RECEIPT_DT,<br/>TEST_RESULT.RECEIVE_DT</i>"]
    T["TEST_DT<br/>instrument ran test<br/><i>TEST_RESULT</i>"]
    V["VERIFIED_DT<br/>tech signed off<br/>STATE = Final/Corrected<br/><i>TEST_RESULT</i>"]
    F["F_REPORTED = Y<br/>final report sent<br/><i>ORDER, TEST_RESULT</i>"]
    X["CANCELLATION_DT<br/>STATE = Canceled<br/><i>V_P_LAB_CANCELLATION</i>"]

    O --> C
    C --> R
    R --> T
    T --> V
    V --> F
    O --> X
    C --> X
    R --> X
    T --> X
    V --> X
```

**Operational notes**
- **Standard measured TAT** = `VERIFIED_DT - RECEIVE_DT` (specimen-receipt to result). This is the SLA-relevant interval for most reports; ignore the `tr.TAT` column — that's the *target*, not the measured value.
- **Other useful intervals:**
  - `RECEIVE_DT - COLLECT_DT` — specimen-transit time
  - `TEST_DT - RECEIVE_DT` — wait time at the analyzer
  - `VERIFIED_DT - TEST_DT` — instrument-run-to-verification
  - `VERIFIED_DT - ORDERED_DT` — order-to-result (door-to-door)
- **Each timestamp lives on multiple views** (denormalized for query convenience):
  - `COLLECT_DT` — canonical on `V_P_LAB_SPECIMEN.COLLECTION_DT`; denormalized to `V_P_LAB_ORDERED_TEST.COLLECTED_DT` and `V_P_LAB_TEST_RESULT.COLLECT_DT`
  - `RECEIVE_DT` — canonical (per-tube) on `V_P_LAB_TUBE.RECEIPT_DT`; denormalized to `V_P_LAB_ORDERED_TEST.RECEIVED_DT` and `V_P_LAB_TEST_RESULT.RECEIVE_DT`
  - `VERIFIED_DT` lives only on `V_P_LAB_TEST_RESULT` (no parent-level rollup)
- **Numeric / DATE triple pattern**: most timestamps have a `*_DATE` (NUMBER, YYYYMMDD), `*_TIME` (NUMBER, HHMM), and `*_DT` (DATE) trio. **Always use the `*_DT` column** — it composes the two and handles the `-1` "not set" sentinel correctly.
- **`ADMISSION_DT` is NOT in this chain** — it sits on `V_P_LAB_STAY` and can be in the FUTURE (Epic posts pre-scheduled visits up to ~5 months ahead). Don't use it as a "did this happen" filter; use a downstream timestamp like `ORDERED_DT` or `VERIFIED_DT`.
- **Cancellation can fire at any point** after order placement and before final report. The cancellation row in `V_P_LAB_CANCELLATION` records `CANCELLATION_DT` plus exactly one of four FK columns identifying the level (order / result / specimen / standing-pattern — see diagram #2). State on the relevant test-result rows flips to `Canceled`.
- **`UNVERIFIED_DT` rolls back from `VERIFIED_DT`** — when a posted result is un-verified for amendment, the `UNVERIFIED_DT` column on `V_P_LAB_TEST_RESULT` records the rollback. The eventual re-verification updates `VERIFIED_DT` again. Useful for amendment-audit reports.
- **Pre-collection ordering**: orders for not-yet-drawn specimens carry `TO_BE_COLLECT_DT` (`V_P_LAB_PENDING_RESULT`) as the planned collection time — distinct from actual `COLLECT_DT`.

---

## Update procedure

When discoveries change schema understanding (column additions, FK corrections, new gotchas), update [claude.md](claude.md) for the column detail and **also reflect the change here** if it affects the visual relationship map. Keep the diagrams focused — don't add columns just because they exist; add them only if a query author would benefit from seeing them next to the relationship arrows.
