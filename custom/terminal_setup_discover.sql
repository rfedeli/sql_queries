-- Find the SoftLab view that carries terminal/specimen-tracking setup columns
-- (terminal_id, specimen_status, specimen_location, place, hide_flag, action_flags)
SELECT owner, table_name, column_name, data_type, data_length
FROM all_tab_columns
WHERE (UPPER(column_name) LIKE '%TERMINAL%'
    OR UPPER(column_name) IN ('SPECIMEN_STATUS','SPECIMEN_LOCATION','PLACE','HIDE_FLAG','ACTION_FLAGS'))
  AND table_name LIKE 'V_S_LAB_%'
ORDER BY table_name, column_id;

-- Show all columns on the most likely candidates
SELECT table_name, column_name, data_type, data_length
FROM all_tab_columns
WHERE table_name IN ('V_S_LAB_TERMINAL','V_S_LAB_SPTR_SETUP','V_S_LAB_SPTR_LOCATION',
                     'V_S_LAB_SPTR_STATUS','V_S_LAB_SPTR_STOP')
ORDER BY table_name, column_id;
