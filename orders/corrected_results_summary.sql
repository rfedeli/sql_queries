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
  IS_PRIVILEGED       'Y' when the amender's V_S_SEC_USER row has
                      SCC_USER='Y' (rare super-account, ~7 rows total)
                      OR ACTIVE='N' (deactivated account — amendments
                      from deactivated accounts warrant auditor review).
                      'N' otherwise. NULL for unmatched amenders.
  CHANGE_SOURCE       'Person'         — MOD_TECH joined to a real
                                          V_S_SEC_USER ROLE='U' account
                                          with a name (manual edit by
                                          an identifiable person).
                      'System'         — MOD_TECH is a known automation/
                                          interface ID. Verified inventory
                                          (HIS, I/AUT, AUTON, SCC) plus
                                          historically-documented (AUTOV,
                                          RBS) — see CLAUDE.md
                                          V_P_LAB_TEST_RESULT_HISTORY
                                          notes for volume + provenance.
                      'User (no name)' — TECH_ID matches V_S_SEC_USER
                                          but LASTNAME is blank (service
                                          account left behind by SCC).
                      'Empty'          — MOD_TECH NULL or blank.
                      'Unknown'        — MOD_TECH didn't join and isn't
                                          a known system identity. If
                                          this appears at non-trivial
                                          volume, re-run
                                          setup/test_result_history_probe.sql
                                          §42 to refresh the system list.
  RMOD_COMMENT        reproduction of the SCC client's Result Comments
                      → History tab line tagged "RMOD" — the same
                      text the user sees in the UI. Format:
                      "Previous value was {VAL} {UNIT} , verified by
                       {VER_TECH} at {HH:MM} on {MM/DD/YYYY}."

V_P_LAB_TEST_RESULT_HISTORY semantics
  - One row per modification event; ATEST_AA_ID -> tr.AA_ID.
  - PREV_RESULT       = value before this modification.
  - VER_TECH/VER_DT   = ORIGINAL verifier and verification time,
                        snapshotted at mod time (NOT the post-amend
                        verifier — see CLAUDE.md).
  - RES_DT            = ORIGINAL resulting timestamp, snapshotted at
                        mod time.
  - "New value" at amendment N = PREV_RESULT of amendment N+1
    chronologically, or current tr.RESULT when N is the latest.
  - SCC client UI note: a single TYPE='RMOD' database row renders
    as TWO lines in the History tab — one tagged RMOD (snapshot
    half) and one tagged FMOD (action half). RMOD_COMMENT below
    reproduces the RMOD-tagged line. See CLAUDE.md
    V_P_LAB_TEST_RESULT_HISTORY → "SCC client History-tab display
    vs. database TYPE" for the full split-display documentation.

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
    non-blank. The report is human-amender focused. Inventory verified
    via setup/test_result_history_probe.sql §42 + diagnostic top-10.
    The CHANGE_SOURCE 'System' branch is intentionally kept in the
    classifier so the column behaves correctly if the WHERE filter
    is ever removed.

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
        h.UNITS                                                AS prev_units,
        h.VER_TECH                                             AS prev_verified_tech,
        h.VER_DT                                               AS prev_verified_dt,
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
    CASE
        WHEN hf.MOD_TECH IS NULL OR hf.MOD_TECH = ''
            THEN 'Empty'
        WHEN hf.MOD_TECH IN ('HIS','SCC','AUTOV','RBS','I/AUT','AUTON')
            THEN 'System'
        WHEN usr.TECH_ID IS NOT NULL
         AND usr.LASTNAME IS NOT NULL
         AND usr.LASTNAME <> ''
            THEN 'Person'
        WHEN usr.TECH_ID IS NOT NULL
            THEN 'User (no name)'
        ELSE 'Unknown'
    END                                             AS CHANGE_SOURCE,
    CASE
        WHEN usr.TECH_ID IS NULL                THEN NULL
        WHEN usr.SCC_USER  = 'Y'                THEN 'Y'
        WHEN usr.ACTIVE    = 'N'                THEN 'Y'
        ELSE 'N'
    END                                             AS IS_PRIVILEGED,
    'Previous value was ' || hf.PREV_RESULT
        || CASE WHEN hf.prev_units IS NOT NULL AND hf.prev_units <> ''
                THEN ' ' || hf.prev_units ELSE '' END
        || ' , verified by ' || hf.prev_verified_tech
        || ' at '  || TO_CHAR(hf.prev_verified_dt, 'HH24:MI')
        || ' on '  || TO_CHAR(hf.prev_verified_dt, 'MM/DD/YYYY')
        || '.'                                      AS RMOD_COMMENT
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
