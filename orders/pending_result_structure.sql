/*
Check structure of V_P_LAB_PENDING_RESULT
*/

SELECT
  cols.column_name AS col_name,
  cols.data_type,
  cols.data_length,
  cols.nullable
FROM user_tab_columns cols
WHERE cols.table_name = 'V_P_LAB_PENDING_RESULT'
ORDER BY cols.column_id;
