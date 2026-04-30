/*
Corrected Results — Summary

One row per result-value change in the window. For each amendment
where the value actually moved, returns:

  ACCESSION           V_P_LAB_ORDER.ID
  MRN                 V_P_LAB_PATIENT.ID
  TEST                V_P_LAB_TEST_RESULT.TEST_NAME
  RESULT_FROM         value before this amendment (PREV_RESULT)
  ORIGINAL_RESULT_DT  when the FROM value was originally resulted
                      (RES_DT, snapshotted at mod time)
  RESULT_TO           value after this amendment
  CHANGED_BY          tech who made the amendment (MOD_TECH)
  CHANGED_AT          when the amendment happened (MOD_DT)
  CHANGE_REASON       free-text reason entered by the amender
                      (MOD_REASON). Sparsely populated — ~46% of
                      RMOD rows carry text; the rest are blank
                      because SCC doesn't force a reason on edit.
                      Use this column as the flagging signal when
                      reviewing rows: a populated CHANGE_REASON is
                      an explicit narrative the amender chose to
                      record, distinct from comment-edit churn.
  REPORT_START_DATE   :START_DATE bind parameter formatted as
                      MM/DD/YYYY string (no time component),
                      echoed on every row so the Grapecity report
                      header/footer can display "Range: <start> –
                      <end>" without re-fetching the parameter.
                      Returned as VARCHAR2 so the time '12:00:00 AM'
                      doesn't surface in the rendered report.
  REPORT_END_DATE     :END_DATE bind parameter formatted as
                      MM/DD/YYYY string. Same shape as
                      REPORT_START_DATE.

V_P_LAB_TEST_RESULT_HISTORY semantics
  - One row per modification event; ATEST_AA_ID -> tr.AA_ID.
  - PREV_RESULT  = value before this modification.
  - RES_DT       = ORIGINAL resulting timestamp, snapshotted at mod
                   time.
  - "New value" at amendment N = PREV_RESULT of amendment N+1
    chronologically, or current tr.RESULT when N is the latest.

Filters
  - Window on MOD_DT (the amendment event itself)
  - Valid MRN (REGEXP_LIKE '^E[0-9]+$')
  - tr.EDITED_FLAG = 'Y' — the live-row "E" indicator from SCC's
    client status column. Redundant with STATE='Corrected' for
    routine amendments; both fire on a freshly-amended row.
  - TYPE IN ('RMOD','FMOD','MODCOM') — RMOD is SCC's "Result-value
    modification" tag (the workhorse). FMOD and MODCOM are added
    defensively: FMOD is a SCC client-side display label rendered
    from RMOD rows (never written to the database in 10 years per
    setup/test_result_history_probe.sql §24/§30); MODCOM lives in
    sibling history views (V_P_LAB_ACT_HISTORY, V_P_LAB_TUBE_HISTORY)
    and has not been observed in V_P_LAB_TEST_RESULT_HISTORY.
    Including them means future SCC tagging changes don't silently
    drop rows. Drops DMOD (comment-only / range / calc-component
    edits) and REVMOD (rare review events). Enum distribution
    verified in setup/test_result_history_probe.sql §2.
  - :DEPOT on COLLECT_CENTER_ID (LIKE wildcards supported)
  - System / interface amendments excluded — MOD_TECH NOT IN
    (HIS, SCC, AUTOV, RBS, I/AUT, AUTON). Inventory verified via
    setup/test_result_history_probe.sql §42 + diagnostic top-10.
  - No-op amendments excluded — only rows where the result value
    actually differs from the post-amendment value are returned.
    Within RMOD this drops nothing in steady state (RMOD = value
    change by definition), but defensively catches edge cases.

Caveats
  - PREV_RESULT='.' means the row was cancelled at that point in
    the chain. Cancel-to-value and value-to-cancel transitions both
    count as changes and surface here.
  - PREV_RESULT='See Comment' is a SCC sentinel — the real prior
    value lives in V_P_LAB_TEST_RESULT_HISTORY.PREV_COMMENT, not
    surfaced here (the comment is RTF-wrapped at rest and the
    SCC RichTextBox preamble — font tables, generator destinations
    — leaks through any regex-based stripper Oracle can express).
    Switch to corrected_results_audit.sql for the raw prior comment.

Parameters (Grapecity parameter type = String, YYYYMMDD for dates)
  :START_DATE  Start of amendment range, e.g. 20260401
  :END_DATE    End of amendment range inclusive, e.g. 20260427
  :DEPOT       V_P_LAB_ORDER.COLLECT_CENTER_ID, LIKE wildcards OK:
                 'T1' Temple inpatient    'J1' Jeanes inpatient
                 'T%' all Temple          'J%' all Jeanes
                 '%'  all facilities
*/

WITH qualifying_atests AS (
    SELECT DISTINCT ATEST_AA_ID
    FROM V_P_LAB_TEST_RESULT_HISTORY
    WHERE MOD_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
      AND MOD_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
),
hist_full AS (
    SELECT
        h.ATEST_AA_ID,
        h.TYPE,
        h.MOD_DT,
        h.MOD_TECH,
        h.MOD_REASON,
        h.PREV_RESULT,
        h.RES_DT                                               AS prev_resulted_dt,
        LEAD(h.PREV_RESULT) OVER (PARTITION BY h.ATEST_AA_ID
                                  ORDER BY h.MOD_DT, h.AA_ID)  AS next_prev_result
    FROM V_P_LAB_TEST_RESULT_HISTORY h
    WHERE h.ATEST_AA_ID IN (SELECT ATEST_AA_ID FROM qualifying_atests)
)
SELECT
    o.ID                                            AS ACCESSION,
    pt.ID                                           AS MRN,
    tr.TEST_NAME                                    AS TEST,
    hf.PREV_RESULT                                  AS RESULT_FROM,
    hf.prev_resulted_dt                             AS ORIGINAL_RESULT_DT,
    COALESCE(hf.next_prev_result, tr.RESULT)        AS RESULT_TO,
    hf.MOD_TECH                                     AS CHANGED_BY,
    hf.MOD_DT                                       AS CHANGED_AT,
    hf.MOD_REASON                                   AS CHANGE_REASON,
    TO_CHAR(TO_DATE(:START_DATE, 'YYYYMMDD'),
            'MM/DD/YYYY')                           AS REPORT_START_DATE,
    TO_CHAR(TO_DATE(:END_DATE,   'YYYYMMDD'),
            'MM/DD/YYYY')                           AS REPORT_END_DATE
FROM hist_full hf
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = hf.ATEST_AA_ID
INNER JOIN V_P_LAB_ORDER o        ON o.AA_ID  = tr.ORDER_AA_ID
INNER JOIN V_P_LAB_STAY st        ON st.AA_ID = o.STAY_AA_ID
INNER JOIN V_P_LAB_PATIENT pt     ON pt.AA_ID = st.PATIENT_AA_ID
WHERE hf.MOD_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND hf.MOD_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
  AND o.COLLECT_CENTER_ID LIKE :DEPOT
  AND tr.EDITED_FLAG = 'Y'
  AND hf.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
  AND hf.TYPE IN ('RMOD','FMOD','MODCOM')
  AND DECODE(hf.PREV_RESULT,
             COALESCE(hf.next_prev_result, tr.RESULT),
             1, 0) = 0
ORDER BY pt.ID, o.ID, tr.TEST_ID, hf.MOD_DT;