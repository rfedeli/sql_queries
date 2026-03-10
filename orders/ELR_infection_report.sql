SELECT DISTINCT SOFII.PTNAME, SOFII.MRN, Max(SOFII.ORDNUM) AS ORDNUM,
  Max(SOFII.RECDT) AS RECDT, Max(SOFII.VERDT) AS VERDT, Max(SOFII.TESTID)
  AS TESTID, SOFII.TESTNAME AS TESTNAME, SOFII.RESULT AS RESULT, Max(SOFII.COLLDT)
  AS COLLDT, Max(SOFII.RECDATE) AS RECDATE, Max(SOFII.TCRECDATE) AS TCRECDATE,
  TO_CHAR(trunc(last_day(add_months(sysdate, -%Month_1%))) + (23 / 24),
  'MM/DD/YYYY') AS SDATE, TO_CHAR(trunc(last_day(add_months(sysdate,
  -%Month_2%))) + (23 / 24), 'MM/DD/YYYY') AS EDATE
FROM (SELECT DISTINCT AU.PTNAME, AU.MRN, Max(AU.ORDNUM) AS ORDNUM,
      Max(AU.COLLDT) AS COLLDT, Max(AU.RECDT) AS RECDT, Max(AU.RECDATE) AS
      RECDATE, Max(AU.TCRECDATE) AS TCRECDATE, Max(AU.VERDT) AS VERDT,
      AU.TESTID, AU.TESTNAME, AU.RESULT, AU.ORDERED_DATE
    FROM (SELECT CONCAT(CONCAT(pt.LAST_NAME, ','), pt.FIRST_NAME) AS PTNAME,
          pt.ID AS MRN, o.ID AS ORDNUM, otst.COLLECTED_DT AS COLLDT,
          otst.RECEIVED_DT AS RECDT, otst.RECEIVED_DATE AS RECDATE,
          TO_CHAR(otst.RECEIVED_DT, 'YYYYMMDD') AS TCRECDATE, tr.VERIFIED_DT AS
          VERDT, tr.TEST_ID AS TESTID, tr.TEST_NAME AS TESTNAME, tr.RESULT AS
          RESULT, o.ORDERED_DATE
        FROM lab.lab.V_P_LAB_PATIENT pt INNER JOIN
          lab.lab.V_P_LAB_STAY st ON st.PATIENT_AA_ID = pt.AA_ID INNER JOIN
          lab.lab.V_P_LAB_ORDER o ON o.STAY_AA_ID = st.AA_ID INNER JOIN
          lab.lab.V_P_LAB_ORDERED_TEST otst ON otst.ORDER_AA_ID = o.AA_ID
          INNER JOIN
          lab.lab.V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = o.AA_ID
        WHERE otst.RECEIVED_DT BETWEEN trunc(last_day(add_months(sysdate,
          -%Month_1%))) + (23 / 24) AND trunc(last_day(add_months(sysdate,
          -%Month_2%))) + (23 / 24) AND tr.TEST_ID IN ('SARSR','FLASR'.'FLBSR') AND
          NOT tr.RESULT = '.') AU
    GROUP BY AU.PTNAME, AU.MRN, AU.TESTID, AU.TESTNAME, AU.RESULT,
      AU.ORDERED_DATE
    HAVING Max(DISTINCT AU.RECDT) BETWEEN trunc(last_day(add_months(sysdate,
      -%Month_1%))) + (23 / 24) AND trunc(last_day(add_months(sysdate,
      -%Month_2%))) + (23 / 24)) SOFII
GROUP BY SOFII.PTNAME, SOFII.MRN, SOFII.TESTNAME, SOFII.RESULT,
  TO_CHAR(trunc(last_day(add_months(sysdate, -%Month_1%))) + (23 / 24),
  'MM/DD/YYYY'), TO_CHAR(trunc(last_day(add_months(sysdate, -%Month_2%))) +
  (23 / 24), 'MM/DD/YYYY')
ORDER BY Max(SOFII.ORDNUM), Max(SOFII.TESTID)