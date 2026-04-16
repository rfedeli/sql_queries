-- Side-by-side diff of two LOCATIONS' specimen-tracking configuration.
-- Note: V_S_LAB_SPTR_SETUP.TERMINAL holds location codes (T1, J1, F1, etc.),
-- not device/PC IDs — so this diffs per-location setup, not per-device.
-- Pivots on (PLACE, POSITION) so matching rows line up; flags DIFFERS='Y'
-- when any compared field disagrees (or one side is missing).
-- Bind :term_a and :term_b to the two location codes to compare.
SELECT
    NVL(a.PLACE, b.PLACE)                                 AS PLACE,
    NVL(a.POSITION, b.POSITION)                           AS POSITION,
    stop_.SPECIMEN_STATUS,
    stop_.SPECIMEN_LOCATION,
    stop_.DESCRIPTION                                     AS PLACE_DESC,
    a.STATUS          AS STATUS_A,   b.STATUS          AS STATUS_B,
    a.HIDE            AS HIDE_A,     b.HIDE            AS HIDE_B,
    a.ACTIONS         AS ACTIONS_A,  b.ACTIONS         AS ACTIONS_B,
    a.LOCATION        AS LOCATION_A, b.LOCATION        AS LOCATION_B,
    a.CONTAINER       AS CONTAINER_A,b.CONTAINER       AS CONTAINER_B,
    a.LOC_DEPT_WRKSTN AS LDW_A,      b.LOC_DEPT_WRKSTN AS LDW_B,
    a.TYPE            AS TYPE_A,     b.TYPE            AS TYPE_B,
    a.SETUP_OPTION    AS OPT_A,      b.SETUP_OPTION    AS OPT_B,
    CASE
      WHEN a.AA_ID IS NULL THEN 'MISSING_IN_A'
      WHEN b.AA_ID IS NULL THEN 'MISSING_IN_B'
      WHEN NVL(a.STATUS,'~')         <> NVL(b.STATUS,'~')
        OR NVL(a.HIDE,'~')           <> NVL(b.HIDE,'~')
        OR NVL(a.ACTIONS,'~')        <> NVL(b.ACTIONS,'~')
        OR NVL(a.LOCATION,'~')       <> NVL(b.LOCATION,'~')
        OR NVL(a.CONTAINER,'~')      <> NVL(b.CONTAINER,'~')
        OR NVL(a.LOC_DEPT_WRKSTN,'~')<> NVL(b.LOC_DEPT_WRKSTN,'~')
        OR NVL(a.TYPE,'~')           <> NVL(b.TYPE,'~')
        OR NVL(TO_CHAR(a.SETUP_OPTION),'~') <> NVL(TO_CHAR(b.SETUP_OPTION),'~')
      THEN 'Y'
      ELSE 'N'
    END                                                   AS DIFFERS
FROM        (SELECT * FROM V_S_LAB_SPTR_SETUP WHERE TERMINAL = :term_a) a
FULL OUTER JOIN
            (SELECT * FROM V_S_LAB_SPTR_SETUP WHERE TERMINAL = :term_b) b
       ON b.PLACE    = a.PLACE
      AND b.POSITION = a.POSITION
LEFT JOIN   V_S_LAB_SPTR_STOP stop_
       ON   stop_.PLACE = NVL(a.PLACE, b.PLACE)
ORDER BY DIFFERS DESC, PLACE, POSITION;
