/*
ABG/VBG results ordered from CICU.

One row per order with the four core timestamps. Filter is clinic NAME LIKE
'%CICU%' so it catches whatever the actual clinic code happens to be — adjust
if you have a specific code in mind.

Parameters (Grapecity parameter type = String, YYYYMMDD):
  :START_DATE - Start of ordering-date range, e.g. 20250101
  :END_DATE   - End of ordering-date range inclusive, e.g. 20251231
*/

SELECT
  c.ID                AS CLINIC_ID,
  c.NAME              AS CLINIC_NAME,
  s.ROOM              AS ROOM,
  s.BED               AS BED,
  o.ID                AS ORDER_ID,
  p.ID                AS MRN,
  p.LAST_NAME,
  p.FIRST_NAME,
  ot.TEST_ID          AS TEST,
  ot.ORDERING_DT      AS ORDER_TIME,
  MAX(tr.COLLECT_DT)  AS COLLECT_TIME,
  MAX(tr.RECEIVE_DT)  AS RECEIVE_TIME,
  MAX(tr.VERIFIED_DT) AS RESULT_TIME,
  ot.PRIORITY
FROM V_P_LAB_ORDERED_TEST ot
JOIN V_P_LAB_ORDER o        ON o.AA_ID = ot.ORDER_AA_ID
JOIN V_P_LAB_STAY s         ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p      ON p.AA_ID = s.PATIENT_AA_ID
JOIN V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = ot.ORDER_AA_ID
                           AND tr.GROUP_TEST_ID = ot.TEST_ID
                           AND tr.ORDERING_WORKSTATION_ID = ot.WORKSTATION_ID
JOIN V_S_LAB_CLINIC c       ON c.ID = ot.CLINIC_ID
WHERE ot.TEST_ID IN ('VBG')
  AND ot.CANCELLED_FLAG = 0
  AND tr.STATE IN ('Final', 'Corrected')
  AND c.NAME LIKE '%CICU%'
  AND ot.ORDERING_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND ot.ORDERING_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
GROUP BY
  c.ID, c.NAME, s.ROOM, s.BED, o.ID, p.ID, p.LAST_NAME, p.FIRST_NAME,
  ot.TEST_ID, ot.ORDERING_DT, ot.PRIORITY
ORDER BY ot.ORDERING_DT;