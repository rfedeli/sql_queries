-- ABG/VBG Collection Method Report: Jan 1 through today
-- Two queries:
--   1. DETAIL   — one row per order with Nurse/Phleb classification and collector ID
--   2. SUMMARY  — totals (Nurse / Phleb / Unknown / grand total)
-- Classification source: V_P_LAB_SPECIMEN.NURSE_COLL (1 = nurse, 0 = phleb; NUMBER)
-- Collector source:      V_P_LAB_SPECIMEN.COLLECTION_PHLEB_ID
-- Oracle 19c compatible

-- =====================================================================
-- 1. DETAIL
-- =====================================================================
WITH order_detail AS (
  SELECT
    cc.SITE                      AS SITE_CODE,
    o.ID                         AS ORDER_ID,
    p.ID                         AS MRN,
    p.LAST_NAME,
    p.FIRST_NAME,
    tr.GROUP_TEST_ID             AS TEST,
    o.ORDERED_DT                 AS ORDER_TIME,
    tr.COLLECT_DT                AS COLLECT_TIME,
    tr.RECEIVE_DT                AS RECEIVE_TIME,
    tr.VERIFIED_DT               AS RESULT_TIME,
    o.PRIORITY,
    o.ORDERING_CLINIC_ID         AS CLINIC,
    MAX(sp.NURSE_COLL)           AS NURSE_COLL_FLAG,
    MAX(sp.COLLECTION_PHLEB_ID)  AS COLLECTOR_ID
  FROM V_P_LAB_ORDER o
    JOIN V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = o.AA_ID
    JOIN V_P_LAB_STAY s         ON s.AA_ID = o.STAY_AA_ID
    JOIN V_P_LAB_PATIENT p      ON p.AA_ID = s.PATIENT_AA_ID
    LEFT JOIN V_S_LAB_COLL_CENTER cc ON cc.ID = o.COLLECT_CENTER_ID
    LEFT JOIN V_P_LAB_TUBE tub       ON tub.ORDER_AA_ID = o.AA_ID
    LEFT JOIN V_P_LAB_SPECIMEN sp    ON sp.AA_ID = tub.SPECIMEN_AA_ID
  WHERE tr.GROUP_TEST_ID IN ('ABG', 'VBG')
    AND tr.STATE IN ('Final', 'Corrected')
    AND tr.RESULT <> '.'
    AND o.ORDERED_DT >= TO_DATE('2026-01-01', 'YYYY-MM-DD')
    AND o.ORDERED_DT <  TRUNC(SYSDATE) + 1
    AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
  GROUP BY
    cc.SITE, o.ID, p.ID, p.LAST_NAME, p.FIRST_NAME,
    tr.GROUP_TEST_ID, o.ORDERED_DT, tr.COLLECT_DT,
    tr.RECEIVE_DT, tr.VERIFIED_DT, o.PRIORITY, o.ORDERING_CLINIC_ID
)
SELECT
  CASE SITE_CODE
    WHEN 'TUH'   THEN 'Temple University Hospital'
    WHEN 'JNS'   THEN 'Jeanes Hospital'
    WHEN 'CH'    THEN 'Chestnut Hill Hospital'
    WHEN 'EPC'   THEN 'Episcopal Hospital'
    WHEN 'FC'    THEN 'Fox Chase Cancer Center'
    WHEN 'WFH'   THEN 'Women and Families Hospital'
    ELSE SITE_CODE
  END AS FACILITY,
  ORDER_ID,
  MRN,
  LAST_NAME,
  FIRST_NAME,
  TEST,
  ORDER_TIME,
  COLLECT_TIME,
  RECEIVE_TIME,
  RESULT_TIME,
  PRIORITY,
  CLINIC,
  CASE
    WHEN NURSE_COLL_FLAG = 1 THEN 'Nurse'
    WHEN NURSE_COLL_FLAG = 0 THEN 'Phleb'
    ELSE 'Unknown'
  END AS COLLECT_BY,
  COLLECTOR_ID
FROM order_detail
ORDER BY SITE_CODE, ORDER_TIME;

-- =====================================================================
-- 2. SUMMARY — totals by collection method
-- =====================================================================
WITH order_detail AS (
  SELECT
    MAX(sp.NURSE_COLL) AS NURSE_COLL_FLAG
  FROM V_P_LAB_ORDER o
    JOIN V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = o.AA_ID
    JOIN V_P_LAB_STAY s         ON s.AA_ID = o.STAY_AA_ID
    JOIN V_P_LAB_PATIENT p      ON p.AA_ID = s.PATIENT_AA_ID
    LEFT JOIN V_P_LAB_TUBE tub       ON tub.ORDER_AA_ID = o.AA_ID
    LEFT JOIN V_P_LAB_SPECIMEN sp    ON sp.AA_ID = tub.SPECIMEN_AA_ID
  WHERE tr.GROUP_TEST_ID IN ('ABG', 'VBG')
    AND tr.STATE IN ('Final', 'Corrected')
    AND tr.RESULT <> '.'
    AND o.ORDERED_DT >= TO_DATE('2026-01-01', 'YYYY-MM-DD')
    AND o.ORDERED_DT <  TRUNC(SYSDATE) + 1
    AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
  GROUP BY o.ID
)
SELECT
  COUNT(CASE WHEN NURSE_COLL_FLAG = 1 THEN 1 END) AS TOTAL_NURSE,
  COUNT(CASE WHEN NURSE_COLL_FLAG = 0 THEN 1 END) AS TOTAL_PHLEB,
  COUNT(CASE WHEN NURSE_COLL_FLAG IS NULL THEN 1 END) AS TOTAL_UNKNOWN,
  COUNT(*)                                                  AS TOTAL_ORDERS
FROM order_detail;
