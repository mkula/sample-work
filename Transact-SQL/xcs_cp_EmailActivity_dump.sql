USE [xyz_dms_cust_REDACTED]
GO

/****** Object:  StoredProcedure [dbo].[xcs_cp_EmailActivity_dump]    Script Date: 10/13/2016 2:09:02 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[xcs_cp_EmailActivity_dump] (@start_date datetime, @finish_date datetime)
AS

DECLARE @cust_id int, @proc_name varchar(255), @row_cnt bigint, @err int, @err_string nvarchar(255), @rc int, @rc_string nvarchar(255), @resource_name nvarchar(255), @start_activity datetime, @finish_activity datetime

SET @proc_name = object_name(@@procid)
EXEC xcs_cp_perf_log @proc_name, 'START', @row_cnt, null, 0

SET @cust_id = 703
SET @resource_name = 'xcs_cp_EmailActivity_dump_' + CAST(@cust_id AS varchar)


SET NOCOUNT ON

BEGIN
-----------------------------------------------------------
-- Author: Mariusz Kula
-- Date: 10/13/2016
-- Client: REDACTED
-- CMS/DMS: REDACTED
-- Time zone: EST
-- Ticket(s): https://jira.cheetahmail.com/browse/REDACTED
-- 
-- -----------------------
-- OVERVIEW:
-- Generate email activity data and store it in a backend table(dbo.xcs_cp_EmailActivity) for retrieval by export stored procs.
-- If the data for the date range already exists in the dbo.xcs_cp_EmailActivity table, no new data will be regenerated.
-- Returns 0 if successful, otherwise returns > 0.
--
-- dbo.xcs_cp_EmailActivity columns:
-- start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, email_address, activity_type, activity_time, category_id, click_id, link_id, link_name, link_url
--
-- -----------------------
-- USAGE:
-- Run the following code from within your stored proc to generate new email activity for the date range of @start_date - @finish_date. Returns > 0 if errors occurred, otherwise returns 0.
--
-- EXEC @rc = dbo.xcs_cp_EmailActivity_dump  @start_date, @finish_date  /* Run stored proc to generate email activity for @start_date - @finish_date. The activity gets stored in dbo.xcs_cp_EmailActivity. */
-- 
-- IF @rc <> 0
-- BEGIN
--   SELECT @msg = text, @severity = severity FROM sys.messages WHERE message_id = @rc  /* Get a string representation of the returned error code (@rc). May not exist. */
--
--   IF @msg IS NULL
--     SET @msg = N'xcs_cp_EmailActivity_dump was unable to generate email activity'
--   IF @severity IS NULL
--     SET @severity = 16
--
--   RAISERROR(@msg, @severity, 0)
-- END
--
-- SELECT * -- or select specific columns that you need
-- INTO #act
-- FROM dbo.xcs_cp_EmailActivity
--
-- -----------------------
-- PROCESS FLOW:
-- 1.  Get Exclusive APPLOCK (Session).
-- 2.  Create backend table to store all (sends, bounces, opens, clicks, usubs from sent messages) activity data, if it doesn't already exist.
-- 3.  If activity data already exists check the date range it stores. If date range matches the requested date range, exist the process. Otherwise truncate the table, we'll generate activity matching the requested date range.
-- 4.  Create temp table to store all activity data.
-- 5.  Get Live (mode_id = 100) Email (channel_type_id = 100) campaigns, include Suspended (status_id = 1600) and Cancelled (status_id = 1800) campaigns.
-- 6.  Get Send activity.
-- 7.  Get Bounce activity.
-- 8.  Get Unsub activity.
-- 9.  Get Open/Click activity with link info.
-- 10. Figure out from what table to get the email_address.
-- 11. Get email address for entity_id.
-- 12. Populate the final email activity data.
--
-- -----------------------
-- NOTES:
-- When making changes to this stored procedure, remember not to set any indexes on the dbo.xcs_cp_EmailActivity table, as this table serves as an email activity datastore for a given date range.
-- Simply load the data into your temp table in your stored proc (see USAGE)and then design and create your indexes there. 
--
-----------------------------------------------------------

  -- We need start_date and finish_date for which to run email activity
  IF (@start_date > @finish_date)
  BEGIN
    SET @err = -1000
    GOTO err
  END

  --- === === === ---

  -- 1. Get Exclusive APPLOCK (Session)
  PRINT convert(varchar,getdate(),120)+' -->> Start Exclusive APPLOCK Get'
  EXEC xcs_cp_perf_log @proc_name, 'Start Exclusive APPLOCK Get', null, null, 0

  EXEC @rc = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session'

  -- If APPLOCK not successfully obtained, error out. Otherwise generate the email activity data.
  IF (@rc < 0) 
  BEGIN 
    SET @err = @rc 
    --- === === === ---
    GOTO err
  END
  ELSE
  BEGIN TRY
    EXEC xcs_cp_perf_log @proc_name, 'Start TRY block', null, null, 0
    --- === === === ---

    -- Translate return code to its string representation
    SET @rc_string = CASE @rc
                       WHEN  0   THEN 'The lock was successfully granted synchronously'
                       WHEN  1   THEN 'The lock was granted successfully after waiting for other incompatible locks to be released'
                       ELSE 'Undefined return code'
                     END
    EXEC xcs_cp_perf_log @proc_name, 'Successful Exclusive APPLOCK Get', @rc, @rc_string, 0
    --- === === === ---

    -- 2. Create backend table to store all (sends, bounces, opens, clicks, usubs from sent messages) activity data, if it doesn't already exist.
    PRINT convert(varchar,getdate(),120)+' -->> Start create backend activity table if it doesnt exist'
    EXEC xcs_cp_perf_log @proc_name, 'Start create backend activity table if it doesnt exist', null, null, 0

    IF OBJECT_ID(N'dbo.xcs_cp_EmailActivity', N'U') IS NULL
    BEGIN
      CREATE TABLE dbo.xcs_cp_EmailActivity (
        start_activity datetime,
        finish_activity datetime,
        cust_id int,
        camp_id int,
        camp_name nvarchar(255),
        subject varchar(255),
        deployment_time datetime,
        entity_id int,
        msg_id int,
        pk_id bigint,
        email_address varchar(255),
        activity_type varchar(255),
        activity_time datetime,
        category_id int,
        click_id bigint,
        link_id int,
        link_name nvarchar(255),
        link_url varchar(8000)
      )
    END
  
    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End create backend activity table', @row_cnt, null, 0
    IF(@err > 0) GOTO err

    --- === === === ---

    -- 3. If activity data already exists check the date range it stores.
    --    If date range matches the requested start_date and finish_date, exit the process, no need to regenerate.
    --    Otherwise we'll generate activity matching the requested date range.
    PRINT convert(varchar,getdate(),120)+' -->> Start check date range of activity stored in backend activity table'
    EXEC xcs_cp_perf_log @proc_name, 'Start check date range of activity stored in backen activity table', null, null, 0

    SELECT TOP 1 @start_activity = start_activity, @finish_activity = finish_activity FROM dbo.xcs_cp_EmailActivity

    IF (@start_activity = @start_date AND @finish_activity = @finish_date)
    BEGIN
      EXEC xcs_cp_perf_log @proc_name, 'Requested activity date range already exists', null, null, 0
      GOTO done
    END

    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End check date range of activity stored in backend activity table, Proceed', @row_cnt, null, 0
    IF(@err> 0) GOTO err

    --- === === === ---

    -- 4. Create temp table to store all email activity data.
    PRINT convert(varchar,getdate(),120)+' -->> Start create temp activity table'
    EXEC xcs_cp_perf_log @proc_name, 'Start create temp activity table', null, null, 0

    CREATE TABLE #activity (
      start_activity datetime,
      finish_activity datetime,
      cust_id int,
      camp_id int,
      camp_name nvarchar(255),
      subject varchar(255),
      deployment_time datetime,
      entity_id int,
      msg_id int,
      pk_id bigint,
      email_address varchar(255),
      activity_type varchar(255),
      activity_time datetime,
      category_id int,
      click_id bigint,
      link_id int,
      link_name nvarchar(255),
      link_url varchar(8000)
    )
  
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End create temp activity table', @row_cnt, null, 0
    IF(@err > 0) GOTO err
      
    --- === === === ---

    -- 5.  Get Live (mode_id = 100) Email (channel_type_id = 100) campaigns, include Suspended (status_id = 1600) and Cancelled (status_id = 1800) campaigns.
    PRINT convert(varchar,getdate(),120)+' -->> Start email camps Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start email camps Get', null, null, 0

    -- DROP TABLE #camp
    SELECT distinct ca.camp_id,
           ca.cust_id,
           ca.entity_id,
           cc.child_camp_id,
           cc.parent_camp_id,
           cc.cell_code,
           ca.camp_name,
           et.subject,
           ca.channel_type_id,
           ca.type_id,
           o.display_name,
           cs.sending_start_time AS deployment_time -- initial deployment of a campaign (launch date)
    INTO #camp
    FROM t_campaign ca WITH(NOLOCK)
    JOIN t_camp_stat cs WITH(NOLOCK) ON cs.camp_id = ca.camp_id
    LEFT OUTER JOIN t_camp_cell cc WITH(NOLOCK) ON ca.camp_id = cc.child_camp_id
    LEFT OUTER JOIN t_email_msg_template et WITH(NOLOCK) ON ca.camp_id = et.camp_id
    JOIN t_obj o WITH(NOLOCK) ON ca.base_camp_id=o.ref_id AND o.type_id in (5100,5110,5120,5130,5150,5190,5050) -- Campaign
    WHERE ca.mode_id = 100 -- Test with 200, Real with 100
    AND ca.channel_type_id = 100 -- EMAIL=100, SMS=200, DATA=500, WEB=300
    AND ca.running_camp_id IS NULL
    AND (ca.status_id < 1000 OR ca.status_id = 1600 OR ca.status_id = 1800) -- Suspended (status_id=1600), Cancelled (status_id=1800)
   
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End email camps Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err
      
    --- === === === ---

    PRINT convert(varchar,getdate(),120)+' -->> Start PK Clustered on #camp(camp_id) Set'
    EXEC xcs_cp_perf_log @proc_name, 'Start Set Clustered on #camp(camp_id) Set', null, null, 0

    ALTER TABLE #camp ADD Primary Key clustered (camp_id)
    
    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End PK Clustered on #camp(camp_id) Set', @row_cnt, null, 0
    IF(@err > 0) GOTO err

    --- === === === ---

    -- 6. Get Send activity.
    PRINT convert(varchar,getdate(),120)+' -->> Start Send activity Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start Send activity Get', null, null, 0
  
    --DROP TABLE #activity
    INSERT INTO #activity (start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, activity_type, activity_time)
    SELECT @start_date, @finish_date, ca.cust_id, ca.camp_id, ca.camp_name, ca.subject, ca.deployment_time, m.entity_id, m.msg_id, m.pk_id, 'Send', mc.send_real_time
    FROM #camp ca
    JOIN t_msg m WITH(NOLOCK) ON m.camp_id = ca.camp_id
    JOIN t_msg_chunk mc WITH(NOLOCK) ON mc.chunk_id = m.chunk_id
    WHERE mc.send_real_time >= @start_date AND mc.send_real_time < @finish_date
    -- WHERE mc.send_real_time >= '07/20/2016' AND mc.send_real_time < '07/30/2016'
              
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End Send activity Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err
  
    --- === === === ---

    -- 7. Get Bounce activity.
    PRINT convert(varchar,getdate(),120)+' -->> Start Bounce activity Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start Bounce activity Get', null, null, 0
  
    INSERT INTO #activity (start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, activity_type, activity_time, category_id)
    SELECT @start_date, @finish_date, ca.cust_id, ca.camp_id, ca.camp_name, ca.subject, ca.deployment_time, b.entity_id, b.msg_id, b.pk_id, 'Bounce', b.bounce_time, b.category_id
    FROM #camp ca
    JOIN t_msg_bounce b WITH(NOLOCK) on ca.camp_id = b.camp_id
    WHERE b.bounce_time >= @start_date AND b.bounce_time < @finish_date
    -- WHERE b.bounce_time >= '07/20/2016' AND b.bounce_time < '07/30/2016'
          
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End Bounce activity Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err
  
    --- === === === ---

    -- 8. Get Unsub activity.
    PRINT convert(varchar,getdate(),120)+' -->> Start Unsub activity Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start Unsub activity Get', null, null, 0
  
    INSERT INTO #activity (start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, activity_type, activity_time, category_id)
    SELECT @start_date, @finish_date, ca.cust_id, ca.camp_id, ca.camp_name, ca.subject, ca.deployment_time, u.entity_id, u.msg_id, u.pk_id, 'Unsub', u.unsub_time, u.category_id
    FROM #camp ca
    JOIN t_msg_unsub u WITH(NOLOCK) on ca.camp_id = u.camp_id
    WHERE u.unsub_time >= @start_date AND u.unsub_time < @finish_date
    -- WHERE u.unsub_time >= '07/20/2016' AND u.unsub_time < '07/30/2016'
          
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End Unsub activity Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err
  
    --- === === === ---

    -- 9. Get Open/Click activity with link info.
    PRINT convert(varchar,getdate(),120)+' -->> Start Open/Click activity Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start Open/Click activity Get', null, null, 0

    INSERT INTO #activity (start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, activity_type, activity_time, click_id, link_id, link_name, link_url)
    SELECT @start_date, @finish_date, ca.cust_id, ca.camp_id, ca.camp_name, ca.subject, ca.deployment_time, c.entity_id, c.msg_id, c.pk_id, CASE WHEN c.click_type_id = 100 THEN 'Open' ELSE 'Click' END, c.click_time, click_id, l.link_id, l.link_name, l.redirect_url
    FROM #camp ca
    JOIN t_click c WITH(NOLOCK) ON ca.camp_id = c.camp_id
    LEFT OUTER JOIN t_link l WITH(NOLOCK) ON l.link_id = c.link_id
    WHERE c.click_type_id IN (100, 200) -- Open, Click
    AND c.click_time >= @start_date AND c.click_time < @finish_date
    -- AND c.click_time >= '07/20/2016' AND c.click_time < '07/30/2016'

    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End Open/Click activity Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err

    --- === === === ---

    -- 10. Figure out from what table to get the email_address.
    PRINT convert(varchar,getdate(),120)+' -->> Start entity email meta Get'
    EXEC xcs_cp_perf_log @proc_name, 'Start entity email meta Get', null, null, 0
  
    -- drop table #entity_email_meta
    CREATE TABLE #entity_email_meta (id INT IDENTITY(1,1), entity_id varchar(255), entity_table varchar(255), entity_email_table varchar(255), entity_email_column varchar(255), entity_email_pk_id varchar(255))
  
    INSERT INTO #entity_email_meta (entity_id, entity_table, entity_email_table, entity_email_column, entity_email_pk_id)
    SELECT e.entity_id AS entity_id,
           e.entity_name AS entity_table,
           dbo.f_prop_table_name_get(p.prop_id) AS entity_email_table, dbo.f_prop_column_name_get(p.prop_id) AS entity_email_column,
           dbo.f_entity_pk_column_name_get(e.entity_id) AS entity_email_pk_id
    FROM t_entity e WITH(NOLOCK)
    JOIN t_property p WITH(NOLOCK) ON p.entity_id = e.entity_id
    WHERE p.type_id = 21 -- email_address
    AND e.entity_id IN (SELECT DISTINCT entity_id FROM #activity)
  
    -- select * from #entity_email_meta
  
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End entity email meta Get', @row_cnt, null, 0
    IF(@err > 0) GOTO err
  
    --- === === === ---

    PRINT convert(varchar,getdate(),120)+' -->> Start non-clustered index on #activity(pk_id) Set'
    EXEC xcs_cp_perf_log @proc_name, 'Start non-clustered index on #activity(pk_id) Set', null, null, 0

    CREATE INDEX pk_tmp_pkid_ix ON #activity(pk_id);
    
    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End non-clustered index on #activity(pk_id) Set', @row_cnt, null, 0
    IF(@err > 0) GOTO err

    --- === === === ---

    -- 11. Get email address for entity_id.
    PRINT convert(varchar,getdate(),120)+' -->> Start email_address Get'

    DECLARE @sql nvarchar(2000)
    DECLARE @mark varchar(255)
    DECLARE @entity_id varchar(255)
    DECLARE @entity_table varchar(255)
    DECLARE @entity_email_table varchar(255)
    DECLARE @entity_email_column varchar(255)
    DECLARE @entity_email_pk_id varchar(255)
    DECLARE @i int
    DECLARE @j int 
  
    SET    @i = 1 
    SELECT @j = count(*) FROM #entity_email_meta
  
    WHILE @i <= @j
    BEGIN
      SELECT @entity_id = entity_id,
             @entity_table = entity_table,
             @entity_email_table = entity_email_table,
             @entity_email_column = entity_email_column,
             @entity_email_pk_id = entity_email_pk_id
      FROM #entity_email_meta
      WHERE id = @i
 
      SET @mark =  'Start email_address Get for ' + @entity_table + ' (entity_id=' + @entity_id + ')'

      EXEC xcs_cp_perf_log @proc_name, @mark, null, null, 0

      SET @sql = 'UPDATE #activity SET email_address = ' + @entity_email_column + ' FROM ' + @entity_email_table + ' e WITH(NOLOCK) JOIN #activity a ON a.pk_id = e.' + @entity_email_pk_id + ' WHERE a.entity_id = ' + @entity_id
  
      EXEC sp_executesql @sql

      SELECT @err = @@error, @row_cnt = @@rowcount

      SET @mark =  'End email_address Get for ' + @entity_table + ' (entity_id=' + @entity_id + ')'

      EXEC xcs_cp_perf_log @proc_name, @mark, @row_cnt, null, 0
      IF(@err > 0) GOTO err

      SET @i = @i + 1
    END
  
    --- === === === ---

    -------------------------------------------------------------------------
    -- 12. Populate the final email activity data.
    -------------------------------------------------------------------------
    PRINT convert(varchar,getdate(),120)+' -->> Populate the final email activity data'

    EXEC xcs_cp_perf_log @proc_name, 'Start TRUNCATE TABLE dbo.xcs_cp_EmailActivity', null, null, 0
    TRUNCATE TABLE dbo.xcs_cp_EmailActivity

    SELECT @err = @@error, @row_cnt = @@rowcount

    EXEC xcs_cp_perf_log @proc_name, 'End TRUNCATE TABLE dbo.xcs_cp_EmailActivity', @row_cnt, null, 0
    IF(@err > 0) GOTO err

    --- === === === ---

    EXEC xcs_cp_perf_log @proc_name, 'Start Populate the final email activity data', null, null, 0
  
    INSERT INTO dbo.xcs_cp_EmailActivity (start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, email_address, activity_type, activity_time, category_id, click_id, link_id, link_name, link_url)
    SELECT DISTINCT start_activity, finish_activity, cust_id, camp_id, camp_name, subject, deployment_time, entity_id, msg_id, pk_id, email_address, activity_type, activity_time, category_id, click_id, link_id, link_name, link_url
    FROM #activity
  
    SELECT @err = @@error, @row_cnt = @@rowcount
  
    EXEC xcs_cp_perf_log @proc_name, 'End Populate the final email activity data', @row_cnt, null, 0
    --- === === === ---
    EXEC xcs_cp_perf_log @proc_name, 'End TRY block', null, null, 0
    --- === === === ---
  END TRY
  BEGIN CATCH
    SET @err = @@error
    --- === === === ---
    GOTO err
  END CATCH
END

done:
EXEC xcs_cp_perf_log @proc_name, 'Start Exclusive APPLOCK Release', null, null, 0
EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
EXEC xcs_cp_perf_log @proc_name, 'End Exclusive APPLOCK Release', null, null, 0
EXEC xcs_cp_perf_log @proc_name, 'FINISHED WITH NO ERRORS', null, null, 0
RETURN 0

err:
-- Get a string representation of the error code (@err). May not exist.
SELECT @err_string = text FROM sys.messages WHERE message_id = @err
-- Custom error code
IF @err_string IS NULL
  SET @err_string = CASE @err
                      WHEN -1    THEN 'The lock request timed out'
                      WHEN -2    THEN 'The lock request was canceled'
                      WHEN -3    THEN 'The lock request was chosen as a deadlock victim'
                      WHEN -999  THEN 'Parameter validation or other call error'
                      WHEN -1000 THEN 'start_date > finish_date'
                      ELSE 'Undefined error code'
                    END
-- Skip APPLOCK release if failed to obtain it
IF @err > 0
BEGIN
  EXEC xcs_cp_perf_log @proc_name, 'Start Exclusive APPLOCK Release', null, null, 0
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  EXEC xcs_cp_perf_log @proc_name, 'End Exclusive APPLOCK Release', null, null, 0
END
--
EXEC xcs_cp_perf_log @proc_name, 'TERMINATED BY ERROR', @err, @err_string, 0
RETURN @err


GO
