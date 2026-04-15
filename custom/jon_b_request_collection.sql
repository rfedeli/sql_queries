/*  Overnight specimens (11PM–5AM) collected & received
    Jeanes + FCCC, Q1 2026
    Requested by Jon B
*/
SELECT DISTINCT
    o.ID                                     AS accession_number,
    sb.CODE                                  AS barcode,
    s.COLLECTION_LOCATION,
    o.ORDERING_CLINIC_ID                     AS unit_location,
    cl.NAME                                  AS unit_name,
    tr.GROUP_TEST_ID                         AS test_id,
    NVL(tg.GTNAME_UPPER, ts.NAME_UPPER)     AS test_name,
    s.COLLECTION_DT                          AS collection_time,
    ti.COLLECTION_PHLEB                      AS collected_by,
    t.RECEIPT_DT                             AS received_time
FROM V_P_LAB_SPECIMEN s
JOIN V_P_LAB_TUBE t
    ON t.SPECIMEN_AA_ID = s.AA_ID
JOIN V_P_LAB_ORDER o
    ON o.AA_ID = t.ORDER_AA_ID
JOIN V_P_LAB_TEST_TO_TUBE ttt
    ON ttt.TUBE_AA_ID = t.AA_ID
JOIN V_P_LAB_TEST_RESULT tr
    ON tr.AA_ID = ttt.RESULT_AA_ID
LEFT JOIN V_S_LAB_TEST_GROUP tg
    ON tg.ID = tr.GROUP_TEST_ID
LEFT JOIN V_S_LAB_TEST ts
    ON ts.ID = tr.GROUP_TEST_ID
   AND tg.ID IS NULL
LEFT JOIN V_P_LAB_TUBEINFO ti
    ON ti.ORDER_ID = o.ID
   AND ti.TUBE_TYPE = t.TUBE_TYPE
JOIN V_P_LAB_SPECIMEN_BARCODE sb
    ON sb.TUBE_AA_ID = t.AA_ID
   AND sb.CODE_TYPE  = 'B'
LEFT JOIN V_S_LAB_CLINIC cl
    ON cl.ID = o.ORDERING_CLINIC_ID
WHERE NVL(s.COLLECTION_LOCATION, o.COLLECT_CENTER_ID) IN ('J1','J2','F1','F2')
  AND s.IS_COLLECTED   = 'Y'
  /* back up 1 day to catch 11PM collections on the night before */
  AND s.COLLECTION_DT >= TO_DATE('2025-12-31 23:00','YYYY-MM-DD HH24:MI')
  AND s.COLLECTION_DT <  TO_DATE('2026-04-01','YYYY-MM-DD')
  AND (   TO_CHAR(s.COLLECTION_DT, 'HH24') >= '23'
       OR TO_CHAR(s.COLLECTION_DT, 'HH24') <  '05')
  AND t.RECEIPT_DT IS NOT NULL
  AND (   TO_CHAR(t.RECEIPT_DT, 'HH24') >= '23'
       OR TO_CHAR(t.RECEIPT_DT, 'HH24') <  '05')
ORDER BY s.COLLECTION_DT, o.ID, sb.CODE
