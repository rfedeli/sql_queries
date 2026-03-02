-- ============================================================
-- Epic Test Compendium Export — One Row Per Individual Test
-- Produces: Test Name, Test Code, LOINC, Unit of Measure,
--           Result Type, Section, Instruments, Labs Performing,
--           CPT Code(s), Collection Containers
-- ============================================================

WITH
-- 0. Deduplicate individual tests: one row per test code
tests AS (
    SELECT ID,
           MAX(NAME)           AS NAME,
           MAX(LOINC)          AS LOINC,
           MAX(UNITS)          AS UNITS,
           MAX(RESULT_TYPE)    AS RESULT_TYPE,
           MAX(DEPARTMENT_ID)  AS DEPARTMENT_ID
    FROM V_S_LAB_TEST
    WHERE ACTIVE = 'Y'
    GROUP BY ID
),

-- 1a. Configured instruments (from setup tables)
instruments_configured AS (
    SELECT
        TEST_ID,
        LISTAGG(ws_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY ws_name) AS instrument_list
    FROM (
        SELECT DISTINCT te.TEST_ID, ws.NAME AS ws_name
        FROM V_S_LAB_TEST_ENVIRONMENT te
        JOIN V_S_LAB_WORKSTATION ws ON ws.ID = te.WORKSTATION_ID
        WHERE NVL(ws.REF_LAB, 0) = 0
    )
    GROUP BY TEST_ID
),

-- 1b. Active instruments (from actual results in the last 7 days)
instruments_active AS (
    SELECT
        TEST_ID,
        LISTAGG(ws_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY ws_name) AS instrument_list
    FROM (
        SELECT DISTINCT tr.TEST_ID, ws.NAME AS ws_name
        FROM V_P_LAB_TEST_RESULT tr
        JOIN V_S_LAB_WORKSTATION ws ON ws.ID = tr.TESTING_WORKSTATION_ID
        WHERE tr.VERIFIED_DT >= SYSDATE - 7
          AND tr.STATE IN ('Final', 'Verified', 'Corrected')
          AND tr.TESTING_WORKSTATION_ID IS NOT NULL
          AND NVL(ws.REF_LAB, 0) = 0
    )
    GROUP BY TEST_ID
),

-- 2. Labs performing test (facility level, per individual test)
performing_labs AS (
    SELECT
        TEST_ID,
        LISTAGG(facility, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY facility) AS lab_list
    FROM (
        SELECT DISTINCT
            te.TEST_ID,
            CASE loc.SITE
                WHEN 'TUH'   THEN 'Temple University Hospital'
                WHEN 'JNS'   THEN 'Jeanes Hospital'
                WHEN 'FC'    THEN 'Fox Chase Cancer Center'
                WHEN 'EPC'   THEN 'Episcopal Hospital'
                WHEN 'CH'    THEN 'Chestnut Hill Hospital'
                WHEN 'WFH'   THEN 'Women and Families Hospital'
                WHEN 'NE'    THEN 'Northeastern Hospital'
                ELSE loc.SITE
            END AS facility
        FROM V_S_LAB_TEST_ENVIRONMENT te
        JOIN V_S_LAB_WORKSTATION ws ON ws.ID = te.WORKSTATION_ID
        JOIN V_S_LAB_LOCATION loc ON loc.ID = ws.LOCATION_ID
        WHERE NVL(ws.REF_LAB, 0) = 0
    )
    GROUP BY TEST_ID
),

-- 3. CPT Codes: from SoftAR BILLRULES (authoritative source)
test_cpt AS (
    SELECT
        TEST_ID,
        LISTAGG(cpt_code, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY cpt_code) AS cpt_list
    FROM (
        SELECT DISTINCT br.BRTSTCODE AS TEST_ID, br.BRCPTCODE AS cpt_code
        FROM V_S_ARE_BILLRULES br
        WHERE br.BRSTAT = 0
          AND br.BRCPTCODE IS NOT NULL
          AND (br.BREXPDT IS NULL OR br.BREXPDT > SYSDATE)
          AND (br.BRBEGDT IS NULL OR br.BRBEGDT <= SYSDATE)
    )
    GROUP BY TEST_ID
),

-- 4. Collection Containers per individual test
containers AS (
    SELECT
        TEST_ID,
        LISTAGG(tube_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY tube_name) AS container_list
    FROM (
        SELECT DISTINCT ts.TEST_ID, sp.NAME AS tube_name
        FROM V_S_LAB_TEST_SPECIMEN ts
        JOIN V_S_LAB_SPECIMEN sp ON sp.ID = ts.COLLECTION_CONTAINER
        WHERE ts.COLLECTION_CONTAINER IS NOT NULL
    )
    GROUP BY TEST_ID
)

-- Main query: one row per individual test
SELECT
    t.NAME                                    AS "Test Name",
    t.ID                                      AS "Test Code",
    t.LOINC                                   AS "LOINC Code",
    t.UNITS                                   AS "Unit of Measure",
    t.RESULT_TYPE                             AS "Result Type",
    d.NAME                                    AS "Section in Lab",
    icfg.instrument_list                      AS "Instruments (Configured)",
    iact.instrument_list                      AS "Instruments (Active)",
    pl.lab_list                               AS "Labs Performing Test",
    tcpt.cpt_list                             AS "CPT Code(s)",
    con.container_list                        AS "Collection Containers"
FROM tests t
LEFT JOIN V_S_LAB_DEPARTMENT d     ON d.ID = t.DEPARTMENT_ID
LEFT JOIN instruments_configured icfg ON icfg.TEST_ID = t.ID
LEFT JOIN instruments_active iact  ON iact.TEST_ID = t.ID
LEFT JOIN performing_labs pl       ON pl.TEST_ID = t.ID
LEFT JOIN test_cpt tcpt            ON tcpt.TEST_ID = t.ID
LEFT JOIN containers con           ON con.TEST_ID = t.ID
ORDER BY t.ID;
