-- Test volumes for 2025 grouped by resulting (performing) department.
-- Uses V_P_LAB_TEST_RESULT.TEST_PERFORMING_DEPT and VERIFIED_DT.
SELECT
    tr.TEST_PERFORMING_DEPT        AS DEPT_CODE,
    d.NAME                         AS DEPT_NAME,
    d.LOCATION_ID                  AS FACILITY,
    tr.TEST_ID,
    t.NAME                         AS TEST_NAME,
    COUNT(*)                       AS RESULT_COUNT
FROM V_P_LAB_TEST_RESULT tr
LEFT JOIN V_S_LAB_DEPARTMENT d ON d.ID = tr.TEST_PERFORMING_DEPT
LEFT JOIN V_S_LAB_TEST       t ON t.ID = tr.TEST_ID
WHERE tr.VERIFIED_DT >= TO_DATE('2025-01-01','YYYY-MM-DD')
  AND tr.VERIFIED_DT <  TO_DATE('2026-01-01','YYYY-MM-DD')
  AND tr.STATE IN ('Final','Verified','Corrected')
GROUP BY
    tr.TEST_PERFORMING_DEPT,
    d.NAME,
    d.LOCATION_ID,
    tr.TEST_ID,
    t.NAME
ORDER BY d.LOCATION_ID, d.NAME, RESULT_COUNT DESC;
