-- Complete Transfer Chain: Track specimens through facility transfers to reference labs
-- Shows: Origin Facility → Transfer Location → Final Destination
-- Oracle 19c compatible

-- *** ADJUST TIMEFRAME HERE ***
-- Currently set to last 30 days

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

    -- Transfer Chain
    perf_loc.SENDING_FACITILY AS origin_facility,

    tr.TEST_PERFORMING_LOCATION AS transfer_location_code,
    perf_loc.NAME AS transfer_location_name,

    perf_loc.RECEIVING_FACILITY AS final_destination,

    perf_loc.REF_LAB AS is_reference_lab,
    tr.PERFORMING_LAB AS performed_at_ref_lab,

    -- Additional Location Info
    tr.REFERENCE_LAB_ID,
    ref_loc.NAME AS reference_lab_name,

    -- Dates
    spec.COLLECTION_DT,
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

-- Join to specimen
LEFT JOIN V_P_LAB_SPECIMEN spec ON spec.PATIENT_AA_ID = p.AA_ID
    AND spec.COLLECTION_DT BETWEEN o.ORDERED_DT - 1 AND o.ORDERED_DT + 1
    AND spec.COLLECTION_DT >= SYSDATE - 30

-- Location lookups
LEFT JOIN V_S_LAB_LOCATION perf_loc ON tr.TEST_PERFORMING_LOCATION = perf_loc.ID
LEFT JOIN V_S_LAB_LOCATION ref_loc ON tr.REFERENCE_LAB_ID = ref_loc.ID

WHERE
    -- Only real patients
    REGEXP_LIKE(p.ID, '^E[0-9]+$')

    -- Only items that went through a transfer (have sending/receiving facility populated)
    AND (perf_loc.SENDING_FACITILY IS NOT NULL
         OR perf_loc.RECEIVING_FACILITY IS NOT NULL
         OR perf_loc.REF_LAB = 1)

    -- Filter to specific reference labs (Quest, ADL, Viracor, etc.)
    -- Exclude THST (TUH Immunogenetics - internal, not external)
    AND (
        perf_loc.NAME LIKE '%QUEST%'
        OR perf_loc.NAME LIKE '%ATLANTIC%'
        OR perf_loc.NAME LIKE '%VIRACOR%'
        OR perf_loc.NAME LIKE '%HISTOTRAC%'
        OR tr.TEST_PERFORMING_LOCATION IN ('JQUC', 'TQUC', 'JQUH', 'TQUH', 'ADL', 'EADL', 'TADL', 'JADL', 'TVIA', 'HIST')
    )

    -- Last 30 days
    AND tr.TEST_DT >= SYSDATE - 30

ORDER BY
    tr.TEST_DT DESC

FETCH FIRST 100 ROWS ONLY

-- Notes:
-- 1. SENDING_FACITILY = Origin facility that sent the specimen
-- 2. Transfer Location = Where specimen was processed/handled
-- 3. RECEIVING_FACILITY = Final destination where specimen was sent
-- 4. REF_LAB = 1 indicates this is a reference lab location
-- 5. PERFORMING_LAB = 'Y' means test was actually done at reference lab
-- 6. This shows the complete transfer chain from origin to final destination
