/*
CSN (Epic Encounter Number) Check

Purpose: Search MISCEL_INFO for any CSN or encounter-related data
         sent from Epic. Lists all distinct SUB_ID labels with
         sample values so we can identify if/where the CSN lands.

Usage: Run as-is. Look for SUB_ID values like 'CSN', 'Encounter', etc.
*/

SELECT
  m.SUB_ID,
  m.VALUE,
  m.OWNER_ID,
  m.PATIENT_DATA,
  m.STAY_DATA,
  m.ORDER_DATA,
  TO_CHAR(m.ADD_DT, 'YYYY-MM-DD HH24:MI') AS ADD_DT,
  p.ID                              AS MRN,
  s.BILLING                         AS STAY_BILLING,
  o.ID                              AS ORDER_NUMBER
FROM V_P_LAB_MISCEL_INFO m
JOIN V_P_LAB_STAY s      ON s.BILLING = m.OWNER_ID
JOIN V_P_LAB_PATIENT p   ON s.PATIENT_AA_ID = p.AA_ID
JOIN V_P_LAB_ORDER o     ON o.STAY_AA_ID = s.AA_ID
WHERE o.ORDERED_DT >= SYSDATE - 1
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
  AND ROWNUM <= 200
ORDER BY m.SUB_ID, m.ADD_DT DESC;
