-- Find every SoftLab view with a TERMINAL (or device-like) column so we can
-- see if anything beyond TERMINAL/LBL_SETUP is keyed per-device.
SELECT table_name, column_name, data_type, data_length
FROM all_tab_columns
WHERE table_name LIKE 'V_%'
  AND column_name IN ('TERMINAL','DEVICE','DEVICE_ID','TERMINAL_ID',
                      'WORKSTATION','WORKSTATION_ID','HOSTNAME','PC_NAME',
                      'PC_ID','CLIENT_ID')
ORDER BY table_name, column_id;

-- For each view the search returns, check if our two devices appear in it
-- (uncomment and run per-view once you see the list).
-- SELECT 'V_S_LAB_TERMINAL' AS SRC, TERMINAL, COUNT(*) FROM V_S_LAB_TERMINAL
--   WHERE TERMINAL IN ('EE7EE','49601') GROUP BY TERMINAL;
