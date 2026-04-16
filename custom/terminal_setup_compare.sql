-- Compare specimen-tracking setup for two terminals side-by-side.
-- SETUP holds per-terminal rows (one per PLACE/POSITION); STOP holds the per-place
-- definition including SPECIMEN_STATUS / SPECIMEN_LOCATION.
SELECT
    s.TERMINAL              AS TERMINAL_ID,
    st.SPECIMEN_STATUS,
    st.SPECIMEN_LOCATION,
    s.PLACE,
    s.POSITION,
    s.STATUS                AS SETUP_STATUS,
    s.HIDE                  AS HIDE_FLAG,
    s.ACTIONS               AS SETUP_ACTIONS,
    st.ACTIONS              AS STOP_ACTIONS,
    s.LOCATION              AS SETUP_LOCATION,
    s.CONTAINER,
    s.LOC_DEPT_WRKSTN,
    s.TYPE                  AS SETUP_TYPE,
    s.SETUP_OPTION
FROM V_S_LAB_SPTR_SETUP s
LEFT JOIN V_S_LAB_SPTR_STOP st
       ON st.PLACE = s.PLACE
WHERE s.TERMINAL IN ('BROKEN_PC','WORKING_PC')
ORDER BY st.SPECIMEN_STATUS, st.SPECIMEN_LOCATION, s.PLACE, s.TERMINAL;
