-- Sanity check: does the terminal ID actually exist in each view, and how is it stored?
-- Replace the two terminal IDs in the WHERE clauses.

-- A. Registered terminals matching either name (fuzzy — case-insensitive, trimmed)
SELECT 'V_S_LAB_TERMINAL' AS SOURCE_VIEW,
       TERMINAL,
       NAME,
       COLL_CENTER_ID,
       LENGTH(TERMINAL) AS TERMLEN
FROM V_S_LAB_TERMINAL
WHERE UPPER(TRIM(TERMINAL)) IN (UPPER('BROKEN_PC'), UPPER('WORKING_PC'));

-- B. How many SPTR_SETUP rows exist per terminal (exact match)
SELECT TERMINAL, COUNT(*) AS SETUP_ROWS
FROM V_S_LAB_SPTR_SETUP
WHERE TERMINAL IN ('BROKEN_PC','WORKING_PC')
GROUP BY TERMINAL;

-- C. Fuzzy match — if B returns nothing, this finds them with case/padding ignored
SELECT TERMINAL,
       COUNT(*) AS SETUP_ROWS,
       LENGTH(TERMINAL) AS TERMLEN
FROM V_S_LAB_SPTR_SETUP
WHERE UPPER(TRIM(TERMINAL)) IN (UPPER('BROKEN_PC'), UPPER('WORKING_PC'))
GROUP BY TERMINAL;

-- D. Browse any terminals with similar names (if you're not sure of the exact ID)
SELECT DISTINCT TERMINAL
FROM V_S_LAB_SPTR_SETUP
WHERE UPPER(TERMINAL) LIKE '%BROKEN%'
   OR UPPER(TERMINAL) LIKE '%WORKING%'
ORDER BY TERMINAL;
