/* ============================================================================
   Report comment provenance

   Question: when SCC's client prints a result report, where does the
   comment text on the printout actually come from?

   Started as a hunt for "extra comments appearing on corrected-result reports
   that aren't in any obvious comment column" but the patterns generalize —
   these probes work for any printed-report comment investigation. The §A
   coverage filter targets the RMOD-amended cohort because that was the
   original entry point; the candidate sources surveyed are the same regardless
   of cohort.

   Already-known sources (resolved in prior sessions / earlier in this file):
   - "Corrected result; previously reported as..." — hard-coded in SCC report
     engine binary (chemistry/general). Not stored anywhere in DB.
   - "This is a corrected report. Previously reported as:" — V_S_LAB_CANNED_MESSAGE
     IDs &CORR / }CORR (microbiology corrected-report notice).
   - tr.COMMENTS (RTF-wrapped) — tech-authored critical-callback narrative.
   - **tr.TEST_INFO_MSG** -> V_S_LAB_CANNED_MESSAGE chain — confirmed 2026-05-01.
     The 5-char ID propagates from V_S_LAB_TEST.MES_TEST_COMMENT (setup level).
     Worked example: 'TGLUF' -> 6-line ADA glucose reference ranges.

   Candidate sources surveyed:
   - V_P_LAB_MESSAGE (verified vestigial — 0% coverage on amended cohort)
   - V_P_LAB_INTERNAL_NOTE (multi-FK polymorphic notes; sparse on amended cohort)
   - tr.COMMENTS (RTF-wrapped, ~25% coverage)
   - tr.INTERPRET_MSG / TEST_INFO_MSG / DELTA_CHECK_FAIL_MSG (canned-message IDs;
     TEST_INFO_MSG 13% coverage, others 0%)
   - V_S_LAB_TEST.MES_TEST_COMMENT (test-setup-level canned-message ref —
     propagates to TEST_INFO_MSG on each result)
   - SoftMic comment views with FLAG_COR_RES='Y' (correction-correlated signal)

   Sections (each independently executable):
     §A  System-wide coverage of candidate sources on RMOD-amended cohort
     §B  Single-result deep-dive (bind :ATEST_AA_ID)
     §C  SoftMic FLAG_COR_RES survey (MIC-only)
     §D  Timing correlation: amendment time vs comment-update time
     §E  Reverse lookup: given a canned-message ID, find the test-setup config
         that propagates it to result rows
   ============================================================================ */


/* ----------------------------------------------------------------------------
   §A — System-wide coverage on the RMOD-amended cohort (30-day window)

   For each candidate comment store, what fraction of recently-amended
   results actually have an attached comment? Below ~5% = dead-end source.
   Above ~30% = likely contributing to the printed report. Single batch
   query so we can compare side-by-side.

   The cohort: RMOD-amended results with non-system MOD_TECH (matches
   corrected_results_summary.sql's filters).
   --------------------------------------------------------------------------- */
WITH amended_atests AS (
    SELECT DISTINCT h.ATEST_AA_ID
    FROM V_P_LAB_TEST_RESULT_HISTORY h
    WHERE h.MOD_DT >= SYSDATE - 30
      AND h.TYPE   = 'RMOD'
      AND h.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
),
cohort AS (
    SELECT aa.ATEST_AA_ID, tr.ORDER_AA_ID, tr.GROUP_TEST_ID,
           tr.COMMENTS         AS tr_comments,
           tr.INTERPRET_MSG    AS interpret_msg,
           tr.TEST_INFO_MSG    AS test_info_msg,
           tr.DELTA_CHECK_FAIL_MSG AS delta_msg
    FROM amended_atests aa
    JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = aa.ATEST_AA_ID
)
SELECT
    COUNT(DISTINCT c.ATEST_AA_ID)                                AS amended_results,
    COUNT(DISTINCT m.TEST_RESULT_AA_ID)                          AS with_lab_message,
    ROUND(100 * COUNT(DISTINCT m.TEST_RESULT_AA_ID)
                / NULLIF(COUNT(DISTINCT c.ATEST_AA_ID), 0), 2)   AS lab_message_pct,
    COUNT(DISTINCT n.TEST_RESULT_AA_ID)                          AS with_internal_note_result_fk,
    COUNT(DISTINCT n2.ORDER_AA_ID)                               AS with_internal_note_order_fk,
    SUM(CASE WHEN c.tr_comments IS NOT NULL
              AND DBMS_LOB.GETLENGTH(c.tr_comments) > 0
             THEN 1 ELSE 0 END)                                  AS with_tr_comments,
    SUM(CASE WHEN c.interpret_msg IS NOT NULL THEN 1 ELSE 0 END) AS with_interpret_msg,
    SUM(CASE WHEN c.test_info_msg IS NOT NULL THEN 1 ELSE 0 END) AS with_test_info_msg,
    SUM(CASE WHEN c.delta_msg     IS NOT NULL THEN 1 ELSE 0 END) AS with_delta_msg
FROM cohort c
LEFT JOIN V_P_LAB_MESSAGE       m  ON m.TEST_RESULT_AA_ID  = c.ATEST_AA_ID
LEFT JOIN V_P_LAB_INTERNAL_NOTE n  ON n.TEST_RESULT_AA_ID  = c.ATEST_AA_ID
LEFT JOIN V_P_LAB_INTERNAL_NOTE n2 ON n2.ORDER_AA_ID       = c.ORDER_AA_ID;


/* ----------------------------------------------------------------------------
   §B — Single-result deep-dive

   Bind :ATEST_AA_ID to a recently-corrected V_P_LAB_TEST_RESULT.AA_ID
   (pull one from a recent corrected_results_summary.sql output). This
   dumps every reachable comment column side-by-side so you can compare
   the SCC client's printed report against the database content.

   Six sub-queries — execute sequentially:
     §B.1  V_P_LAB_MESSAGE rows for this result (multi-line, ordered)
     §B.2  V_P_LAB_INTERNAL_NOTE rows for the result + parent order + tube
     §B.3  Live tr.COMMENTS (RTF — display raw, eyeball the wrapper)
     §B.4  Canned-message ID columns on tr + their expanded text
     §B.5  Amendment history (so you can see if a comment got added at MOD_DT)
     §B.6  Test-setup-level canned-message ref (V_S_LAB_TEST.MES_TEST_COMMENT)
   --------------------------------------------------------------------------- */

-- §B.1 — V_P_LAB_MESSAGE rows for this result
SELECT
    m.TEST_RESULT_SORT  AS line_no,
    m.TYPE              AS msg_type,
    m.TECH_ID           AS msg_tech,
    m.UPDATE_DT         AS msg_dt,
    m.TEXT              AS msg_text
FROM V_P_LAB_MESSAGE m
WHERE m.TEST_RESULT_AA_ID = :ATEST_AA_ID
ORDER BY m.TEST_RESULT_SORT;


-- §B.2 — V_P_LAB_INTERNAL_NOTE attached at result / order / tube level
WITH context AS (
    SELECT tr.AA_ID AS atest_aa_id, tr.ORDER_AA_ID
    FROM V_P_LAB_TEST_RESULT tr
    WHERE tr.AA_ID = :ATEST_AA_ID
)
SELECT
    n.AA_ID,
    CASE
        WHEN n.TEST_RESULT_AA_ID IS NOT NULL THEN 'result'
        WHEN n.ORDER_AA_ID       IS NOT NULL THEN 'order'
        WHEN n.TUBE_AA_ID        IS NOT NULL THEN 'tube'
        ELSE 'other'
    END                                              AS note_level,
    n.NOTE_CATEGORY,
    n.NOTE_TECH,
    n.NOTE_DATETIME,
    n.NOTE_CANMSG,
    n.NOTE_TEXT
FROM context c
JOIN V_P_LAB_INTERNAL_NOTE n
     ON n.TEST_RESULT_AA_ID = c.atest_aa_id
     OR n.ORDER_AA_ID       = c.ORDER_AA_ID
ORDER BY n.NOTE_DATETIME;


-- §B.3 — Live tr.COMMENTS (RTF — raw dump; expect \rtf1\ansi... wrapper)
SELECT
    tr.AA_ID,
    tr.STATE,
    tr.EDITED_FLAG,
    tr.VERIFIED_DT,
    tr.UNVERIFIED_DT,
    tr.COMMENTS                                      AS tr_comments_rtf
FROM V_P_LAB_TEST_RESULT tr
WHERE tr.AA_ID = :ATEST_AA_ID;


-- §B.4 — Canned-message ID columns on tr + their expanded text via
--        V_S_LAB_CANNED_MESSAGE. The IDs are VARCHAR2 5; the report engine
--        joins to the canned-message library at print time. If any of
--        these are populated, the resolved TEXT is what would print.
WITH cm AS (
    SELECT
        tr.AA_ID,
        tr.INTERPRET_MSG,
        tr.TEST_INFO_MSG,
        tr.DELTA_CHECK_FAIL_MSG
    FROM V_P_LAB_TEST_RESULT tr
    WHERE tr.AA_ID = :ATEST_AA_ID
)
SELECT * FROM (
    SELECT
        'INTERPRET_MSG'         AS src_col,
        cm.INTERPRET_MSG        AS canmsg_id,
        msg.LINE_NUMBER         AS line_no,
        msg.TEXT                AS canmsg_text
    FROM cm
    LEFT JOIN V_S_LAB_CANNED_MESSAGE msg
           ON msg.ID = cm.INTERPRET_MSG
          AND msg.ACTIVE = 'Y'
          AND (msg.EXP_DT IS NULL OR msg.EXP_DT >= SYSDATE)
    WHERE cm.INTERPRET_MSG IS NOT NULL
    UNION ALL
    SELECT 'TEST_INFO_MSG', cm.TEST_INFO_MSG, msg.LINE_NUMBER, msg.TEXT
    FROM cm
    LEFT JOIN V_S_LAB_CANNED_MESSAGE msg
           ON msg.ID = cm.TEST_INFO_MSG
          AND msg.ACTIVE = 'Y'
          AND (msg.EXP_DT IS NULL OR msg.EXP_DT >= SYSDATE)
    WHERE cm.TEST_INFO_MSG IS NOT NULL
    UNION ALL
    SELECT 'DELTA_CHECK_FAIL_MSG', cm.DELTA_CHECK_FAIL_MSG, msg.LINE_NUMBER, msg.TEXT
    FROM cm
    LEFT JOIN V_S_LAB_CANNED_MESSAGE msg
           ON msg.ID = cm.DELTA_CHECK_FAIL_MSG
          AND msg.ACTIVE = 'Y'
          AND (msg.EXP_DT IS NULL OR msg.EXP_DT >= SYSDATE)
    WHERE cm.DELTA_CHECK_FAIL_MSG IS NOT NULL
)
ORDER BY 1, 3;


-- §B.5 — Amendment history with prior comment snapshots
SELECT
    h.MOD_DT,
    h.TYPE,
    h.MOD_TECH,
    h.MOD_REASON,
    h.PREV_RESULT,
    DBMS_LOB.GETLENGTH(h.PREV_COMMENT)               AS prev_comment_len,
    h.PREV_COMMENT
FROM V_P_LAB_TEST_RESULT_HISTORY h
WHERE h.ATEST_AA_ID = :ATEST_AA_ID
ORDER BY h.MOD_DT, h.AA_ID;


-- §B.6 — V_S_LAB_TEST.MES_TEST_COMMENT for the test on this result
WITH ctx AS (
    SELECT tr.GROUP_TEST_ID, tr.TEST_ID
    FROM V_P_LAB_TEST_RESULT tr
    WHERE tr.AA_ID = :ATEST_AA_ID
)
SELECT
    t.ID                          AS test_id,
    t.NAME                        AS test_name,
    t.MES_TEST_COMMENT            AS canmsg_id,
    msg.TEXT                      AS canmsg_text
FROM ctx c
JOIN V_S_LAB_TEST t              ON t.ID = c.TEST_ID
LEFT JOIN V_S_LAB_CANNED_MESSAGE msg
     ON msg.ID = t.MES_TEST_COMMENT
    AND msg.ACTIVE = 'Y'
    AND (msg.EXP_DT IS NULL OR msg.EXP_DT >= SYSDATE)
WHERE t.MES_TEST_COMMENT IS NOT NULL;


/* ----------------------------------------------------------------------------
   §C — SoftMic comment views with FLAG_COR_RES='Y'

   The SoftMic comment family has FLAG_COR_RES (corrected-result flag) on
   every grain — order/test/isolate/media/sensi/therapy. If techs flag a
   comment as correction-related when amending a micro result, this is
   where it surfaces. Run AFTER §A/§B if your corrected-results cohort
   includes micro tests.

   Returns volume of FLAG_COR_RES='Y' comments by view in the last 90 days,
   so we can see whether this flag is operationally used or vestigial.
   --------------------------------------------------------------------------- */
SELECT * FROM (
    SELECT 'V_P_MIC_TESTCOMM'    AS view_name,
           COUNT(*)              AS rows_total,
           SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END) AS cor_res_y,
           ROUND(100 * SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END)
                       / NULLIF(COUNT(*), 0), 2) AS cor_res_pct
    FROM V_P_MIC_TESTCOMM
    WHERE MOD_DT >= SYSDATE - 90
    UNION ALL SELECT 'V_P_MIC_ISOCOMM',
           COUNT(*),
           SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END),
           ROUND(100 * SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END)
                       / NULLIF(COUNT(*), 0), 2)
    FROM V_P_MIC_ISOCOMM   WHERE MOD_DT >= SYSDATE - 90
    UNION ALL SELECT 'V_P_MIC_MEDIACOMM',
           COUNT(*),
           SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END),
           ROUND(100 * SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END)
                       / NULLIF(COUNT(*), 0), 2)
    FROM V_P_MIC_MEDIACOMM WHERE MOD_DT >= SYSDATE - 90
    UNION ALL SELECT 'V_P_MIC_THERAPYCOMM',
           COUNT(*),
           SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END),
           ROUND(100 * SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END)
                       / NULLIF(COUNT(*), 0), 2)
    FROM V_P_MIC_THERAPYCOMM WHERE MOD_DT >= SYSDATE - 90
    UNION ALL SELECT 'V_P_MIC_ORDER_COMM',
           COUNT(*),
           SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END),
           ROUND(100 * SUM(CASE WHEN FLAG_COR_RES = 'Y' THEN 1 ELSE 0 END)
                       / NULLIF(COUNT(*), 0), 2)
    FROM V_P_MIC_ORDER_COMM WHERE MOD_DT >= SYSDATE - 90
)
ORDER BY 3 DESC;


/* ----------------------------------------------------------------------------
   §E — Confirm canned-message is configured at the TEST SETUP level

   Hypothesis: TGLUF (or any canned-message ID showing up via tr.TEST_INFO_MSG)
   is set at V_S_LAB_TEST.MES_TEST_COMMENT in the test setup. The per-result
   TEST_INFO_MSG column is a snapshot/copy from that setup, attached to every
   result of the test — which is why the same canned text prints on every
   report, original and corrected.

   §E.1 — Reverse lookup: given a canned-message ID, find every test that
          has it configured as MES_TEST_COMMENT in setup.
   §E.2 — Same lookup but for test-result usage: how many V_P_LAB_TEST_RESULT
          rows reference the same canned-message ID via TEST_INFO_MSG, and
          do they all share the same TEST_ID? (If yes, that's confirmation
          the setup-level config is the source.)

   Bind :CANMSG_ID to the canned-message ID of interest (e.g., 'TGLUF').
   --------------------------------------------------------------------------- */

-- §E.1 — Tests where MES_TEST_COMMENT = :CANMSG_ID
SELECT
    t.ID                          AS test_id,
    t.NAME                        AS test_name,
    t.NAME_REPORTABLE,
    t.MES_TEST_COMMENT            AS canmsg_id,
    t.ACTIVE                      AS test_active,
    t.DEPARTMENT_ID,
    t.WORKSTATION_ID
FROM V_S_LAB_TEST t
WHERE t.MES_TEST_COMMENT = :CANMSG_ID
ORDER BY t.ID;


-- §E.2 — Live result rows referencing the same canned-message ID
--        Confirms: every result with TEST_INFO_MSG = :CANMSG_ID has
--        TEST_ID matching one of the §E.1 results, proving the setup
--        propagates to the result row.
SELECT
    tr.TEST_ID,
    COUNT(*)                                          AS result_rows,
    COUNT(DISTINCT tr.TEST_PERFORMING_LOCATION)       AS distinct_facilities,
    MIN(tr.TEST_DT)                                   AS earliest,
    MAX(tr.TEST_DT)                                   AS latest
FROM V_P_LAB_TEST_RESULT tr
WHERE tr.TEST_INFO_MSG = :CANMSG_ID
  AND tr.TEST_DT >= SYSDATE - 30
GROUP BY tr.TEST_ID
ORDER BY 2 DESC;


/* ----------------------------------------------------------------------------
   §D — Optional: timing correlation

   For RMOD-amended results that DO have a V_P_LAB_MESSAGE row, what's the
   typical gap between amendment time (MOD_DT) and message-update time
   (UPDATE_DT)? If most are within ±15 minutes, that's strong evidence
   the comment is added at correction time and surfaces on the printed
   corrected report.
   --------------------------------------------------------------------------- */
WITH amended AS (
    SELECT h.ATEST_AA_ID, MIN(h.MOD_DT) AS first_mod_dt
    FROM V_P_LAB_TEST_RESULT_HISTORY h
    WHERE h.MOD_DT >= SYSDATE - 30
      AND h.TYPE   = 'RMOD'
      AND h.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
    GROUP BY h.ATEST_AA_ID
)
SELECT
    CASE
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt) * 24 * 60 <= 15  THEN '0_within_15m'
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt) * 24       <= 1   THEN '1_within_1h'
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt)            <= 1   THEN '2_within_1d'
        WHEN m.UPDATE_DT < a.first_mod_dt                       THEN '3_before_amendment'
        ELSE                                                         '4_after_1d'
    END                                                           AS bucket,
    COUNT(*)                                                      AS rows_count
FROM amended a
JOIN V_P_LAB_MESSAGE m ON m.TEST_RESULT_AA_ID = a.ATEST_AA_ID
GROUP BY
    CASE
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt) * 24 * 60 <= 15  THEN '0_within_15m'
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt) * 24       <= 1   THEN '1_within_1h'
        WHEN ABS(m.UPDATE_DT - a.first_mod_dt)            <= 1   THEN '2_within_1d'
        WHEN m.UPDATE_DT < a.first_mod_dt                       THEN '3_before_amendment'
        ELSE                                                         '4_after_1d'
    END
ORDER BY 1;
