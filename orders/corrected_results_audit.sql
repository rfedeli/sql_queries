/*
Corrected Results Audit Report

One row per amendment event for results that are currently in STATE='Corrected'.
For each row: PREV_RESULT (value before this amendment) and NEW_RESULT
(value after — derived from the next amendment's PREV_RESULT, or, for the
last amendment, the current RESULT on V_P_LAB_TEST_RESULT).

V_P_LAB_TEST_RESULT_HISTORY semantics
  - One row per modification event on a result; ATEST_AA_ID -> tr.AA_ID.
  - PREV_RESULT  = value as it stood BEFORE this modification.
  - MOD_DT/_TECH/_REASON  = when/who/why the modification happened.
  - TYPE         = kind of modification. Observed enum (30-day data):
                   RMOD ~57% (result-value mod), DMOD ~43% (non-value
                   edit — range/comment/calc-component trigger), REVMOD
                   <1% (review-related, rare).
  - PREV_COMMENT = CLOB snapshot of the prior comment text. Surfaced
                   alongside PREV_RESULT because results with
                   PREV_RESULT='See Comment' carry the real value here.
                   PHI-adjacent (free-text narrative).
  Therefore the new value at amendment N is the PREV_RESULT of amendment
  N+1 (chronologically), or the current RESULT on V_P_LAB_TEST_RESULT
  when N is the latest.

Window
  :START_DATE / :END_DATE filter on MOD_DT — the amendment event itself.
  LEAD() runs over the full history per result so a window cut never
  loses the next-amendment lookup.

Cross-cutting filters
  - Valid MRN only: REGEXP_LIKE '^E[0-9]+$'
  - Current STATE = 'Corrected' (drops Final/Pending/Canceled). A result
    that was corrected and then re-amended back to Final won't appear.

Enrichment columns from outside the history view
  - UNVERIFIED_DT / UNVERIFIED_TECH (V_P_LAB_TEST_RESULT) — rollback
    timestamp on the live row, set when the result was un-verified before
    being re-verified. Pairs with CURR_VERIFIED_DT to give the
    un-verify -> re-verify gap directly off the result row, no history
    arithmetic needed.
  - RES_CHANGES_IN_PERM_REPORT (V_P_LAB_ORDER) — order-level counter for
    "result changes after a permanent report was sent." Non-zero values
    flag regulatory-flavored corrections (changes that escaped to a final
    report and forced a re-issue).

Parameters (Grapecity parameter type = String, YYYYMMDD for dates)
  :START_DATE  Start of amendment date range, e.g. 20260401
  :END_DATE    End of amendment date range inclusive, e.g. 20260427
  :DEPOT       V_P_LAB_ORDER.COLLECT_CENTER_ID, supports LIKE wildcards:
                 'T1'  Temple inpatient        'J1'  Jeanes inpatient
                 'T2'  Temple outpatient       'J2'  Jeanes outpatient
                 'T%'  all Temple              'J%'  all Jeanes
                 'C%'  all Chestnut Hill       'E%'  all Episcopal
                 'F%'  all Fox Chase           'W%'  all WFH
                 '%'   all facilities
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
        h.AA_ID                                                       AS hist_aa_id,
        h.MOD_DT,
        h.TYPE                                                        AS amend_type,
        h.MOD_TECH,
        h.MOD_REASON,
        h.PREV_RESULT,
        h.PREV_COMMENT,
        h.UNITS                                                       AS prev_units,
        h.RANGE_NORMAL                                                AS prev_normal_range,
        h.ABNORMAL_FLAGS                                              AS prev_abnormal_flags,
        h.VER_DT                                                      AS prev_verified_dt,
        h.VER_TECH                                                    AS prev_verified_tech,
        LEAD(h.PREV_RESULT) OVER (PARTITION BY h.ATEST_AA_ID
                                  ORDER BY h.MOD_DT, h.AA_ID)         AS next_prev_result
    FROM V_P_LAB_TEST_RESULT_HISTORY h
    WHERE h.ATEST_AA_ID IN (SELECT ATEST_AA_ID FROM qualifying_atests)
)
SELECT
    pt.ID                                                             AS MRN,
    pt.LAST_NAME,
    pt.FIRST_NAME,
    o.ID                                                              AS ORDER_NO,
    o.ORDERED_DT                                                      AS ORDER_DT,
    o.COLLECT_CENTER_ID,
    o.RES_CHANGES_IN_PERM_REPORT                                      AS PERM_REPORT_CHANGES,
    tr.TEST_ID,
    tr.GROUP_TEST_ID,
    tr.TEST_NAME,
    tr.LOINC_CODE,
    tr.TEST_PERFORMING_LOCATION                                       AS PERF_LOC,
    hf.MOD_DT                                                         AS AMENDED_AT,
    hf.amend_type                                                     AS AMEND_TYPE,
    hf.MOD_TECH                                                       AS AMENDED_BY,
    hf.MOD_REASON                                                     AS AMEND_REASON,
    hf.PREV_RESULT,
    COALESCE(hf.next_prev_result, tr.RESULT)                          AS NEW_RESULT,
    CASE WHEN DECODE(hf.PREV_RESULT,
                     COALESCE(hf.next_prev_result, tr.RESULT),
                     1, 0) = 0
         THEN 'Y' ELSE 'N'
    END                                                               AS RESULT_VALUE_CHANGED,
    hf.PREV_COMMENT                                                   AS PREV_COMMENT,
    tr.COMMENTS                                                       AS CURR_COMMENT,
    hf.prev_units                                                     AS PREV_UNITS,
    tr.UNITS                                                          AS CURR_UNITS,
    hf.prev_normal_range                                              AS PREV_NORMAL_RANGE,
    tr.NORMAL_RANGE                                                   AS CURR_NORMAL_RANGE,
    hf.prev_abnormal_flags                                            AS PREV_ABNORMAL_FLAGS,
    tr.ABNORMAL_FLAGS                                                 AS CURR_ABNORMAL_FLAGS,
    hf.prev_verified_dt                                               AS PREV_VERIFIED_DT,
    hf.prev_verified_tech                                             AS PREV_VERIFIED_TECH,
    tr.UNVERIFIED_DT                                                  AS UNVERIFIED_DT,
    tr.UNVERIFIED_TECH                                                AS UNVERIFIED_TECH,
    tr.VERIFIED_DT                                                    AS CURR_VERIFIED_DT,
    tr.TECH_ID                                                        AS CURR_TECH,
    tr.STATE                                                          AS CURR_STATE
FROM hist_full hf
INNER JOIN V_P_LAB_TEST_RESULT tr ON tr.AA_ID  = hf.ATEST_AA_ID
INNER JOIN V_P_LAB_ORDER o        ON o.AA_ID   = tr.ORDER_AA_ID
INNER JOIN V_P_LAB_STAY st        ON st.AA_ID  = o.STAY_AA_ID
INNER JOIN V_P_LAB_PATIENT pt     ON pt.AA_ID  = st.PATIENT_AA_ID
WHERE tr.STATE = 'Corrected'
  AND hf.MOD_DT >= TO_DATE(:START_DATE, 'YYYYMMDD')
  AND hf.MOD_DT <  TO_DATE(:END_DATE,   'YYYYMMDD') + 1
  AND o.COLLECT_CENTER_ID LIKE :DEPOT
  AND REGEXP_LIKE(pt.ID, '^E[0-9]+$')
ORDER BY pt.ID, o.ID, tr.TEST_ID, hf.MOD_DT;
