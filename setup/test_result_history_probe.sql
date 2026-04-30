/* ============================================================================
   V_P_LAB_TEST_RESULT_HISTORY — discovery probe

   Schema (already captured from a column-list query):
     AA_ID, ATEST_AA_ID -> tr.AA_ID, TYPE (VARCHAR2 11),
     MOD_DATE/MOD_TIME/MOD_DT (numeric pair + DATE),
     MOD_TECH, MOD_REASON,
     PREV_RESULT (VARCHAR2 40), PREV_COMMENT (CLOB 4000),
     VER_DATE/VER_TIME/VER_DT/VER_TECH    (snapshot of verification triple),
     RES_DATE/RES_TIME/RES_DT/RES_TECH    (snapshot of resulting triple),
     ABNORMAL_FLAGS, UNITS, RANGE_NORMAL, RANGE_LOW, RANGE_HIGH,
     REFLABID, INTERPRET_MSG, IS_AUTORESULTED_WITH_DEFAULT,
     STATUS (VARCHAR2 12), QC_STATUS, ORGANIZATION_AA_ID, INTERPRETER_AA_ID,
     PANIC_REPEATED/_MSG/_ORDER, ISPOSTEDINFO_PRESENT, POSTED_FLAG,
     TESTING_WORKSTATION_ID

   Sample row observed: TYPE='RMOD', MOD_REASON='Result updated. Component
   results of this calculated test were edited', MOD_TECH != original
   verifier — i.e., amender is often a different person.

   Run sections sequentially. Each is independently executable.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   1. Volume + date span (30-day window on MOD_DT)
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS rows_30d,
    COUNT(DISTINCT ATEST_AA_ID)                    AS distinct_results_amended_30d,
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT ATEST_AA_ID), 0), 2)
                                                   AS amendments_per_result,
    MIN(MOD_DT)                                    AS earliest_mod,
    MAX(MOD_DT)                                    AS latest_mod
FROM V_P_LAB_TEST_RESULT_HISTORY
WHERE MOD_DT >= SYSDATE - 30;


/* ----------------------------------------------------------------------------
   2. TYPE enum — distinct values + frequency (30-day window)
   --------------------------------------------------------------------------- */
SELECT
    TYPE,
    COUNT(*)                                       AS row_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                                   AS pct,
    MIN(MOD_DT)                                    AS first_seen,
    MAX(MOD_DT)                                    AS last_seen
FROM V_P_LAB_TEST_RESULT_HISTORY
WHERE MOD_DT >= SYSDATE - 30
GROUP BY TYPE
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   3. STATUS enum — distinct values (snapshot of result status at mod time)
   --------------------------------------------------------------------------- */
SELECT
    STATUS,
    COUNT(*)                                       AS row_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                                   AS pct
FROM V_P_LAB_TEST_RESULT_HISTORY
WHERE MOD_DT >= SYSDATE - 30
GROUP BY STATUS
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   4. Population rates — which columns are vestigial vs workhorse
       Skips DATA_LENGTH=0 cols (none in this view per the column list).
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS total_rows,
    COUNT(ATEST_AA_ID)                             AS atest_pop,
    COUNT(TYPE)                                    AS type_pop,
    COUNT(MOD_DT)                                  AS mod_dt_pop,
    COUNT(MOD_TECH)                                AS mod_tech_pop,
    COUNT(MOD_REASON)                              AS mod_reason_pop,
    COUNT(PREV_RESULT)                             AS prev_result_pop,
    COUNT(VER_DT)                                  AS ver_dt_pop,
    COUNT(VER_TECH)                                AS ver_tech_pop,
    COUNT(RES_DT)                                  AS res_dt_pop,
    COUNT(RES_TECH)                                AS res_tech_pop,
    COUNT(ABNORMAL_FLAGS)                          AS abnormal_flags_pop,
    COUNT(UNITS)                                   AS units_pop,
    COUNT(RANGE_NORMAL)                            AS range_normal_pop,
    COUNT(RANGE_LOW)                               AS range_low_pop,
    COUNT(RANGE_HIGH)                              AS range_high_pop,
    COUNT(REFLABID)                                AS reflabid_pop,
    COUNT(INTERPRET_MSG)                           AS interpret_msg_pop,
    COUNT(IS_AUTORESULTED_WITH_DEFAULT)            AS autoresult_pop,
    COUNT(STATUS)                                  AS status_pop,
    COUNT(QC_STATUS)                               AS qc_status_pop,
    COUNT(ORGANIZATION_AA_ID)                      AS org_aa_pop,
    COUNT(INTERPRETER_AA_ID)                       AS interp_aa_pop,
    COUNT(PANIC_REPEATED)                          AS panic_repeated_pop,
    COUNT(PANIC_REPEATED_MSG)                      AS panic_msg_pop,
    COUNT(PANIC_REPEATED_ORDER)                    AS panic_order_pop,
    COUNT(ISPOSTEDINFO_PRESENT)                    AS posted_info_pop,
    COUNT(POSTED_FLAG)                             AS posted_flag_pop,
    COUNT(TESTING_WORKSTATION_ID)                  AS test_ws_pop
FROM V_P_LAB_TEST_RESULT_HISTORY
WHERE MOD_DT >= SYSDATE - 30;


/* ----------------------------------------------------------------------------
   5. Indexes on the underlying base table (via ALL_DEPENDENCIES → ALL_INDEXES)
       Confirms whether MOD_DT and ATEST_AA_ID are indexed — directly affects
       the report's join performance.
   --------------------------------------------------------------------------- */
SELECT
    dep.REFERENCED_NAME                                                   AS base_table,
    idx.INDEX_NAME,
    idx.UNIQUENESS,
    LISTAGG(ic.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ic.COLUMN_POSITION)
                                                                          AS index_columns
FROM ALL_DEPENDENCIES dep
    INNER JOIN ALL_INDEXES idx
        ON idx.TABLE_NAME  = dep.REFERENCED_NAME
       AND idx.TABLE_OWNER = dep.REFERENCED_OWNER
    INNER JOIN ALL_IND_COLUMNS ic
        ON ic.INDEX_NAME  = idx.INDEX_NAME
       AND ic.INDEX_OWNER = idx.OWNER
WHERE UPPER(dep.NAME)         = 'V_P_LAB_TEST_RESULT_HISTORY'
  AND dep.TYPE                = 'VIEW'
  AND dep.REFERENCED_TYPE     = 'TABLE'
GROUP BY dep.REFERENCED_NAME, idx.INDEX_NAME, idx.UNIQUENESS
ORDER BY idx.INDEX_NAME;


/* ----------------------------------------------------------------------------
   6. TYPE × current STATE correlation
       For each TYPE value, what STATE do the corresponding live results
       end up in? Tells us:
        - Is TYPE='RMOD' specifically the corrected-result amendment?
        - Are there TYPE values that fire on results that stay 'Final'
          (i.e., non-correction edits like un-verify/re-verify with no
          value change)?
   --------------------------------------------------------------------------- */
SELECT
    h.TYPE                                         AS amend_type,
    tr.STATE                                       AS curr_result_state,
    COUNT(*)                                       AS row_count,
    COUNT(DISTINCT h.ATEST_AA_ID)                  AS distinct_results,
    SUM(CASE WHEN h.PREV_RESULT IS NOT NULL
              AND h.PREV_RESULT <> tr.RESULT
             THEN 1 ELSE 0 END)                    AS rows_where_prev_diff_curr
FROM V_P_LAB_TEST_RESULT_HISTORY h
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = h.ATEST_AA_ID
WHERE h.MOD_DT >= SYSDATE - 30
GROUP BY h.TYPE, tr.STATE
ORDER BY h.TYPE, row_count DESC;


/* ----------------------------------------------------------------------------
   7. Sanity check — how many history rows per result?
       A flat 1:1 means most amendments are single-step.
       A long tail means we'll see real multi-amendment chains.
   --------------------------------------------------------------------------- */
WITH per_result AS (
    SELECT ATEST_AA_ID, COUNT(*) AS amendments
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= SYSDATE - 30
    GROUP BY ATEST_AA_ID
)
SELECT
    amendments,
    COUNT(*)                                       AS results_with_n_amendments,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                                   AS pct
FROM per_result
GROUP BY amendments
ORDER BY amendments;


/* ----------------------------------------------------------------------------
   8. Spot check — pick 3 multi-amendment results, dump their full history.
       History-only (no join to V_P_LAB_TEST_RESULT) so we don't pay the
       60M-row lookup cost. Confirms TYPE / PREV_RESULT / MOD_REASON look
       sane across a real multi-step chain.

       Replace MRN/names with placeholders before sharing — MOD_REASON can
       carry PHI in its narrative text.
   --------------------------------------------------------------------------- */
WITH chains AS (
    SELECT ATEST_AA_ID
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= SYSDATE - 30
    GROUP BY ATEST_AA_ID
    HAVING COUNT(*) >= 2
),
target AS (
    SELECT ATEST_AA_ID FROM chains WHERE ROWNUM <= 3
)
SELECT
    h.ATEST_AA_ID,
    h.MOD_DT,
    h.TYPE,
    h.MOD_TECH,
    SUBSTR(h.MOD_REASON, 1, 80)                    AS mod_reason_short,
    h.PREV_RESULT,
    h.UNITS,
    h.RANGE_NORMAL,
    h.STATUS                                       AS hist_status_snapshot
FROM V_P_LAB_TEST_RESULT_HISTORY h
WHERE h.ATEST_AA_ID IN (SELECT ATEST_AA_ID FROM target)
ORDER BY h.ATEST_AA_ID, h.MOD_DT;


/* ----------------------------------------------------------------------------
   9. TYPE enum lookup hunt — find any setup/reference object that decodes
       RMOD / DMOD / REVMOD into human meanings.

       SCC modules typically expose enums via V_S_* setup views. Three angles:
        (a) view/table name suggests amendment-type definitions
        (b) column comment mentions any of the observed values
        (c) any column literally named TYPE on a V_S_LAB_* view that could
            be the parent lookup
   --------------------------------------------------------------------------- */

-- 9a. Object-name search across SCC views for likely lookups
SELECT OWNER, OBJECT_NAME, OBJECT_TYPE
FROM ALL_OBJECTS
WHERE OBJECT_TYPE IN ('VIEW', 'TABLE')
  AND (   UPPER(OBJECT_NAME) LIKE '%MOD%'
       OR UPPER(OBJECT_NAME) LIKE '%HISTORY%'
       OR UPPER(OBJECT_NAME) LIKE '%AMEND%'
       OR UPPER(OBJECT_NAME) LIKE '%CORRECT%'
       OR UPPER(OBJECT_NAME) LIKE '%RMOD%'
       OR UPPER(OBJECT_NAME) LIKE '%DMOD%'
       OR UPPER(OBJECT_NAME) LIKE '%REVMOD%' )
  AND OWNER NOT IN ('SYS','SYSTEM','XDB','MDSYS','CTXSYS','APEX_040200','APEX_050000','APEX_180200')
ORDER BY OWNER, OBJECT_NAME;

-- 9b. Column-comment search across SCC for any string mentioning the values
SELECT OWNER, TABLE_NAME, COLUMN_NAME, COMMENTS
FROM ALL_COL_COMMENTS
WHERE (   UPPER(COMMENTS) LIKE '%RMOD%'
       OR UPPER(COMMENTS) LIKE '%DMOD%'
       OR UPPER(COMMENTS) LIKE '%REVMOD%'
       OR UPPER(COMMENTS) LIKE '%RESULT MOD%'
       OR UPPER(COMMENTS) LIKE '%AMENDMENT TYPE%'
       OR UPPER(COMMENTS) LIKE '%MODIFICATION TYPE%' )
  AND COMMENTS IS NOT NULL
ORDER BY OWNER, TABLE_NAME, COLUMN_NAME;

-- 9c. Table-comment search at object level (some lookups document themselves
--     in the table comment, not column comments)
SELECT OWNER, TABLE_NAME, COMMENTS
FROM ALL_TAB_COMMENTS
WHERE (   UPPER(COMMENTS) LIKE '%RMOD%'
       OR UPPER(COMMENTS) LIKE '%DMOD%'
       OR UPPER(COMMENTS) LIKE '%REVMOD%'
       OR UPPER(COMMENTS) LIKE '%MODIFICATION%'
       OR UPPER(COMMENTS) LIKE '%AMENDMENT%' )
  AND COMMENTS IS NOT NULL
ORDER BY OWNER, TABLE_NAME;

-- 9d. Check the LAB_ATEST_HISTORY base table for FK constraints — if TYPE
--     references a lookup table, it'll show up here.
SELECT
    cons.CONSTRAINT_NAME,
    cons.CONSTRAINT_TYPE,
    cons.R_CONSTRAINT_NAME                         AS references_constraint,
    LISTAGG(cc.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY cc.POSITION) AS local_cols
FROM ALL_CONSTRAINTS cons
INNER JOIN ALL_CONS_COLUMNS cc
    ON cc.CONSTRAINT_NAME = cons.CONSTRAINT_NAME
   AND cc.OWNER           = cons.OWNER
WHERE cons.TABLE_NAME = 'LAB_ATEST_HISTORY'
GROUP BY cons.CONSTRAINT_NAME, cons.CONSTRAINT_TYPE, cons.R_CONSTRAINT_NAME
ORDER BY cons.CONSTRAINT_TYPE, cons.CONSTRAINT_NAME;


/* ----------------------------------------------------------------------------
   10. V_S_GCM_CORRECTIONDICT probe — strongest candidate from §9a.
        If this contains rows like ('RMOD', 'Result modification'), we have
        our authoritative decode. If it's GCM-specific (cytogenetics codes),
        we'll know to keep treating RMOD/DMOD/REVMOD as observed-empirical
        rather than dictionary-backed.
   --------------------------------------------------------------------------- */

-- 10a. Schema
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE UPPER(TABLE_NAME) = 'V_S_GCM_CORRECTIONDICT'
ORDER BY COLUMN_ID;

-- 10b. Full contents — small lookup table, safe to dump
SELECT * FROM V_S_GCM_CORRECTIONDICT;


/* ----------------------------------------------------------------------------
   11. Sibling history views — does the RMOD/DMOD/REVMOD pattern repeat?
        Quick TYPE distinct-value probe on the other LAB history views
        surfaced by §9a. If they share the same enum, RMOD/DMOD are an
        SCC-wide LAB-module convention, not test-result-specific.
   --------------------------------------------------------------------------- */

-- 11a. Action history
SELECT 'V_P_LAB_ACT_HISTORY' AS source, TYPE, COUNT(*) AS row_count
FROM V_P_LAB_ACT_HISTORY
WHERE ROWNUM <= 100000  -- bound the scan; this view's volume is unknown
GROUP BY TYPE
ORDER BY row_count DESC;

-- 11b. Tube history
SELECT 'V_P_LAB_TUBE_HISTORY' AS source, TYPE, COUNT(*) AS row_count
FROM V_P_LAB_TUBE_HISTORY
WHERE ROWNUM <= 100000
GROUP BY TYPE
ORDER BY row_count DESC;


/* ============================================================================
   PART 2 — Probes for sibling tables touched during the print-template hunt
   ============================================================================
   Goal: collect dictionary-quality data (volume, population, enums, indexes)
   before folding these tables into CLAUDE.md alongside V_P_LAB_TEST_RESULT_HISTORY.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   12. V_P_LAB_INTERNAL_NOTE — volume + date span (use NOTE_DATETIME, the
       only DATE column)
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS total_rows,
    MIN(NOTE_DATETIME)                             AS earliest,
    MAX(NOTE_DATETIME)                             AS latest,
    SUM(CASE WHEN NOTE_DATETIME >= SYSDATE - 30 THEN 1 ELSE 0 END)
                                                   AS rows_30d
FROM V_P_LAB_INTERNAL_NOTE;


/* ----------------------------------------------------------------------------
   13. V_P_LAB_INTERNAL_NOTE — population rates (the 5 owner FKs are the
       discriminated-union test; ideally each row populates exactly one)
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS total_rows,
    COUNT(PATIENT_AA_ID)                           AS patient_pop,
    COUNT(STAY_AA_ID)                              AS stay_pop,
    COUNT(ORDER_AA_ID)                             AS order_pop,
    COUNT(TUBE_AA_ID)                              AS tube_pop,
    COUNT(TEST_RESULT_AA_ID)                       AS result_pop,
    COUNT(NOTE_TEXT)                               AS text_pop,
    COUNT(NOTE_CATEGORY)                           AS category_pop,
    COUNT(NOTE_TECH)                               AS tech_pop,
    COUNT(NOTE_DATETIME)                           AS dt_pop,
    COUNT(NOTE_CANMSG)                             AS canmsg_pop,
    COUNT(RECUR_AA_ID)                             AS recur_pop,
    -- Discriminated-union test: how often is exactly one owner FK populated?
    SUM(CASE WHEN
            (CASE WHEN PATIENT_AA_ID     IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN STAY_AA_ID        IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN ORDER_AA_ID       IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN TUBE_AA_ID        IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN TEST_RESULT_AA_ID IS NOT NULL THEN 1 ELSE 0 END)
          = 1 THEN 1 ELSE 0 END)                   AS exactly_one_owner_rows
FROM V_P_LAB_INTERNAL_NOTE;


/* ----------------------------------------------------------------------------
   14. V_P_LAB_INTERNAL_NOTE — NOTE_CATEGORY enum
   --------------------------------------------------------------------------- */
SELECT NOTE_CATEGORY, COUNT(*) AS row_count
FROM V_P_LAB_INTERNAL_NOTE
GROUP BY NOTE_CATEGORY
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   15. V_P_LAB_INTERNAL_NOTE — NOTE_TECH distribution (system vs human)
   --------------------------------------------------------------------------- */
SELECT NOTE_TECH, COUNT(*) AS row_count
FROM V_P_LAB_INTERNAL_NOTE
GROUP BY NOTE_TECH
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   16. V_P_LAB_INTERNAL_NOTE — NOTE_CANMSG patterns + indexes
   --------------------------------------------------------------------------- */

-- 16a. NOTE_CANMSG enum (we saw |R, |RRES — bar-prefix likely a convention)
SELECT NOTE_CANMSG, COUNT(*) AS row_count
FROM V_P_LAB_INTERNAL_NOTE
WHERE NOTE_CANMSG IS NOT NULL
GROUP BY NOTE_CANMSG
ORDER BY row_count DESC;

-- 16b. Indexes on the underlying base table
SELECT
    dep.REFERENCED_NAME                                                   AS base_table,
    idx.INDEX_NAME,
    idx.UNIQUENESS,
    LISTAGG(ic.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ic.COLUMN_POSITION)
                                                                          AS index_columns
FROM ALL_DEPENDENCIES dep
    INNER JOIN ALL_INDEXES idx
        ON idx.TABLE_NAME  = dep.REFERENCED_NAME
       AND idx.TABLE_OWNER = dep.REFERENCED_OWNER
    INNER JOIN ALL_IND_COLUMNS ic
        ON ic.INDEX_NAME  = idx.INDEX_NAME
       AND ic.INDEX_OWNER = idx.OWNER
WHERE UPPER(dep.NAME)         = 'V_P_LAB_INTERNAL_NOTE'
  AND dep.TYPE                = 'VIEW'
  AND dep.REFERENCED_TYPE     = 'TABLE'
GROUP BY dep.REFERENCED_NAME, idx.INDEX_NAME, idx.UNIQUENESS
ORDER BY idx.INDEX_NAME;


/* ----------------------------------------------------------------------------
   17. V_S_LAB_CANNED_MESSAGE — volume, active/expired split
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                                       AS total_rows,
    COUNT(DISTINCT ID)                                             AS distinct_message_ids,
    SUM(CASE WHEN ACTIVE = 'Y' THEN 1 ELSE 0 END)                  AS active_rows,
    SUM(CASE WHEN ACTIVE = 'N' THEN 1 ELSE 0 END)                  AS inactive_rows,
    SUM(CASE WHEN EXP_DT < SYSDATE THEN 1 ELSE 0 END)              AS expired_rows,
    SUM(CASE WHEN EXP_DT >= SYSDATE OR EXP_DT IS NULL THEN 1 ELSE 0 END)
                                                                   AS unexpired_rows
FROM V_S_LAB_CANNED_MESSAGE;


/* ----------------------------------------------------------------------------
   18. V_S_LAB_CANNED_MESSAGE — population rates per column
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*)                                       AS total_rows,
    COUNT(AA_ID)                                   AS aa_id_pop,
    COUNT(ID)                                      AS id_pop,
    COUNT(TEXT)                                    AS text_pop,
    COUNT(ACTIVE)                                  AS active_pop,
    COUNT(EXP_DATE)                                AS exp_date_pop,
    COUNT(LINE_NUMBER)                             AS line_number_pop,
    COUNT(NEW_LINE)                                AS new_line_pop,
    COUNT(EXP_DT)                                  AS exp_dt_pop,
    COUNT(CATEGORY)                                AS category_pop,
    COUNT(DISCARD_CONTAINER)                       AS discard_container_pop
FROM V_S_LAB_CANNED_MESSAGE;


/* ----------------------------------------------------------------------------
   19. V_S_LAB_CANNED_MESSAGE — CATEGORY enum (we saw OTHER/RNG/RESUL/MICI/MICT
       in samples; the full enum is the dictionary-grade question)
   --------------------------------------------------------------------------- */
SELECT
    CATEGORY,
    COUNT(*)                                       AS row_count,
    COUNT(DISTINCT ID)                             AS distinct_messages
FROM V_S_LAB_CANNED_MESSAGE
GROUP BY CATEGORY
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   20. V_S_LAB_CANNED_MESSAGE — ID prefix-character analysis
       SCC system-reserved messages use special-character prefixes
       (&, }, @, |, $ — saw &CORR, }CORR, @CRR). This shows the convention's
       full vocabulary.
   --------------------------------------------------------------------------- */
SELECT
    SUBSTR(ID, 1, 1)                               AS first_char,
    CASE WHEN REGEXP_LIKE(SUBSTR(ID, 1, 1), '^[A-Za-z0-9]$')
         THEN 'alphanumeric (user-defined)'
         ELSE 'special (system-reserved)'
    END                                            AS id_class,
    COUNT(*)                                       AS row_count,
    COUNT(DISTINCT ID)                             AS distinct_messages
FROM V_S_LAB_CANNED_MESSAGE
GROUP BY SUBSTR(ID, 1, 1),
         CASE WHEN REGEXP_LIKE(SUBSTR(ID, 1, 1), '^[A-Za-z0-9]$')
              THEN 'alphanumeric (user-defined)'
              ELSE 'special (system-reserved)' END
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   21. V_S_LAB_CANNED_MESSAGE — multi-line message patterns
       LINE_NUMBER > 0 means the message has continuation lines. How common?
   --------------------------------------------------------------------------- */
SELECT
    lines_per_message,
    COUNT(*)                                       AS message_count
FROM (
    SELECT ID, COUNT(*) AS lines_per_message
    FROM V_S_LAB_CANNED_MESSAGE
    GROUP BY ID
)
GROUP BY lines_per_message
ORDER BY lines_per_message;


/* ----------------------------------------------------------------------------
   22. V_S_LAB_CANNED_MESSAGE — base table + indexes
   --------------------------------------------------------------------------- */
SELECT
    dep.REFERENCED_NAME                                                   AS base_table,
    idx.INDEX_NAME,
    idx.UNIQUENESS,
    LISTAGG(ic.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ic.COLUMN_POSITION)
                                                                          AS index_columns
FROM ALL_DEPENDENCIES dep
    INNER JOIN ALL_INDEXES idx
        ON idx.TABLE_NAME  = dep.REFERENCED_NAME
       AND idx.TABLE_OWNER = dep.REFERENCED_OWNER
    INNER JOIN ALL_IND_COLUMNS ic
        ON ic.INDEX_NAME  = idx.INDEX_NAME
       AND ic.INDEX_OWNER = idx.OWNER
WHERE UPPER(dep.NAME)         = 'V_S_LAB_CANNED_MESSAGE'
  AND dep.TYPE                = 'VIEW'
  AND dep.REFERENCED_TYPE     = 'TABLE'
GROUP BY dep.REFERENCED_NAME, idx.INDEX_NAME, idx.UNIQUENESS
ORDER BY idx.INDEX_NAME;


/* ----------------------------------------------------------------------------
   23. V_P_LAB_TEST_RESULT_HISTORY — long-window TYPE check
       Confirms RMOD/DMOD/REVMOD is the FULL enum, not just the
       30-day-window subset. Wider window = more confidence about absent
       values (e.g., UNVERIFY, AUTOMOD, etc.).

       Uses 1-year window; on a small table (~85K rows/year) this is cheap.
   --------------------------------------------------------------------------- */
SELECT
    TYPE,
    COUNT(*)                                       AS row_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                                   AS pct,
    MIN(MOD_DT)                                    AS first_seen,
    MAX(MOD_DT)                                    AS last_seen
FROM V_P_LAB_TEST_RESULT_HISTORY
WHERE MOD_DT >= SYSDATE - 365
GROUP BY TYPE
ORDER BY row_count DESC;


/* ============================================================================
   FOLLOW-UP: FMOD discovery (2026-04-28)

   The §23 1-year window concluded RMOD/DMOD/REVMOD was the full enum, and
   the CLAUDE.md V_P_LAB_TEST_RESULT_HISTORY section was written based on
   that finding. A user-supplied screenshot of the SCC client's History
   tab (Result Comments dialog) on a GLU result from 2026-04-24 shows a
   row tagged 'FMOD' with text "Revised: Comment was added, verified by
   TKAZ at 23:27 on 04/24/2026" — directly contradicting the documented
   enum.

   Sections 24-30 below probe whether FMOD exists in the database, how
   often, when it started appearing, what fields it populates differently
   than RMOD, and whether it always co-occurs with another TYPE.

   Run sequentially.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   24. Full-table TYPE re-survey (no date window)
       The §23 probe used SYSDATE - 365. If FMOD is rarer than ~1 row/year
       it would have escaped that window. Run with no window to catch
       every TYPE value that has ever been written.
   --------------------------------------------------------------------------- */
SELECT
    TYPE,
    COUNT(*)                                       AS row_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 4)
                                                   AS pct,
    MIN(MOD_DT)                                    AS first_seen,
    MAX(MOD_DT)                                    AS last_seen
FROM V_P_LAB_TEST_RESULT_HISTORY
GROUP BY TYPE
ORDER BY row_count DESC;


/* ----------------------------------------------------------------------------
   25. TYPE distribution by year
       Tells us if FMOD is steady-state-but-rare, brand new (e.g., a recent
       SCC client release added it), or ancient/legacy.
   --------------------------------------------------------------------------- */
SELECT
    EXTRACT(YEAR FROM MOD_DT)                      AS yr,
    TYPE,
    COUNT(*)                                       AS row_count
FROM V_P_LAB_TEST_RESULT_HISTORY
GROUP BY EXTRACT(YEAR FROM MOD_DT), TYPE
ORDER BY yr DESC, row_count DESC;


/* ----------------------------------------------------------------------------
   26. FMOD sample rows — populated fields, content patterns
       Pull recent FMOD rows directly. Compare which fields are populated
       and inspect MOD_REASON / PREV_RESULT / PREV_COMMENT to infer FMOD
       semantics.

       NOTE: PREV_COMMENT is CLOB — preview only the first 200 chars to
       avoid giant outputs.
   --------------------------------------------------------------------------- */
SELECT
    h.AA_ID,
    h.ATEST_AA_ID,
    h.MOD_DT,
    h.MOD_TECH,
    h.MOD_REASON,
    h.PREV_RESULT,
    h.UNITS,
    h.STATUS,
    h.VER_TECH,
    h.VER_DT,
    h.RES_TECH,
    h.RES_DT,
    DBMS_LOB.SUBSTR(h.PREV_COMMENT, 200, 1)        AS prev_comment_preview
FROM V_P_LAB_TEST_RESULT_HISTORY h
WHERE h.TYPE = 'FMOD'
  AND ROWNUM <= 25
ORDER BY h.MOD_DT DESC;


/* ----------------------------------------------------------------------------
   27. Field-population fingerprint per TYPE
       For each TYPE, what fraction of rows have each field populated.
       The History-tab template differs by TYPE, so the underlying field
       population should differ too:
         - RMOD template: "Previous value was {PREV_RESULT} {UNITS}, verified
           by {VER_TECH} at {time} on {date}" → expect high PREV_RESULT/UNITS
         - FMOD template: "Revised: Comment was added, verified by {VER_TECH}
           at {time} on {date}" → expect PREV_COMMENT populated, PREV_RESULT
           may be unchanged from RMOD pattern (snapshot field)

       Uses the full table — FMOD volume might be too small for a windowed
       sample to characterize.
   --------------------------------------------------------------------------- */
SELECT
    TYPE,
    COUNT(*)                                       AS total,
    SUM(CASE WHEN MOD_REASON IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_mod_reason,
    SUM(CASE WHEN PREV_RESULT IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_prev_result,
    SUM(CASE WHEN UNITS IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_units,
    SUM(CASE WHEN STATUS IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_status,
    SUM(CASE WHEN VER_DT IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_ver_dt,
    SUM(CASE WHEN RES_DT IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_res_dt,
    SUM(CASE WHEN PREV_COMMENT IS NOT NULL
              AND DBMS_LOB.GETLENGTH(PREV_COMMENT) > 0 THEN 1 ELSE 0 END)
                                                   AS n_prev_comment,
    SUM(CASE WHEN ABNORMAL_FLAGS IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_abnormal_flags,
    SUM(CASE WHEN RANGE_NORMAL IS NOT NULL THEN 1 ELSE 0 END)
                                                   AS n_range_normal
FROM V_P_LAB_TEST_RESULT_HISTORY
GROUP BY TYPE
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   28. TYPE x value-changed correlation (re-baseline)
       §6 ran this at 30 days against RMOD/DMOD only. Re-run with FMOD in
       the mix. Hypothesis: FMOD is a comment-modification class — value
       should NOT change on FMOD rows (similar to DMOD).
   --------------------------------------------------------------------------- */
WITH hist_with_next AS (
    SELECT
        h.ATEST_AA_ID,
        h.AA_ID,
        h.TYPE,
        h.PREV_RESULT,
        LEAD(h.PREV_RESULT) OVER (PARTITION BY h.ATEST_AA_ID
                                  ORDER BY h.MOD_DT, h.AA_ID)
                                                   AS next_prev_result
    FROM V_P_LAB_TEST_RESULT_HISTORY h
    WHERE h.MOD_DT >= SYSDATE - 90
)
SELECT
    hwn.TYPE,
    COUNT(*)                                       AS total,
    SUM(CASE WHEN DECODE(hwn.PREV_RESULT,
                         COALESCE(hwn.next_prev_result, tr.RESULT),
                         1, 0) = 0 THEN 1 ELSE 0 END)
                                                   AS value_changed,
    SUM(CASE WHEN DECODE(hwn.PREV_RESULT,
                         COALESCE(hwn.next_prev_result, tr.RESULT),
                         1, 0) = 1 THEN 1 ELSE 0 END)
                                                   AS value_unchanged
FROM hist_with_next hwn
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = hwn.ATEST_AA_ID
GROUP BY hwn.TYPE
ORDER BY total DESC;


/* ----------------------------------------------------------------------------
   29. Per-result TYPE combinations
       The screenshot shows FMOD and RMOD co-occurring on the same result.
       Does FMOD always co-occur with another TYPE, or can it stand alone?
       Useful for understanding whether FMOD is a side-effect of another
       modification class or an independent event.

       Oracle 19c: no LISTAGG(DISTINCT...) — pre-DISTINCT then aggregate.
   --------------------------------------------------------------------------- */
WITH distinct_pairs AS (
    SELECT DISTINCT
           ATEST_AA_ID,
           TYPE
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= SYSDATE - 90
),
per_result AS (
    SELECT
        ATEST_AA_ID,
        LISTAGG(TYPE, ',') WITHIN GROUP (ORDER BY TYPE)
                                                   AS type_combo
    FROM distinct_pairs
    GROUP BY ATEST_AA_ID
)
SELECT
    type_combo,
    COUNT(*)                                       AS atest_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                                   AS pct
FROM per_result
GROUP BY type_combo
ORDER BY atest_count DESC;


/* ----------------------------------------------------------------------------
   30. Ground-truth: surface the screenshot example
       GLU result, 2026-04-24, with FMOD by TKAZ at 23:27 and RMOD by
       THOMAS at 23:07 referenced in the History tab. Pull both rows from
       V_P_LAB_TEST_RESULT_HISTORY directly to confirm the data matches
       the client display, and to grab ATEST_AA_ID for follow-up joins.
   --------------------------------------------------------------------------- */
SELECT
    h.AA_ID,
    h.ATEST_AA_ID,
    h.TYPE,
    h.MOD_DT,
    h.MOD_TECH,
    h.MOD_REASON,
    h.PREV_RESULT,
    h.UNITS,
    h.VER_TECH,
    h.VER_DT,
    DBMS_LOB.SUBSTR(h.PREV_COMMENT, 400, 1)        AS prev_comment_preview
FROM V_P_LAB_TEST_RESULT_HISTORY h
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = h.ATEST_AA_ID
WHERE h.MOD_DT >= TO_DATE('2026-04-24', 'YYYY-MM-DD')
  AND h.MOD_DT <  TO_DATE('2026-04-25', 'YYYY-MM-DD')
  AND tr.TEST_ID = 'GLU'
  AND h.TYPE IN ('FMOD', 'RMOD')
ORDER BY h.MOD_DT, h.AA_ID;


/* ----------------------------------------------------------------------------
   30b. Same GLU result — ALL history rows (no TYPE filter)
        §30 returned a single RMOD row, but the SCC client UI showed two
        History-tab entries. Either the client renders one DB row as two
        UI lines (split-display theory), or there's a DMOD/REVMOD row at
        23:27 that the §30 TYPE filter excluded.

        This re-run pins it down: same ATEST_AA_ID, no TYPE filter, also
        widens the date window in case rows landed outside 04/24.
   --------------------------------------------------------------------------- */
SELECT
    h.AA_ID,
    h.ATEST_AA_ID,
    h.TYPE,
    h.MOD_DT,
    h.MOD_TECH,
    h.MOD_REASON,
    h.PREV_RESULT,
    h.UNITS,
    h.VER_TECH,
    h.VER_DT,
    h.RES_TECH,
    h.RES_DT,
    DBMS_LOB.SUBSTR(h.PREV_COMMENT, 400, 1)        AS prev_comment_preview
FROM V_P_LAB_TEST_RESULT_HISTORY h
WHERE h.ATEST_AA_ID = 690477560
ORDER BY h.MOD_DT, h.AA_ID;


/* ============================================================================
   FOLLOW-UP: MOD_TECH person-vs-system classification (2026-04-28)

   To distinguish manual-human amendments from system-process amendments
   in the corrected-results report, we need to classify each MOD_TECH
   value. Two questions for the data:

     §31  Distinct MOD_TECH values + V_S_LAB_PHLEBOTOMIST join coverage
          across recent amendments. Tells us how many amenders are real
          people vs. system identities vs. unknown.

     §32  Whether V_P_ARE_SCCSECUSER (SCC security user view from the
          AR module) covers the gaps left by V_S_LAB_PHLEBOTOMIST.
          Hypothesis: SCC's auth user table is more comprehensive than
          the lab-phleb roster, which is mostly collector role codes.

   Known system identities (from accumulated dictionary findings):
     HIS, SCC, AUTOV, RBS — these should classify as 'System' even if
     they happen to appear in V_S_LAB_PHLEBOTOMIST.

   Known role codes in V_S_LAB_PHLEBOTOMIST (not real people):
     PHLEB, NUR, PHY, PAT, UNK
   ============================================================================ */


/* ----------------------------------------------------------------------------
   31. MOD_TECH distribution + phleb join coverage (90-day window)
       Per distinct MOD_TECH: how many amendment rows, whether it joins
       to V_S_LAB_PHLEBOTOMIST, and a coarse classification.

       Output is sorted by row volume so the highest-volume amenders
       surface first — useful for sanity-checking that the top amenders
       are indeed real techs (or for spotting an unexpected system
       identity dominating the data).
   --------------------------------------------------------------------------- */
WITH recent_mod_tech AS (
    SELECT
        MOD_TECH,
        COUNT(*)                                       AS amendment_rows
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= SYSDATE - 90
    GROUP BY MOD_TECH
)
SELECT
    rmt.MOD_TECH,
    rmt.amendment_rows,
    phleb.LAST_NAME,
    phleb.FIRST_NAME,
    phleb.NURSE,
    phleb.ACTIVE,
    CASE
        WHEN rmt.MOD_TECH IS NULL OR rmt.MOD_TECH = '' THEN 'Empty'
        WHEN rmt.MOD_TECH IN ('HIS','SCC','AUTOV','RBS')
            THEN 'System (known)'
        WHEN rmt.MOD_TECH IN ('PHLEB','NUR','PHY','PAT','UNK')
            THEN 'Role code'
        WHEN phleb.ID IS NOT NULL
         AND phleb.LAST_NAME IS NOT NULL
         AND phleb.LAST_NAME <> ''
            THEN 'Person'
        WHEN phleb.ID IS NOT NULL
            THEN 'Phleb match (no name)'
        ELSE 'Unknown (no phleb match)'
    END                                                AS classification
FROM recent_mod_tech rmt
LEFT JOIN V_S_LAB_PHLEBOTOMIST phleb
       ON phleb.ID = rmt.MOD_TECH
ORDER BY rmt.amendment_rows DESC;


/* ----------------------------------------------------------------------------
   32. V_P_ARE_SCCSECUSER coverage probe — does the AR security-user
       view fill the V_S_LAB_PHLEBOTOMIST gap?

       Ungrounded-discovery probe: I haven't seen the V_P_ARE_SCCSECUSER
       column list yet. This SELECT * with ROWNUM <= 5 surfaces it.
       If it has an ID/USERNAME and name fields, run it as the
       follow-on join target.
   --------------------------------------------------------------------------- */
SELECT *
FROM V_P_ARE_SCCSECUSER
WHERE ROWNUM <= 5;


/* ----------------------------------------------------------------------------
   32b. (Run this after seeing 32's column list) — coverage join
        Replace USERNAME_COL / LASTNAME_COL with the actual columns.
        This template mirrors §31 but joins V_P_ARE_SCCSECUSER instead.
   --------------------------------------------------------------------------- */
-- WITH recent_mod_tech AS (
--     SELECT
--         MOD_TECH,
--         COUNT(*)                                       AS amendment_rows
--     FROM V_P_LAB_TEST_RESULT_HISTORY
--     WHERE MOD_DT >= SYSDATE - 90
--     GROUP BY MOD_TECH
-- )
-- SELECT
--     rmt.MOD_TECH,
--     rmt.amendment_rows,
--     u.<LASTNAME_COL>                                   AS last_name,
--     u.<FIRSTNAME_COL>                                  AS first_name,
--     CASE
--         WHEN u.<USERNAME_COL> IS NOT NULL THEN 'AR-user matched'
--         ELSE 'No AR-user match'
--     END                                                AS coverage
-- FROM recent_mod_tech rmt
-- LEFT JOIN V_P_ARE_SCCSECUSER u
--        ON u.<USERNAME_COL> = rmt.MOD_TECH
-- ORDER BY rmt.amendment_rows DESC;


/* ----------------------------------------------------------------------------
   33. Schema discovery — what owners can this connection see?
       Cross-checks whether there's an SCC, SCCSEC, SOFTSEC, or similar
       schema beyond LAB that might host the global user store.
   --------------------------------------------------------------------------- */
SELECT
    OWNER,
    COUNT(*)                                       AS object_count
FROM ALL_OBJECTS
WHERE OBJECT_TYPE IN ('TABLE', 'VIEW')
GROUP BY OWNER
ORDER BY object_count DESC;


/* ----------------------------------------------------------------------------
   34. User/security-like objects — name-pattern scan across ALL schemas
       Catches anything with USER, SEC, AUTH, or LOGIN in the object name,
       regardless of which schema owns it. Surfaces candidates we don't
       know about yet.
   --------------------------------------------------------------------------- */
SELECT
    OWNER,
    OBJECT_TYPE,
    OBJECT_NAME
FROM ALL_OBJECTS
WHERE OBJECT_TYPE IN ('TABLE', 'VIEW')
  AND ( UPPER(OBJECT_NAME) LIKE '%USER%'
     OR UPPER(OBJECT_NAME) LIKE '%SEC%'
     OR UPPER(OBJECT_NAME) LIKE '%AUTH%'
     OR UPPER(OBJECT_NAME) LIKE '%LOGIN%' )
  AND OWNER NOT IN ('SYS', 'SYSTEM', 'XDB', 'CTXSYS', 'MDSYS',
                    'OLAPSYS', 'ORDSYS', 'WMSYS', 'EXFSYS',
                    'APEX_030200', 'APEX_040000', 'APEX_040200',
                    'PUBLIC', 'OUTLN', 'DBSNMP', 'APPQOSSYS',
                    'AUDSYS', 'GSMADMIN_INTERNAL', 'ORDDATA',
                    'DVSYS', 'LBACSYS', 'OJVMSYS')
ORDER BY OWNER, OBJECT_NAME;


/* ----------------------------------------------------------------------------
   35. Column-name scan — find tables/views with user-name-shaped fields
       Catches user stores that don't have USER/SEC/AUTH in the object
       name but DO have USERNAME / USER_ID / LASTNAME / FIRSTNAME columns.
       Restricts to likely owners to keep result count manageable.
   --------------------------------------------------------------------------- */
SELECT
    OWNER,
    TABLE_NAME,
    LISTAGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY COLUMN_NAME)
                                                   AS user_shaped_cols
FROM ALL_TAB_COLUMNS
WHERE UPPER(COLUMN_NAME) IN (
        'USERNAME', 'USER_NAME', 'USERID', 'USER_ID', 'USERCODE', 'USER_CODE',
        'LOGIN', 'LOGIN_ID', 'LOGINID',
        'EMP_ID', 'EMPLOYEE_ID', 'EMPLOYEEID',
        'INITIALS', 'TECH_INITIALS'
      )
  AND OWNER NOT IN ('SYS', 'SYSTEM', 'XDB', 'CTXSYS', 'MDSYS',
                    'OLAPSYS', 'ORDSYS', 'WMSYS', 'EXFSYS',
                    'APEX_030200', 'APEX_040000', 'APEX_040200',
                    'PUBLIC', 'OUTLN', 'DBSNMP', 'APPQOSSYS',
                    'AUDSYS', 'GSMADMIN_INTERNAL', 'ORDDATA',
                    'DVSYS', 'LBACSYS', 'OJVMSYS')
GROUP BY OWNER, TABLE_NAME
ORDER BY OWNER, TABLE_NAME;


/* ----------------------------------------------------------------------------
   36. Cross-check: does any candidate object actually contain MOD_TECH-
       shaped values? Tests a specific known MOD_TECH (TKAZ from the
       earlier GLU example) against every candidate table the previous
       probes turned up.

       Usage: after §34 / §35 surface candidates, fill in the table
       names below and run. A table with TKAZ in its data is almost
       certainly the user store.

       (Filled with V_P_ARE_SCCSECUSER as a starting candidate;
       add UNION ALLs for each new candidate from §34 / §35.)
   --------------------------------------------------------------------------- */
-- SELECT 'V_P_ARE_SCCSECUSER' AS source, COUNT(*) AS tkaz_match_rows
-- FROM V_P_ARE_SCCSECUSER
-- WHERE UPPER(<some_id_col>) = 'TKAZ'
-- UNION ALL
-- SELECT '<another candidate>' AS source, COUNT(*) AS tkaz_match_rows
-- FROM <another candidate>
-- WHERE UPPER(<some_id_col>) = 'TKAZ';


/* ============================================================================
   SCC SECURITY MODULE DISCOVERY (2026-04-28)

   §34 surfaced the SCC Security module's view family in the SCCODBC schema:
     V_S_SEC_USER             — primary user account view (likely)
     V_S_SEC_USER_EXT         — user extension fields
     V_S_SEC_CONTACT_INFO     — names / contact details (likely)
     V_S_SEC_USERROLES        — user role assignments
     V_S_SEC_USERSITEROLE     — user site/role mapping
     V_S_SEC_USER_GROUP       — user-to-group assignments
     V_S_SEC_GROUP_ASSIGNMENT — group assignments
   plus ~25 more (printers, terminals, system params, etc.).

   The SCCODBC schema is separate from LAB. Queries below try
   unqualified names first; if Oracle returns ORA-00942 (table/view
   does not exist), prefix with SCCODBC. (e.g. SCCODBC.V_S_SEC_USER).

   Goal: identify which view holds the join key matching MOD_TECH
   and which holds the human-readable name fields, then build the
   right enrichment for corrected_results_summary.sql.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   37. V_S_SEC_USER column discovery
   --------------------------------------------------------------------------- */
SELECT *
FROM V_S_SEC_USER
WHERE ROWNUM <= 5;


/* ----------------------------------------------------------------------------
   38. V_S_SEC_USER_EXT column discovery
   --------------------------------------------------------------------------- */
SELECT *
FROM V_S_SEC_USER_EXT
WHERE ROWNUM <= 5;


/* ----------------------------------------------------------------------------
   39. V_S_SEC_CONTACT_INFO column discovery
        Likely the source of LAST_NAME / FIRST_NAME for users.
   --------------------------------------------------------------------------- */
SELECT *
FROM V_S_SEC_CONTACT_INFO
WHERE ROWNUM <= 5;


/* ----------------------------------------------------------------------------
   40. Locate TKAZ across the three security views simultaneously
       Uses the GLU/2026-04-24 example's MOD_TECH = 'TKAZ' as a known
       lab-tech value. Whichever view returns a row tells us which is
       the right join target for MOD_TECH.

       This query uses dynamic column probing — searches every column
       in each view for 'TKAZ'. If your client doesn't support multi-
       column predicates well, run §37/§38/§39 first and grep the
       output instead.
   --------------------------------------------------------------------------- */
-- One-liner version: count how many rows contain 'TKAZ' in any varchar field.
-- Run §37/§38/§39 first to identify the actual ID/USERNAME column,
-- then write a targeted probe like:
--
--   SELECT 'V_S_SEC_USER' AS view_name, <id_col>, <name_col>
--   FROM V_S_SEC_USER
--   WHERE UPPER(<id_col>) = 'TKAZ';
--
-- (Filling this in once §37 reveals the column names.)


/* ----------------------------------------------------------------------------
   41. Ground-truth: confirm TKAZ joins to V_S_SEC_USER via TECH_ID
        From §37 we know the join key is V_S_SEC_USER.TECH_ID
        (uppercase 3–5 char tech initials). The GLU/2026-04-24 example's
        MOD_TECH was 'TKAZ' (Tom Kaznowski). This grounds the join.
   --------------------------------------------------------------------------- */
SELECT
    AA_ID,
    USER_ID,
    TECH_ID,
    LASTNAME,
    FIRSTNAME,
    MIDDLENAME,
    ACTIVE,
    ROLE,
    DEPARTMENT
FROM V_S_SEC_USER
WHERE TECH_ID = 'TKAZ';


/* ----------------------------------------------------------------------------
   42. MOD_TECH × V_S_SEC_USER coverage (90-day window)
       Per distinct MOD_TECH on V_P_LAB_TEST_RESULT_HISTORY, how many
       amendments + whether it joins to V_S_SEC_USER.

       Replaces §31 (V_S_LAB_PHLEBOTOMIST coverage) — that was the
       wrong target. V_S_SEC_USER is the SCC Security module's user
       store and should cover real lab techs.

       Output sorted by volume so high-frequency amenders surface first.
   --------------------------------------------------------------------------- */
WITH recent_mod_tech AS (
    SELECT
        MOD_TECH,
        COUNT(*)                                       AS amendment_rows
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= SYSDATE - 90
    GROUP BY MOD_TECH
)
SELECT
    rmt.MOD_TECH,
    rmt.amendment_rows,
    usr.LASTNAME,
    usr.FIRSTNAME,
    usr.ROLE,
    usr.ACTIVE,
    usr.DEPARTMENT,
    CASE
        WHEN rmt.MOD_TECH IS NULL OR rmt.MOD_TECH = ''
            THEN 'Empty'
        WHEN rmt.MOD_TECH IN ('HIS','SCC','AUTOV','RBS')
            THEN 'System'
        WHEN usr.TECH_ID IS NOT NULL
         AND usr.LASTNAME IS NOT NULL
         AND usr.LASTNAME <> ''
            THEN 'Person'
        WHEN usr.TECH_ID IS NOT NULL
            THEN 'User (no name)'
        ELSE 'Unknown'
    END                                                AS classification
FROM recent_mod_tech rmt
LEFT JOIN V_S_SEC_USER usr
       ON usr.TECH_ID = rmt.MOD_TECH
ORDER BY rmt.amendment_rows DESC;


/* ============================================================================
   §§43-51 — SCC Security module deep-probe
   Source: setup/dictionary_pdf_discrepancies.md §3 (V_S_SEC_USER outstanding
           questions, plus V_S_SEC_USERROLES / V_S_SEC_CONTACT_INFO /
           V_S_SEC_USER_GROUP / V_S_SEC_GROUP_ASSIGNMENT /
           V_S_SEC_GROUP_ROLES_MAPPING that aren't characterized yet).

   Use case: enrich corrected_results_summary.sql with role / group /
   contact context so a downstream auditor can answer
     - "Was the amender a Lab Tech, Pathologist, or Sysadmin?"
     - "Which department/group does this amender belong to?"
     - "Are there active+human amendments by accounts with elevated
       (Emergency / Future-deactivated / SCC_USER) flags?"

   Goals
     1. Catalog every V_S_SEC_* view available
     2. Profile V_S_SEC_USER's open enums + flags
     3. Find the role-assignment view (V_S_SEC_USERROLES) and its role
        master, and confirm the join keys
     4. Find the group-membership chain (USER_GROUP, GROUP_ASSIGNMENT,
        GROUP_ROLES_MAPPING) and confirm the join keys
     5. Verify whether V_S_SEC_CONTACT_INFO duplicates V_S_SEC_USER's
        name fields or carries different/extended demographics
     6. Compose a forward-looking enrichment template for
        corrected_results_summary.sql

   Expectation: SCCODBC-prefixed names may be required in some clients.
   The catalog query in §43 also surfaces the schema owner so subsequent
   queries can be qualified if needed.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   43. Full V_S_SEC_* view catalog
       Lists every Security-module view visible to the connected user
       with column count and (rough) row count. Establishes the actual
       view inventory in this deployment vs. the dict's reference list.
   --------------------------------------------------------------------------- */
SELECT
    o.OWNER,
    o.OBJECT_NAME,
    o.OBJECT_TYPE,
    (SELECT COUNT(*) FROM ALL_TAB_COLUMNS c
       WHERE c.OWNER = o.OWNER
         AND c.TABLE_NAME = o.OBJECT_NAME)               AS column_count,
    o.CREATED,
    o.LAST_DDL_TIME
FROM ALL_OBJECTS o
WHERE o.OBJECT_NAME LIKE 'V_S_SEC%'
  AND o.OBJECT_TYPE IN ('VIEW','TABLE')
ORDER BY o.OWNER, o.OBJECT_NAME;


/* ----------------------------------------------------------------------------
   44. V_S_SEC_USER population profile
       Open questions from the discrepancies file:
         - Full ROLE enum (only U/R observed in 5-row sample)
         - Are negative ID values a sign-flipped sequence vs. a tier?
         - SCC_USER flag — system vs. human accounts?
         - EMERGENCY_ACCESS / EMERGENCY_ROLE / FUTURE_ACTIVATE_DATE /
           FUTURE_DEACTIVATE_DATE — when populated?
         - ACTIVE distribution
   --------------------------------------------------------------------------- */
-- 44a. ROLE enum
SELECT ROLE, COUNT(*) AS rows_in_role
FROM V_S_SEC_USER
GROUP BY ROLE
ORDER BY rows_in_role DESC;

-- 44b. ACTIVE distribution
SELECT ACTIVE, COUNT(*) AS rows_in_state
FROM V_S_SEC_USER
GROUP BY ACTIVE
ORDER BY rows_in_state DESC;

-- 44c. SCC_USER flag distribution (and its correlation with ROLE)
SELECT SCC_USER, ROLE, COUNT(*) AS row_count
FROM V_S_SEC_USER
GROUP BY SCC_USER, ROLE
ORDER BY row_count DESC;

-- 44d. ID column polarity — does it really have negatives, and how dense?
SELECT
    SIGN(ID)                                             AS id_sign,
    COUNT(*)                                             AS row_count,
    MIN(ID)                                              AS min_id,
    MAX(ID)                                              AS max_id
FROM V_S_SEC_USER
GROUP BY SIGN(ID)
ORDER BY id_sign;

-- 44e. ID polarity ↔ ROLE / SCC_USER correlation
SELECT
    CASE WHEN ID < 0 THEN 'negative'
         WHEN ID = 0 THEN 'zero'
         ELSE 'positive' END                             AS id_bucket,
    ROLE,
    SCC_USER,
    COUNT(*)                                             AS row_count
FROM V_S_SEC_USER
GROUP BY
    CASE WHEN ID < 0 THEN 'negative'
         WHEN ID = 0 THEN 'zero'
         ELSE 'positive' END,
    ROLE,
    SCC_USER
ORDER BY row_count DESC;

-- 44f. Optional flag fields — populated rate and overlap with ACTIVE
SELECT
    COUNT(*)                                             AS total_rows,
    SUM(CASE WHEN EMERGENCY_ACCESS IS NOT NULL
              AND EMERGENCY_ACCESS <> '' THEN 1 ELSE 0 END)
                                                         AS emergency_access_set,
    SUM(CASE WHEN EMERGENCY_ROLE IS NOT NULL
              AND EMERGENCY_ROLE <> '' THEN 1 ELSE 0 END)
                                                         AS emergency_role_set,
    SUM(CASE WHEN FUTURE_ACTIVATE_DATE IS NOT NULL THEN 1 ELSE 0 END)
                                                         AS future_activate_set,
    SUM(CASE WHEN FUTURE_DEACTIVATE_DATE IS NOT NULL THEN 1 ELSE 0 END)
                                                         AS future_deactivate_set,
    SUM(CASE WHEN LAST_PWD_DATE IS NOT NULL THEN 1 ELSE 0 END)
                                                         AS last_pwd_set
FROM V_S_SEC_USER;

-- 44g. Future-deactivated user spotlight (likely terminated employees still
--      in the table). Useful for distinguishing "active human" amendments
--      from "ghost-account" amendments.
SELECT
    TECH_ID,
    USER_ID,
    LASTNAME,
    FIRSTNAME,
    ACTIVE,
    ROLE,
    FUTURE_ACTIVATE_DATE,
    FUTURE_DEACTIVATE_DATE,
    LAST_PWD_DATE
FROM V_S_SEC_USER
WHERE FUTURE_DEACTIVATE_DATE IS NOT NULL
   OR FUTURE_ACTIVATE_DATE   IS NOT NULL
ORDER BY FUTURE_DEACTIVATE_DATE NULLS LAST;


/* ----------------------------------------------------------------------------
   45. V_S_SEC_USERROLES — role-assignment table
       Discover the column shape, then locate the role-master view and
       confirm the join keys. The dict suggests USER_ID + ROLE_ID columns
       plus metadata.
   --------------------------------------------------------------------------- */
-- 45a. Schema discovery
SELECT
    COLUMN_ID,
    COLUMN_NAME,
    DATA_TYPE,
    DATA_LENGTH,
    NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_USERROLES'
ORDER BY COLUMN_ID;

-- 45b. Sample rows
SELECT *
FROM V_S_SEC_USERROLES
WHERE ROWNUM <= 10;

-- 45c. Role distribution — group by the role column once 45a reveals its name.
--      Stub query (replace ROLE_ID with the actual column from 45a):
-- SELECT ROLE_ID, COUNT(*) AS user_count
-- FROM V_S_SEC_USERROLES
-- GROUP BY ROLE_ID
-- ORDER BY user_count DESC;


/* ----------------------------------------------------------------------------
   46. Role master view discovery
       UPDATED post-§43: there is no V_S_SEC_ROLE / V_S_SEC_ROLES master.
       The §43 catalog returns these candidate masters (the views that
       could hold role definitions referenced by USERROLES /
       GROUP_ROLES_MAPPING / USERSITEROLE):
         V_S_SEC_UPERMCLASS  (41 cols) — User Permission Class. Wide
                                          column count suggests this is
                                          the actual role/perm definition
         V_S_SEC_RFUNCTION   (5 cols)  — possibly Role-Function lookup
         V_S_SEC_CLASSITEM   (8 cols)  — items inside a permission class
         V_S_SEC_RESTRICTCTG (7 cols)  — restriction category (less likely
                                          to be the role master, but worth
                                          probing for completeness)

       Probe each schema to see which one carries the role/permission
       NAME column referenced by the join tables.
   --------------------------------------------------------------------------- */
-- 46a. V_S_SEC_UPERMCLASS schema + sample
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_UPERMCLASS'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_UPERMCLASS
WHERE ROWNUM <= 10;

-- 46b. V_S_SEC_RFUNCTION schema + sample
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_RFUNCTION'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_RFUNCTION
WHERE ROWNUM <= 10;

-- 46c. V_S_SEC_CLASSITEM schema + sample
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_CLASSITEM'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_CLASSITEM
WHERE ROWNUM <= 10;

-- 46d. V_S_SEC_RESTRICTCTG schema + sample
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_RESTRICTCTG'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_RESTRICTCTG
WHERE ROWNUM <= 10;


/* ----------------------------------------------------------------------------
   46e. V_S_SEC_USERSITEROLE — site-scoped role assignments
       Temple has 6+ facilities (TUH, JNS, CHH, EPC, FCH, WFH) so role
       assignments are almost certainly site-scoped. With 9 columns
       this likely carries USER_FK + SITE_ID + ROLE_FK + activity
       flags. May supersede V_S_SEC_USERROLES (4 cols) as the live
       role-grant table in this deployment.
   --------------------------------------------------------------------------- */
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_USERSITEROLE'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_USERSITEROLE
WHERE ROWNUM <= 10;

-- 46f. Coverage comparison: USERROLES vs USERSITEROLE
SELECT
    (SELECT COUNT(*) FROM V_S_SEC_USERROLES)     AS userroles_rows,
    (SELECT COUNT(*) FROM V_S_SEC_USERSITEROLE)  AS usersiterole_rows,
    (SELECT COUNT(*) FROM V_S_SEC_USER)          AS user_rows
FROM dual;


/* ----------------------------------------------------------------------------
   46g. V_S_SEC_USER_EXT — extension columns beyond V_S_SEC_USER
       47 cols (vs USER's 190) — likely an HR-side extension carrying
       department, manager, hire date, employee number, etc. Worth
       knowing whether this is where DEPARTMENT actually lives (vs.
       being a column on V_S_SEC_USER as §37 implied).
   --------------------------------------------------------------------------- */
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_USER_EXT'
ORDER BY COLUMN_ID;

SELECT *
FROM V_S_SEC_USER_EXT
WHERE ROWNUM <= 5;


/* ----------------------------------------------------------------------------
   47. Role coverage for recent amenders
       For every MOD_TECH on V_P_LAB_TEST_RESULT_HISTORY in the last 90
       days, list the assigned roles. Joins through the chain:
         MOD_TECH → V_S_SEC_USER.TECH_ID → V_S_SEC_USER.AA_ID
                                       → V_S_SEC_USERROLES.<user_fk>
                                       → role master.ROLE_NAME

       This query is a STUB — fill in the FK column names from §45a/§46
       output before running. Pattern preserved so it's easy to wire up.
   --------------------------------------------------------------------------- */
-- WITH recent_mod_tech AS (
--     SELECT MOD_TECH, COUNT(*) AS amendment_rows
--     FROM V_P_LAB_TEST_RESULT_HISTORY
--     WHERE MOD_DT >= SYSDATE - 90
--     GROUP BY MOD_TECH
-- )
-- SELECT
--     rmt.MOD_TECH,
--     rmt.amendment_rows,
--     usr.LASTNAME,
--     usr.FIRSTNAME,
--     LISTAGG(role_name, '; ') WITHIN GROUP (ORDER BY role_name)
--                                                 AS roles
-- FROM recent_mod_tech                rmt
-- LEFT JOIN V_S_SEC_USER             usr ON usr.TECH_ID = rmt.MOD_TECH
-- LEFT JOIN V_S_SEC_USERROLES        ur  ON ur.<user_fk>  = usr.AA_ID
-- LEFT JOIN <role_master_view>        rm  ON rm.<role_pk> = ur.<role_fk>
-- GROUP BY rmt.MOD_TECH, rmt.amendment_rows, usr.LASTNAME, usr.FIRSTNAME
-- ORDER BY rmt.amendment_rows DESC;


/* ----------------------------------------------------------------------------
   48. Group membership chain
       Three views form the user→group→role chain per the dict:
         V_S_SEC_USER_GROUP        — user-to-group membership (M:M)
         V_S_SEC_GROUP_ASSIGNMENT  — group definition / parent grouping
         V_S_SEC_GROUP_ROLES_MAPPING — role(s) granted to a group

       Discover schema for each, then sample rows.
   --------------------------------------------------------------------------- */
-- 48a. V_S_SEC_USER_GROUP schema
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_USER_GROUP'
ORDER BY COLUMN_ID;

-- 48b. V_S_SEC_USER_GROUP sample
SELECT *
FROM V_S_SEC_USER_GROUP
WHERE ROWNUM <= 10;

-- 48c. V_S_SEC_GROUP_ASSIGNMENT schema
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_GROUP_ASSIGNMENT'
ORDER BY COLUMN_ID;

-- 48d. V_S_SEC_GROUP_ASSIGNMENT sample
SELECT *
FROM V_S_SEC_GROUP_ASSIGNMENT
WHERE ROWNUM <= 10;

-- 48e. V_S_SEC_GROUP_ROLES_MAPPING schema
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_GROUP_ROLES_MAPPING'
ORDER BY COLUMN_ID;

-- 48f. V_S_SEC_GROUP_ROLES_MAPPING sample
SELECT *
FROM V_S_SEC_GROUP_ROLES_MAPPING
WHERE ROWNUM <= 10;


/* ----------------------------------------------------------------------------
   49. Group-master discovery
       Locate a top-level "group" view (just GROUP/GRP, no
       ASSIGNMENT/ROLES suffix) that probably defines the group code +
       name + description. Same schema-search pattern as §46.
   --------------------------------------------------------------------------- */
SELECT OWNER, OBJECT_NAME, OBJECT_TYPE
FROM ALL_OBJECTS
WHERE OBJECT_NAME LIKE 'V_S_SEC%GROUP%'
  AND OBJECT_TYPE IN ('VIEW','TABLE')
ORDER BY OBJECT_NAME;


/* ----------------------------------------------------------------------------
   50. V_S_SEC_CONTACT_INFO follow-through
       The dict notes possible redundancy with V_S_SEC_USER's LASTNAME /
       FIRSTNAME / MIDDLENAME. Compare the column sets and check whether
       CONTACT_INFO carries different/extended fields (email, phone,
       title, address, etc.) that we should surface alongside name.
   --------------------------------------------------------------------------- */
-- 50a. Schema (re-run for completeness)
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_S_SEC_CONTACT_INFO'
ORDER BY COLUMN_ID;

-- 50b. Find the FK back to V_S_SEC_USER (likely USER_AA_ID, USER_ID, or
--      similar — confirm with 50a output).
-- 50c. Compare CONTACT_INFO populated rate to V_S_SEC_USER row count.
SELECT
    (SELECT COUNT(*) FROM V_S_SEC_USER)         AS user_rows,
    (SELECT COUNT(*) FROM V_S_SEC_CONTACT_INFO) AS contact_rows;

-- 50d. CONTACT_INFO row for our ground-truth tech (TKAZ).
--      Stub — fill in the actual user-FK column from 50a:
-- SELECT *
-- FROM V_S_SEC_CONTACT_INFO ci
-- JOIN V_S_SEC_USER         u  ON u.AA_ID = ci.<user_fk>
-- WHERE u.TECH_ID = 'TKAZ';


/* ----------------------------------------------------------------------------
   51. Composed enrichment for corrected_results_summary.sql
       Once §43-§50 reveal the exact join keys, this is the shape of
       the proposed final enrichment to add to corrected_results_summary
       (or break out into a corrected_results_audit_with_roles variant).

       Resulting columns (added to the existing query):
         CHANGED_BY_ROLES   — '; '-joined role names (e.g.,
                              "Lab Tech; Pathologist")
         CHANGED_BY_GROUPS  — '; '-joined group names (e.g.,
                              "TUH Chemistry; All Sites")
         CHANGED_BY_TITLE   — title or position from CONTACT_INFO if
                              non-redundant with V_S_SEC_USER fields
         IS_PRIVILEGED      — Y/N derived flag for SCC_USER='Y' OR
                              EMERGENCY_ACCESS='Y' OR
                              FUTURE_DEACTIVATE_DATE < SYSDATE — flags
                              amendments that should get extra
                              auditor scrutiny

       This template is left as commented SQL until §43-§50 confirm
       the column names. After confirmation, paste the column-aware
       version into corrected_results_summary.sql or its audit sibling.
   --------------------------------------------------------------------------- */
-- WITH ... (existing hist_full CTE from corrected_results_summary.sql) ...
-- ,
-- amender_role AS (
--     SELECT
--         u.TECH_ID,
--         LISTAGG(rm.<role_name>, '; ')
--             WITHIN GROUP (ORDER BY rm.<role_name>)            AS roles
--     FROM V_S_SEC_USER          u
--     JOIN V_S_SEC_USERROLES     ur ON ur.<user_fk>  = u.AA_ID
--     JOIN <role_master_view>     rm ON rm.<role_pk> = ur.<role_fk>
--     GROUP BY u.TECH_ID
-- ),
-- amender_group AS (
--     SELECT
--         u.TECH_ID,
--         LISTAGG(g.<group_name>, '; ')
--             WITHIN GROUP (ORDER BY g.<group_name>)            AS groups
--     FROM V_S_SEC_USER             u
--     JOIN V_S_SEC_USER_GROUP       ug ON ug.<user_fk>  = u.AA_ID
--     JOIN V_S_SEC_GROUP_ASSIGNMENT g  ON g.<group_pk>  = ug.<group_fk>
--     GROUP BY u.TECH_ID
-- )
-- SELECT
--     ...,                                               -- existing columns
--     ar.roles                                           AS CHANGED_BY_ROLES,
--     ag.groups                                          AS CHANGED_BY_GROUPS,
--     CASE
--         WHEN usr.SCC_USER = 'Y'                       THEN 'Y'
--         WHEN usr.EMERGENCY_ACCESS = 'Y'               THEN 'Y'
--         WHEN usr.FUTURE_DEACTIVATE_DATE < SYSDATE     THEN 'Y'
--         ELSE 'N'
--     END                                                AS IS_PRIVILEGED
-- FROM ...
-- LEFT JOIN amender_role  ar ON ar.TECH_ID = hf.MOD_TECH
-- LEFT JOIN amender_group ag ON ag.TECH_ID = hf.MOD_TECH
-- ...;


/* ----------------------------------------------------------------------------
   52. V_P_LAB_MESSAGE — per-accession comment dump for application comparison

       Context: corrected_results_summary.sql surfaces the value transition
       and audit metadata, but exposes no result-level free-text narrative.
       The SCC client's Result Comment tab writes user-authored comments to
       the result-comment-line table — legacy SCC docs call this RPMESS,
       and the modern view layer exposes it as V_P_LAB_MESSAGE (dict line
       3256). The 18-location sweep that grounded the "chemistry correction
       notice is hard-coded" finding included V_P_LAB_MESSAGE.TEXT and
       returned 0 hits for the system-template phrase — but that was scoped
       to *system* text. User-authored narrative on RMOD-amended results
       was not characterized.

       Goal: dump every V_P_LAB_MESSAGE row tied to the RMOD-amended cohort
       with enough context (accession, MRN, test, mod time) to pull the
       same result up in the SCC client and compare what the application
       displays vs what the table actually carries. If the dump yields
       narrative the summary should surface, this informs whether to add a
       comment column to corrected_results_summary.sql.

       Structure: 52a discovers schema (no prior probe captured it), 52b
       runs the dump once 52a's column names are filled in.
   --------------------------------------------------------------------------- */

-- 52a. V_P_LAB_MESSAGE column inventory
--      Run first. Identifies (a) the FK back to V_P_LAB_TEST_RESULT
--      (likely ATEST_AA_ID or TEST_RESULT_AA_ID — confirm here), (b) the
--      text/CLOB column holding the comment body (the dict references
--      .TEXT), and (c) any line-number / type / timestamp columns we'll
--      want in the dump's ORDER BY and output.
SELECT
    COLUMN_ID,
    COLUMN_NAME,
    DATA_TYPE,
    DATA_LENGTH,
    NULLABLE
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'V_P_LAB_MESSAGE'
ORDER BY COLUMN_ID;


-- 52b. Per-accession comment dump (RMOD cohort, 30-day window)
--      Mirrors corrected_results_summary.sql's filters: RMOD-only, valid
--      MRN, EDITED_FLAG='Y', human amenders (system-identity exclusion
--      list verified in §42).
--
--      Fill in <test_result_fk> and <text_col> from 52a's output. If
--      V_P_LAB_MESSAGE has a line-number or sequence column for multi-
--      line comments, append it to the ORDER BY so the lines surface in
--      the order the SCC client renders them.
--
--      Note: V_P_LAB_MESSAGE rows attach to the LIVE result, not to a
--      specific amendment — there is no MOD_DT-snapshot of comments here
--      (that's PREV_COMMENT on V_P_LAB_TEST_RESULT_HISTORY). What this
--      dumps is the current comment state, which is what the SCC client's
--      Result Comment tab also displays.
-- WITH amended_atests AS (
--     SELECT DISTINCT h.ATEST_AA_ID
--     FROM V_P_LAB_TEST_RESULT_HISTORY h
--     WHERE h.MOD_DT >= SYSDATE - 30
--       AND h.TYPE   = 'RMOD'
--       AND h.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
-- )
-- SELECT
--     o.ID                                          AS accession,
--     pt.ID                                         AS mrn,
--     tr.TEST_NAME                                  AS test,
--     tr.AA_ID                                      AS atest_aa_id,
--     m.*                                          -- surface all msg cols
--                                                   --   so we can see TYPE/
--                                                   --   line-no/timestamp
--                                                   --   alongside text
-- FROM amended_atests aa
-- JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = aa.ATEST_AA_ID
-- JOIN V_P_LAB_ORDER       o  ON o.AA_ID  = tr.ORDER_AA_ID
-- JOIN V_P_LAB_STAY        st ON st.AA_ID = o.STAY_AA_ID
-- JOIN V_P_LAB_PATIENT     pt ON pt.AA_ID = st.PATIENT_AA_ID
-- JOIN V_P_LAB_MESSAGE     m  ON m.<test_result_fk> = tr.AA_ID
-- WHERE REGEXP_LIKE(pt.ID, '^E[0-9]+$')
--   AND tr.EDITED_FLAG = 'Y'
-- ORDER BY pt.ID, o.ID, tr.AA_ID;  -- add m.<line_no_col> when known


-- 52c. Coverage cross-check (run after 52b is parameterized)
--      How many of the RMOD-amended results in the 30-day cohort have
--      ANY V_P_LAB_MESSAGE row? If coverage is near 0%, the table is a
--      dead end for corrected-results enrichment. If meaningfully > 0%,
--      promote one of 52b's text columns to a column on
--      corrected_results_summary.sql (or its audit sibling).
-- SELECT
--     COUNT(DISTINCT aa.ATEST_AA_ID)                 AS amended_results,
--     COUNT(DISTINCT m.<test_result_fk>)             AS results_with_message,
--     ROUND(100 * COUNT(DISTINCT m.<test_result_fk>)
--                / NULLIF(COUNT(DISTINCT aa.ATEST_AA_ID), 0), 2)
--                                                    AS pct_with_message
-- FROM (
--     SELECT DISTINCT h.ATEST_AA_ID
--     FROM V_P_LAB_TEST_RESULT_HISTORY h
--     WHERE h.MOD_DT >= SYSDATE - 30
--       AND h.TYPE   = 'RMOD'
--       AND h.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
-- ) aa
-- LEFT JOIN V_P_LAB_MESSAGE m ON m.<test_result_fk> = aa.ATEST_AA_ID;
