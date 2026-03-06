-- ============================================================
-- SoftLab Laboratories & Sections Directory
-- One row per location + department combination.
-- Group by location in the report tool for hierarchical display.
--
-- Available from SCC:  Name, Abbreviation, Sections, In-House/External,
--                      Interfaced (ref labs), CLIA
-- Not stored in SCC:   Type of Lab, Pathology Work Performed
-- ============================================================

SELECT
    loc.NAME                        AS "Name",
    loc.ID                          AS "Abbreviation",
    d.NAME                          AS "Sections in Lab",
    d.ID                            AS "Section Code",
    CASE
        WHEN NVL(loc.REF_LAB, 0) = 0 THEN 'In-House'
        ELSE 'External'
    END                             AS "In-House or External",
    CASE
        WHEN NVL(loc.REF_LAB, 0) = 1
             AND NVL(loc.REF_NOTINTERFACED, 0) = 0
        THEN 'Yes'
        WHEN NVL(loc.REF_LAB, 0) = 1
             AND NVL(loc.REF_NOTINTERFACED, 0) = 1
        THEN 'No'
        ELSE NULL
    END                             AS "If External, Interfaced?",
    NULL                            AS "Type of Lab",
    NULL                            AS "Pathology Work Performed",
    loc.CLIA                        AS "CLIA #"
FROM V_S_LAB_LOCATION loc
LEFT JOIN V_S_LAB_DEPARTMENT d ON d.LOCATION_ID = loc.ID
ORDER BY loc.NAME, d.NAME;
