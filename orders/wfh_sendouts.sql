-- WFH Send-Outs: Track specimens collected at Women and Families Hospital
-- Shows WFH specimens that were performed or sent out ELSEWHERE (not at WFH)
-- Aggregated by order and GROUP_TEST_ID to reduce duplication
-- Oracle 19c compatible

-- *** ADJUST DATE RANGE HERE ***
-- Format: YYYYMMDD

SELECT
    -- Order Info
    o.ID AS order_id,
    o.ORDERED_DT,

    -- Patient Info
    p.ID AS mrn,

    -- Test Info
    tr.GROUP_TEST_ID,
    MAX(tr.STATE) AS result_state,

    -- Ordering Location
    o.ORDERING_CLINIC_ID,
    o.COLLECT_CENTER_ID,

    -- Collection Info
    MAX(spec.COLLECTION_LOCATION) AS collection_location,
    MAX(spec.COLLECTION_DT) AS collection_dt,

    -- Performing Location Info
    MAX(tr.TEST_PERFORMING_LOCATION) AS test_performing_location,
    MAX(perf_loc.NAME) AS performing_location_name,
    MAX(tr.TEST_PERFORMING_DEPT) AS test_performing_dept,

    -- Reference Lab Info (if sent out)
    MAX(tr.REFERENCE_LAB_ID) AS reference_lab_id,

    -- Transit Tracking
    MAX(CASE WHEN tl.STATUS_DESCRIPTION = 'Transit' THEN 'Y' ELSE 'N' END) AS went_into_transit,

    -- Dates
    MIN(tr.RECEIVE_DT) AS receive_dt

FROM V_P_LAB_TEST_RESULT tr

-- Join to order
JOIN V_P_LAB_ORDER o ON tr.ORDER_AA_ID = o.AA_ID

-- Join to patient via stay
JOIN V_P_LAB_STAY s ON o.STAY_AA_ID = s.AA_ID
JOIN V_P_LAB_PATIENT p ON s.PATIENT_AA_ID = p.AA_ID

-- Join to specimen
LEFT JOIN V_P_LAB_SPECIMEN spec ON spec.PATIENT_AA_ID = p.AA_ID
    AND spec.COLLECTION_DT BETWEEN o.ORDERED_DT - 1 AND o.ORDERED_DT + 1

-- Join to tube for tracking
LEFT JOIN V_P_LAB_TUBE t ON t.ORDER_AA_ID = o.AA_ID

-- Join to tube location tracking
LEFT JOIN V_P_LAB_TUBE_LOCATION tl ON tl.TUBE_AA_ID = t.AA_ID

-- Location lookups
LEFT JOIN V_S_LAB_LOCATION perf_loc ON tr.TEST_PERFORMING_LOCATION = perf_loc.ID

WHERE
    -- Only real patients
    REGEXP_LIKE(p.ID, '^E[0-9]+$')

    -- Collected at Women and Families Hospital (W1 or W2)
    AND spec.COLLECTION_LOCATION IN ('W1', 'W2')

    -- NOT performed at WFH (exclude WFH from performing location)
    AND tr.TEST_PERFORMING_LOCATION NOT IN ('WFH')

    -- Exclude cancelled tests
    AND tr.STATE <> 'Canceled'

    -- Date range (using parameters above)
    AND tr.TEST_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
    AND tr.TEST_DT < TO_DATE(:END_DATE, 'YYYYMMDD') + 1

GROUP BY
    o.ID,
    o.ORDERED_DT,
    p.ID,
    o.ORDERING_CLINIC_ID,
    o.COLLECT_CENTER_ID,
    tr.GROUP_TEST_ID

ORDER BY
    MIN(tr.RECEIVE_DT) DESC,
    o.ID

-- Notes:
-- 1. Shows specimens collected at WFH (W1, W2) but performed elsewhere
-- 2. TEST_PERFORMING_LOCATION uses different codes than COLLECTION_LOCATION
--    - Collection uses: W1, W2 (inpatient, outpatient)
--    - Performing uses: WFH (facility code)
-- 3. Aggregated by order and GROUP_TEST_ID to reduce duplication (panels show as 1 row)
-- 4. PERFORMING_LAB = 'Y' means it was sent to an external reference lab
-- 5. receive_dt shows first time specimen was received in lab
