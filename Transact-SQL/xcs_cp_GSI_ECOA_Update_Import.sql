USE [xyz_dms_cust_REDACTED]
GO

/****** Object:  StoredProcedure [dbo].[xcs_cp_REDACTED_ECOA_Update_Import]    Script Date: 5/23/2016 2:23:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[xcs_cp_REDACTED_ECOA_Update_Import](@import_id int)
AS

-- drop procedure xcs_cp_REDACTED_ECOA_Update_Import

/****** Object:  StoredProcedure [dbo].xcs_cp_REDACTED_ECOA_Update_Import    Script Date: 5/23/2015 ******/


DECLARE @err int, @row_cnt int, @proc_name varchar(255)
SET @proc_name = object_name(@@procid)
EXEC p_perf_log @proc_name, 'START', @row_cnt, null, 0

DECLARE @cust_id int = 538
DECLARE @epref_entity_id int = 121
DECLARE @time_zone_id varchar(255) = 'Central Standard Time' 


SET NOCOUNT ON


------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- Author: Mariusz Kula
-- Date: 5/23/2016
-- Client: REDACTED
-- CMS/DMS: REDACTED
-- Time zone: EST
-- Ticket(s): https://jira.cheetahmail.com/browse/PS-15411
--
-- As client's customers change their email addresses, a daily file of the changes gets loaded into a table called ECOA. The ECOA table is built specifically so that we can do an ECOA import stored procedure. 
-- The ECOA table has three unique identifiers, and all three fields are provided to us in the daily file from the client:
-- 1. Old_Email
-- 2. New_Email
-- 3. Timestamp
--
-- This stored procedure takes the data in this table and updates the email addresses inside the Marketing Suite as ECOA files are imported.
-- There are three different tables where the email address have to get changed:
-- 1. Reciepient
-- 2. Email_Activity
-- 3. Email_Preference
--
--
-- See PROCESS FLOW at the bottom of this page for more information about table layouts, etc.
--
-- PROCESS FLOW:
--
-- 1.  Create #ecoa table to map records from import file to e_ecoa table.
-- 2.  Create #epref_metadata table. Metadata about the fields of the e_email_preference table.
-- 3.  Create #epref_join table. Metadata about all the join tables that join to e_email_preference.
-- 4.  Create #map table for mapping of ECOA to e_email_preference.
-- 5.  Update e_email_preference where epref_new_email_pk_email_preference_id IS NULL
-- 6.  Update e_recipient_p_email
-- 7.  Update e_email_activity
-- 8.  Merge (Update/Insert) e_email_preference_p_ecoa_date
-- 9.  Merge (Update/Insert) e_recipient_p_ecoa_date
-- 10. Merge (Update/Insert) e_email_activity_p_ecoa_date
-- 11. Update/Delete e_email_preference Joins
--
-- UPDATE e_email_preference FIELDS
-- 12. EXECUTE Dynamic SQL INSERT into e_email_preference fields
-- 13. EXECUTE Dynamic SQL UPDATE e_email_preference fields
--
-- UPDATE DEPENDEND TABLES
-- 14. EXECUTE Dynamic SQL DELETE from deleted table
-- 15. EXECUTE Dynamic SQL DELETE from guid table
-- 16. EXECUTE Dynamic SQL DELETE from upd table
-- 17. EXECUTE Dynamic SQL DELETE from cust table
-- 
-- UPDATE e_email_preference FIELDS
-- 18. EXECUTE Dynamic SQL DELETE from e_email_preference FIELDS
--
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
BEGIN
  --
  -- 1. Create #ecoa to map records from import file to e_ecoa table.
  PRINT convert(varchar,getdate(),120)+' -->> Map records from import file to e_ecoa table'
  EXEC xcs_cp_perf_log @proc_name, 'START: Map records from import file to e_ecoa table'

  IF NOT EXISTS (SELECT TOP 1 pk_id FROM #pk_table)
  BEGIN
    --RAISERROR('No records to run against',16,0)
    RETURN
  END

  SELECT *
  INTO #ecoa
  FROM (
    SELECT e.*,
           ROW_NUMBER() OVER (PARTITION BY e.p_old_email ORDER BY e.creation_time DESC, e.p_timestamp DESC) AS row_count
    FROM #pk_table imp
    JOIN e_ecoa e WITH(NOLOCK) ON e.pk_ecoa_id = imp.pk_id
  ) AS i
  where i.row_count = 1 

  IF NOT EXISTS (SELECT TOP 1 pk_ecoa_id FROM #ecoa)
  BEGIN
    --RAISERROR('No records to run against',16,0)
    RETURN
  END

  CREATE INDEX tmp_ecoa_ix ON #ecoa(p_old_email)

  EXEC xcs_cp_perf_log @proc_name, 'END: Map records from import file to e_ecoa table', @@rowcount
  IF(@@error > 0) GOTO err
  --
  -- declare variables used in while loops
  DECLARE @i int
  DECLARE @j int
  --
  -- declare variables used in updating e_email_preference
  DECLARE @id int
  DECLARE @do_insert varchar(1)
  DECLARE @do_update varchar(1)
  DECLARE @do_delete varchar(1)
  DECLARE @entity_table_name varchar(255)
  DECLARE @property_table_name varchar(255)
  DECLARE @pk_field varchar(255)
  DECLARE @pk_field_type varchar(255)
  DECLARE @p_field varchar(255)
  DECLARE @p_field_type varchar(255)
  DECLARE @p_date varchar(255)
  DECLARE @p_date_type varchar(255)
  DECLARE @email_property_table_name varchar(255)
  DECLARE @email_property_column_name varchar(255)
  --
  -- declare variable to hold delete table names, deleted, merge, guid, cust, upd
  DECLARE @delete_table_name varchar(255)
  --
  -- declare variables used in updating e_email_activity
  DECLARE @old_email_pk_email_activity_id bigint
  DECLARE @old_email_ak_email_activity varchar(255)
  DECLARE @new_email_ak_email_activity varchar(255)
  DECLARE @old_email_creation_time datetime
  DECLARE @old_email_p_email varchar(255)
  DECLARE @new_email_p_email varchar(255)
  DECLARE @old_email_p_eventtype varchar(255)
  DECLARE @old_email_p_eventtimestamp datetime
  --
  --
  -- 2. Create #epref_metadata table. Metadata about the fields of the e_email_preference table.
  PRINT convert(varchar,getdate(),120)+' -->> CREATE #epref_metadata to hold e_email_preference table metadata'
  EXEC xcs_cp_perf_log @proc_name, 'START: CREATE TABLE #epref_metadata'
  --
  -- DROP TABLE #epref_metadata
  CREATE TABLE #epref_metadata (id INT IDENTITY(1,1), do_insert varchar(1), do_update varchar(1), do_delete varchar(1), entity_table_name varchar(255), property_table_name varchar(255), pk_field varchar(255), pk_field_type varchar(255), p_field varchar(255), p_field_type varchar(255), p_date varchar(255), p_date_type varchar(255))
  -- insert parent table
  INSERT INTO #epref_metadata (do_insert, do_update, do_delete, entity_table_name, property_table_name, pk_field, pk_field_type, p_field, p_field_type, p_date, p_date_type)
  SELECT 'N', -- do_insert
         'Y', -- do_update
         'Y', -- do_update
         dbo.f_entity_table_name_get(e.entity_id), -- entity_table_name
         dbo.f_entity_table_name_get(e.entity_id), -- property_table_name
         dbo.f_entity_pk_column_name_get(e.entity_id), -- pk_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, null), -- pk_field_type
         (SELECT dbo.f_prop_column_name_get(prop_id) FROM t_property WHERE entity_id = @epref_entity_id AND ak_seq = 1), -- p_field
         (SELECT dbo.f_prop_column_sql_data_type_get_by_prop_type(type_id, null) FROM t_property WHERE entity_id = @epref_entity_id AND ak_seq = 1), -- p_field_type
         NULL, -- p_date
         NULL -- p_date_type
  FROM t_entity e
  JOIN t_property p ON p.entity_id = e.entity_id
  WHERE e.entity_id = @epref_entity_id AND p.pk_flag = 1
  --
  -- populate table fields (child tables)
  INSERT INTO #epref_metadata (do_insert, do_update, do_delete, entity_table_name, property_table_name, pk_field, pk_field_type, p_field, p_field_type, p_date, p_date_type)
  SELECT CASE WHEN p.prop_name IN ('ecoa_date', 'email') THEN 'N' ELSE 'Y' END, -- do_insert
         CASE WHEN p.prop_name IN ('ecoa_date', 'email') THEN 'N' ELSE 'Y' END, -- do_update
         CASE WHEN p.prop_name IN ('email') THEN 'N' ELSE 'Y' END, -- do_delete
         dbo.f_entity_table_name_get(e.entity_id), -- entity_table_name
         dbo.f_prop_table_name_get(p.prop_id), -- property_table_name
         dbo.f_entity_pk_column_name_get(e.entity_id), -- pk_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- pk_field_type
         dbo.f_prop_column_name_get(p.prop_id), -- p_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- p_field_type
         NULL, -- p_date
         NULL -- p_date_type
  FROM t_entity e
  JOIN t_property p ON p.entity_id = e.entity_id
  WHERE e.entity_id = @epref_entity_id AND p.cust_id = @cust_id
  ORDER BY p.prop_name
  --
  -- populate table history fields (child tables)
  INSERT INTO #epref_metadata (do_insert, do_update, do_delete, entity_table_name, property_table_name, pk_field, pk_field_type, p_field, p_field_type, p_date, p_date_type)
  SELECT CASE WHEN p.prop_name IN ('ecoa_date', 'email') THEN 'N' ELSE 'Y' END, -- do_insert
         CASE WHEN p.prop_name IN ('ecoa_date', 'email') THEN 'N' ELSE 'Y' END, -- do_update
         CASE WHEN p.prop_name IN ('email') THEN 'N' ELSE 'Y' END, -- do_delete
         dbo.f_entity_table_name_get(e.entity_id), -- entity_table_name
         dbo.f_prop_history_table_name_get(p.prop_id), -- property_table_name
         dbo.f_entity_pk_column_name_get(e.entity_id), -- pk_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- pk_field_type
         dbo.f_prop_history_column_name_get(p.prop_id), -- p_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- p_field_type
         'record_time', -- p_date
         'datetime'-- p_date_type
  FROM t_entity e
  JOIN t_property p ON p.entity_id = e.entity_id
  WHERE e.entity_id = @epref_entity_id AND p.cust_id = @cust_id AND preference_flag is not null
  ORDER BY p.prop_name
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: CREATE TABLE #epref_metadata', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 3. Create #epref_join table. Metadata about all the join tables that join to e_email_preference.
  PRINT convert(varchar,getdate(),120)+' -->> CREATE #epref_joins to hold metadata of tables that join to e_email_preference'
  EXEC xcs_cp_perf_log @proc_name, 'START: CREATE TABLE #epref_join'
  --
  -- populate tables which join to e_email_preference (entity_id = 121)
  CREATE TABLE #epref_join (id INT IDENTITY(1,1), do_insert varchar(1), do_update varchar(1), do_delete varchar(1), entity_table_name varchar(255), property_table_name varchar(255), pk_field varchar(255), pk_field_type varchar(255), p_field varchar(255), p_field_type varchar(255), email_property_table_name varchar(255), email_property_column_name varchar(255))
  INSERT INTO #epref_join (do_insert, do_update, do_delete, entity_table_name, property_table_name, pk_field, pk_field_type, p_field, p_field_type, email_property_table_name, email_property_column_name)
  SELECT 'Y', -- do_insert
         'Y', -- do_update
         'Y', -- do_delete
         dbo.f_entity_table_name_get(e.entity_id), -- entity_table_name
         dbo.f_prop_table_name_get(p.prop_id), -- property_table_name
         dbo.f_entity_pk_column_name_get(e.entity_id), -- pk_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- pk_field_type
         dbo.f_prop_column_name_get(p.prop_id), -- p_field
         dbo.f_prop_column_sql_data_type_get_by_prop_type(p.type_id, NULL), -- p_field_type
         (SELECT dbo.f_prop_table_name_get(prop_id)  FROM t_property WHERE entity_id = e.entity_id AND prop_name = 'email'), -- email_property_table_name
         (SELECT dbo.f_prop_column_name_get(prop_id) FROM t_property WHERE entity_id = e.entity_id AND prop_name = 'email') -- email_property_column_name
  FROM t_entity e
  JOIN t_property p ON p.entity_id = e.entity_id
  WHERE p.type_id = @epref_entity_id
  ORDER BY p.prop_name
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: CREATE TABLE #epref_join', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 4. Create #map table for mapping of ECOA to e_email_preference.
  PRINT convert(varchar,getdate(),120)+' -->> CREATE #map table for mapping of ECOA to e_email_preference'
  EXEC xcs_cp_perf_log @proc_name, 'START: CREATE TABLE #map'
  -- DROP TABLE #map
  CREATE TABLE #map (
    ecoa_pk_ecoa_id bigint,
    ecoa_p_new_email varchar(255),
    ecoa_p_old_email varchar(255),
    ecoa_creation_time datetime,
    ecoa_p_timestamp datetime,
    ecoa_p_updsrce varchar(255),
  )
  --
  SET    @i = 1
  SELECT @j = COUNT(*) FROM #epref_metadata
  --
  WHILE @i <= @j
  BEGIN
    -- load the variables
    SELECT @id = id,
           @do_insert = do_insert,
           @do_update = do_update,
           @do_delete = do_delete,
           @entity_table_name = entity_table_name,
           @property_table_name = property_table_name,
           @pk_field = pk_field,
           @pk_field_type = pk_field_type,
           @p_field = p_field,
           @p_field_type = p_field_type,
           @p_date = p_date,
           @p_date_type = p_date_type
    FROM #epref_metadata
    WHERE id = @i
    --
    IF NOT(@do_insert = 'N' AND @do_update = 'N' AND @do_delete = 'N')
    BEGIN
      IF @id = 1 -- parent table
      BEGIN
        EXEC('ALTER TABLE #map ADD epref_new_email_' + @pk_field + ' ' + @pk_field_type)
        EXEC('ALTER TABLE #map ADD epref_old_email_' + @pk_field + ' ' + @pk_field_type)
        EXEC('ALTER TABLE #map ADD epref_new_email_' + @p_field  + ' ' + @p_field_type)
        EXEC('ALTER TABLE #map ADD epref_old_email_' + @p_field  + ' ' + @p_field_type)
      END
      ELSE
      BEGIN
        EXEC('ALTER TABLE #map ADD epref_new_email_' + @p_field + ' ' + @p_field_type)
        EXEC('ALTER TABLE #map ADD epref_old_email_' + @p_field + ' ' + @p_field_type)
      END
    END
    --
    SET @i = @i + 1
  END
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: CREATE TABLE #map', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  PRINT convert(varchar,getdate(),120)+' -->> Map records from e_ecoa table to e_email_preference table'
  EXEC xcs_cp_perf_log @proc_name, 'START: Map records from e_ecoa table to e_email_preference table'
  --
  INSERT INTO #map (
    ecoa_pk_ecoa_id,
    ecoa_p_new_email,
    ecoa_p_old_email,
    ecoa_creation_time,
    ecoa_p_timestamp,
    ecoa_p_updsrce
  )
  SELECT 
    e.pk_ecoa_id,
    e.p_new_email,
    e.p_old_email,
    e.creation_time,
    e.p_timestamp,
    s.p_updsrce
  FROM #ecoa e
  LEFT OUTER JOIN e_ecoa_p_updsrce s WITH(NOLOCK) ON s.pk_ecoa_id = e.pk_ecoa_id
  --
  CREATE INDEX tmp_new_email_ix ON #map(ecoa_p_new_email)
  CREATE INDEX tmp_old_email_ix ON #map(ecoa_p_old_email)
  --
  --
  SET    @i = 1
  SELECT @j = COUNT(*) FROM #epref_metadata
  --
  WHILE @i <= @j
  BEGIN
    SELECT @id = id,
           @do_insert = do_insert,
           @do_update = do_update,
           @do_delete = do_delete,
           @entity_table_name = entity_table_name,
           @property_table_name = property_table_name,
           @pk_field = pk_field,
           @pk_field_type = pk_field_type,
           @p_field = p_field,
           @p_field_type = p_field_type,
           @p_date = p_date,
           @p_date_type = p_date_type
    FROM #epref_metadata
    WHERE id = @i
    --
    IF @id = 1 -- parent table
    BEGIN
      EXEC('UPDATE #map SET epref_new_email_' + @pk_field + ' = p.' + @pk_field + ', epref_new_email_' + @p_field  + ' = p.' + @p_field  + ' FROM #map m JOIN ' + @entity_table_name + ' p WITH(NOLOCK) ON p.p_email = m.ecoa_p_new_email') 
      --
      EXEC('UPDATE #map SET epref_old_email_' + @pk_field + ' = p.' + @pk_field + ', epref_old_email_' + @p_field  + ' = p.' + @p_field  + ' FROM #map m JOIN ' + @entity_table_name + ' p WITH(NOLOCK) ON p.p_email = m.ecoa_p_old_email')
      --
    END
    ELSE
    IF NOT(@do_insert = 'N' AND @do_update = 'N' AND @do_delete = 'N')
    BEGIN
      EXEC('UPDATE #map SET epref_new_email_' + @p_field + ' = p.' + @p_field + ' FROM #map m JOIN ' + @entity_table_name + ' e WITH(NOLOCK) ON e.p_email = m.ecoa_p_new_email LEFT OUTER JOIN ' + @property_table_name + ' p WITH(NOLOCK) ON p.' + @pk_field + ' = e.' + @pk_field)
      --
      EXEC('UPDATE #map SET epref_old_email_' + @p_field + ' = p.' + @p_field + ' FROM #map m JOIN ' + @entity_table_name + ' e WITH(NOLOCK) ON e.p_email = m.ecoa_p_old_email LEFT OUTER JOIN ' + @property_table_name + ' p WITH(NOLOCK) ON p.' + @pk_field + ' = e.' + @pk_field)
      --
    END
    --
    SET @i = @i + 1
  END
  --
  CREATE INDEX tmp_new_email_id_ix ON #map(epref_new_email_pk_email_preference_id)
  CREATE INDEX tmp_old_email_id_ix ON #map(epref_old_email_pk_email_preference_id)
  -- END populate mapping temp table that will be used to run the required logic
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: Map records from e_ecoa table to e_email_preference table', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -----------------------------------------------------------------------
  -- Old_Email Exists and New_Email Does not Exist in Email_Preference
  -- a. Locate matching record based off of Email in Email_Preference and Old_Email in ECOA
  -- b. Make sure that no other records match based off of Email in Email_Preference match the New_Email in ECOA
  -- c. Update Email in Email_Preference to reflect the New_Email value in ECOA
  --
  --
  -- 5. Update e_email_preference where epref_new_email_pk_email_preference_id IS NULL
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_email_preference'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_email_preference'
  --
  UPDATE e_email_preference
  SET ak_email_preference = m.ecoa_p_new_email,
      p_email = m.ecoa_p_new_email
  FROM #map m
  JOIN e_email_preference p WITH(NOLOCK) ON p.pk_email_preference_id = m.epref_old_email_pk_email_preference_id -- Locate matching record based off of Email in Email_Preference and Old_Email in ECOA. Old_Email Exists in Email_Preference
  WHERE m.epref_new_email_pk_email_preference_id IS NULL -- New_Email Does not Exist in Email_Preference. Make sure that no other records match based off of Email in Email_Preference match the New_Email in ECOA
  -- END UPDATE e_email_preference
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_preference', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 6. Update e_recipient_p_email
  PRINT convert(varchar,getdate(),120)+' -->> UPDATE e_recipient_p_email'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_recipient_p_email'
  --
  UPDATE e_recipient_p_email
  SET p_email = m.ecoa_p_new_email
  FROM #map m
  JOIN e_recipient_p_email r WITH(NOLOCK) ON r.p_email = m.ecoa_p_old_email -- Locate matching records based off of Email in Customers and Old_Email in ECOA
  -- END UPDATE e_recipient_p_email
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_recipient_p_email', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 7. Update e_email_activity
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_email_activity'
  EXEC xcs_cp_perf_log @proc_name, 'Start: UPDATE e_email_activity', @@rowcount
  --
  DECLARE oe_cursor CURSOR FOR
  SELECT a.pk_email_activity_id,
         a.ak_email_activity,
         a.creation_time,
         a.p_email,
         m.ecoa_p_new_email,
         a.p_eventtype,
         a.p_eventtimestamp
  FROM e_email_activity a
  JOIN #map m WITH(NOLOCK) ON m.ecoa_p_old_email = a.p_email -- Locate matching records based off of Email in Email_Activity and Old_Email in ECOA
  FOR UPDATE OF ak_email_activity, p_email

  OPEN oe_cursor

  FETCH NEXT FROM oe_cursor
  INTO @old_email_pk_email_activity_id,
       @old_email_ak_email_activity,
       @old_email_creation_time,
       @old_email_p_email,
       @new_email_p_email,
       @old_email_p_eventtype,
       @old_email_p_eventtimestamp
  --
  EXEC xcs_cp_perf_log @proc_name, 'START: CURSOR loop'
  --
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- increment current p_eventtimestamp by 10ms until no matching value of ak_email_activity found in e_email_activity
    SET @old_email_p_eventtimestamp = DATEADD(ms, 10, @old_email_p_eventtimestamp)
    SET @new_email_ak_email_activity = @new_email_p_email + '+' + @old_email_p_eventtype + '+' + CONVERT(varchar(30), @old_email_p_eventtimestamp, 109)
    -- 
    -- if ak_email_activity value not found in e_email_activity table
    -- update ak_email_activity in e_email_activity with new value
    -- get next row from cursor
    IF NOT EXISTS (SELECT * FROM e_email_activity WHERE ak_email_activity = @new_email_ak_email_activity)
    BEGIN
      UPDATE e_email_activity SET
        ak_email_activity = @new_email_ak_email_activity,
        p_email = @new_email_p_email
      WHERE CURRENT OF oe_cursor
      --
      FETCH NEXT FROM oe_cursor
      INTO @old_email_pk_email_activity_id,
           @old_email_ak_email_activity,
           @old_email_creation_time,
           @old_email_p_email,
           @new_email_p_email,
           @old_email_p_eventtype,
           @old_email_p_eventtimestamp
    END
  END
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: CURSOR loop', @@rowcount
  --
  CLOSE oe_cursor
  DEALLOCATE oe_cursor
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_activity', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -----------------------------------------------------------------------
  -- START UPDATE time of update to email_preference, recipient, and email_activity
  --
  -- 8. Merge (Update/Insert) e_email_preference_p_ecoa_date
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_email_preference_p_ecoa_date' 
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_email_preference_p_ecoa_date'
  --
  MERGE e_email_preference_p_ecoa_date AS t
  USING (SELECT epref_old_email_pk_email_preference_id,
                MAX(ecoa_creation_time) AS 'ecoa_creation_time'
         FROM #map
         WHERE epref_new_email_pk_email_preference_id IS NULL
         GROUP BY epref_old_email_pk_email_preference_id
  ) AS s
  ON s.epref_old_email_pk_email_preference_id = t.pk_email_preference_id
  WHEN MATCHED THEN
    UPDATE SET p_ecoa_date = dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id)
  WHEN NOT MATCHED THEN
    INSERT (pk_email_preference_id, p_ecoa_date) VALUES (s.epref_old_email_pk_email_preference_id, dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id))
  ; 
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_preference_p_ecoa_date', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_email_preference_p_ecoa_date' 
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_email_preference_p_ecoa_date'
  --
  MERGE e_email_preference_p_ecoa_date AS t
  USING (SELECT epref_new_email_pk_email_preference_id,
                MAX(ecoa_creation_time) AS 'ecoa_creation_time'
         FROM #map
         WHERE epref_new_email_pk_email_preference_id IS NOT NULL
         GROUP BY epref_new_email_pk_email_preference_id
  ) AS s
  ON s.epref_new_email_pk_email_preference_id = t.pk_email_preference_id
  WHEN MATCHED THEN
    UPDATE SET p_ecoa_date = dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id)
  WHEN NOT MATCHED THEN
    INSERT (pk_email_preference_id, p_ecoa_date) VALUES (s.epref_new_email_pk_email_preference_id, dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id))
  ; 
  -- END UPDATE e_email_preference_p_ecoa_date
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_preference_p_ecoa_date', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 9. Merge (Update/Insert) e_recipient_p_ecoa_date
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_recipient_p_ecoa_date'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_recipient_p_ecoa_date'
  --
  MERGE e_recipient_p_ecoa_date AS t
  USING (SELECT r.pk_recip_id,
                MAX(m.ecoa_creation_time) AS 'ecoa_creation_time'
         FROM #map m
         JOIN e_recipient_p_email r WITH(NOLOCK) ON r.p_email = m.ecoa_p_new_email -- Locate matching records based off of Email in Customers and New_Email in ECOA
         GROUP BY r.pk_recip_id
  ) AS s
  ON s.pk_recip_id = t.pk_recip_id
  WHEN MATCHED THEN
    UPDATE SET p_ecoa_date = dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id)
  WHEN NOT MATCHED THEN
    INSERT (pk_recip_id, p_ecoa_date) VALUES (s.pk_recip_id, dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id))
  ; 
  -- END UPDATE e_recipient_p_ecoa_date
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_recipient_p_ecoa_date', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 10. Merge (Update/Insert) e_email_activity_p_ecoa_date
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE e_email_activity_p_ecoa_date'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_email_activity_p_ecoa_date'
  --
  MERGE e_email_activity_p_ecoa_date AS t
  USING (SELECT a.pk_email_activity_id,
                MAX(m.ecoa_creation_time) AS 'ecoa_creation_time'
         FROM #map m
         JOIN e_email_activity a WITH(NOLOCK) ON a.p_email = m.ecoa_p_new_email -- Locate matching records based off of Email in Customers and New_Email in ECOA
         GROUP BY a.pk_email_activity_id
  ) AS s
  ON s.pk_email_activity_id = t.pk_email_activity_id
  WHEN MATCHED THEN
    UPDATE SET p_ecoa_date = dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id)
  WHEN NOT MATCHED THEN
    INSERT (pk_email_activity_id, p_ecoa_date) VALUES (s.pk_email_activity_id, dbo.ConvertDateTimeFromServer(s.ecoa_creation_time, @time_zone_id))
  ; 
  -- END UPDATE e_email_activity_p_ecoa_date
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_activity_p_ecoa_date', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- 11. Update/Delete e_email_preference Joins
  -- Old_Email and New_Email Exists in Email_Preference
  -- a. Update joins so that all Customers records all join up to the surviving Email_Preference record
  PRINT convert(varchar,getdate(),120)+' -->> START UPDATE TABLES that JOIN e_email_preferece'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE TABLES that JOIN e_email_preferece'
  --
  SET    @i = 1
  SELECT @j = COUNT(*) FROM #epref_join
  --
  WHILE @i <= @j
  BEGIN
    SELECT @id = id,
           @do_insert = do_insert,
           @do_update = do_update,
           @do_delete = do_delete,
           @entity_table_name = entity_table_name,
           @property_table_name = property_table_name,
           @pk_field = pk_field,
           @pk_field_type = pk_field_type,
           @p_field = p_field,
           @p_field_type = p_field_type,
           @email_property_table_name = email_property_table_name,
           @email_property_column_name = email_property_column_name
    FROM #epref_join
    WHERE id = @i
    --
    EXEC('UPDATE ' + @property_table_name + ' SET ' + @p_field + ' = m.epref_new_email_pk_email_preference_id FROM #map m JOIN ' + @email_property_table_name + ' e WITH(NOLOCK) ON e.' + @email_property_column_name + ' = m.ecoa_p_new_email JOIN ' + @property_table_name + ' j WITH(NOLOCK) ON j.' + @pk_field + ' = e.' + @pk_field + ' WHERE m.epref_new_email_p_email IS NOT NULL')
    --
	EXEC('DELETE FROM ' + @property_table_name + ' FROM ' + @property_table_name + ' j JOIN #map m ON m.epref_old_email_pk_email_preference_id = j.' + @p_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
	--
    SET @i = @i + 1
  END 
  -- END UPDATE TABLES that JOIN to e_email_preference
  -- 
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE TABLES that JOIN e_email_preferece', @@rowcount
  IF(@@error > 0) GOTO err
  --
  --
  -- Old_Email and New_Email Exists in Email_Preference
  -- 1.Locate matching records based off of Email in Email_Preference and Old_Email in ECOA
  -- 2.Make sure that there is a separate matching record based off of Email in Email_Preference and New_Email in ECOA
  -- 3.Merge the two Email_Preference records together:
  --    a. Based on UpdSrce (GT_ECOA vs GS_ECOA) in the ECOA table. 
  --       If UpdSrce is GT_ECOA keep all four fields listed below with based off the most recent GT_EmailOptInDT. 
  --       If UpdSrce is GS_ECOA keep all four fields listed below with based off the most recent GS_EmailOptInDT.
  --
  --       Based on UpdSrce (GT_ECOA vs GS_ECOA) keep the following fields:
  --       i.   GT_EmailOptIn
  --       ii.  GS_EmailOptIn
  --       iii. GT_EmailOptInDT
  --       iv.  GS_EmailOptInDT
  --
  --    b. Based on UpdTime in the Email_Preference table. All other fields aside from the four listed above get preserved on the most recent UpdTime.
  --    c. Nulls/Blank fields never overwrite populated values.
  -- 4.See bullet #3 from the Customers table, all Customers records must join up to the surviving Email_Preference record
  -- 5.Email_Preference record that is not surviving will be deleted
  -- 6.Add to Update History on surviving record to say “Updated Email Address via ECOA from (Old_Email) to (New Email)
  --
  --
  -- START UPDATE i, ii, iii, iv.
  -- i.   GT_EmailOptIn   - e_email_preference_p_gt_emailoptinfl
  -- ii.  GS_EmailOptIn   - e_email_preference_p_gs_emailoptinfl
  -- iii. GT_EmailOptInDT - e_email_preference_p_gt_emailoptindt
  -- iv.  GS_EmailOptInDT - e_email_preference_p_gs_emailoptindt
  --
  -- UPDATE e_email_preference FIELDS
  PRINT convert(varchar,getdate(),120)+' -->> UPDATE e_email_preference table fields'
  EXEC xcs_cp_perf_log @proc_name, 'START: UPDATE e_email_preference table fields'
  --
  SELECT @i = COUNT(*) FROM #epref_metadata
  --
  WHILE @i > 0
  BEGIN
    SELECT @id = id,
           @do_insert = do_insert,
           @do_update = do_update,
           @do_delete = do_delete,
           @entity_table_name = entity_table_name,
           @property_table_name = property_table_name,
           @pk_field = pk_field,
           @pk_field_type = pk_field_type,
           @p_field = p_field,
           @p_field_type = p_field_type,
           @p_date = p_date,
           @p_date_type = p_date_type
    FROM #epref_metadata 
    WHERE id = @i
    --
    PRINT convert(varchar,getdate(),120)+' -->> Generate Dynamic SQL INSERT, UPDATE, DELETE for ' + @property_table_name
    EXEC xcs_cp_perf_log @proc_name, 'START: Generate Dynamic SQL INSERT, UPDATE, DELETE'
    --
    -- INSERT
    IF @do_insert = 'Y'
    BEGIN
      -- 12. EXECUTE Dynamic SQL INSERT into e_email_preference fields
      PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL INSERT into email_preference table'
      --
      IF @p_date IS NOT NULL
      BEGIN
        EXEC('INSERT INTO ' + @property_table_name + '(' + @pk_field + ', ' + @p_field + ', ' + @p_date + ') SELECT CASE WHEN m.epref_new_email_' + @p_field + ' IS NULL THEN m.epref_new_email_' + @pk_field + ' ELSE m.epref_old_email_' + @pk_field + ' END, ISNULL(m.epref_new_email_' + @p_field + ', m.epref_old_email_' + @p_field + '), GETDATE() FROM #map m WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL AND ((m.epref_new_email_' + @p_field + ' IS NULL AND m.epref_old_email_' + @p_field + ' IS NOT NULL) OR (m.epref_new_email_' + @p_field + ' IS NOT NULL AND m.epref_old_email_' + @p_field + ' IS NULL))')
      END
      ELSE
      BEGIN
        EXEC('INSERT INTO ' + @property_table_name + '(' + @pk_field + ', ' + @p_field + ') SELECT CASE WHEN m.epref_new_email_' + @p_field + ' IS NULL THEN m.epref_new_email_' + @pk_field + ' ELSE m.epref_old_email_' + @pk_field + ' END, ISNULL(m.epref_new_email_' + @p_field + ', m.epref_old_email_' + @p_field + ') FROM #map m WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL AND ((m.epref_new_email_' + @p_field + ' IS NULL AND m.epref_old_email_' + @p_field + ' IS NOT NULL) OR (m.epref_new_email_' + @p_field + ' IS NOT NULL AND m.epref_old_email_' + @p_field + ' IS NULL))')
      END
      --
      EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL INSERT: e_email_preference', @@rowcount
      IF(@@error > 0) GOTO err
    END
    --
    -- UPDATE
    IF @do_update = 'Y'  
    BEGIN
      -- 13. EXECUTE Dynamic SQL UPDATE e_email_preference fields
      PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL UPDATE email_preference'
      --
      IF @property_table_name = 'e_email_preference'
      BEGIN
        EXEC('UPDATE ' + @property_table_name + ' SET ' + @p_field + ' = m.ecoa_p_new_email FROM #map m JOIN ' + @property_table_name + ' p WITH(NOLOCK) ON p.' + @pk_field + ' IN (m.epref_new_email_pk_email_preference_id, m.epref_old_email_pk_email_preference_id) WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
      END
      ELSE IF @property_table_name IN ('e_email_preference_p_gs_emailoptindt', 'e_email_preference_p_gs_emailoptinfl', 'e_email_preference_p_gs_emailoptinfl_history', 'e_email_preference_p_gt_emailoptindt', 'e_email_preference_p_gt_emailoptinfl', 'e_email_preference_p_gt_emailoptinfl_history')
      BEGIN
        EXEC('UPDATE ' + @property_table_name + ' SET ' + @p_field + ' = CASE  m.ecoa_p_updsrce WHEN ''GT_ECOA'' THEN CASE WHEN ISNULL(m.epref_new_email_p_gt_emailoptindt, '''') >= ISNULL(m.epref_old_email_p_gt_emailoptindt, '''') THEN ISNULL(m.epref_new_email_' + @p_field + ', m.epref_old_email_' + @p_field + ') ELSE ISNULL(m.epref_old_email_' + @p_field + ', m.epref_new_email_' + @p_field + ') END WHEN ''GS_ECOA'' THEN CASE WHEN ISNULL(m.epref_new_email_p_gs_emailoptindt, '''') >= ISNULL(m.epref_old_email_p_gs_emailoptindt, '''') THEN ISNULL(m.epref_new_email_' + @p_field + ', m.epref_old_email_' + @p_field + ') ELSE ISNULL(m.epref_old_email_' + @p_field + ', m.epref_new_email_' + @p_field + ') END END FROM #map m JOIN ' + @property_table_name + ' p WITH(NOLOCK) ON p.' + @pk_field + ' IN (m.epref_new_email_pk_email_preference_id, m.epref_old_email_pk_email_preference_id) WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
      END 
      ELSE
      BEGIN
        EXEC('UPDATE ' + @property_table_name + ' SET ' + @p_field + ' = CASE WHEN ISNULL(m.epref_new_email_p_updtime, '''') >= ISNULL(m.epref_old_email_p_updtime, '''') THEN ISNULL(m.epref_new_email_' + @p_field + ', m.epref_old_email_' + @p_field + ') ELSE ISNULL(m.epref_old_email_' + @p_field + ', m.epref_new_email_' + @p_field + ') END FROM #map m JOIN ' + @property_table_name + ' p WITH(NOLOCK) ON p.' + @pk_field + ' IN (m.epref_new_email_pk_email_preference_id, m.epref_old_email_pk_email_preference_id) WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
      END
      --
      EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL UPDATE: e_email_preference', @@rowcount
      IF(@@error > 0) GOTO err
    END
    -- 
    --
    -- UPDATE DEPENDEND TABLES
    IF @do_delete = 'Y'
    BEGIN
      --
      IF @id = 1 -- parent table, we need to remove any history of the record
      BEGIN
        --
        --
        -- 14. EXECUTE Dynamic SQL DELETE from deleted table
        PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from deleted table: '
        -- DELETE from deleted table
        SET @delete_table_name = dbo.f_entity_deleted_table_name_get(@epref_entity_id)
        --
        EXEC('DELETE FROM ' + @delete_table_name + ' FROM ' + @delete_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.' + @pk_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
        --
        EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from deleted table', @@rowcount
        IF(@@error > 0) GOTO err
        --
        --
        -- 15. EXECUTE Dynamic SQL DELETE from guid table
        PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from guid table'
        -- DELETE from guid table
        SET @delete_table_name = dbo.f_entity_ak_guid_table_name_get(@epref_entity_id)
        --
        EXEC('DELETE FROM ' + @delete_table_name + ' FROM ' + @delete_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.' + @pk_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
        --
        EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from guid table', @@rowcount
        IF(@@error > 0) GOTO err
        --
        --
        -- PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from merge table'
        -- DELETE from merge table
        -- SET @delete_table_name = dbo.f_entity_merge_table_name_get(@epref_entity_id)
        --
        -- EXEC('DELETE FROM ' + @delete_table_name + ' FROM ' + @delete_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.target_pk_id WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
        --
        -- EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from merge table', @@rowcount
        -- IF(@@error > 0) GOTO err
        --
        --
        -- 16. EXECUTE Dynamic SQL DELETE from upd table
        PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from upd table'
        -- DELETE from upd table
        SET @delete_table_name = dbo.f_upd_entity_table_name_get(@epref_entity_id)
        --
        EXEC('DELETE FROM ' + @delete_table_name + ' FROM ' + @delete_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.' + @pk_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
        --
        EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from upd table', @@rowcount
        IF(@@error > 0) GOTO err
        --
        --
        -- 17. EXECUTE Dynamic SQL DELETE from cust table
        PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from cust table'
        -- DELETE from cust table
        SET @delete_table_name = dbo.f_cust_entity_table_name_get(@epref_entity_id)
        --
        EXEC('DELETE FROM ' + @delete_table_name + ' FROM ' + @delete_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.' + @pk_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
        --
        EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from cust table', @@rowcount
        IF(@@error > 0) GOTO err
        --
      END
      --
      -- UPDATE e_email_preference FIELDS
      -- 18. EXECUTE Dynamic SQL DELETE from e_email_preference FIELDS
      PRINT convert(varchar,getdate(),120)+' -->> EXECUTE Dynamic SQL DELETE from email_preference table'
      -- DELETE from email_preference table
      EXEC('DELETE FROM ' + @property_table_name + ' FROM ' + @property_table_name + ' p JOIN #map m ON m.epref_old_email_' + @pk_field + ' = p.' + @pk_field + ' WHERE m.epref_old_email_p_email IS NOT NULL AND m.epref_new_email_p_email IS NOT NULL')
      --
      EXEC xcs_cp_perf_log @proc_name, 'EXECUTE Dynamic SQL DELETE from email_preference table', @@rowcount
      IF(@@error > 0) GOTO err
    END
    --
    EXEC xcs_cp_perf_log @proc_name, 'END: Generate Dynamic SQL INSERT, UPDATE, DELETE', @@rowcount
    IF(@@error > 0) GOTO err
    -- 
    -- onto the next field
    SET @i = @i - 1
  END
  --
  EXEC xcs_cp_perf_log @proc_name, 'END: UPDATE e_email_preference table fields', @@rowcount
  IF(@@error > 0) GOTO err
  --
END

done:

EXEC p_perf_log @proc_name, 'FINISH', @row_cnt, null, 0
RETURN 0

err:

EXEC p_perf_log @proc_name, 'FINISH WITH ERROR', @row_cnt, null, 0
RETURN @err



GO


------------------------------------------------------------------------------------------
-- PROCESS FLOW:
--
-- 1. Create #ecoa table to map records from import file to e_ecoa table.
--
-- 2. Create #epref_metadata table. Metadata about the fields of the e_email_preference table.
--
--    id|do_insert|do_update|do_delete|entity_table_name|property_table_name|pk_field|pk_field_type|p_field|p_field_type|p_date|p_date_type
--    1|N|Y|Y|e_email_preference|e_email_preference|pk_email_preference_id|bigint|p_email|varchar(255)|NULL|NULL
--    2|Y|Y|Y|e_email_preference|e_email_preference_p_address_1|pk_email_preference_id|varchar(255)|p_address_1|varchar(255)|NULL|NULL
--    3|Y|Y|Y|e_email_preference|e_email_preference_p_address_2|pk_email_preference_id|varchar(255)|p_address_2|varchar(255)|NULL|NULL
--    4|Y|Y|Y|e_email_preference|e_email_preference_p_bday_day|pk_email_preference_id|integer|p_bday_day|integer|NULL|NULL
--    5|Y|Y|Y|e_email_preference|e_email_preference_p_bday_month|pk_email_preference_id|integer|p_bday_month|integer|NULL|NULL
--    6|Y|Y|Y|e_email_preference|e_email_preference_p_bday_year|pk_email_preference_id|integer|p_bday_year|integer|NULL|NULL
--    7|Y|Y|Y|e_email_preference|e_email_preference_p_birthday|pk_email_preference_id|datetime|p_birthday|datetime|NULL|NULL
--    8|Y|Y|Y|e_email_preference|e_email_preference_p_casl_confirmation|pk_email_preference_id|varchar(255)|p_casl_confirmation|varchar(255)|NULL|NULL
--    9|Y|Y|Y|e_email_preference|e_email_preference_p_chosenstore|pk_email_preference_id|varchar(255)|p_chosenstore|varchar(255)|NULL|NULL
--    10|Y|Y|Y|e_email_preference|e_email_preference_p_city|pk_email_preference_id|varchar(255)|p_city|varchar(255)|NULL|NULL
--    11|Y|Y|Y|e_email_preference|e_email_preference_p_countrycode|pk_email_preference_id|varchar(255)|p_countrycode|varchar(255)|NULL|NULL
--    12|Y|Y|Y|e_email_preference|e_email_preference_p_crsrce|pk_email_preference_id|varchar(255)|p_crsrce|varchar(255)|NULL|NULL
--    13|Y|Y|Y|e_email_preference|e_email_preference_p_crtime|pk_email_preference_id|datetime|p_crtime|datetime|NULL|NULL
--    14|N|N|Y|e_email_preference|e_email_preference_p_ecoa_date|pk_email_preference_id|datetime|p_ecoa_date|datetime|NULL|NULL
--    15|N|N|N|e_email_preference|e_email_preference|pk_email_preference_id|varchar(255)|p_email|varchar(255)|NULL|NULL
--    16|Y|Y|Y|e_email_preference|e_email_preference_p_emailpref_to_cust|pk_email_preference_id|BIGINT|p_emailpref_to_cust|BIGINT|NULL|NULL
--    17|Y|Y|Y|e_email_preference|e_email_preference_p_emailpref_to_ind|pk_email_preference_id|BIGINT|p_emailpref_to_ind|BIGINT|NULL|NULL
--    18|Y|Y|Y|e_email_preference|e_email_preference_p_emailpref_to_store|pk_email_preference_id|BIGINT|p_emailpref_to_store|BIGINT|NULL|NULL
--    19|Y|Y|Y|e_email_preference|e_email_preference_p_firstname|pk_email_preference_id|varchar(255)|p_firstname|varchar(255)|NULL|NULL
--    20|Y|Y|Y|e_email_preference|e_email_preference_p_frequencypref|pk_email_preference_id|varchar(255)|p_frequencypref|varchar(255)|NULL|NULL
--    21|Y|Y|Y|e_email_preference|e_email_preference_p_gender|pk_email_preference_id|varchar(255)|p_gender|varchar(255)|NULL|NULL
--    22|Y|Y|Y|e_email_preference|e_email_preference_p_gripsshaftsservices|pk_email_preference_id|varchar(255)|p_gripsshaftsservices|varchar(255)|NULL|NULL
--    23|Y|Y|Y|e_email_preference|e_email_preference_p_gs_dailydealoptin|pk_email_preference_id|integer|p_gs_dailydealoptin|integer|NULL|NULL
--    24|Y|Y|Y|e_email_preference|e_email_preference_p_gs_emailoptindt|pk_email_preference_id|datetime|p_gs_emailoptindt|datetime|NULL|NULL
--    25|Y|Y|Y|e_email_preference|e_email_preference_p_gs_emailoptinfl|pk_email_preference_id|integer|p_gs_emailoptinfl|integer|NULL|NULL
--    26|Y|Y|Y|e_email_preference|e_email_preference_p_gs_emailstatus|pk_email_preference_id|integer|p_gs_emailstatus|integer|NULL|NULL
--    27|Y|Y|Y|e_email_preference|e_email_preference_p_gt_dailydealoptin|pk_email_preference_id|integer|p_gt_dailydealoptin|integer|NULL|NULL
--    28|Y|Y|Y|e_email_preference|e_email_preference_p_gt_emailoptindt|pk_email_preference_id|datetime|p_gt_emailoptindt|datetime|NULL|NULL
--    29|Y|Y|Y|e_email_preference|e_email_preference_p_gt_emailoptinfl|pk_email_preference_id|integer|p_gt_emailoptinfl|integer|NULL|NULL
--    30|Y|Y|Y|e_email_preference|e_email_preference_p_gt_emailstatus|pk_email_preference_id|integer|p_gt_emailstatus|integer|NULL|NULL
--    31|Y|Y|Y|e_email_preference|e_email_preference_p_individualid|pk_email_preference_id|varchar(255)|p_individualid|varchar(255)|NULL|NULL
--    32|Y|Y|Y|e_email_preference|e_email_preference_p_instorespecials|pk_email_preference_id|varchar(255)|p_instorespecials|varchar(255)|NULL|NULL
--    33|Y|Y|Y|e_email_preference|e_email_preference_p_language|pk_email_preference_id|varchar(255)|p_language|varchar(255)|NULL|NULL
--    34|Y|Y|Y|e_email_preference|e_email_preference_p_lastname|pk_email_preference_id|varchar(255)|p_lastname|varchar(255)|NULL|NULL
--    35|Y|Y|Y|e_email_preference|e_email_preference_p_nutsvsnots|pk_email_preference_id|varchar(255)|p_nutsvsnots|varchar(255)|NULL|NULL
--    36|Y|Y|Y|e_email_preference|e_email_preference_p_onlinespecials|pk_email_preference_id|varchar(255)|p_onlinespecials|varchar(255)|NULL|NULL
--    37|Y|Y|Y|e_email_preference|e_email_preference_p_phonenumber|pk_email_preference_id|bigint|p_phonenumber|bigint|NULL|NULL
--    38|Y|Y|Y|e_email_preference|e_email_preference_p_profile_complete_identifier|pk_email_preference_id|varchar(255)|p_profile_complete_identifier|varchar(255)|NULL|NULL
--    39|Y|Y|Y|e_email_preference|e_email_preference_p_recipid|pk_email_preference_id|bigint|p_recipid|bigint|NULL|NULL
--    40|Y|Y|Y|e_email_preference|e_email_preference_p_state_province|pk_email_preference_id|varchar(255)|p_state_province|varchar(255)|NULL|NULL
--    41|Y|Y|Y|e_email_preference|e_email_preference_p_updsrce|pk_email_preference_id|varchar(255)|p_updsrce|varchar(255)|NULL|NULL
--    42|Y|Y|Y|e_email_preference|e_email_preference_p_updtime|pk_email_preference_id|datetime|p_updtime|datetime|NULL|NULL
--    43|Y|Y|Y|e_email_preference|e_email_preference_p_zip_postalcode|pk_email_preference_id|varchar(255)|p_zip_postalcode|varchar(255)|NULL|NULL
--    44|Y|Y|Y|e_email_preference|e_email_preference_p_gs_dailydealoptin_history|pk_email_preference_id|integer|p_gs_dailydealoptin_history|integer|record_time|datetime
--    45|Y|Y|Y|e_email_preference|e_email_preference_p_gs_emailoptinfl_history|pk_email_preference_id|integer|p_gs_emailoptinfl_history|integer|record_time|datetime
--    46|Y|Y|Y|e_email_preference|e_email_preference_p_gt_dailydealoptin_history|pk_email_preference_id|integer|p_gt_dailydealoptin_history|integer|record_time|datetime
--    47|Y|Y|Y|e_email_preference|e_email_preference_p_gt_emailoptinfl_history|pk_email_preference_id|integer|p_gt_emailoptinfl_history|integer|record_time|datetime
--
--
-- 3. Create #epref_join table. Metadata about all the join tables that join to e_email_preference.
--
--    id|do_insert|do_update|do_delete|entity_table_name|property_table_name|pk_field|pk_field_type|p_field|p_field_type|email_property_table_name|email_property_column_name
--    1|Y|Y|Y|e_booking_bug|e_booking_bug_p_bbug_to_emailpref|pk_booking_bug_id|BIGINT|p_bbug_to_emailpref|BIGINT|e_booking_bug_p_email|p_email
--    2|Y|Y|Y|e_bounce_exchange|e_bounce_exchange_p_be_to_emailpref|pk_bounce_exchange_id|BIGINT|p_be_to_emailpref|BIGINT|e_bounce_exchange|p_email
--    3|Y|Y|Y|e_recipient|e_recipient_p_cust_to_emailpref|pk_recip_id|BIGINT|p_cust_to_emailpref|BIGINT|e_recipient_p_email|p_email
--    4|Y|Y|Y|e_email_activity|e_email_activity_p_emailacty_to_emailpref|pk_email_activity_id|BIGINT|p_emailacty_to_emailpref|BIGINT|e_email_activity|p_email
--    5|Y|Y|Y|e_smarter_remarketer|e_smarter_remarketer_p_smart_to_emailpref|pk_smarter_remarketer_id|BIGINT|p_smart_to_emailpref|BIGINT|e_smarter_remarketer|p_email
--
--
-- 4. Create #map
--
--    ecoa_pk_ecoa_id|ecoa_p_new_email|ecoa_p_old_email|ecoa_creation_time|ecoa_p_timestamp|ecoa_p_updsrce|epref_new_email_pk_email_preference_id|epref_old_email_pk_email_preference_id|epref_new_email_p_email|epref_old_email_p_email|epref_new_email_p_address_1|epref_old_email_p_address_1|epref_new_email_p_address_2|epref_old_email_p_address_2|epref_new_email_p_bday_day|epref_old_email_p_bday_day|epref_new_email_p_bday_month|epref_old_email_p_bday_month|epref_new_email_p_bday_year|epref_old_email_p_bday_year|epref_new_email_p_birthday|epref_old_email_p_birthday|epref_new_email_p_casl_confirmation|epref_old_email_p_casl_confirmation|epref_new_email_p_chosenstore|epref_old_email_p_chosenstore|epref_new_email_p_city|epref_old_email_p_city|epref_new_email_p_countrycode|epref_old_email_p_countrycode|epref_new_email_p_crsrce|epref_old_email_p_crsrce|epref_new_email_p_crtime|epref_old_email_p_crtime|epref_new_email_p_ecoa_date|epref_old_email_p_ecoa_date|epref_new_email_p_emailpref_to_cust|epref_old_email_p_emailpref_to_cust|epref_new_email_p_emailpref_to_ind|epref_old_email_p_emailpref_to_ind|epref_new_email_p_emailpref_to_store|epref_old_email_p_emailpref_to_store|epref_new_email_p_firstname|epref_old_email_p_firstname|epref_new_email_p_frequencypref|epref_old_email_p_frequencypref|epref_new_email_p_gender|epref_old_email_p_gender|epref_new_email_p_gripsshaftsservices|epref_old_email_p_gripsshaftsservices|epref_new_email_p_gs_dailydealoptin|epref_old_email_p_gs_dailydealoptin|epref_new_email_p_gs_emailoptindt|epref_old_email_p_gs_emailoptindt|epref_new_email_p_gs_emailoptinfl|epref_old_email_p_gs_emailoptinfl|epref_new_email_p_gs_emailstatus|epref_old_email_p_gs_emailstatus|epref_new_email_p_gt_dailydealoptin|epref_old_email_p_gt_dailydealoptin|epref_new_email_p_gt_emailoptindt|epref_old_email_p_gt_emailoptindt|epref_new_email_p_gt_emailoptinfl|epref_old_email_p_gt_emailoptinfl|epref_new_email_p_gt_emailstatus|epref_old_email_p_gt_emailstatus|epref_new_email_p_individualid|epref_old_email_p_individualid|epref_new_email_p_instorespecials|epref_old_email_p_instorespecials|epref_new_email_p_language|epref_old_email_p_language|epref_new_email_p_lastname|epref_old_email_p_lastname|epref_new_email_p_nutsvsnots|epref_old_email_p_nutsvsnots|epref_new_email_p_onlinespecials|epref_old_email_p_onlinespecials|epref_new_email_p_phonenumber|epref_old_email_p_phonenumber|epref_new_email_p_profile_complete_identifier|epref_old_email_p_profile_complete_identifier|epref_new_email_p_recipid|epref_old_email_p_recipid|epref_new_email_p_state_province|epref_old_email_p_state_province|epref_new_email_p_updsrce|epref_old_email_p_updsrce|epref_new_email_p_updtime|epref_old_email_p_updtime|epref_new_email_p_zip_postalcode|epref_old_email_p_zip_postalcode|epref_new_email_p_gs_dailydealoptin_history|epref_old_email_p_gs_dailydealoptin_history|epref_new_email_p_gs_emailoptinfl_history|epref_old_email_p_gs_emailoptinfl_history|epref_new_email_p_gt_dailydealoptin_history|epref_old_email_p_gt_dailydealoptin_history|epref_new_email_p_gt_emailoptinfl_history|epref_old_email_p_gt_emailoptinfl_history
--    1|conl@gmail.com|connollyd@gmail.com|2015-10-27 18:01:20.347|2015-10-16 12:34:48.000|GS_ECOA|6303133|5646776|conl@gmail.com|connollyd@gmail.com|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|US|GolfSmith_ActivitySP Feed|GolfSmith_ActivitySP Feed|2015-10-16 10:04:11.143|2015-05-26 16:11:31.943|NULL|NULL|NULL|NULL|NULL|7136466|NULL|NULL|NULL|DAVID|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|1500|100|NULL|100|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|3757787821579667053|NULL|NULL|NULL|EN|NULL|CONNOLLY|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|101030227088|101030227088|NULL|NULL|GolfSmith_ActivitySP Feed|GS_Customer_US Feed|2015-11-23 14:04:24.000|2016-04-26 12:37:02.540|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL
--    2|dlgrabmann@outlook.com|david.grabmann@brucepower.com|2015-10-27 18:01:20.347|2015-10-16 12:25:59.000|GS_ECOA|6303137|312381|dlgrabmann@outlook.com|DAVID.GRABMANN@BRUCEPOWER.COM|NULL|429 GRANDVIEW RD|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|526|NULL|WINGHAM|NULL|CA|GolfSmith_ActivitySP Feed|GS_Customer_CAN_Initial Feed|2015-10-16 10:04:11.143|2015-04-02 12:19:20.223|NULL|NULL|NULL|NULL|NULL|1510371|NULL|100|NULL|DAVE|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|100|100|NULL|NULL|NULL|NULL|NULL|2013-04-27 11:05:00.000|NULL|1500|NULL|1500|NULL|3755688442603472493|NULL|NULL|NULL|Email|NULL|GRABMANN|NULL|NULL|NULL|NULL|NULL|15193579164|NULL|NULL|112307642263|112988152508|NULL|ON|GolfSmith_ActivitySP Feed|GT Unsub Manual Import|2015-11-21 14:41:26.000|2016-05-03 18:48:04.297|NULL|N0G 2W0|NULL|NULL|NULL|NULL|NULL|NULL|NULL|1500
--    3|dick.parker@verizon.net|dick.parker@cox.net|2015-10-27 18:01:20.347|2015-10-16 13:21:44.000|GS_ECOA|6303136|2135765|dick.parker@verizon.net|DICK.PARKER@COX.NET|NULL|727 CHESHIRE FOREST DR|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|129|NULL|CHESAPEAKE|NULL|US|GolfSmith_ActivitySP Feed|GS_Customer_US_Initial Feed|2015-10-16 10:04:11.143|2015-04-02 15:26:05.040|NULL|NULL|NULL|NULL|NULL|5376132|NULL|34|NULL|RICHARD|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|2007-06-07 22:30:00.000|100|100|NULL|100|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|4223925648823664235|NULL|NULL|NULL|NULL|NULL|PARKER|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|4540510459|4540510459|NULL|VA|GolfSmith_ActivitySP Feed|GS_Customer_US Feed|2015-10-16 13:20:36.000|2016-04-26 12:33:01.557|NULL|23322|NULL|NULL|NULL|100|NULL|NULL|NULL|NULL
--    4|shecky8688@gmail.com|jcsheck@comcast.net|2015-10-27 18:01:20.347|2015-10-16 14:17:49.000|GS_ECOA|NULL|2856701|NULL|JCSHECK@COMCAST.NET|NULL|15135 KALLASTE DR|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|84|NULL|PHILADELPHIA|NULL|US|NULL|GS_Customer_US_Initial Feed|NULL|2015-04-02 15:26:05.040|NULL|NULL|NULL|NULL|NULL|7665674|NULL|373|NULL|JOSEPH|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|100|NULL|100|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL|4223912821476015721|NULL|NULL|NULL|NULL|NULL|SHECK|NULL|NULL|NULL|NULL|NULL|12156762829|NULL|NULL|NULL|6611000742|NULL|PA|NULL|GS_Customer_US Feed|NULL|2016-04-26 11:30:03.980|NULL|19116|NULL|NULL|NULL|NULL|NULL|NULL|NULL|NULL
--
--
-- 5.  Update e_email_preference where epref_new_email_pk_email_preference_id IS NULL
-- 6.  Update e_recipient_p_email
-- 7.  Update e_email_activity
-- 8.  Merge (Update/Insert) e_email_preference_p_ecoa_date
-- 9.  Merge (Update/Insert) e_recipient_p_ecoa_date
-- 10. Merge (Update/Insert) e_email_activity_p_ecoa_date
-- 11. Update/Delete e_email_preference Joins
--
-- UPDATE e_email_preference FIELDS
-- 12. EXECUTE Dynamic SQL INSERT into e_email_preference fields
-- 13. EXECUTE Dynamic SQL UPDATE e_email_preference fields
--
-- UPDATE DEPENDEND TABLES
-- 14. EXECUTE Dynamic SQL DELETE from deleted table
-- 15. EXECUTE Dynamic SQL DELETE from guid table
-- 16. EXECUTE Dynamic SQL DELETE from upd table
-- 17. EXECUTE Dynamic SQL DELETE from cust table
-- 
-- UPDATE e_email_preference FIELDS
-- 18. EXECUTE Dynamic SQL DELETE from e_email_preference FIELDS
--
--
