-- ============================================================
-- SoftLab Collection Containers — Tube Type Reference
-- One row per specimen/tube type.
--
-- Available from SCC:  Name, Volume (capacity), Additives
-- Not stored in SCC:   Container Name on Label, Color
-- ============================================================

SELECT
    sp.NAME                         AS "Name",
    NULL                            AS "Container Name on Label",
    NULL                            AS "Color",
    tc.CAPACITY                     AS "Volume (mL)",
    sp.ADDITIVES_PRESERVATIVES      AS "Additives"
FROM V_S_LAB_SPECIMEN sp
LEFT JOIN V_S_LAB_TUBE_CAPACITY tc ON tc.SPECIMEN_ID = sp.ID
WHERE sp.ACTIVE = 'Y'
ORDER BY sp.NAME;
