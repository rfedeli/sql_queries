-- ============================================================
-- Epic Test Compendium — Orderables Tab
-- One row per orderable test (group tests and individually
-- orderable tests). Components are listed in the Analytes column.
-- ============================================================

WITH
-- 0. Deduplicate group tests: one row per test code
group_tests AS (
    SELECT ID, MAX(AA_ID) AS AA_ID,
           MAX(GTNAME_UPPER) AS GTNAME_UPPER,
           MAX(FL_SEND_OUT) AS FL_SEND_OUT
    FROM V_S_LAB_TEST_GROUP
    WHERE ACTIVE = 'Y'
    GROUP BY ID
),

-- 1. Deduplicate individual tests: one row per test code
tests AS (
    SELECT ID,
           MAX(NAME)           AS NAME,
           MAX(DEPARTMENT_ID)  AS DEPARTMENT_ID
    FROM V_S_LAB_TEST
    WHERE ACTIVE = 'Y'
    GROUP BY ID
),

-- 2. Analytes: aggregate component test names per group test
analytes AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(comp_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY comp_name) AS analyte_list
    FROM (
        SELECT DISTINCT tc.TEST_AA_ID, t.NAME AS comp_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN tests t ON t.ID = tc.COMPONENT
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 3. Labs performing test: aggregate distinct facilities per group test
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
        WHERE NVL(ws.REF_LAB, 0) = 0
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 4. Section in lab: aggregate distinct sections per group test
sections AS (
    SELECT
        tc.TEST_AA_ID,
        LISTAGG(section_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY section_name) AS section_list
    FROM (
        SELECT DISTINCT tc.TEST_AA_ID, d.NAME AS section_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN tests t ON t.ID = tc.COMPONENT
        JOIN V_S_LAB_DEPARTMENT d ON d.ID = t.DEPARTMENT_ID
    ) tc
    GROUP BY tc.TEST_AA_ID
),

-- 5. CPT Codes: parent vs component billing
--    Parent-billed: single CPT from the group test billing rule
--    Component-billed: aggregate CPTs from component billing rules

-- 5a. Parent-level CPT
parent_cpt AS (
    SELECT DISTINCT gtg.AA_ID AS TEST_AA_ID, br.BRCPTCODE AS cpt_code
    FROM group_tests gtg
    JOIN V_S_ARE_BILLRULES br ON br.BRTSTCODE = gtg.ID
                              AND br.BRSTAT = 0
                              AND br.BRCPTCODE IS NOT NULL
                              AND NVL(br.BRNOBILL, 0) NOT IN (1, 2)
                              AND (br.BREXPDT IS NULL OR br.BREXPDT > SYSDATE)
                              AND (br.BRBEGDT IS NULL OR br.BRBEGDT <= SYSDATE)
),

-- 5b. Component-level CPT (when no parent rule)
component_cpt AS (
    SELECT DISTINCT tc.TEST_AA_ID, br.BRCPTCODE AS cpt_code
    FROM V_S_LAB_TEST_COMPONENT tc
    JOIN V_S_ARE_BILLRULES br ON br.BRTSTCODE = tc.COMPONENT
                              AND br.BRSTAT = 0
                              AND br.BRCPTCODE IS NOT NULL
                              AND (br.BREXPDT IS NULL OR br.BREXPDT > SYSDATE)
                              AND (br.BRBEGDT IS NULL OR br.BRBEGDT <= SYSDATE)
    WHERE NOT EXISTS (
        SELECT 1 FROM parent_cpt pc WHERE pc.TEST_AA_ID = tc.TEST_AA_ID
    )
),

-- 5c. Combine parent and component CPTs
cpt_codes AS (
    SELECT
        TEST_AA_ID,
        LISTAGG(cpt_code, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY cpt_code) AS cpt_list
    FROM (
        SELECT TEST_AA_ID, cpt_code FROM parent_cpt
        UNION
        SELECT TEST_AA_ID, cpt_code FROM component_cpt
    )
    GROUP BY TEST_AA_ID
),

-- 6. Collection Containers: group specimen primary, test specimen fallback
containers AS (
    SELECT
        TEST_AA_ID,
        LISTAGG(tube_name, ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
            WITHIN GROUP (ORDER BY tube_name) AS container_list
    FROM (
        SELECT DISTINCT gs.TEST_AA_ID, sp.NAME AS tube_name
        FROM V_S_LAB_TEST_GROUP_SPECIMEN gs
        JOIN V_S_LAB_SPECIMEN sp ON sp.ID = gs.SAMPLE_TYPE
        UNION
        SELECT DISTINCT tc.TEST_AA_ID, sp.NAME AS tube_name
        FROM V_S_LAB_TEST_COMPONENT tc
        JOIN V_S_LAB_TEST_SPECIMEN ts ON ts.TEST_ID = tc.COMPONENT
                                      AND ts.COLLECTION_CONTAINER IS NOT NULL
        JOIN V_S_LAB_SPECIMEN sp ON sp.ID = ts.COLLECTION_CONTAINER
    )
    GROUP BY TEST_AA_ID
)

-- Main query: one row per orderable test
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
