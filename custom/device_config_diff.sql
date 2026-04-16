-- Device-level config diff for two physical PCs/terminals.
-- Scans every SoftLab view that has a TERMINAL column and shows values for
-- both devices plus a DIFFERS flag. Tables where TERMINAL is actually a
-- location code (e.g., V_S_LAB_SPTR_SETUP) are excluded.
-- Bind :dev_a and :dev_b to the two device IDs (e.g., 'EE7EE','49601').

-- 1. Discovery: full column list on every view keyed by TERMINAL
SELECT table_name, column_name, data_type, data_length
FROM all_tab_columns
WHERE table_name IN ('V_S_LAB_TERMINAL','V_S_LAB_LBL_SETUP')
ORDER BY table_name, column_id;

-- 2. V_S_LAB_TERMINAL side-by-side (device registry)
SELECT 'V_S_LAB_TERMINAL' AS SOURCE_VIEW,
       a.TERMINAL          AS TERMINAL_A,
       b.TERMINAL          AS TERMINAL_B,
       a.NAME              AS NAME_A,        b.NAME              AS NAME_B,
       a.COLL_CENTER_ID    AS CENTER_A,      b.COLL_CENTER_ID    AS CENTER_B,
       a.FORCEBYTERM       AS FORCEBYTERM_A, b.FORCEBYTERM       AS FORCEBYTERM_B,
       CASE WHEN NVL(a.NAME,'~')           <> NVL(b.NAME,'~')
              OR NVL(a.COLL_CENTER_ID,'~') <> NVL(b.COLL_CENTER_ID,'~')
              OR NVL(a.FORCEBYTERM,'~')    <> NVL(b.FORCEBYTERM,'~')
            THEN 'Y' ELSE 'N' END AS DIFFERS
FROM        (SELECT * FROM V_S_LAB_TERMINAL WHERE TERMINAL = :dev_a) a
FULL OUTER JOIN
            (SELECT * FROM V_S_LAB_TERMINAL WHERE TERMINAL = :dev_b) b
       ON 1 = 1;

-- 3. V_S_LAB_LBL_SETUP rows for both devices (label printing setup).
--    Columns beyond TERMINAL are unknown until discovery above runs — once you
--    see them, swap the SELECT * below for an explicit side-by-side like #2.
SELECT 'V_S_LAB_LBL_SETUP' AS SOURCE_VIEW, TERMINAL, lbl.*
FROM V_S_LAB_LBL_SETUP lbl
WHERE TERMINAL IN (:dev_a, :dev_b)
ORDER BY TERMINAL;
