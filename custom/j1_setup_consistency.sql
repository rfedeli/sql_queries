-- Verify the 42 J1 SPTR_SETUP rows are genuinely shared and not scoped per-device.

-- 1. Confirm there are no rows keyed on the device IDs themselves (sanity)
SELECT TERMINAL, COUNT(*) AS N
FROM V_S_LAB_SPTR_SETUP
WHERE TERMINAL IN ('EE7EE','49601','J1')
GROUP BY TERMINAL;

-- 2. Dump the 42 J1 rows with every config column, joined to the place definition
SELECT s.PLACE,
       s.POSITION,
       stop_.SPECIMEN_STATUS,
       stop_.SPECIMEN_LOCATION,
       stop_.DESCRIPTION     AS PLACE_DESC,
       s.STATUS              AS SETUP_STATUS,
       s.HIDE,
       s.ACTIONS,
       s.LOCATION,
       s.CONTAINER,
       s.LOC_DEPT_WRKSTN,
       s.TYPE,
       s.SETUP_OPTION
FROM V_S_LAB_SPTR_SETUP s
LEFT JOIN V_S_LAB_SPTR_STOP stop_ ON stop_.PLACE = s.PLACE
WHERE s.TERMINAL = 'J1'
ORDER BY stop_.SPECIMEN_STATUS, stop_.SPECIMEN_LOCATION, s.PLACE, s.POSITION;

-- 3. Look for any scope-narrowing values (workstation/department) that could
--    make certain rows apply to one PC but not the other.
SELECT LOC_DEPT_WRKSTN, COUNT(*) AS N
FROM V_S_LAB_SPTR_SETUP
WHERE TERMINAL = 'J1'
GROUP BY LOC_DEPT_WRKSTN
ORDER BY N DESC, LOC_DEPT_WRKSTN;
