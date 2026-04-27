/* Coagulation Specimen Report
   Produces: Order ID, Specimen ID (barcode), Collected/Received/Verified
             date+time, Test name, Ordering location, Method (workstation), Priority
   Parameters: :start_date — begin date inclusive (YYYYMMDD)
               :end_date   — end date inclusive (YYYYMMDD)
*/
WITH result_data AS (
    SELECT
        o.ID                                                    AS order_id,
        tr.AA_ID                                                AS result_aa_id,
        tr.COLLECT_DT,
        tr.RECEIVE_DT,
        tr.VERIFIED_DT,
        tr.GROUP_TEST_ID,
        tr.TESTING_WORKSTATION_ID,
        tr.PRIORITY,
        ot.CLINIC_ID,
        ROW_NUMBER() OVER (
            PARTITION BY tr.ORDER_AA_ID, tr.GROUP_TEST_ID, tr.ORDERING_WORKSTATION_ID
            ORDER BY tr.TEST_ID
        )                                                       AS rn
    FROM V_P_LAB_TEST_RESULT tr
        JOIN V_P_LAB_ORDER o
            ON o.AA_ID = tr.ORDER_AA_ID
        JOIN V_P_LAB_ORDERED_TEST ot
            ON  ot.ORDER_AA_ID    = tr.ORDER_AA_ID
            AND ot.TEST_ID        = tr.GROUP_TEST_ID
            AND ot.WORKSTATION_ID = tr.ORDERING_WORKSTATION_ID
    WHERE ot.CANCELLED_FLAG  = 0
      AND tr.STATE           IN ('Final', 'Verified', 'Corrected')
      AND tr.COLLECT_DT      IS NOT NULL
      AND tr.RECEIVE_DT      IS NOT NULL
      AND tr.VERIFIED_DT     IS NOT NULL
      AND tr.TESTING_WORKSTATION_ID IN (
            SELECT ws.ID FROM V_S_LAB_WORKSTATION ws
              JOIN V_S_LAB_DEPARTMENT d ON d.ID = ws.DEPARTMENT_ID
            WHERE UPPER(d.NAME) LIKE '%COAG%'
              AND ws.LOCATION_ID = 'TUH'
          )
      AND tr.VERIFIED_DT >= TO_DATE(:start_date, 'YYYYMMDD')
      AND tr.VERIFIED_DT <  TO_DATE(:end_date,   'YYYYMMDD') + 1
)
SELECT
    rd.order_id,
    (SELECT MIN(sb.CODE)
       FROM V_P_LAB_TEST_TO_TUBE  ttt
       JOIN V_P_LAB_SPECIMEN_BARCODE sb
            ON  sb.TUBE_AA_ID = ttt.TUBE_AA_ID
            AND sb.CODE_TYPE  = 'B'
      WHERE ttt.RESULT_AA_ID = rd.result_aa_id
    )                                                           AS specimen_id,
    TO_CHAR(rd.COLLECT_DT,  'MM/DD/YYYY')                      AS collected_date,
    TO_CHAR(rd.COLLECT_DT,  'HH24:MI')                         AS collected_time,
    TO_CHAR(rd.RECEIVE_DT,  'MM/DD/YYYY')                      AS received_date,
    TO_CHAR(rd.RECEIVE_DT,  'HH24:MI')                         AS received_time,
    TO_CHAR(rd.VERIFIED_DT, 'MM/DD/YYYY')                      AS verified_date,
    TO_CHAR(rd.VERIFIED_DT, 'HH24:MI')                         AS verified_time,
    COALESCE(
        (SELECT MIN(tg.GTNAME_UPPER) FROM V_S_LAB_TEST_GROUP tg WHERE tg.ID = rd.GROUP_TEST_ID),
        (SELECT MIN(t.NAME_UPPER)    FROM V_S_LAB_TEST t        WHERE t.ID  = rd.GROUP_TEST_ID)
    )                                                           AS test,
    rd.CLINIC_ID                                                AS order_loc,
    rd.TESTING_WORKSTATION_ID                                   AS method,
    DECODE(rd.PRIORITY, 'S','STAT', 'R','Routine', 'T','Timed', rd.PRIORITY) AS priority
FROM result_data rd
WHERE rd.rn = 1
ORDER BY rd.COLLECT_DT, rd.order_id