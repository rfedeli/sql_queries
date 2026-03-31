/*
Delayed Billing Report - Bills sent after specified threshold

Purpose: Identify visits where the first bill date is more than N days
         after the service date, indicating delayed billing.

Parameters:
  :DAYS_THRESHOLD - Minimum days between service and billing (e.g., 5)
  :START_DATE     - Start of service date range in YYYYMMDD format (e.g., 20250101)
  :END_DATE       - End of service date range in YYYYMMDD format (e.g., 20251231)

Example usage:
  DEFINE DAYS_THRESHOLD = 5
  DEFINE START_DATE = 20250101
  DEFINE END_DATE = 20251231

Columns:
  - MRN: Medical record number
  - ORDER_ID: SoftLab order number
  - BILLING_ID: AR visit reference/invoice number
  - SERVICE_DATE: Date of service (VTSRVDT)
  - FIRST_BILL_DATE: Date bill was first sent (VTFBDT)
  - LAST_BILL_DATE: Date bill was last sent (VTLBDT)
  - DAYS_TO_BILL: Number of days between service and billing
  - LATEST_TEST_CODE: Test code of the most recently billed item
  - LATEST_TEST_DESC: Description of the most recently billed item
  - MANUAL_MOD_FLAG: Y if item has a modifier not matching billing rules config
  - MOD_CHANGED_BY: User who added/changed the modifier (from audit trail)
  - MOD_CHANGED_DATE: Date/time the modifier was added/changed (from audit trail)
  - LAST_VERIFIED_DATE: Last verification date for any result on this order
  - DAYS_VERIFIED_TO_BILL: Days between last result verification and first bill
  - DAYS_MOD_TO_BILL: Days between modifier change and first bill

*/

WITH delayed_bills AS (
  SELECT
    p.ID AS MRN,
    o.ID AS ORDER_ID,
    v.VTREFNO AS BILLING_ID,
    v.VTINTN,
    o.AA_ID AS ORDER_AA_ID,
    v.VTSRVDT AS SERVICE_DATE,
    v.VTFBDT AS FIRST_BILL_DATE,
    v.VTLBDT AS LAST_BILL_DATE,
    v.VTFBDT - v.VTSRVDT AS DAYS_TO_BILL
  FROM V_P_LAB_ORDER o
  JOIN V_P_LAB_STAY s ON o.STAY_AA_ID = s.AA_ID
  JOIN V_P_LAB_PATIENT p ON s.PATIENT_AA_ID = p.AA_ID
  JOIN V_P_ARE_VISIT v ON v.VTORGORDNUM = o.ID
  WHERE v.VTFBDT IS NOT NULL                    -- Must have been billed
    AND v.VTSRVDT IS NOT NULL                   -- Must have service date
    AND v.VTFBDT - v.VTSRVDT <= :DAYS_THRESHOLD  -- Billed after threshold
    AND TRUNC(v.VTSRVDT) BETWEEN TO_DATE(:START_DATE, 'YYYYMMDD')
                             AND TO_DATE(:END_DATE, 'YYYYMMDD')  -- Service date range
    AND REGEXP_LIKE(p.ID, '^E[0-9]+$')          -- Valid MRNs only
),
latest_items AS (
  SELECT
    i.ITVTINTN,
    i.ITINTN,
    i.ITTSTCODE,
    NVL(t.TSTDESC, i.ITDESC) AS TEST_DESC,
    CASE WHEN i.ITCPTMOD0 IS NOT NULL
              AND i.ITCPTMOD0 != NVL(br.BRMODCODE0, '~')
         THEN 'Y' ELSE 'N'
    END AS MANUAL_MOD_FLAG,
    ROW_NUMBER() OVER (
      PARTITION BY i.ITVTINTN
      ORDER BY NVL(i.ITEDITDTM, i.ITCREATDTM) DESC, i.ITINTN DESC
    ) AS rn
  FROM V_P_ARE_ITEM i
  LEFT JOIN V_S_ARE_TEST t ON t.TSTCODE = i.ITTSTCODE AND t.TSTSTAT = 0
  LEFT JOIN V_S_ARE_BILLRULES br
    ON br.BRTSTCODE = i.ITTSTCODE
    AND br.BRCPTCODE = i.ITCPTCD
    AND br.BRSTAT = 0
  WHERE i.ITSTAT = 0  -- Active items only
),
mod_audit AS (
  SELECT
    aud.ATROWINTN,
    aud.ATUSER,
    aud.ATDATE,
    ROW_NUMBER() OVER (
      PARTITION BY aud.ATROWINTN
      ORDER BY aud.ATDATE DESC
    ) AS rn
  FROM V_P_ARE_AUDITTRAIL aud
  WHERE aud.ATTABLE = 'Item'
    AND aud.ATFIELD = 'itcptmod0'
),
last_verified AS (
  SELECT
    tr.ORDER_AA_ID,
    MAX(tr.VERIFIED_DT) AS LAST_VERIFIED_DT
  FROM V_P_LAB_TEST_RESULT tr
  WHERE tr.STATE IN ('Final', 'Corrected')
    AND tr.RESULT <> '.'
    AND tr.VERIFIED_DT IS NOT NULL
  GROUP BY tr.ORDER_AA_ID
)
SELECT
  db.MRN,
  db.ORDER_ID,
  db.BILLING_ID,
  TO_CHAR(db.SERVICE_DATE, 'YYYY-MM-DD HH24:MI') AS SERVICE_DATE,
  TO_CHAR(db.FIRST_BILL_DATE, 'YYYY-MM-DD HH24:MI') AS FIRST_BILL_DATE,
  TO_CHAR(db.LAST_BILL_DATE, 'YYYY-MM-DD HH24:MI') AS LAST_BILL_DATE,
  db.DAYS_TO_BILL,
  li.ITTSTCODE AS LATEST_TEST_CODE,
  li.TEST_DESC AS LATEST_TEST_DESC,
  li.MANUAL_MOD_FLAG,
  ma.ATUSER AS MOD_CHANGED_BY,
  TO_CHAR(ma.ATDATE, 'YYYY-MM-DD HH24:MI') AS MOD_CHANGED_DATE,
  TO_CHAR(lv.LAST_VERIFIED_DT, 'YYYY-MM-DD HH24:MI') AS LAST_VERIFIED_DATE,
  ROUND(db.FIRST_BILL_DATE - lv.LAST_VERIFIED_DT, 1) AS DAYS_VERIFIED_TO_BILL,
  ROUND(db.FIRST_BILL_DATE - ma.ATDATE, 1) AS DAYS_MOD_TO_BILL
FROM delayed_bills db
LEFT JOIN latest_items li ON li.ITVTINTN = db.VTINTN AND li.rn = 1
LEFT JOIN mod_audit ma ON ma.ATROWINTN = li.ITINTN AND ma.rn = 1
LEFT JOIN last_verified lv ON lv.ORDER_AA_ID = db.ORDER_AA_ID
ORDER BY db.DAYS_TO_BILL DESC, db.SERVICE_DATE DESC;