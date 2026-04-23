-- FCCC Manual Dilution Report: Orders with MDO test result 'MANUAL' at Fox Chase outpatient
-- Parameters: :Month_1 and :Month_2 define the date range as months ago
--   e.g., Month_1 = 2, Month_2 = 1 gives the window from end of 2 months ago to end of last month
-- Oracle 19c compatible

SELECT
    o.ID AS ID,
    o.ORDERING_CLINIC_ID AS ORDERING_CLINIC_ID,
    tr.TEST_ID AS TEST_ID,
    tr.RESULT AS RESULT,
    o.COLLECT_CENTER_ID AS COLLECT_CENTER_ID,
    TO_CHAR(TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -:Month_1))) + (23/24), 'MM/DD/YYYY') AS SDATE,
    TO_CHAR(TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -:Month_2))) + (23/24), 'MM/DD/YYYY') AS EDATE
FROM V_P_LAB_ORDER o
    JOIN V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = o.AA_ID
WHERE tr.TEST_ID = 'MDO'
    AND tr.RESULT = 'MANUAL'
    AND o.COLLECT_CENTER_ID = 'F2'
    AND o.ORDERED_DT BETWEEN TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -:Month_1))) + (23/24)
                           AND TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -:Month_2))) + (23/24)
ORDER BY o.ID
