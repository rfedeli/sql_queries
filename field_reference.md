# SCC Field Reference — Human-Readable Guide

Quick reference for the database fields used in our queries.
Organized by system area, showing what each field means and where it lives.

> **Note:** GUI Label column reflects SCC application labels where known.
> Fields marked **(TBD)** need a screenshot from the app to confirm the label.

---

## SoftAR — Visit (V_P_ARE_VISIT)

The AR visit is the billing record created when a lab order crosses from SoftLab into SoftAR.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `VTINTN` | (internal) | Visit primary key | Used for all joins within SoftAR |
| `VTREFNO` | Invoice No **(TBD)** | Invoice/reference number | Human-readable identifier |
| `VTORGORDNUM` | Accession No **(TBD)** | Original order number from SoftLab | Links back to `V_P_LAB_ORDER.ID` |
| `VTSRVDT` | Service Date **(TBD)** | Date of service | Used for date-range filtering |
| `VTINVDT` | Invoice Date **(TBD)** | Date the invoice was created | NULL = never invoiced |
| `VTFBDT` | First Bill Date **(TBD)** | Date the bill was first sent to payor | NULL = never billed |
| `VTLBDT` | Last Bill Date **(TBD)** | Date of most recent bill | |
| `VTSTAT` | Status **(TBD)** | Visit status code | 0=Pending, 1=Active, 2=Held, 3=Cancelled, 4=Other |
| `VTREADY` | Ready **(TBD)** | Ready-to-bill flag | 0=Ready, 1=Not Ready |
| `VTCHARGE` | Charge **(TBD)** | Total charge amount | Stored in **cents** (divide by 100) |
| `VTFCLTY` | Facility **(TBD)** | Facility code | |
| `VTWARD` | Ward **(TBD)** | Ward code | |
| `VTHOLDTILL` | Hold Until **(TBD)** | Hold-until date | Visit held from billing until this date |
| `VTHOLDRES` | Hold Reason **(TBD)** | Hold reason code | 0=none |
| `VTCREATDTM` | Created **(TBD)** | When the visit record was created | |
| `VTKIND` | Kind **(TBD)** | Visit kind | |

### Key Concepts — Visit Pipeline
```
Lab Order (SoftLab) ──► AR Visit created ──► Invoice (VTINVDT set) ──► Bill sent (VTFBDT set)
```
- **Uninvoiced**: `VTINVDT IS NULL` — visit exists but invoice was never generated
- **Invoiced / Unbilled**: `VTINVDT` is set but `VTFBDT IS NULL` — invoice exists but was never sent to payor
- Uninvoiced visits have **zero items** in V_P_ARE_ITEM — they are visit shells only

---

## SoftAR — Billing Errors (V_P_ARE_BILLERROR)

Errors logged against visits during the billing pipeline. These are **visit-level** (not item-level).

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `BEINTN` | (internal) | Error primary key | |
| `BERVTINTN` | (internal) | FK to visit | Join: `BERVTINTN = VTINTN` |
| `BERCODE` | Error Code **(TBD)** | Error code | Usually empty — look up via `NVL(BERCODE, 'IN75')` in V_S_ARE_ARERROR |
| `BERDESC` | Description **(TBD)** | Raw error description text | **Primary useful field** — carries the actual error detail |
| `BERDTM` | Error Date **(TBD)** | When the error was logged | Generally matches service date |
| `BEFLAGS` | Flags **(TBD)** | Error flags | |
| `BECNT` | Count **(TBD)** | Error count | |

---

## SoftAR — Error Definitions (V_S_ARE_ARERROR)

Lookup table for billing error codes. Join: `ERRCODE = NVL(be.BERCODE, 'IN75')`.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ERRCODE` | Code **(TBD)** | Error code (PK) | e.g., 'IN75', 'NOMOD', 'IN24', 'STXER' |
| `ERRDESC` | Description **(TBD)** | Error description | |
| `ERRACTION` | Action **(TBD)** | What the system does | 0=Abort, 1=Skip, 2=Warning, 3=Ignore, 4=Drop Item, 5=Hold, 6=Split, 7=Split Warn, 8=Hold & Bill Client |
| `ERRGRP` | Stage **(TBD)** | Pipeline stage that raised it | 0=Invoicing, 1=Billing, 2=Other, 3=Posting, 4=Remittance |

### Common Error Patterns (from investigation)
| Code | Action | Stage | What Happens | Result |
|------|--------|-------|-------------|--------|
| NOMOD | Skip | Billing | Missing CCI modifier | Invoiced, **not billed** |
| IN24 | Skip | Invoicing | Payor HIS components don't meet criteria | **Not invoiced** |
| STXER | Warning | Billing | Patient data syntax error (e.g., last name) | Invoiced, **not billed** |
| (none) | — | — | Order never crossed from SoftLab to SoftAR | **No AR visit at all** |

---

## SoftAR — Items (V_P_ARE_ITEM)

Billing line items on a visit. Each item = one billable test/CPT code.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ITINTN` | (internal) | Item primary key | |
| `ITVTINTN` | (internal) | FK to visit | Join: `ITVTINTN = VTINTN` |
| `ITTSTCODE` | Test Code **(TBD)** | AR test code | FK to V_S_ARE_TEST.TSTCODE |
| `ITCPTCD` | CPT Code **(TBD)** | CPT/HCPCS code | FK to V_S_ARE_CPTTABLE.CPTCODE |
| `ITCPTMOD0–3` | Modifier 0–3 **(TBD)** | CPT modifiers | Up to 4 modifier slots |
| `ITPRICE` | Price **(TBD)** | Item price | Stored in **cents** (divide by 100) |
| `ITUNITS` | Units **(TBD)** | Quantity | |
| `ITSTAT` | Status **(TBD)** | Item status | 0=Active |
| `ITINEXT` | Ins Ext **(TBD)** | Insurance extension | Links item to invoice via `INEXT` |
| `ITCCITINTN` | CCI Link **(TBD)** | CCI conflict pointer | Points to the column-1 item's ITINTN (NOT to V_S_ARE_CCI) |
| `ITABN` | ABN **(TBD)** | ABN status | 0=N(ok), 1=Y, 2=U, 3=P, 4=R, 5=W, 6=X, 7=S |
| `ITMODFLAG` | Mod Flag **(TBD)** | Modifier override flag | 0=None, 1=Payable w/ Modifier, >1=Not Allowed |
| `ITFCLTY` | Facility **(TBD)** | Facility code | |
| `ITWARD` | Ward **(TBD)** | Ward code | |
| `ITDESC` | Description **(TBD)** | Item description | |

### Fields Always Zero in Our System
These exist but are never populated — do not use for filtering:
- `ITFREQSTAT` — Frequency limit status (always 0)
- `ITMEDNECSTAT` — Medical necessity status (always 0)
- `ITBAL` — Item balance (always 0)
- `INDUEAMT` — Invoice due amount (always 0)
- `VTPAID` — Visit paid amount (always 0)

---

## SoftAR — Invoices (V_P_ARE_INVOICE)

Invoice records linking visits to payors. Join to items via `INVTINTN = VTINTN AND INEXT = ITINEXT`.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ININTN` | (internal) | Invoice primary key | |
| `INVTINTN` | (internal) | FK to visit | |
| `INEXT` | Ins Ext **(TBD)** | Insurance extension | Matches `ITINEXT` on items |
| `INSTAT` | Status **(TBD)** | Invoice status | 0=Active |
| `INBILLTO` | Bill To **(TBD)** | Payor code | FK to V_S_ARE_PAYOR.PYOCODE |
| `INCHARGE` | Charge **(TBD)** | Invoice charge amount | Stored in **cents** |
| `INFBDT` | First Billed **(TBD)** | First bill date | NULL = never billed |
| `INLBDT` | Last Billed **(TBD)** | Last bill date | |

---

## SoftAR — Payors (V_S_ARE_PAYOR)

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `PYOCODE` | Payor Code **(TBD)** | Payor identifier | |
| `PYOCLASS` | Class **(TBD)** | Billing classification | |
| `PYOTYPE` | Type **(TBD)** | Payor type | 0=Insurance, 1=Client, 2=Self-Pay, 3=Collection, 4=Undetermined |

---

## SoftAR — Test Setup (V_S_ARE_TEST)

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `TSTCODE` | Test Code **(TBD)** | AR test code | |
| `TSTDESC` | Description **(TBD)** | Test description | |
| `TSTSYSCODE` | System Code **(TBD)** | SoftLab test ID | Links AR test to lab test |

---

## SoftAR — CCI Edits (V_S_ARE_CCI)

Correct Coding Initiative edit pairs — rules that flag conflicting CPT codes on the same visit.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `CCINTN` | (internal) | CCI rule primary key | |
| `CCCPT1` | CPT Column 1 **(TBD)** | First CPT in the pair | The "grouped" code |
| `CCCPT2` | CPT Column 2 **(TBD)** | Second CPT in the pair | The "subordinate" code |
| `CCPYOCODE` | Payor **(TBD)** | Payor-specific rule | |
| `CCFLAG` | Modifier Indicator **(TBD)** | Can a modifier override? | 0=Not Allowed, 1=Allowed, 9=N/A |
| `CCEFFDT` | Effective Date **(TBD)** | Rule start date | |
| `CCEXPDT` | Expiration Date **(TBD)** | Rule end date | NULL=no expiration |

---

## SoftAR — Billing Rules (V_S_ARE_BILLRULES)

Per-test/payor billing configuration.

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `BRTSTCODE` | Test Code **(TBD)** | AR test code | |
| `BRCPTCODE` | CPT Code **(TBD)** | CPT assigned by rule | |
| `BRPYOCODE` | Payor **(TBD)** | Payor this rule applies to | |
| `BRCCIMOD` | CCI Modifier **(TBD)** | Modifier to apply for CCI override | e.g., 59, XE, XP |
| `BRNOBILL` | No Bill **(TBD)** | Billing disposition | 0=Normal, 1=Free, 2=Split to Components, 3=Bill to PRIV, 4=Bill to Secondary, 5=Bill to Ward, 6=Bill to Specified |

---

## SoftLab — Orders (V_P_LAB_ORDER)

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Order primary key | |
| `ID` | Order No / Accession **(TBD)** | Order number | Links to `V_P_ARE_VISIT.VTORGORDNUM` |
| `STAY_AA_ID` | (internal) | FK to stay | |
| `ORDERED_DT` | Ordered Date **(TBD)** | When the order was placed | |
| `COLLECT_DT` | Collect Date **(TBD)** | Scheduled collection date | |
| `PRIORITY` | Priority **(TBD)** | Order priority | S=Stat, R=Routine, T=Timed |
| `ORDERING_CLINIC_ID` | Ordering Ward **(TBD)** | Where the order came from | FK to V_S_LAB_CLINIC.ID |
| `REQUESTING_DOCTOR_ID` | Doctor **(TBD)** | Requesting physician | |
| `COLLECT_CENTER_ID` | Depot **(TBD)** | Collection center / site | |
| `NO_CHARGE` | No Charge **(TBD)** | No-charge flag | Y/N |

---

## SoftLab — Ordered Tests (V_P_LAB_ORDERED_TEST)

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Ordered test primary key | |
| `ORDER_AA_ID` | (internal) | FK to order | |
| `TEST_ID` | Test ID **(TBD)** | Test code | Matches `V_P_LAB_TEST_RESULT.GROUP_TEST_ID` |
| `ORDER_NO` | Order No **(TBD)** | Order number | Also links to `V_P_BB_BB_Order.ORDERNO` |
| `WORKSTATION_ID` | Workstation **(TBD)** | Ordering workstation | Part of 3-way join key with test results |
| `CANCELLED_FLAG` | Cancelled **(TBD)** | Cancellation flag | 0=Active, non-zero=Cancelled |
| `BILL_TYPE` | Bill Type **(TBD)** | Billing type | 0=None, 1=Bill Only, 3=No Charge |

---

## SoftLab — Test Results (V_P_LAB_TEST_RESULT)

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ORDER_AA_ID` | (internal) | FK to order | |
| `TEST_ID` | Test ID **(TBD)** | Component-level test code | Individual test within a panel |
| `GROUP_TEST_ID` | Group Test ID **(TBD)** | Panel-level test code | Matches `ORDERED_TEST.TEST_ID` — panels count as 1 test |
| `ORDERING_WORKSTATION_ID` | Workstation **(TBD)** | Ordering workstation | Part of 3-way join key |
| `RESULT` | Result **(TBD)** | Test result value | `'.'` = cancelled test — always exclude |
| `STATE` | State **(TBD)** | Result state | Pending, Final, Verified, Corrected, Canceled |
| `VERIFIED_DT` | Verified Date **(TBD)** | When result was verified | |
| `COLLECT_DT` | Collected **(TBD)** | Collection date/time | |
| `RECEIVE_DT` | Received **(TBD)** | Receive date/time | |
| `TEST_PERFORMING_LOCATION` | Perf Location **(TBD)** | Where the test was performed | |

### Join Pattern: Ordered Test to Test Result
```sql
ot.ORDER_AA_ID = tr.ORDER_AA_ID
AND ot.TEST_ID = tr.GROUP_TEST_ID
AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
```

---

## SoftLab — Patients & Stays

### V_P_LAB_PATIENT

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Patient primary key | |
| `ID` | MRN **(TBD)** | Medical Record Number | Only `^E[0-9]+$` are real patients |
| `LAST_NAME` | Last Name **(TBD)** | | |
| `FIRST_NAME` | First Name **(TBD)** | | |

### V_P_LAB_STAY

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Stay primary key | |
| `PATIENT_AA_ID` | (internal) | FK to patient | |
| `CLINIC_ID` | Clinic **(TBD)** | Clinic code | |

---

## SoftLab — Specimens & Tubes

### V_P_LAB_SPECIMEN

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Specimen primary key | |
| `PATIENT_AA_ID` | (internal) | FK to patient | |
| `COLLECTION_DT` | Collected **(TBD)** | Collection date/time | |
| `IS_COLLECTED` | Collected **(TBD)** | Collection flag | Y/N |
| `IS_CANCELLED` | Cancelled **(TBD)** | Cancellation flag | Y/N |
| `DRAW_TYPE` | Draw Type **(TBD)** | Specimen draw type | |

### V_P_LAB_TUBE

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Tube primary key | |
| `ORDER_AA_ID` | (internal) | FK to order | |
| `SPECIMEN_AA_ID` | (internal) | FK to specimen | |
| `RECEIPT_DT` | Received **(TBD)** | Receipt date/time | |
| `IS_LABELLED` | Labelled **(TBD)** | Label flag | 0/1 |

### V_P_LAB_SPECIMEN_BARCODE

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `TUBE_AA_ID` | (internal) | FK to tube | |
| `CODE` | Barcode **(TBD)** | Barcode/identifier value | |
| `CODE_TYPE` | Type **(TBD)** | Code type | S=Specimen ID, B=Barcode, O=Order number |
| `SOURCE` | Source **(TBD)** | Source system | L=SoftLab, H=HIS, B=SoftBank |

---

## Blood Bank — Orders & Results

### V_P_BB_BB_Order

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ORDERNO` | Order No **(TBD)** | Blood bank order number | Links to `V_P_LAB_ORDERED_TEST.ORDER_NO` |
| `MRN` | MRN **(TBD)** | Medical record number | |
| `DEPOT` | Depot / Site **(TBD)** | Site location | |
| `REQUESTEDDT` | Requested **(TBD)** | Requested date/time | Use this for date filtering (RELEASEDDT is mostly NULL) |

### V_P_BB_Result

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `ORDERNO` | Order No **(TBD)** | FK to BB order | |
| `TEST_RESULT` | (internal) | FK to V_P_BB_Test.AA_ID | |
| `STATUS` | Status **(TBD)** | Result status | `'F'` = finalized |
| `REVIEWDT` | Reviewed **(TBD)** | Review date/time | Use for date filtering |
| `RESULTEDDT` | Resulted **(TBD)** | Result date/time | |

### V_P_BB_Test

| Field | GUI Label | What It Means | Values / Notes |
|-------|-----------|---------------|----------------|
| `AA_ID` | (internal) | Test primary key | |
| `ORDERNO` | Order No **(TBD)** | FK to BB order | |
| `CODE` | Test Code **(TBD)** | Test code (e.g., 'TS3') | |
| `STATUS` | Status **(TBD)** | Test status | CHAR(1): blank=completed, `'N'`=not complete |

---

## How the Systems Connect

```
SoftLab                          SoftAR                           Blood Bank
────────                         ──────                           ──────────
V_P_LAB_PATIENT (AA_ID)
  └► V_P_LAB_STAY (PATIENT_AA_ID)
       └► V_P_LAB_ORDER (STAY_AA_ID)
            │
            ├► ORDERED_TEST ◄───────────────────────────────────► V_P_BB_BB_Order
            │   (ORDER_NO = ORDERNO)                               (ORDERNO)
            │
            ├► TEST_RESULT
            │   (ORDER_AA_ID, GROUP_TEST_ID, ORDERING_WORKSTATION_ID)
            │
            └► ORDER.ID ─────────► V_P_ARE_VISIT.VTORGORDNUM
                                      │
                                      ├► V_P_ARE_ITEM (ITVTINTN)
                                      │    └► V_P_ARE_INVOICE (INVTINTN + INEXT)
                                      │
                                      └► V_P_ARE_BILLERROR (BERVTINTN)
                                           └► V_S_ARE_ARERROR (ERRCODE)
```

---

## Valid MRN Rule

Only MRNs matching `^E[0-9]+$` (E followed by digits only) are real patients.
All other prefixes (TX, EX, ZZ, etc.) are test/fake patients — always exclude.

```sql
WHERE REGEXP_LIKE(p.ID, '^E[0-9]+$')
```

---

## Money Fields

All SoftAR monetary fields are stored in **cents**. Divide by 100 for dollars.

Applies to: `ITPRICE`, `ITBAL`, `INCHARGE`, `INDUEAMT`, `VTCHARGE`, `TRAMT`

---

*Last updated: 2026-02-11. Fields marked (TBD) need GUI label confirmation via screenshot.*
