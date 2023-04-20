CREATE OR REPLACE FUNCTION clientdev_get_issueid (p_mid IN issue.product_id%TYPE, p_wostart IN issue.wostart%TYPE) RETURN issue.issue_name%TYPE AS
-- the function takes two parameters 
-- 1) MAILING ID 
-- 2) WOSTART
-- and returns the associated ISSUE ID 
-- if no associated ISSUE ID exists, the function returns a NULL
-- a NULL is returned in case of an exception
  v_issueid issue.issue_name%TYPE := NULL;
BEGIN
  SELECT issue_name
  INTO   v_issueid
  FROM   issue
  WHERE  product_id = p_mid AND wostart = p_wostart;
  RETURN v_issueid;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END clientdev_get_issueid;
/
