/*
TACR Turn-Around Time Summary — TUH Performing Location

Purpose: Evaluate received-to-verified TAT for Tacrolimus (TACR) at TUH.
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
  - ORDERING_CLINIC: Clinic/ward where test was ordered
  - TESTING_WORKSTATION: Instrument/workstation that ran the test
  - ORDERED_DT: When test was ordered
  - COLLECTED_DT: When specimen was collected
  - RECEIVED_DT: When specimen was received in lab
  - VERIFIED_DT: When result was verified
  - RECEIVE_TO_VERIFY_MIN: Minutes from receipt to verification

Summary Columns (same value on every row):
  - TOTAL_SAMPLES: Total number of verified TACR results
  - WITHIN_45_MIN: Count of results with receive-to-verify TAT <= 45 minutes
  - PCT_WITHIN_45_MIN: Percentage of results within 45 minutes
*/


SELECT
  p.ID AS MRN,
  o.ID AS ORDER_ID,
  ot.CLINIC_ID AS ORDERING_CLINIC,
  tr.TESTING_WORKSTATION_ID AS TESTING_WORKSTATION,
  TO_CHAR(ot.ORDERING_DT, 'YYYYMMDD HH24:MI:SS') AS ORDERED_DT,
  TO_CHAR(tr.COLLECT_DT, 'YYYYMMDD HH24:MI:SS') AS COLLECTED_DT,
  TO_CHAR(tr.RECEIVE_DT, 'YYYYMMDD HH24:MI:SS') AS RECEIVED_DT,
  TO_CHAR(tr.VERIFIED_DT, 'YYYYMMDD HH24:MI:SS') AS VERIFIED_DT,
  ROUND((tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440, 2) AS RECEIVE_TO_VERIFY_MIN,
  COUNT(*) OVER () AS TOTAL_SAMPLES,
  SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 <= 45 THEN 1 ELSE 0 END) OVER () AS WITHIN_45_MIN,
  ROUND(
    SUM(CASE WHEN (tr.VERIFIED_DT - tr.RECEIVE_DT) * 1440 <= 45 THEN 1 ELSE 0 END) OVER ()
    / COUNT(*) OVER () * 100, 2
  ) AS PCT_WITHIN_45_MIN
FROM V_P_LAB_TEST_RESULT tr
JOIN V_P_LAB_ORDER o ON o.AA_ID = tr.ORDER_AA_ID
JOIN V_P_LAB_STAY s ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p ON p.AA_ID = s.PATIENT_AA_ID
JOIN V_P_LAB_ORDERED_TEST ot ON ot.ORDER_AA_ID = tr.ORDER_AA_ID
                             AND ot.TEST_ID = tr.GROUP_TEST_ID
                             AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
WHERE tr.GROUP_TEST_ID = 'TACR'
  AND tr.TEST_PERFORMING_LOCATION = 'TUH'
  AND tr.STATE IN ('Final', 'Corrected')
  AND tr.RECEIVE_DT IS NOT NULL
  AND tr.VERIFIED_DT IS NOT NULL
  AND TRUNC(ot.ORDERING_DT) BETWEEN TO_DATE(:START_DATE, 'YYYYMMDD')
                                AND TO_DATE(:END_DATE, 'YYYYMMDD')
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
ORDER BY ot.ORDERING_DT DESC;
