-- Urine Specific Gravity results > 1.040
-- Pulls order demographics and result comment for review
SELECT
  p.ID                    AS MRN,
  p.LAST_NAME,
  p.FIRST_NAME,
  o.ID                    AS ORDER_NUM,
  o.ORDERING_CLINIC_ID    AS ORDERING_CLINIC,
  o.REQUESTING_DOCTOR_ID  AS REQ_DOCTOR,
  tr.RESULT,
  tr.COLLECT_DT,
  TO_CHAR(tr.RESULT) AS RESULT_CHAR,
  tr.VERIFIED_DT,
  REGEXP_REPLACE(
    REGEXP_REPLACE(DBMS_LOB.SUBSTR(tr.COMMENTS, 4000), '\\[a-z0-9]+', ''),
    '[{}]', ''
  ) AS COMMENTS
FROM V_P_LAB_TEST_RESULT tr
  INNER JOIN V_P_LAB_ORDER o ON o.AA_ID = tr.ORDER_AA_ID
  INNER JOIN V_P_LAB_STAY st ON st.AA_ID = o.STAY_AA_ID
  INNER JOIN V_P_LAB_PATIENT p ON p.AA_ID = st.PATIENT_AA_ID
WHERE tr.TEST_ID = 'USPG'
  AND tr.STATE IN ('Final', 'Corrected')
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
  AND o.COLLECT_CENTER_ID LIKE 'T%'
  AND tr.VERIFIED_DT BETWEEN TO_DATE(:start_date, 'YYYYMMDD') AND TO_DATE(:end_date, 'YYYYMMDD') + 0.999999
ORDER BY tr.VERIFIED_DT DESC;
