/*
FXAUF/FXALM Turn-Around Time Summary — Stat Cases Only

Purpose: Evaluate received-to-verified TAT for Fox Chase Urinalysis
         (FXAUF and FXALM) for stat priority cases only.
         Each row is a detail record with TAT data; summary stats are appended
         as columns via window functions so everything comes back in one result set.

Parameters:
  :START_DATE - Start of date range in YYYYMMDD format (e.g., 20250101)
  :END_DATE   - End of date range in YYYYMMDD format (e.g., 20251231)

Example usage:
  DEFINE START_DATE = 20250101
  DEFINE END_DATE = 20251231

Detail Columns:
  - MRN: Medical record number
  - ORDER_ID: Order number
  - GROUP_TEST: Which test (FXAUF or FXALM)
  - ORDERING_CLINIC: Clinic/ward where test was ordered
  - TESTING_WORKSTATION: Instrument/workstation that ran the test
  - ORDERED_DT: When test was ordered
  - COLLECTED_DT: When specimen was collected
  - RECEIVED_DT: When specimen was received in lab
  - VERIFIED_DT: When result was verified
  - RECEIVE_TO_VERIFY_MIN: Minutes from receipt to verification

Summary Columns (same value on every row):
  - TOTAL_SAMPLES: Total number of verified stat results
  - EXCEEDED_45_MIN: Count of results with receive-to-verify TAT > 45 minutes
  - PCT_EXCEEDED_45_MIN: Percentage of results exceeding 45 minutes
  - EXCEEDED_60_MIN: Count of results with receive-to-verify TAT > 60 minutes
  - PCT_EXCEEDED_60_MIN: Percentage of results exceeding 60 minutes
*/


SELECT
  p.ID AS MRN,
  o.ID AS ORDER_ID,
  tr.GROUP_TEST_ID AS GROUP_TEST,
  ot.CLINIC_ID AS ORDERING_CLINIC,
  tr.TESTING_WORKSTATION_ID AS TESTING_WORKSTATION,
  TO_CHAR(ot.ORDERING_DT, 'YYYYMMDD HH24:MI:SS') AS ORDERED_DT,
  TO_CHAR(tr.COLLECT_DT, 'YYYYMMDD HH24:MI:SS') AS COLLECTED_DT,
  TO_CHAR(tr.RECEIVE_DT, 'YYYYMMDD HH24:MI:SS') AS RECEIVED_DT,
  TO_CHAR(tr.VERIFIED_DT, 'YYYYMMDD HH24:MI:SS') AS VERIFIED_DT,
  ROUND((tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440, 2) AS RECEIVE_TO_VERIFY_MIN,
  COUNT(*) OVER () AS TOTAL_SAMPLES,
  SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 > 45 THEN 1 ELSE 0 END) OVER () AS EXCEEDED_45_MIN,
  ROUND(
    SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 > 45 THEN 1 ELSE 0 END) OVER ()
    / COUNT(*) OVER () * 100, 2
  ) AS PCT_EXCEEDED_45_MIN,
  SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 > 60 THEN 1 ELSE 0 END) OVER () AS EXCEEDED_60_MIN,
  ROUND(
    SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 > 60 THEN 1 ELSE 0 END) OVER ()
    / COUNT(*) OVER () * 100, 2
  ) AS PCT_EXCEEDED_60_MIN
FROM V_P_LAB_TEST_RESULT tr
JOIN V_P_LAB_ORDER o ON o.AA_ID = tr.ORDER_AA_ID
JOIN V_P_LAB_STAY s ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p ON p.AA_ID = s.PATIENT_AA_ID
JOIN V_P_LAB_ORDERED_TEST ot ON ot.ORDER_AA_ID = tr.ORDER_AA_ID
                             AND ot.TEST_ID = tr.GROUP_TEST_ID
                             AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
WHERE tr.GROUP_TEST_ID IN ('FXAUF', 'FXALM')
  AND tr.PRIORITY = 'S'
  AND tr.STATE IN ('Final', 'Corrected')
  AND tr.RECEIVE_DT IS NOT NULL
  AND tr.VERIFIED_DT IS NOT NULL
  AND TRUNC(ot.ORDERING_DT) BETWEEN TO_DATE(:START_DATE, 'YYYYMMDD')
                                AND TO_DATE(:END_DATE, 'YYYYMMDD')
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
ORDER BY ot.ORDERING_DT DESC;
