-- What values actually live in V_S_LAB_SPTR_SETUP.TERMINAL?
-- Shows distinct terminal codes with row counts so you can spot the format.
SELECT TERMINAL, COUNT(*) AS ROW_CNT
FROM V_S_LAB_SPTR_SETUP
GROUP BY TERMINAL
ORDER BY TERMINAL;

-- Fuzzy search for your terminals in case they are stored differently
SELECT DISTINCT TERMINAL
FROM V_S_LAB_SPTR_SETUP
WHERE UPPER(TERMINAL) LIKE '%EE7EE%'
   OR UPPER(TERMINAL) LIKE '%49601%'
ORDER BY TERMINAL;

-- Cross-check: does V_S_LAB_TERMINAL know about these IDs?
SELECT TERMINAL, NAME, COLL_CENTER_ID
FROM V_S_LAB_TERMINAL
WHERE TERMINAL IN ('EE7EE','49601')
   OR UPPER(NAME) LIKE '%EE7EE%'
   OR UPPER(NAME) LIKE '%49601%';
