/*
Test Turn-Around Time (TAT) Analysis

Purpose: Track time intervals through the testing process from order to verification.

Parameters:
  :TEST_CODE  - Test code to analyze (e.g., 'CBC', 'BMP')
  :LOCATION   - Performing location code (e.g., 'MAIN', 'LAB1')
  :START_DATE - Start of date range in YYYYMMDD format (e.g., 20250101)
  :END_DATE   - End of date range in YYYYMMDD format (e.g., 20251231)

Example usage:
  DEFINE TEST_CODE = 'CBC'
  DEFINE LOCATION = 'MAIN'
  DEFINE START_DATE = 20250101
  DEFINE END_DATE = 20251231

Columns:
  - MRN: Medical record number
  - ORDER_ID: Order number
  - TEST_ID: Test code
  - ORDERING_CLINIC: Clinic/ward where test was ordered
  - PERFORMING_LOCATION: Location where test was performed
  - TESTING_WORKSTATION: Instrument/workstation that ran the test
  - ORDERED_DT: When test was ordered
  - COLLECTED_DT: When specimen was collected
  - RECEIVED_DT: When specimen was received in lab
  - TESTED_DT: When instrument ran the test
  - VERIFIED_DT: When result was verified
  - ORDER_TO_COLLECT_MIN: Minutes from order to collection
  - COLLECT_TO_RECEIVE_MIN: Minutes from collection to lab receipt
  - RECEIVE_TO_TEST_MIN: Minutes from receipt to instrument run
  - TEST_TO_VERIFY_MIN: Minutes from instrument run to verification
  - TOTAL_TAT_MIN: Total minutes from order to verification
*/


SELECT
  p.ID AS MRN,
  o.ID AS ORDER_ID,
  tr.TEST_ID,
  ot.CLINIC_ID AS ORDERING_CLINIC,
  tr.TEST_PERFORMING_LOCATION AS PERFORMING_LOCATION,
  tr.TESTING_WORKSTATION_ID AS TESTING_WORKSTATION,
  TO_CHAR(ot.ORDERING_DT, 'YYYYMMDD HH24:MI:SS') AS ORDERED_DT,
  TO_CHAR(tr.COLLECT_DT, 'YYYYMMDD HH24:MI:SS') AS COLLECTED_DT,
  TO_CHAR(tr.RECEIVE_DT, 'YYYYMMDD HH24:MI:SS') AS RECEIVED_DT,
  TO_CHAR(tr.TEST_DT, 'YYYYMMDD HH24:MI:SS') AS TESTED_DT,
  TO_CHAR(tr.VERIFIED_DT, 'YYYYMMDD HH24:MI:SS') AS VERIFIED_DT,
  ROUND((tr.COLLECT_DT - ot.ORDERING_DT) * 1440, 2) AS ORDER_TO_COLLECT_MIN,
  ROUND((tr.RECEIVE_DT - tr.COLLECT_DT) * 1440, 2) AS COLLECT_TO_RECEIVE_MIN,
  ROUND((tr.TEST_DT - tr.RECEIVE_DT) * 1440, 2) AS RECEIVE_TO_TEST_MIN,
  ROUND((tr.VERIFIED_DT - tr.TEST_DT) * 1440, 2) AS TEST_TO_VERIFY_MIN,
  ROUND((tr.VERIFIED_DT - ot.ORDERING_DT) * 1440, 2) AS TOTAL_TAT_MIN
FROM V_P_LAB_TEST_RESULT tr
JOIN V_P_LAB_ORDER o ON o.AA_ID = tr.ORDER_AA_ID
JOIN V_P_LAB_STAY s ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p ON p.AA_ID = s.PATIENT_AA_ID
JOIN V_P_LAB_ORDERED_TEST ot ON ot.ORDER_AA_ID = tr.ORDER_AA_ID
                             AND ot.TEST_ID = tr.GROUP_TEST_ID
                             AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
WHERE tr.GROUP_TEST_ID = :TEST_CODE
  AND tr.TEST_PERFORMING_LOCATION = :LOCATION
  AND tr.STATE IN ('Final', 'Corrected')  -- Only finalized results
  AND TRUNC(ot.ORDERING_DT) BETWEEN TO_DATE(:START_DATE, 'YYYYMMDD')
                                AND TO_DATE(:END_DATE, 'YYYYMMDD')
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')  -- Valid MRNs only
ORDER BY ot.ORDERING_DT DESC;