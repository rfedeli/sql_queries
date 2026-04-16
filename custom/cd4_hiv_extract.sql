-- Patient demographics + results extract for CD4 (TFLOW), HIVPC, HIVGN (TMOL)
-- Adjust date window as needed.
SELECT
    o.ID                    AS ACCESSION_NUMBER,
    p.LAST_NAME,
    p.FIRST_NAME,
    p.DOB_DT                AS DOB,
    p.RACE,
    p.SEX,
    TRIM(p.STREET_LINE1 || ' ' || p.STREET_LINE2) AS STREET,
    p.CITY,
    NULL                    AS COUNTY,  -- not stored on V_P_LAB_PATIENT
    p.STATE,
    p.ZIP,
    p.TEL                   AS PHONE,
    TO_CHAR(tr.COLLECT_DT,'MM/DD/YYYY') || ' / ' || TO_CHAR(tr.COLLECT_DT,'HH24:MI') AS CDATE_CTIME,
    tst.NAME                AS TEST_NAME,
    tr.TEST_ID              AS TEST_CODE,
    tr.GROUP_TEST_ID        AS GROUP_TEST_CODE,
    tr.RESULT,
    tr.UNITS
FROM V_P_LAB_TEST_RESULT tr
JOIN V_P_LAB_ORDER       o   ON o.AA_ID = tr.ORDER_AA_ID
JOIN V_P_LAB_STAY        st  ON st.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT     p   ON p.AA_ID = st.PATIENT_AA_ID
LEFT JOIN (SELECT ID, MIN(NAME) AS NAME
             FROM V_S_LAB_TEST
            WHERE ID IN ('CD4P','CD4A','HIVPC','PROIN','NURTI','NONRT','INTGI')
            GROUP BY ID) tst
       ON tst.ID = tr.TEST_ID
WHERE tr.TEST_ID IN ('CD4P','CD4A','HIVPC','PROIN','NURTI','NONRT','INTGI')
  AND tr.STATE IN ('Final','Verified','Corrected')
  AND o.COLLECT_DT BETWEEN TO_DATE(:startdate,'YYYYMMDD')
                       AND TO_DATE(:enddate,'YYYYMMDD') + 1 - (1/86400)
  AND p.SEX = 'F'
ORDER BY tr.COLLECT_DT, o.ID, tst.NAME;
