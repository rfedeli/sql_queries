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

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| PATIENT_AA_ID | NUMBER 14 | FK → V_P_LAB_PATIENT.AA_ID |
| BILLING | VARCHAR2 23 | Billing number |
| CLINIC_ID | VARCHAR2 15 | Clinic id |
| ROOM | VARCHAR2 7 | Room |
| BED | VARCHAR2 3 | Bed |
| DOCTOR_ID | VARCHAR2 15 | Admitting doctor |
| ADMISSION_DT | DATE | Admission date/time |
| DISCHARGE_DT | DATE | Discharge date/time |
| DIAGNOSIS1_ID | VARCHAR2 11 | Primary diagnosis code |
| DIAGNOSIS2_ID | VARCHAR2 11 | Secondary diagnosis code |
| HIS_PATIENT_TYPE | VARCHAR2 1 | HIS patient type |
| ADMIT_FLAG | VARCHAR2 1 | Admitted flag |
| DISCHARGE_FLAG | VARCHAR2 1 | Discharged flag |
| ADMITTING_DOCTOR_ID | VARCHAR2 15 | Admitting doctor |
| CONSULTING_DOCTOR_ID | VARCHAR2 15 | Consulting doctor |

### V_P_LAB_ORDER — Order data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 11 | Order number |
| STAY_AA_ID | NUMBER 14 | FK → V_P_LAB_STAY.AA_ID |
| ORDERED_DT | DATE | Ordering date/time |
| COLLECT_DT | DATE | To-be-collected date/time |
| PRIORITY | CHAR 1 | Ordering priority (S=Stat, R=Routine, T=Timed) |
| REQUESTING_DOCTOR_ID | VARCHAR2 15 | Requesting doctor |
| ORDERING_CLINIC_ID | VARCHAR2 15 | Ordering ward/clinic |
| COLLECT_CENTER_ID | VARCHAR2 11 | Collection center |
| INSURANCE1_ID | VARCHAR2 15 | Insurance |
| VERIFIED | VARCHAR2 1 | Verified flag |
| BBTEST | VARCHAR2 1 | Blood bank test ordered flag |
| BACTITEST | VARCHAR2 1 | Micro test ordered flag |
| HOMECARE | VARCHAR2 1 | Homecare flag |
| NO_CHARGE | VARCHAR2 1 | No charge flag |
| PRE_OP | VARCHAR2 1 | Pre-op flag |

### V_P_LAB_ORDERED_TEST — Ordered test data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDER_AA_ID | NUMBER 14 | FK → V_P_LAB_ORDER.AA_ID |
| TEST_ID | VARCHAR2 5 | Test code |
| ORDER_NO | VARCHAR2 11 | Order number (matches V_P_BB_BB_Order.ORDERNO) |
| ORDERING_DT | DATE | Ordering date/time |
| WORKSTATION_ID | VARCHAR2 5 | Ordering workstation |
| CANCELLED_FLAG | NUMBER | Canceled flag (0 = active) |
| TECH_ID | VARCHAR2 16 | Technologist |
| SIGNING_DOCTOR_ID | VARCHAR2 15 | Authorizing doctor |
| DOCTOR_ID | VARCHAR2 15 | Requesting doctor |
| MEDICAL_SERVICE_ID | VARCHAR2 5 | Medical service |
| CLINIC_ID | VARCHAR2 15 | Ordering ward |
| PRIORITY | CHAR 1 | Ordering priority |
| TRIAGE_STATUS | VARCHAR2 40 | Triage status |
| BILL_TYPE | NUMBER 5 | Billing type (0=none, 1=Bill Only, 3=No Charge) |

### V_P_LAB_TEST_RESULT — Test result data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDER_AA_ID | NUMBER 14 | FK → V_P_LAB_ORDER.AA_ID |
| TEST_ID | VARCHAR2 5 | Individual test id (component level) |
| GROUP_TEST_ID | VARCHAR2 5 | Code of ordered test (matches ORDERED_TEST.TEST_ID) |
| RESULT | VARCHAR2 40 | Test result value |
| STATE | VARCHAR2 9 | Result state: Pending, Final, Verified, Corrected, Canceled |
| PRIORITY | CHAR 1 | Priority (S/R/T) |
| ORDERING_WORKSTATION_ID | VARCHAR2 5 | Ordering workstation |
| TESTING_WORKSTATION_ID | VARCHAR2 5 | Testing/performing workstation |
| TEST_PERFORMING_LOCATION | VARCHAR2 4 | Location where test is performed |
| TEST_PERFORMING_DEPT | VARCHAR2 5 | Performing department |
| TEST_DT | DATE | Testing date/time |
| VERIFIED_DT | DATE | Verification date/time |
| COLLECT_DT | DATE | Collection date/time |
| RECEIVE_DT | DATE | Receive date/time |
| REFLEX_DT | DATE | Reflex date/time |
| TECHNIK_ID | VARCHAR2 16 | Technologist id |
| REVIEWER_ID | VARCHAR2 16 | Reviewer id |
| COMMENTS | CLOB | Test comments |
| SPECIMEN_TYPE | VARCHAR2 8 | Specimen type |
| UNITS | VARCHAR2 80 | Test units at resulting |
| PERFORMING_LAB | VARCHAR2 1 | Flag: resulted at reference lab (Y/N) |
| REFERENCE_LAB_ID | VARCHAR2 20 | Reference lab ID |

### V_P_LAB_SPECIMEN — Specimen data

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| PATIENT_AA_ID | NUMBER 14 | FK → V_P_LAB_PATIENT.AA_ID |
| COLLECTION_DT | DATE | Collection date/time |
| DRAW_TYPE | VARCHAR2 8 | Specimen draw type |
| IS_COLLECTED | VARCHAR2 1 | Collected flag (Y/N) |
| IS_CANCELLED | VARCHAR2 1 | Cancelled flag |
| IS_MICRO | VARCHAR2 1 | Micro testing flag |
| SPECIMEN_TYPE | VARCHAR2 12 | Specimen type |
| COLLECTION_LOCATION | VARCHAR2 15 | Collection location |
| DRAW_SITE | VARCHAR2 255 | Draw site |
| COLLECTION_LIST | NUMBER 10 | Collection list number |
| CONTAINERS_NUM | NUMBER | Number of containers |

### V_P_LAB_TUBE — Ordered specimen / tube info

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDER_AA_ID | NUMBER 14 | FK → V_P_LAB_ORDER.AA_ID |
| SPECIMEN_AA_ID | NUMBER 14 | FK → V_P_LAB_SPECIMEN.AA_ID |
| TUBE_TYPE | VARCHAR2 8 | Tube type |
| TUBE_NAME | VARCHAR2 23 | Tube name |
| TUBE_SUBTYPE | VARCHAR2 8 | Tube subtype |
| TUBE_CAPACITY | NUMBER 10 | Tube capacity |
| SPECIMEN_VOLUME | NUMBER 10 | Volume |
| IS_LABELLED | NUMBER 5 | Labelled flag |
| IS_ALIQUOTED | NUMBER 5 | Aliquoted flag |
| IS_DISCARDED | NUMBER 5 | Discarded flag |
| IS_MICRO | NUMBER 5 | Micro specimen flag |
| RECEIPT_DT | DATE | Receipt date/time |
| RECEIPT_TECH | VARCHAR2 16 | Receipt tech |
| RECEIPT_LOC | VARCHAR2 11 | Receipt location |
| DELIVERY_LOC | VARCHAR2 20 | Delivery location |

### V_P_LAB_TUBEINFO — Specimen tube info (denormalized)

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER | PK (NOT NULL) |
| ORDER_ID | VARCHAR2 11 | Order number |
| BARCODE | VARCHAR2 31 | Specimen barcode |
| COLLECTION_DT | DATE | Collection date/time |
| COLLECTION_PHLEB | VARCHAR2 16 | Collecting phlebotomist |
| SPECIMEN_TYPE | VARCHAR2 12 | Specimen type |
| TUBE_TYPE | VARCHAR2 8 | Tube type |
| LAST_NAME | VARCHAR2 50 | Patient last name |
| FIRST_NAME | VARCHAR2 80 | Patient first name |
| MIDDLE_INITIAL | VARCHAR2 27 | Patient middle initial |
| SEX | VARCHAR2 1 | Patient sex |
| DATE_OF_BIRTH | DATE | Patient date of birth |
| MRN | VARCHAR2 23 | Medical record number |

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

### V_S_LAB_CLINIC — Clinic / ordering location setup

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ID | VARCHAR2 15 | Clinic code |
| NAME | VARCHAR2 100 | Clinic name |
| ORD_LOCATION_ID | VARCHAR2 15 | Ordering location / collection center ID |
| FACILITY | VARCHAR2 20 | Hospital code |
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

---

## Blood Bank (SoftBank) Views — Detail

### V_P_BB_BB_Order — Blood bank order

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDERNO | VARCHAR2 11 | Order number (unique; cross-links to V_P_LAB_ORDERED_TEST.ORDER_NO) |
| MRN | VARCHAR2 23 | Medical record number |
| REQUESTING_PHYSICIAN | VARCHAR2 15 | Requesting physician |
| PHLEBOTOMIST | VARCHAR2 16 | Phlebotomist |
| DEPOT | VARCHAR2 11 | Site / depot location |
| ORDER_TYPE | CHAR 1 | Entity type |
| ORDERTYPE | CHAR 1 | Order type |
| PATIENTTYPE | CHAR 1 | Patient type |
| LINKEDORDERNO | VARCHAR2 11 | Linked order number |
| HOLLISTERNO | VARCHAR2 15 | Hollister number |
| MEDICALSERVICE | VARCHAR2 5 | Medical service |
| REQUESTEDDT | DATE | Requested date/time |
| COLLECTEDDT | DATE | Collected date/time |
| RECEIVEDDT | DATE | Received date/time |
| REPORTDT | DATE | Report date/time |

### V_P_BB_Result — Blood bank test result

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDERNO | VARCHAR2 11 | FK → V_P_BB_BB_Order.ORDERNO |
| TEST_RESULT | NUMBER 14 | FK → V_P_BB_Test.AA_ID |
| CODE | VARCHAR2 5 | Result code |
| STATUS | CHAR 1 | Status |
| RESULTNO | NUMBER 5 | Sequential result number |
| RESULTEDDT | DATE | Resulted date/time |
| REVIEWDT | DATE | Review date/time |
| SUP_REVIEWDT | DATE | Supervisory review date/time |
| FIRST_REPORTEDDT | DATE | First reported date/time |
| BILLINGDT | DATE | Billing date/time |
| RESULT01–RESULT23 | VARCHAR2 2 | Result values (positional) |

### V_P_BB_Test — Blood bank test

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| ORDERNO | VARCHAR2 11 | FK → V_P_BB_BB_Order.ORDERNO |
| CODE | VARCHAR2 5 | Test code |
| ORDEREDCODE | VARCHAR2 5 | Ordered code |
| STATUS | CHAR 1 | Status |
| TESTNO | NUMBER 5 | Sequential test number |
| TEST_TYPE | CHAR 1 | Type |
| PHYSICIAN | VARCHAR2 15 | Requesting physician |
| WARD | VARCHAR2 15 | Ordering ward |
| FINAL_INTERPRETATION | VARCHAR2 26 | Interpretation text |
| RELEASING_TECH | VARCHAR2 16 | Releasing technologist |
| REQUESTDT | DATE | Request date/time |
| REQUESTEDDT | DATE | Requested date/time |
| RELEASEDDT | DATE | Released date/time |

### V_P_BB_Patient — Blood bank patient demographics

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 14 | PK |
| MRN | VARCHAR2 23 | Medical record number |
| SSN | VARCHAR2 23 | Social security number |
| LAST_NAME | VARCHAR2 35 | Last name |
| FIRST_NAME | VARCHAR2 31 | First name |
| ABO | VARCHAR2 2 | ABO blood type |
| RH | CHAR 1 | Rh factor |
| HISTORICAL_ABO | VARCHAR2 2 | Historical ABO |
| HISTORICAL_RH | CHAR 1 | Historical Rh |
| SEX | CHAR 1 | Sex |
| RACE | VARCHAR2 40 | Race |
| SITE | VARCHAR2 5 | Site |

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
| VTINVDT | DATE | Invoice date |
| VTFBDT | DATE | First bill date |
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
| VTSTAT | NUMBER | Status (NOT NULL) |
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
| VTREADY | NUMBER | Ready flag (NOT NULL) |
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
| TSTSYSCODE | VARCHAR2 5 | System code (links to SoftLab test) |
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
| BRNOBILL | NUMBER | No bill flag |
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
| ITPRICE | NUMBER | Price |
| ITTAXAMT | NUMBER | Tax amount |
| ITGROSS | NUMBER | Gross amount |
| ITACCAMT | NUMBER | Account amount |
| ITBAL | NUMBER | Balance |
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
| ITFREQSTAT | NUMBER | Frequency limit status |
| ITMEDNECSTAT | NUMBER | Medical necessity status |
| ITABN | NUMBER | ABN status |
| ITCCITINTN | NUMBER | FK → V_S_ARE_CCI.CCINTN (system-flagged CCI edit) |
| ITMODFLAG | NUMBER | Modifier flag |
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

---

## Not Found in Dictionaries

| View | Notes |
|------|-------|
| V_P_IDN_LOG | Used in `draw_by_location` query. Columns: PATIENT_ID, SPECIMEN_ID, PHLEB_ID, ROLE_ID, DEVICE_ID, TERMINAL_ID, LOG_DT, EVENT, MESSAGE. Likely an ID/barcode scanning event log — not documented in the provided SCC dictionaries. |

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
