CREATE OR REPLACE FUNCTION clientdev_get_email (p_said IN NUMBER, p_user_prof_id IN NUMBER) RETURN VARCHAR2 AS
-- the function takes two parameters 
-- 1) SAID
-- 2) USER_PROF_IF
-- and returns the associated EMAIL
-- if no associated EMAIL exists, the function returns a NULL
-- a NULL is returned in case of an exception
--  v_data_table VARCHAR2(25)  := 'DATA_' || p_said;
  v_cursor_id NUMBER;
  v_email     VARCHAR2(150);
  v_query     VARCHAR2(150);
BEGIN
  --EXECUTE IMMEDIATE v_query INTO v_email USING IN p_said, IN p_user_prof_id;
  --v_query := 'SELECT email FROM data_REDACTED WHERE user_prof_id = :p_user_prof_id';
  --EXECUTE IMMEDIATE v_query INTO v_email USING IN p_user_prof_id;
  v_query := 'SELECT email INTO  FROM data_' || p_said || ' WHERE user_prof_id = ' || p_user_prof_id;
  v_cursor_id := DBMS_SQL.OPEN_CURSOR;
  v_email := DBMS_SQL.PARSE(v_cursor_id, v_query, DBMS_SQL.NATIVE);
  --v_email := DBMS_SQL.EXECUTE(v_cursor_id);
  DBMS_SQL.CLOSE_CURSOR(v_cursor_id);
  RETURN v_email;
--EXCEPTION
--  WHEN OTHERS THEN
    --RETURN NULL;
--    RETURN 'test';
END clientdev_get_email;
/
