/*
Facility TAT Report — designed for WFH, parameterized for any facility.

One row per order + group test (orderable) with the four core timestamps:
  ORDDT    Test ordered (per-test, captures add-ons accurately)
  COLL_DT  Specimen collected
  REC_DT   Received in lab
  VERDT    Result verified

Group tests don't carry timestamps directly — they live on component-test
result rows. MAX collapses across components so each timestamp is the
"group complete" point (e.g., VERDT = when the last component verified).

TAT segments (in minutes):
  ORD_TO_COLL_MIN  Order placed → specimen collected
  COLL_TO_REC_MIN  Collected → received in lab
  REC_TO_VER_MIN   Received → verified
  TOTAL_TAT_MIN    Order placed → verified (overall)

Parameters (Grapecity parameter type = String, YYYYMMDD for dates):
  :START_DATE      Start of test-ordered date range, e.g. 20260101
  :END_DATE        End of test-ordered date range inclusive, e.g. 20260131
  :COLLECT_CENTER  Collect center code, supports LIKE wildcards:
                     'W1'  WFH inpatient
                     'W2'  WFH outpatient
                     'W%'  all WFH
                     'J%'  all Jeanes (J1 inpatient, J2 outpatient)
                     'T%'  all Temple
                     '%'   all facilities
*/

SELECT
  o.ID                    AS ORDNUM,
  tr.GROUP_TEST_ID        AS GTEST,
  o.PRIORITY              AS PRIORITY,
  MAX(ot.ORDERING_DT)     AS ORDDT,
  MAX(spt.COLLECTION_DT)  AS COLL_DT,
  MAX(tr.RECEIVE_DT)      AS REC_DT,
  MAX(tr.VERIFIED_DT)     AS VERDT,
  ROUND((MAX(spt.COLLECTION_DT) - MAX(ot.ORDERING_DT))    * 1440) AS ORD_TO_COLL_MIN,
  ROUND((MAX(tr.RECEIVE_DT)     - MAX(spt.COLLECTION_DT)) * 1440) AS COLL_TO_REC_MIN,
  ROUND((MAX(tr.VERIFIED_DT)    - MAX(tr.RECEIVE_DT))     * 1440) AS REC_TO_VER_MIN,
  ROUND((MAX(tr.VERIFIED_DT)    - MAX(ot.ORDERING_DT))    * 1440) AS TOTAL_TAT_MIN,
  o.COLLECT_CENTER_ID,
  p.ID                    AS MRN
FROM V_P_LAB_ORDER o
  INNER JOIN V_P_LAB_SPECIMEN_TUBE spt ON spt.ORDER_AA_ID  = o.AA_ID
  INNER JOIN V_P_LAB_TEST_RESULT tr   ON tr.ORDER_AA_ID    = o.AA_ID
  INNER JOIN V_P_LAB_ORDERED_TEST ot  ON ot.ORDER_AA_ID    = tr.ORDER_AA_ID
                                     AND ot.TEST_ID        = tr.GROUP_TEST_ID
                                     AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
  INNER JOIN V_P_LAB_STAY st          ON st.AA_ID          = o.STAY_AA_ID
  INNER JOIN V_P_LAB_PATIENT p        ON p.AA_ID           = st.PATIENT_AA_ID
  INNER JOIN V_S_LAB_DEPARTMENT d     ON d.ID              = tr.TEST_PERFORMING_DEPT
WHERE o.COLLECT_CENTER_ID LIKE :COLLECT_CENTER
  AND tr.STATE IN ('Final', 'Corrected')
  AND spt.IS_CANCELLED = 'N'
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')  -- Valid MRNs only
  AND d.NAME NOT IN ('BLOOD BANK', 'MICROBIOLOGY', 'REFERENCE LAB')
  AND tr.PERFORMING_LAB <> 'Y'
  AND NOT EXISTS (
    SELECT 1 FROM V_P_LAB_TEST_RESULT_HISTORY trhist
    WHERE trhist.ATEST_AA_ID = tr.AA_ID
  )
  AND ot.ORDERING_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND ot.ORDERING_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
GROUP BY o.ID, tr.GROUP_TEST_ID,
         o.PRIORITY, o.COLLECT_CENTER_ID, p.ID
ORDER BY ORDNUM;
