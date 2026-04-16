-- Given two device-terminal IDs, find their collection centers and compare setup
-- using the location-level keys that V_S_LAB_SPTR_SETUP actually uses.
SELECT t.TERMINAL AS DEVICE_ID,
       t.NAME     AS DEVICE_NAME,
       t.COLL_CENTER_ID,
       cc.SITE,
       (SELECT COUNT(*) FROM V_S_LAB_SPTR_SETUP s
         WHERE s.TERMINAL = t.COLL_CENTER_ID) AS SETUP_ROWS_AT_CENTER
FROM V_S_LAB_TERMINAL t
LEFT JOIN V_S_LAB_COLL_CENTER cc ON cc.ID = t.COLL_CENTER_ID
WHERE t.TERMINAL IN ('EE7EE','49601');
