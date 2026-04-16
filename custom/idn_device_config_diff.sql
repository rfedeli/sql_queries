-- Per-device IDN (specimen ID / tracking) configuration diff.
-- V_S_IDN_DEVICE_OPTION stores key-value config per device: CODE = option name,
-- VALUE = option value. Bind :dev_a and :dev_b to the two device IDs.

-- Option-by-option side-by-side diff
SELECT NVL(a.CODE, b.CODE)                       AS OPTION_CODE,
       a.VALUE                                    AS VALUE_A,
       b.VALUE                                    AS VALUE_B,
       CASE
         WHEN a.AA_ID IS NULL THEN 'MISSING_IN_A'
         WHEN b.AA_ID IS NULL THEN 'MISSING_IN_B'
         WHEN NVL(a.VALUE,'~') <> NVL(b.VALUE,'~') THEN 'Y'
         ELSE 'N'
       END                                        AS DIFFERS
FROM        (SELECT * FROM V_S_IDN_DEVICE_OPTION WHERE DEVICE_ID = :dev_a) a
FULL OUTER JOIN
            (SELECT * FROM V_S_IDN_DEVICE_OPTION WHERE DEVICE_ID = :dev_b) b
       ON b.CODE = a.CODE
ORDER BY DIFFERS DESC, OPTION_CODE;

-- Label-format assignments per workstation (diff of LABEL_FORMAT by PRIORITY/ID)
SELECT NVL(a.ID, b.ID)                            AS LBL_ID,
       NVL(a.PRIORITY, b.PRIORITY)                AS PRIORITY,
       a.PRINTING_PROFILE                         AS PROFILE_A,
       b.PRINTING_PROFILE                         AS PROFILE_B,
       CASE WHEN NVL(a.PRINTING_PROFILE,'~') <> NVL(b.PRINTING_PROFILE,'~')
              OR NVL(DBMS_LOB.SUBSTR(a.LABEL_FORMAT,2000,1),'~')
                <> NVL(DBMS_LOB.SUBSTR(b.LABEL_FORMAT,2000,1),'~')
            THEN 'Y' ELSE 'N' END                 AS DIFFERS
FROM        (SELECT * FROM V_S_IDN_DOMAIN_LBLFMT WHERE WORKSTATION = :dev_a) a
FULL OUTER JOIN
            (SELECT * FROM V_S_IDN_DOMAIN_LBLFMT WHERE WORKSTATION = :dev_b) b
       ON b.ID = a.ID AND b.PRIORITY = a.PRIORITY
ORDER BY DIFFERS DESC, LBL_ID, PRIORITY;

-- Role/test assignments per workstation
SELECT NVL(a.ID, b.ID)                            AS ROLE_TEST_ID,
       a.ROLE_AA_ID                               AS ROLE_A,
       b.ROLE_AA_ID                               AS ROLE_B,
       CASE WHEN NVL(a.ROLE_AA_ID,-1) <> NVL(b.ROLE_AA_ID,-1)
            THEN 'Y' ELSE 'N' END                 AS DIFFERS
FROM        (SELECT * FROM V_S_IDN_ROLE_TEST WHERE WORKSTATION = :dev_a) a
FULL OUTER JOIN
            (SELECT * FROM V_S_IDN_ROLE_TEST WHERE WORKSTATION = :dev_b) b
       ON b.ID = a.ID
ORDER BY DIFFERS DESC, ROLE_TEST_ID;
