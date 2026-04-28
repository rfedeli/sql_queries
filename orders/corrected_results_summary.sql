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
  CHANGED_BY          tech who made the amendment (MOD_TECH), with
                      the V_S_SEC_USER name appended in parens when the
                      MOD_TECH resolves to a non-system human user —
                      e.g., "KDG (Galdo, Kathleen)". For known system
                      identities (HIS, SCC, AUTOV, RBS, I/AUT, AUTON)
                      and unmatched MOD_TECHs, just the literal value
                      is shown — no parens. System-identity inventory
                      verified via setup/test_result_history_probe.sql
                      §42 + diagnostic top-10.
  CHANGED_AT          when the amendment happened (MOD_DT)

V_P_LAB_TEST_RESULT_HISTORY semantics
  - One row per modification event; ATEST_AA_ID -> tr.AA_ID.
  - PREV_RESULT  = value before this modification (RESULT_FROM).
  - RES_DT       = ORIGINAL resulting timestamp, snapshotted at mod
                   time (ORIGINAL_RESULT_DT).
  - "New value" at amendment N = PREV_RESULT of amendment N+1
    chronologically, or current tr.RESULT when N is the latest.

Filters
  - Window on MOD_DT (the amendment event itself)
  - Valid MRN (REGEXP_LIKE '^E[0-9]+$')
  - tr.EDITED_FLAG = 'Y' — the live-row "E" indicator from SCC's
    client status column. Redundant with STATE='Corrected' for
    routine amendments; both fire on a freshly-amended row.
  - Value actually changed (null-safe DECODE) — drops DMOD non-value
    edits and any RMOD that didn't ultimately move the value.
  - :DEPOT on COLLECT_CENTER_ID (LIKE wildcards supported)
  - System / interface amendments excluded — MOD_TECH NOT IN
    (HIS, SCC, AUTOV, RBS, I/AUT, AUTON), and MOD_TECH non-null /
    non-blank. Report is human-amender focused. Inventory verified
    via setup/test_result_history_probe.sql §42 + diagnostic top-10.
    The CHANGED_BY CASE branch for system identities is intentionally
    kept so the column behaves correctly if the WHERE filter is ever
    relaxed.

Caveats
  - PREV_RESULT='.' means the row was cancelled at that point in
    the chain. Cancel-to-value and value-to-cancel transitions both
    count as changes and surface here.
  - PREV_RESULT='See Comment' is a SCC sentinel — the real prior
    value lives in V_P_LAB_TEST_RESULT_HISTORY.PREV_COMMENT. This
    summary surfaces the sentinel as-is; switch to
    corrected_results_audit.sql for the PREV_COMMENT text.

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
        h.MOD_DT,
        h.MOD_TECH,
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
    hf.MOD_TECH
        || CASE
               WHEN hf.MOD_TECH IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
                   THEN ''
               WHEN usr.LASTNAME IS NOT NULL
                AND usr.LASTNAME <> ''
                   THEN ' ('
                        || TRIM(usr.LASTNAME
                               || CASE WHEN usr.FIRSTNAME IS NOT NULL
                                        AND usr.FIRSTNAME <> ''
                                       THEN ', ' || usr.FIRSTNAME
                                       ELSE '' END)
                        || ')'
               ELSE ''
           END                                      AS CHANGED_BY,
    hf.MOD_DT                                       AS CHANGED_AT
FROM hist_full hf
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID = hf.ATEST_AA_ID
INNER JOIN V_P_LAB_ORDER o        ON o.AA_ID  = tr.ORDER_AA_ID
INNER JOIN V_P_LAB_STAY st        ON st.AA_ID = o.STAY_AA_ID
INNER JOIN V_P_LAB_PATIENT pt     ON pt.AA_ID = st.PATIENT_AA_ID
LEFT JOIN  V_S_SEC_USER usr       ON usr.TECH_ID = hf.MOD_TECH
                                  AND usr.ROLE   = 'U'
WHERE hf.MOD_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND hf.MOD_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
  AND o.COLLECT_CENTER_ID LIKE :DEPOT
  AND REGEXP_LIKE(pt.ID, '^E[0-9]+$')
  AND tr.EDITED_FLAG = 'Y'
  AND hf.MOD_TECH IS NOT NULL
  AND hf.MOD_TECH <> ''
  AND hf.MOD_TECH NOT IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
  AND DECODE(hf.PREV_RESULT,
             COALESCE(hf.next_prev_result, tr.RESULT),
             1, 0) = 0
ORDER BY pt.ID, o.ID, tr.TEST_ID, hf.MOD_DT;
