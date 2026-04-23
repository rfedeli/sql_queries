-- ABG/VBG Report: Order, collection, receive, and result times
-- Runs Jan 1 through today
-- One row per order, sorted by facility
-- Oracle 19c compatible

SELECT
    CASE cc.SITE
        WHEN 'TUH'   THEN 'Temple University Hospital'
        WHEN 'JNS'   THEN 'Jeanes Hospital'
        WHEN 'CH'    THEN 'Chestnut Hill Hospital'
        WHEN 'EPC'   THEN 'Episcopal Hospital'
        WHEN 'FC'    THEN 'Fox Chase Cancer Center'
        WHEN 'WFH'   THEN 'Women and Families Hospital'
        ELSE cc.SITE
    END AS FACILITY,
    o.ID AS ORDER_ID,
    p.ID AS MRN,
    p.LAST_NAME,
    p.FIRST_NAME,
    tr.GROUP_TEST_ID AS TEST,
    o.ORDERED_DT AS ORDER_TIME,
    tr.COLLECT_DT AS COLLECT_TIME,
    tr.RECEIVE_DT AS RECEIVE_TIME,
    tr.VERIFIED_DT AS RESULT_TIME,
    o.PRIORITY,
    o.ORDERING_CLINIC_ID AS CLINIC
FROM V_P_LAB_ORDER o
    JOIN V_P_LAB_TEST_RESULT tr ON tr.ORDER_AA_ID = o.AA_ID
    JOIN V_P_LAB_STAY s ON s.AA_ID = o.STAY_AA_ID
    JOIN V_P_LAB_PATIENT p ON p.AA_ID = s.PATIENT_AA_ID
    LEFT JOIN V_S_LAB_COLL_CENTER cc ON cc.ID = o.COLLECT_CENTER_ID
WHERE tr.GROUP_TEST_ID IN ('ABG', 'VBG')
    AND tr.STATE IN ('Final', 'Corrected')
    AND tr.RESULT <> '.'
    AND o.ORDERED_DT >= TO_DATE('2026-01-01', 'YYYY-MM-DD')
    AND o.ORDERED_DT <  TRUNC(SYSDATE) + 1
    AND REGEXP_LIKE(p.ID, '^E[0-9]+$')
GROUP BY
    cc.SITE,
    o.ID,
    p.ID,
    p.LAST_NAME,
    p.FIRST_NAME,
    tr.GROUP_TEST_ID,
    o.ORDERED_DT,
    tr.COLLECT_DT,
    tr.RECEIVE_DT,
    tr.VERIFIED_DT,
    o.PRIORITY,
    o.ORDERING_CLINIC_ID
ORDER BY
    cc.SITE,
    o.ORDERED_DT
