-- Reference Lab Send-Outs: Track tests sent to external reference labs
-- This shows items actually sent out to reference labs for testing
-- Oracle 19c compatible

-- *** ADJUST TIMEFRAME HERE ***
-- Change the date filter in the WHERE clause below (currently set to last 30 days)
-- Examples:
--   Last 7 days:     AND tr.TEST_DT >= SYSDATE - 7
--   Last 90 days:    AND tr.TEST_DT >= SYSDATE - 90
--   Specific date:   AND tr.TEST_DT >= TO_DATE('2025-01-01', 'YYYY-MM-DD')

SELECT
    -- Order Info
    o.ID AS order_id,
    o.ORDERED_DT,

    -- Patient Info
    p.ID AS mrn,
    p.LAST_NAME,
    p.FIRST_NAME,

    -- Test Info
    tr.TEST_ID,
    tr.GROUP_TEST_ID,
    tr.STATE AS result_state,

    -- Reference Lab Info
    tr.REFERENCE_LAB_ID,
    ref_loc.NAME AS reference_lab_name,
    tr.PERFORMING_LAB,

    -- Performing Location Info
    tr.TEST_PERFORMING_LOCATION,
    perf_loc.NAME AS performing_location_name,
    tr.TEST_PERFORMING_DEPT,

    -- Dates
    tr.COLLECT_DT,
    tr.RECEIVE_DT,
    tr.TEST_DT,
    tr.VERIFIED_DT,

    -- Specimen Info
    tr.SPECIMEN_TYPE

FROM V_P_LAB_TEST_RESULT tr

-- Join to order
JOIN V_P_LAB_ORDER o ON tr.ORDER_AA_ID = o.AA_ID

-- Join to patient via stay
JOIN V_P_LAB_STAY s ON o.STAY_AA_ID = s.AA_ID
JOIN V_P_LAB_PATIENT p ON s.PATIENT_AA_ID = p.AA_ID

-- Location lookups
LEFT JOIN V_S_LAB_LOCATION ref_loc ON tr.REFERENCE_LAB_ID = ref_loc.ID
LEFT JOIN V_S_LAB_LOCATION perf_loc ON tr.TEST_PERFORMING_LOCATION = perf_loc.ID

WHERE
    -- Only real patients
    REGEXP_LIKE(p.ID, '^E[0-9]+$')

    -- Tests sent to reference lab
    AND tr.PERFORMING_LAB = 'Y'
    AND tr.REFERENCE_LAB_ID IS NOT NULL

    -- Exclude internal labs (THST is TUH Immunogenetics, not external)
    AND tr.REFERENCE_LAB_ID NOT IN ('THST')

    -- Last 30 days
    AND tr.TEST_DT >= SYSDATE - 30

ORDER BY
    tr.TEST_DT DESC

FETCH FIRST 100 ROWS ONLY;

-- Notes:
-- 1. PERFORMING_LAB = 'Y' means test was performed at reference lab
-- 2. REFERENCE_LAB_ID identifies which external lab did the testing
-- 3. This is the actual send-out workflow, not facility transfers
-- 4. To track facility-to-facility transfers, we may need different fields
