/*
VBG orders — multi-facility, classified by HL7 OBR[11].

One row per order with order/collection/receipt/result timestamps and a
nurse-vs-lab collect classification from V_P_LAB_SPECIMEN.NURSE_COLL (LIS
storage of HL7 OBR[11]). Per SCC docs (KB 13803, KB 23096), OBR[11]='O' means
nurse-collect (NURSE_COLL=1), 'L' means lab/phleb-collect (NURSE_COLL=0).
Validated populated on every ABG/VBG specimen in the sample we checked.

Watch the 'Unknown' count: if it starts appearing on rows where it didn't
before, that's the signal that the OBR[11] feed broke for some orders.

Component collapsing:
  V_P_LAB_TEST_RESULT has one row per component (pH, pCO2, pO2, HCO3...).
  GROUP BY order-level fields + MAX of timestamps collapses to one row per
  order. MAX(VERIFIED_DT) = when the last component was verified.

Parameters (Grapecity parameter type = String, YYYYMMDD):
  :START_DATE - Start of collection-date range, e.g. 20260101
  :END_DATE   - End of collection-date range inclusive, e.g. 20260131
*/

WITH order_intent AS (
  -- Per-order OBR[11] flag from V_P_LAB_SPECIMEN.NURSE_COLL.
  -- An order may have multiple tubes/specimens; MAX collapses to one value
  -- per order (validated as consistent within ABG/VBG orders).
  SELECT
    tu.ORDER_AA_ID,
    MAX(sp.NURSE_COLL) AS NURSE_COLL
  FROM V_P_LAB_TUBE tu
  JOIN V_P_LAB_SPECIMEN sp ON sp.AA_ID = tu.SPECIMEN_AA_ID
  WHERE sp.COLLECTION_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
    AND sp.COLLECTION_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
  GROUP BY tu.ORDER_AA_ID
)
SELECT
  c.ORD_LOCATION_ID    AS FACILITY,
  o.ID                 AS ORDER_ID,
  p.ID                 AS MRN,
  p.LAST_NAME,
  p.FIRST_NAME,
  ot.TEST_ID           AS TEST,
  ot.ORDERING_DT       AS ORDER_TIME,
  MAX(tr.COLLECT_DT)   AS COLLECT_TIME,
  MAX(tr.RECEIVE_DT)   AS RECEIVE_TIME,
  MAX(tr.VERIFIED_DT)  AS RESULT_TIME,
  ot.PRIORITY,
  ti.COLLECTION_PHLEB  AS COLLECTOR_ID,
  CASE
    WHEN oi.NURSE_COLL = 1 THEN 'Nurse'
    WHEN oi.NURSE_COLL = 0 THEN 'Phleb'
    ELSE 'Unknown'
  END                  AS COLLECT_BY
FROM V_P_LAB_ORDERED_TEST ot
JOIN V_P_LAB_ORDER o           ON o.AA_ID = ot.ORDER_AA_ID
JOIN V_P_LAB_STAY s            ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p         ON p.AA_ID = s.PATIENT_AA_ID
JOIN V_P_LAB_TEST_RESULT tr    ON tr.ORDER_AA_ID = ot.ORDER_AA_ID
                              AND tr.GROUP_TEST_ID = ot.TEST_ID
                              AND tr.ORDERING_WORKSTATION_ID = ot.WORKSTATION_ID
JOIN V_S_LAB_CLINIC c          ON c.ID = ot.CLINIC_ID
LEFT JOIN order_intent oi      ON oi.ORDER_AA_ID = ot.ORDER_AA_ID
LEFT JOIN V_P_LAB_TUBEINFO ti  ON ti.ORDER_ID = o.ID
WHERE ot.TEST_ID = 'VBG'
  AND ot.CANCELLED_FLAG = 0
  AND tr.STATE IN ('Final', 'Corrected')
  AND tr.COLLECT_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND tr.COLLECT_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
GROUP BY
  c.ORD_LOCATION_ID,
  o.ID,
  p.ID,
  p.LAST_NAME,
  p.FIRST_NAME,
  ot.TEST_ID,
  ot.ORDERING_DT,
  ot.PRIORITY,
  ti.COLLECTION_PHLEB,
  oi.NURSE_COLL
ORDER BY MAX(tr.COLLECT_DT);