/*
Cancelled tests — Jeanes Chemistry (JCHEM), weekly report.

One row per cancelled test result with patient, ward, doctor, and
cancellation reason. INNER joins V_P_LAB_CANCELLATION on the test result,
so only canceled results appear.

Excluded GROUP_TEST_IDs (VENIP, HEM, TUR, ICT) are workflow-only codes
that surface in the cancellation table but aren't real test cancellations
to report on.

Original query used a hardcoded "previous ISO week" range
(Trunc(SYSDATE,'IW')-7 → Trunc(SYSDATE,'IW')-1s). Parameterized here for
Grapecity scheduling flexibility — pass the Monday of the target week as
:start_date and the following Monday as :end_date (half-open).

Parameters (Grapecity parameter type = String, YYYYMMDD):
  :start_date - Monday of target week, e.g. 20260420
  :end_date   - Following Monday (exclusive), e.g. 20260427
*/

SELECT DISTINCT
  pt.ID                                                       AS MRN,
  pt.LAST_NAME || ',' || pt.FIRST_NAME                        AS PT_NAME,
  st.BILLING                                                  AS BILLING,
  ord.ID                                                      AS ORD,
  ord.ORDERING_CLINIC_ID                                      AS WARD,
  tr.GROUP_TEST_ID                                            AS TEST,
  tr.TEST_PERFORMING_DEPT                                     AS DEPT,
  ord.ORDERED_DT                                              AS ORD_DTTM,
  tr.COLLECT_DT                                               AS COLLECT_DTTM,
  tr.RECEIVE_DT                                               AS RECEIVE_DTTM,
  tr.VERIFIED_DT                                              AS VERIFIED_DTTM,
  pcanc.CANCELLATION_DT                                       AS CANC_DTTM,
  pcanc.REASON                                                AS REASON,
  sdoc.LAST_NAME || ',' || sdoc.FIRST_NAME                    AS DOC_NAME,
  ord.COLLECT_CENTER_ID                                       AS DEPOT,
  TO_CHAR(TO_DATE(:start_date, 'YYYYMMDD'),       'MM/DD/YYYY') AS SDATE,
  TO_CHAR(TO_DATE(:end_date,   'YYYYMMDD') - 1,   'MM/DD/YYYY') AS EDATE
FROM V_P_LAB_PATIENT pt
  INNER JOIN V_P_LAB_STAY st             ON st.PATIENT_AA_ID         = pt.AA_ID
  INNER JOIN V_P_LAB_ORDER ord           ON ord.STAY_AA_ID           = st.AA_ID
  INNER JOIN V_P_LAB_TEST_RESULT tr      ON tr.ORDER_AA_ID           = ord.AA_ID
  INNER JOIN V_S_LAB_DOCTOR sdoc         ON sdoc.ID                  = ord.REQUESTING_DOCTOR_ID
  INNER JOIN V_P_LAB_CANCELLATION pcanc  ON pcanc.TEST_RESULT_AA_ID  = tr.AA_ID
WHERE ord.ORDERING_CLINIC_ID LIKE 'J%'
  AND tr.GROUP_TEST_ID NOT IN ('VENIP', 'HEM', 'TUR', 'ICT')
  AND tr.TEST_PERFORMING_DEPT IN ('JCHEM')
  AND ord.ORDERED_DT >= TO_DATE(:start_date, 'YYYYMMDD')
  AND ord.ORDERED_DT <  TO_DATE(:end_date,   'YYYYMMDD')
  AND REGEXP_LIKE(pt.ID, '^E[0-9]+$')
ORDER BY pcanc.CANCELLATION_DT DESC;
