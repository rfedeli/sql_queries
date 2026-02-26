-- ============================================================
-- Epic Test Compendium Export
-- Produces: LIS Order Code, Name, Labs Performing Test,
--           Section in Lab, Analytes, CPT Codes,
--           Lab Only?, Collection Containers
-- ============================================================

WITH
-- 0. Deduplicate group tests: pick one AA_ID per test code (ID)
--    Some tests have multiple AA_IDs in V_S_LAB_TEST_GROUP
group_tests AS (
    SELECT ID, MAX(AA_ID) AS AA_ID,
           MAX(GTNAME_UPPER) AS GTNAME_UPPER,
           MAX(FL_SEND_OUT) AS FL_SEND_OUT
    FROM V_S_LAB_TEST_GROUP
    WHERE ACTIVE = 'Y'
    GROUP BY ID
),

-- 1. Analytes: aggregate component test names per group test
analytes AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(comp_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY comp_name) AS analyte_list
    FROM (
        SELECT DISTINCT tc.TEST_AA_ID, t.NAME AS comp_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_LAB_TEST t ON t.ID = tc.COMPONENT AND t.ACTIVE = 'Y'
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 2. Labs Performing Test: aggregate distinct facilities per group test
--    Uses SITE from location for facility-level grouping
performing_labs AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(facility, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY facility) AS lab_list
    FROM (
        SELECT DISTINCT
            tc.TEST_AA_ID,
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
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_LAB_TEST_ENVIRONMENT te ON te.TEST_ID = tc.COMPONENT
        JOIN V_S_LAB_WORKSTATION ws ON ws.ID = te.WORKSTATION_ID
        JOIN V_S_LAB_LOCATION loc ON loc.ID = ws.LOCATION_ID
        WHERE NVL(ws.REF_LAB, 0) = 0  -- exclude reference lab workstations
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 3. Section in Lab: aggregate distinct section names per group test
--    Uses department NAME which is generic (Chemistry, Hematology, etc.)
sections AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(section_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY section_name) AS section_list
    FROM (
        SELECT DISTINCT tc.TEST_AA_ID, d.NAME AS section_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_LAB_TEST t ON t.ID = tc.COMPONENT
        JOIN V_S_LAB_DEPARTMENT d ON d.ID = t.DEPARTMENT_ID
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 4. CPT Codes: from SoftAR BILLRULES (authoritative source)
--    V_S_LAB_TEST.CPT_BASIC_CODE_1-8 are NOT populated in this system
cpt_codes AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(cpt_code, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY cpt_code) AS cpt_list
    FROM (
        SELECT DISTINCT tc.TEST_AA_ID, br.BRCPTCODE AS cpt_code
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_ARE_BILLRULES br ON br.BRTSTCODE = tc.COMPONENT
                                  AND br.BRSTAT = 0
                                  AND br.BRCPTCODE IS NOT NULL
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 5. Collection Containers: primary from group specimen, fallback from test specimen
containers AS (
    SELECT
        TEST_AA_ID,
        LISTAGG(tube_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY tube_name) AS container_list
    FROM (
        -- Primary: group-level specimen requirements
        SELECT DISTINCT gs.TEST_AA_ID, sp.NAME AS tube_name
        FROM V_S_LAB_TEST_GROUP_SPECIMEN gs
        JOIN V_S_LAB_SPECIMEN sp ON sp.ID = gs.SAMPLE_TYPE
        UNION
        -- Fallback: component-level specimen requirements (per test/workstation)
        SELECT DISTINCT tc.TEST_AA_ID, sp.NAME AS tube_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_LAB_TEST_SPECIMEN ts ON ts.TEST_ID = tc.COMPONENT
                                      AND ts.COLLECTION_CONTAINER IS NOT NULL
        JOIN V_S_LAB_SPECIMEN sp ON sp.ID = ts.COLLECTION_CONTAINER
    )
    GROUP BY TEST_AA_ID
)

-- Main query: one row per unique test code
SELECT
    gtg.ID                          AS "LIS Order Code",
    gtg.GTNAME_UPPER                AS "Name",
    pl.lab_list                     AS "Labs Performing Test",
    sec.section_list                AS "Section in Lab",
    an.analyte_list                 AS "Analytes Included in Order",
    cpt.cpt_list                    AS "CPT Code(s)",
    CASE WHEN gtg.FL_SEND_OUT = 'Y'
         THEN 'Yes' ELSE NULL
    END                             AS "Lab Only?",
    con.container_list              AS "Collection Containers"
FROM group_tests gtg
LEFT JOIN analytes an          ON an.TEST_AA_ID = gtg.AA_ID
LEFT JOIN performing_labs pl   ON pl.TEST_AA_ID = gtg.AA_ID
LEFT JOIN sections sec         ON sec.TEST_AA_ID = gtg.AA_ID
LEFT JOIN cpt_codes cpt        ON cpt.TEST_AA_ID = gtg.AA_ID
LEFT JOIN containers con       ON con.TEST_AA_ID = gtg.AA_ID
ORDER BY gtg.ID;
