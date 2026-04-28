/* ============================================================================
   VIEW DEEP PROBE — Comprehensive single-view discovery template
   ============================================================================

   PURPOSE
     Replaces the iterative 5-query manual discovery pattern with a single
     comprehensive scan that surfaces:
       - Column list, types, nullability                          (Section A)
       - Per-column population rate (vestigial detection)         (Section B)
       - Per-column distinct-count for enum candidates            (Section C)
       - Numeric/DATE triple identification                       (Section D)
       - Index information via ALL_DEPENDENCIES → ALL_INDEXES     (Section E)
       - Column comments (USER/ALL_COL_COMMENTS)                  (Section F)
       - 5 recent sample rows                                     (Section G)
       - Volume + date span                                       (Section H)

   USAGE
     1. Edit the SETUP block below (find/replace 3 placeholders).
     2. Run sections sequentially. Each is independently executable —
        select the section's SQL block in your client and execute.
     3. Sections B and C use a generator-then-assembled-query pattern:
        run the generator first, copy the output, paste, run the
        assembled query.
     4. Read the OPERATIONAL RISK callouts in each section's header
        before running on V_P_LAB_TEST_RESULT or any other large view.

   READ FIRST: ../README.md (operational risk section especially).

   ============================================================================
   SETUP — edit these three placeholders globally before running anything
   ============================================================================
     __VIEW_NAME__    : the SCC view to investigate
                        (e.g., V_P_LAB_TEST_RESULT)
     __DATE_COL__     : primary indexed timestamp column for windowing
                        (e.g., TEST_DT, VERIFIED_DT, RECEIPT_DT, ORDERED_DT)
     __WINDOW_DAYS__  : how far back to scan
                        - 7 for V_P_LAB_TEST_RESULT (~162K rows/day)
                        - 30 for everything else (BB, ORDER, STAY, etc.)

   Optional: if duplicate view names exist across schemas, also uncomment
   the OWNER filter in each section.

   ============================================================================
*/


/* ============================================================================
   SECTION A — Column list + types + nullability
   ----------------------------------------------------------------------------
   Cheap metadata-only query. Always safe to run.
   Expected runtime: <1 second.
   ============================================================================ */

SELECT
    COLUMN_ID,
    COLUMN_NAME,
    DATA_TYPE,
    DATA_LENGTH,
    NULLABLE,
    CASE WHEN DATA_LENGTH = 0 THEN 'VESTIGIAL' END AS LEN0_FLAG
FROM ALL_TAB_COLUMNS
WHERE UPPER(TABLE_NAME) = UPPER('__VIEW_NAME__')
--    AND OWNER = 'LAB'   -- uncomment if duplicate names across schemas
ORDER BY COLUMN_ID;


/* ============================================================================
   SECTION B — Per-column population rate (vestigial detection)
   ----------------------------------------------------------------------------
   GENERATOR QUERY: produces SELECT-clause fragments. Run this first, copy
   the output, paste between the markers in the ASSEMBLED QUERY, run that.

   Skips DATA_LENGTH=0 columns (already known to be vestigial from Section A).

   ⚠ OPERATIONAL RISK: the assembled query does ONE full scan of the windowed
     dataset, computing one COUNT() per non-vestigial column. On
     V_P_LAB_TEST_RESULT with __WINDOW_DAYS__=7, that's ~1.1M rows × ~240 cols.
     Should complete in <30 seconds with a properly-indexed __DATE_COL__.
     If it hangs, kill it — your date filter likely isn't using an index.
   ============================================================================ */

-- B-GENERATOR: produces COUNT(col) fragments. Copy the SQL_FRAGMENT column.
SELECT '  COUNT(' || RPAD(COLUMN_NAME, 24) || ') AS '
       || COLUMN_NAME || '_pop,' AS SQL_FRAGMENT
FROM ALL_TAB_COLUMNS
WHERE UPPER(TABLE_NAME) = UPPER('V_P_BB_Patient')
  AND DATA_LENGTH > 0
ORDER BY COLUMN_ID;

-- B-ASSEMBLED: paste the generator output between the markers below, then run.
-- The result is one wide row; divide each *_pop value by total_rows for the
-- population percentage.
/*
SELECT
  -- BEGIN paste B-GENERATOR output here
  COUNT(AA_ID) AS                               aa_id_pop,
  COUNT(__example_col__) AS                     example_pop,
  -- END paste B-GENERATOR output here
  COUNT(*) AS total_rows
FROM __VIEW_NAME__
WHERE __DATE_COL__ >= SYSDATE - __WINDOW_DAYS__;
*/


/* ============================================================================
   SECTION C — Distinct-count per column (enum candidate detection)
   ----------------------------------------------------------------------------
   Restricted to small CHAR/VARCHAR2 columns (DATA_LENGTH <= 16). Anything
   larger is unlikely to be an enum and the COUNT(DISTINCT) cost rises with
   data width.

   GENERATOR + ASSEMBLED pattern (same as Section B).

   Interpretation: distinct-count <= ~20 = enum candidate. The actual values
   can then be probed with a per-column GROUP BY.

   ⚠ OPERATIONAL RISK: COUNT(DISTINCT) is more expensive than COUNT(). The
     filter to small columns helps, but on a 240-col view about 80 columns
     may qualify. Expect 30-60 seconds on V_P_LAB_TEST_RESULT with a 7-day
     window. Skip this section if Section B's runtime alone was concerning.
   ============================================================================ */

-- C-GENERATOR: produces COUNT(DISTINCT col) fragments for enum-candidate columns.
SELECT '  COUNT(DISTINCT ' || RPAD(COLUMN_NAME, 24) || ') AS '
       || COLUMN_NAME || '_dc,' AS SQL_FRAGMENT
FROM ALL_TAB_COLUMNS
WHERE UPPER(TABLE_NAME) = UPPER('__VIEW_NAME__')
  AND DATA_LENGTH > 0
  AND DATA_LENGTH <= 16
  AND DATA_TYPE IN ('CHAR', 'VARCHAR2')
ORDER BY COLUMN_ID;

-- C-ASSEMBLED: paste the generator output between the markers, run.
-- A column whose *_dc value is small (<=20) and whose count of populated
-- rows (from Section B) is non-trivial is an enum worth probing.
/*
SELECT
  -- BEGIN paste C-GENERATOR output here
  COUNT(DISTINCT STATUS) AS                     status_dc,
  COUNT(DISTINCT __example_col__) AS            example_dc,
  -- END paste C-GENERATOR output here
  COUNT(*) AS total_rows
FROM __VIEW_NAME__
WHERE __DATE_COL__ >= SYSDATE - __WINDOW_DAYS__;
*/


/* ============================================================================
   SECTION D — Numeric/DATE triple detection
   ----------------------------------------------------------------------------
   Pattern: SCC views often store timestamps as a triple of
     <root>_DATE  (NUMBER, YYYYMMDD)
     <root>_TIME  (NUMBER, HHMM or HHMMSS)
     <root>_DT    (DATE,   canonical)

   Use the *_DT column for date predicates; the numeric pair carries
   sentinel values like -1 for "not set" and is index-unfriendly.

   This section identifies all such triples (and pairs missing one element)
   in the target view.
   ============================================================================ */

WITH cols AS (
    SELECT
        COLUMN_NAME,
        DATA_TYPE,
        REGEXP_SUBSTR(COLUMN_NAME, '^(.+)_(DATE|TIME|DT)$', 1, 1, NULL, 1) AS root,
        REGEXP_SUBSTR(COLUMN_NAME, '_(DATE|TIME|DT)$', 1, 1, NULL, 1)      AS suffix
    FROM ALL_TAB_COLUMNS
    WHERE UPPER(TABLE_NAME) = UPPER('__VIEW_NAME__')
      AND REGEXP_LIKE(COLUMN_NAME, '_(DATE|TIME|DT)$')
)
SELECT
    root,
    MAX(CASE WHEN suffix = 'DATE' THEN COLUMN_NAME || ' (' || DATA_TYPE || ')' END) AS date_col,
    MAX(CASE WHEN suffix = 'TIME' THEN COLUMN_NAME || ' (' || DATA_TYPE || ')' END) AS time_col,
    MAX(CASE WHEN suffix = 'DT'   THEN COLUMN_NAME || ' (' || DATA_TYPE || ')' END) AS dt_col,
    COUNT(*) AS components,
    CASE WHEN COUNT(*) = 3 THEN 'full triple'
         WHEN COUNT(*) = 2 THEN 'pair (one missing)'
         ELSE 'singleton' END AS pattern
FROM cols
WHERE root IS NOT NULL
GROUP BY root
ORDER BY components DESC, root;


/* ============================================================================
   SECTION E — Index information (via ALL_DEPENDENCIES → ALL_INDEXES)
   ----------------------------------------------------------------------------
   SCC views are typically thin wrappers over base tables, so indexes live
   on the base table, not the view itself. This query walks ALL_DEPENDENCIES
   to find the base table, then joins to ALL_INDEXES / ALL_IND_COLUMNS.

   Critical for:
     - Confirming __DATE_COL__ is actually indexed (it should be, for a
       performant date-range scan)
     - Identifying which other timestamp columns are indexed (TEST_DT vs
       VERIFIED_DT vs RECEIPT_DT — pick the indexed one)
     - Surfacing PK and unique-constraint indexes (AA_ID is usually the PK)

   ⚠ OPERATIONAL RISK: cheap metadata query, no data scan. Safe to run.
     If it returns no rows, either the view's base table is in a schema you
     can't read, or it's a synonym chain — try the SECTION E-DIAG query.
   ============================================================================ */

SELECT
    dep.REFERENCED_NAME                                                   AS base_table,
    idx.INDEX_NAME,
    idx.UNIQUENESS,
    LISTAGG(ic.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ic.COLUMN_POSITION) AS index_columns
FROM ALL_DEPENDENCIES dep
    INNER JOIN ALL_INDEXES idx
        ON idx.TABLE_NAME  = dep.REFERENCED_NAME
       AND idx.TABLE_OWNER = dep.REFERENCED_OWNER
    INNER JOIN ALL_IND_COLUMNS ic
        ON ic.INDEX_NAME  = idx.INDEX_NAME
       AND ic.INDEX_OWNER = idx.OWNER
WHERE UPPER(dep.NAME)         = UPPER('__VIEW_NAME__')
  AND dep.TYPE                = 'VIEW'
  AND dep.REFERENCED_TYPE     = 'TABLE'
GROUP BY dep.REFERENCED_NAME, idx.INDEX_NAME, idx.UNIQUENESS
ORDER BY idx.INDEX_NAME;

-- E-DIAG: if Section E returns no rows, the dependency chain may be more
-- than one hop deep (view → view → table) or hidden behind a synonym.
-- This shows whatever __VIEW_NAME__ depends on, so you can chase the chain.
/*
SELECT REFERENCED_OWNER, REFERENCED_NAME, REFERENCED_TYPE
FROM ALL_DEPENDENCIES
WHERE UPPER(NAME) = UPPER('__VIEW_NAME__');
*/


/* ============================================================================
   SECTION F — Column comments (Oracle metadata, if populated)
   ----------------------------------------------------------------------------
   Cheap query. SCC environments rarely populate column comments, but it's
   worth checking — when they exist, they often capture business semantics
   that aren't visible in column names.
   ============================================================================ */

SELECT
    COLUMN_NAME,
    COMMENTS
FROM ALL_COL_COMMENTS
WHERE UPPER(TABLE_NAME) = UPPER('__VIEW_NAME__')
  AND COMMENTS IS NOT NULL
ORDER BY COLUMN_NAME;


/* ============================================================================
   SECTION G — Sample 5 recent rows
   ----------------------------------------------------------------------------
   Subquery + ROWNUM (Oracle client lacks FETCH FIRST per project memory).
   Provides full-row visual of what's actually populated.

   ⚠ PHI WARNING: sample rows contain real patient identifiers, names,
     diagnoses, and free-text comments. Per project memory rule
     `feedback_obfuscate_queried_data.md`, NEVER paste raw output into
     shared docs, the dictionary, GitHub commits, or external chat.
     Replace identifiers with placeholders (E*******, LASTNAME) before
     sharing.

   ⚠ OPERATIONAL RISK: heavy rows (e.g., V_P_LAB_TEST_RESULT 242 cols) may
     be wide and slow to render in the client. Reduce LIMIT to <= 3 if
     scrolling becomes painful.
   ============================================================================ */

SELECT *
FROM (
    SELECT *
    FROM __VIEW_NAME__
    WHERE __DATE_COL__ >= SYSDATE - __WINDOW_DAYS__
    ORDER BY __DATE_COL__ DESC
)
WHERE ROWNUM <= 5;


/* ============================================================================
   SECTION H — Volume + date span
   ----------------------------------------------------------------------------
   Single aggregate query — total rows in window, distinct values of any
   useful identifier (often AA_ID equals row count, but for child entities
   distinct ORDER_AA_ID/PATIENT_AA_ID tells you the parent-cohort size),
   date range covered.

   Edit the second line to pick the most-relevant cardinality metric for
   the view (e.g., DISTINCT PATIENT_AA_ID for stay-level views, DISTINCT
   ORDER_AA_ID for order-test/result views).
   ============================================================================ */

SELECT
    COUNT(*)                                                          AS rows_in_window,
    -- EDIT: replace with most-relevant cohort identifier for this view
    COUNT(DISTINCT AA_ID)                                             AS distinct_cohort,
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT AA_ID), 0), 2)             AS rows_per_cohort,
    MIN(__DATE_COL__)                                                 AS min_dt,
    MAX(__DATE_COL__)                                                 AS max_dt,
    -- Sanity check: did __DATE_COL__ filter pull in future-dated rows?
    -- Relevant on V_P_LAB_STAY.ADMISSION_DT which can be future-scheduled.
    SUM(CASE WHEN __DATE_COL__ > SYSDATE THEN 1 ELSE 0 END)           AS future_dated_rows
FROM __VIEW_NAME__
WHERE __DATE_COL__ >= SYSDATE - __WINDOW_DAYS__;


/* ============================================================================
   AFTER RUNNING — Folding results into CLAUDE.md

   Per the test-all-hypotheses memory rule, claims land in CLAUDE.md only
   when directly verified. The deep probe verifies:
     - column count, types, nullability                  (Sections A, B)
     - vestigial columns                                 (Section A LEN0_FLAG; Section B *_pop = 0)
     - enum candidate columns                            (Section C *_dc small)
     - date triple structure                             (Section D)
     - index coverage                                    (Section E)
     - column-level comments                             (Section F)
     - representative populated values                   (Section G)
     - row volume + date coverage                        (Section H)

   What it does NOT verify (use a hypothesis-verification template instead):
     - semantic meaning of enum values (run a GROUP BY + correlation probe)
     - parent-child code fanout patterns (verify_parent_child_fanout.sql)
     - whether two similar-named columns hold the same data (verify_duplicate_columns.sql)
     - cross-view join keys (manual probe via sample joins)
   ============================================================================ */
