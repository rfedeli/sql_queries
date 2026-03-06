-- ============================================================
-- SoftLab Instruments / Workstations Reference
-- One row per workstation (analyzer/instrument) in the LIS.
--
-- Available from SCC:  Instrument Code, Name, Laboratory, Section, Interfaced
-- Not stored in SCC:   Make, Model (embedded in Name but not discrete fields)
-- ============================================================

SELECT
    ws.ID                           AS "Instrument Code",
    ws.NAME                         AS "Name for Instrument in System",
    NULL                            AS "Make",
    NULL                            AS "Model",
    loc.NAME                        AS "Laboratory",
    d.NAME                          AS "Section",
    CASE WHEN iws.WORKSTATION IS NOT NULL
         THEN 'Yes' ELSE 'No'
    END                             AS "Interfaced?"
FROM V_S_LAB_WORKSTATION ws
LEFT JOIN V_S_LAB_DEPARTMENT d   ON d.ID = ws.DEPARTMENT_ID
LEFT JOIN V_S_LAB_LOCATION loc   ON loc.ID = ws.LOCATION_ID
LEFT JOIN V_S_INST_WORKSTATIONS iws ON iws.WORKSTATION = ws.ID
WHERE NVL(ws.REF_LAB, 0) = 0
ORDER BY loc.NAME, d.NAME, ws.NAME;
