-- Instrument interface list from V_S_INST_INSTRUMENT
-- Includes lab analyzers, reference lab interfaces, and system/infrastructure interfaces
SELECT
    i.ID AS instrument_id,
    i.NAME AS instrument_name,
    CASE i.ACTIVE
        WHEN 'Y' THEN 'Active'
        WHEN 'A' THEN 'Active (Auto)'
        WHEN 'N' THEN 'Inactive'
        ELSE i.ACTIVE
    END AS status,
    i.INSTRUMENT_TYPE,
    i.ORD_WORKSTATION_ID AS ord_workstation,
    i.RES_WORKSTATION_ID AS res_workstation,
    i.TEMPLATE_ID,
    i.PORT_NAME AS connection,
    i.DIR_NAME AS directory,
    i.INSTRUMENT_FLAG,
    i.CREATE_DATE,
    i.MOD_DATE
FROM V_S_INST_INSTRUMENT i
ORDER BY
    CASE i.INSTRUMENT_TYPE
        WHEN 'CHEMISTRY' THEN 1
        WHEN 'HEMATOLOGY' THEN 2
        WHEN 'MICROBIOLOGY' THEN 3
        WHEN 'HIS' THEN 4
        ELSE 5
    END,
    i.ACTIVE DESC,
    i.NAME
