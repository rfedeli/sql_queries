-- All tests in the system (active and inactive)
-- Group tests (orderable panels) and individual component tests
SELECT
    tg.ID AS group_test_id,
    tg.GTNAME_UPPER AS group_test_name,
    tg.ACTIVE AS group_active,
    tg.TEST_COUNT AS component_count,
    tg.SERIES_TEST,
    tg.FL_LAST_LEVEL,
    tg.FL_SEND_OUT,
    t.ID AS component_test_id,
    t.NAME AS component_test_name,
    t.ACTIVE AS component_active,
    t.WORKSTATION_ID,
    t.DEPARTMENT_ID,
    t.LOINC,
    t.UNITS,
    t.RESULT_TYPE,
    t.FL_NOT_IN_TAT_CALC,
    t.FL_HIDDEN,
    t.FL_AUTORESULT,
    t.FL_DONOTREPORT
FROM V_S_LAB_TEST_GROUP tg
LEFT JOIN V_S_LAB_TEST_COMPONENT tc
    ON tc.TEST_AA_ID = tg.AA_ID
LEFT JOIN V_S_LAB_TEST t
    ON t.ID = tc.COMPONENT
ORDER BY tg.ACTIVE DESC, tg.ID, tc.TEST_SORT
