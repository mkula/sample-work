USE [xyz_dms_cust_REDACTED]
GO
/****** Object:  StoredProcedure [dbo].[xcs_cp_REDACTED_PromoCode_campProc]    Script Date: 3/8/2016 3:45:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[xcs_cp_REDACTED_PromoCode_campProc](@camp_id int) WITH RECOMPILE
AS

--DROP PROCEDURE xcs_cp_REDACTED_PromoCode_campProc

/****** Object:  StoredProcedure [dbo].[xcs_cp_REDACTED_PromoCode_campProc]    Script Date: 3/8/2016 ******/

DECLARE @err int, @row_cnt int, @proc_name varchar(255)
SET @proc_name = object_name(@@procid)
EXEC p_perf_log @proc_name, 'START', @row_cnt, null, 0
EXEC xcs_cp_perf_log @proc_name, 'START', @row_cnt, null, @camp_id

DECLARE @time_zone_id varchar(255) = 'Pacific Standard Time';

PRINT convert(varchar,getdate(),120)+' -->> Start Declare @cust_id'
DECLARE @cust_id int
SELECT @cust_id = (SELECT DISTINCT cust_id from t_campaign WITH(NOLOCK) where camp_id=@camp_id)

DECLARE @result int
DECLARE @resource_name nvarchar(255)
SET @resource_name = 'xcs_cp_REDACTED_CouponAssign_campProc_' + CAST(@cust_id AS varchar)


SET NOCOUNT ON

BEGIN
-----------------------------------------------------------------------
-- Author: Mariusz Kula
-- Date: 3/8/2016
-- Client: REDACTED
-- CMS/DMS: REDACTED
-- Time zone: EST
-- Ticket(s): https://jira.cheetahmail.com/browse/PS-17556
--
-- This is a campaign stored proc that gets attached to a campaign that sends promo codes to its audience.
--
-- A separate promo code import process loads promo codes to the p_promocd and p_promotype fields of the e_promo table.
--
-- When this stored proc runs, it will allocate specific (promotype) promo codes needed for the audience of the campaign.
-- In the case where the #of_audience > #_of_unassigned promo codes (promotype), the stored proc will error out with the messages:
-- '***None or Not Enough promo codes available. Contact Client Services - Let Cust know to Import more promo codes.***'
--
-- Process Flow:
--
-- 1.  Populate #msg with the campaign audience.
-- 2.  Populate #promo with every type of promotype for camp_id.
-- 3.  Declare variables for Dynamic SQL and assign values from #msg.
-- 4.  Populate #assigned with the promo codes from the promo table marked as assigned = 'Yes' and promo_type = @type.
-- 5.  Populate #assigned with the promo codes from the xcs_cp_TempPromoAssigned temp table where creation_time is within the last hour.
-- 6.  Populate #assigned with the promo codes from the promo table that join to e_promo_p_promo_to_recipient (@entity_id = 100) or e_promo_p_promo_to_acqhist (@entity_id = 114) join table and where promo_type = @type.
-- 7.  Populate #bc with unassigned promo codes from the promo table where promo_type = @type.
-- 8.  Populate xcs_cp_TempPromoAssigned with the promo codes from #bc and assign them creation_time of NOW.
-- 9.  If the count of #bc is different than the count of #msg (not enough promo codes for distribution), DELETE promo codes from xcs_cp_TempPromoAssigned that exist in #bc.
-- 10. Populate #join with a join of #msg and #bc.
-- 11. If the count of #join is different than the count of #msg, DELETE promo codes from xcs_cp_TempPromoAssigned that exist in.
-- 12. Populate the e_promo_p_promo_to_recipient (@entity_id = 100) or e_promo_p_promo_to_acqhist (@entity_id = 114) join with promo codes from #join.
-- 13. Populate e_promo_entity_id with promo codes and matching entity_id from #join.
-- 14. Populate e_promo_p_campid with promo codes and matching camp_id from #join.
-- 15. Populate e_promo_p_msgid with promo codes and matching msg_id from #join.
-- 16. Populate e_promo_p_email promo_codes and matching email address of the member of the audience from #join and e_recipient (@entity_id = 100) or e_acquisition_history (@entity_id = 114).
-- 17. Populate e_promo_p_campaignmodeid with promo codes and matching mode_id from #join, If mode_id = 200 (Proofs made).
-- 18. Populate e_promo_p_date_assigned with promo codes from #join and assign them date_assigned of NOW (GETDATE()).
-- 20. Populate e_promo_p_assigned with promo codes from #join and assign them value of 'Yes'.
-- 21. Delete from xcs_cp_TempPromoAssigned promo codes which creation time is older than 2 hrs ago.
--
IF NOT EXISTS (SELECT TOP 1 pk_id FROM #pk_table)
BEGIN
  --RAISERROR('No records to run against',16,0)
RETURN
END

--- === === === ---

DECLARE @perf_string varchar(255);
SET @perf_string = CONVERT(varchar(255), @camp_id)
                 + '_'
                 + CONVERT(varchar(10), getdate(), 120)
                 + '_#pk_table_Count_'
                 + CONVERT(varchar(255), (SELECT count(*) FROM #pk_table))

PRINT convert(varchar,getdate(),120)+' -->> Start SELECT PK_IDS AND MSG_ID FROM CAMP'
--
-- Populate #msg with the campaign audience:
-- * row_id - row number (identity)
-- * pk_id - recipient's pk_id
-- * entity_id - campaign sending table
-- * msg_id
-- * cust_id - eg. REDACTED
-- * mode_id - Real=100, Test=200
-- * camp_id - eg.
--
-- DROP TABLE #msg
-- DECLARE @camp_id int = 18978
--
SELECT row_id = identity(int),
       p.pk_id,
       m.entity_id,
       MAX(msg_id) AS 'msg_id',
       ca.cust_id,
       ca.mode_id,
       @camp_id AS 'camp_id'
INTO #msg
FROM #pk_table p WITH(NOLOCK)
JOIN t_msg m WITH(NOLOCK) ON p.pk_id = m.pk_id
JOIN t_campaign ca WITH(NOLOCK) on m.camp_id = ca.camp_id
WHERE m.camp_id = @camp_id
GROUP BY p.pk_id,
         m.entity_id,
         ca.cust_id,
         ca.mode_id

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err

EXEC xcs_cp_perf_log @proc_name, 'SELECT PK_IDS AND MSG_ID FROM CAMP', @row_cnt, @perf_string, @camp_id

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start Add Primary Key to #msg'
ALTER TABLE #msg ADD Primary Key clustered (row_id)

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start GET PROMO_TYPE For CAMP for #Promo'
--
-- Populate #promo with every type of promo_type for camp_id:
--   * camp_id
--   * promotype
--
-- DROP TABLE #promo
-- DECLARE @camp_id int = 18978
--
-- SELECT *
-- FROM t_camp_meta_param cmp
-- JOIN t_camp_meta_param_option cmpo on cmpo.option_id = cmp.option_id
-- WHERE camp_id in (18978)
-- AND (string_val is not null OR integer_val is not null)
-- ORDER BY display_seq
--
SELECT DISTINCT c.camp_id,
       cmp.string_val AS 'promotype'
INTO #promo
FROM t_campaign c WITH(NOLOCK)
LEFT OUTER JOIN t_camp_meta_param cmp WITH(NOLOCK) ON cmp.camp_id = c.camp_id
JOIN t_camp_meta_param_option cmpo WITH(NOLOCK) ON cmpo.option_id = cmp.option_id AND cmpo.option_name = 'promotype'
WHERE c.camp_id = @camp_id

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start Declare Variables For Dynamic SQL'
--
-- Declare variables and assign values from #msg:
--   * @count - count from #msg (count of audience for campaign)
--   * @entity_id - campaign sending table
--   * @mode_id - Real(100) or Test(200)
--   * @type - promo code type, eg. Welcome, Test, etc.
--
PRINT convert(varchar,getdate(),120)+' -->> Start Declare @count Variables'
DECLARE @count int
SELECT @count = (SELECT count(*) FROM #msg)
--
PRINT convert(varchar,getdate(),120)+' -->> Start Declare @entity'
DECLARE @entity_id int
SELECT @entity_id = (SELECT DISTINCT entity_id FROM #msg m WITH(NOLOCK))
--
PRINT convert(varchar,getdate(),120)+' -->> Start Declare @mode_id'
DECLARE @mode_id int
SELECT @mode_id = (SELECT DISTINCT mode_id FROM #msg m WITH(NOLOCK))
--
PRINT convert(varchar,getdate(),120)+' -->> Start Declare @type'
DECLARE @type varchar(255)
SELECT @type = promotype FROM #promo p WITH(NOLOCK)

--Error if no StaticCoupon code added to metadata
IF @type IS NULL
BEGIN
  RAISERROR('Please contact Client Services team and let them know that Promo Code metadata was NOT entered', 16, 0)
RETURN
END

--OUTSIDE APPLOCK
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';
IF (@result < 0) RETURN -1

--- === === === ---

--------------------------------------------------------------------------------------------------
PRINT convert(varchar,getdate(),120)+' -->> START Promo_code JOIN Inserts'
--------------------------------------------------------------------------------------------------
--### GET SESSION APP LOCK ###--
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';

--- === === === ---

IF (@result < 0) RETURN -1
BEGIN TRY
  --
  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE #assigned', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  PRINT convert(varchar,getdate(),120)+' -->> START Create temp Assigned Table'
  --
  -- Populate #assigned with the promo codes from the promo table marked as assigned = 'Yes' and promo_type = @type
  --
  SELECT a.pk_promo_id
  INTO #assigned
  FROM e_promo_p_assigned a 
  JOIN e_promo_p_promotype t WITH(NOLOCK) ON t.pk_promo_id = t.pk_promo_id
  WHERE p_assigned = 'Yes' AND t.p_promotype = @type

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  CREATE INDEX pk_temp_pk_ix on #assigned(pk_promo_id)

  EXEC xcs_cp_perf_log @proc_name, 'FINISH Create temp Assigned Table', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  PRINT convert(varchar,getdate(),120)+' -->> START INSERT Assigned Table - xcs_cp_TempPromoAssigned'
  --
  -- Populate #assigned with the promo codes from the xcs_cp_TempPromoAssigned temp table where creation_time is within the last hour
  --
  INSERT INTO #assigned (pk_promo_id)
  SELECT tmp.pk_promo_id
  FROM xcs_cp_TempPromoAssigned tmp
  WHERE creation_time >= DATEADD(hour, -1, GETDATE())
  AND tmp.pk_promo_id NOT IN (SELECT pk_promo_id FROM #assigned)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH Additional INSERT Assigned Table - xcs_cp_TempPromoAssigned', @row_cnt, @perf_string, @camp_id

  --### RELEASE SESSION APP LOCK ###--
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  --
END TRY
BEGIN CATCH
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
END CATCH

--- === === === ---

--
-- IF entity_id = 100 or entity_id = 114:
--
IF @entity_id = 100 -- e_recipient
BEGIN
  --
  PRINT convert(varchar,getdate(),120)+' -->> START INSERT Assigned Table - Recipient'
  --
  -- Populate #assigned with the promo codes from the promo table that join to e_promo_p_promo_to_recipient join table and where promo_type = @type
  --
  INSERT INTO #assigned (pk_promo_id)
  SELECT t.pk_promo_id
  FROM e_promo_p_promotype t WITH(NOLOCK)
  JOIN e_promo_p_promo_to_recipient j WITH(NOLOCK) ON j.pk_promo_id = t.pk_promo_id
  WHERE t.p_promotype = @type
  AND t.pk_promo_id NOT IN (SELECT pk_promo_id FROM #assigned)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH Additional INSERT Assigned Table - Recipient', @row_cnt, @perf_string, @camp_id
  --
END
ELSE IF @entity_id = 114 -- e_acquisition_history
BEGIN
  --
  PRINT convert(varchar,getdate(),120)+' -->> START INSERT Assigned Table - Acquisition_History'
  --
  -- Populate #assigned with the promo codes from the promo table that join to e_promo_p_promo_to_acqhist join table and where promo_type = @type
  --
  INSERT INTO #assigned (pk_promo_id)
  SELECT t.pk_promo_id
  FROM e_promo_p_promotype t WITH(NOLOCK)
  JOIN e_promo_p_promo_to_acqhist j WITH(NOLOCK) ON j.pk_promo_id = t.pk_promo_id
  WHERE t.p_promotype = @type
  AND t.pk_promo_id NOT IN (SELECT pk_promo_id FROM #assigned)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH Additional INSERT Assigned Table - Acquisition_History', @row_cnt, @perf_string, @camp_id
  --
END

--- === === === ---

EXEC xcs_cp_perf_log @proc_name, 'START POPULATE #bc', @row_cnt, @perf_string, @camp_id

--### GET SESSION APP LOCK ###--
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';

--- === === === ---

IF (@result < 0) RETURN -1
BEGIN TRY
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start GET PROMO_TYPE For #bc Populate Count'
  --
  -- Populate #bc with unassigned promo codes from the promo table where promo_type = @type
  --
  SELECT TOP (@count) row_id = identity(int),
         t.pk_promo_id
  INTO #bc
  FROM e_promo_p_promotype t WITH(NOLOCK)
  WHERE t.p_promotype = @type
  AND t.pk_promo_id NOT IN (SELECT pk_promo_id FROM #assigned WITH(NOLOCK))

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  CREATE INDEX pk_temp_promo_ix on #bc(pk_promo_id)

  EXEC xcs_cp_perf_log @proc_name, 'FINISH GET PROMO_TYPE For #bc Populate Count', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE xcs_cp_TempPromoAssigned', @row_cnt, @perf_string, @camp_id
  ----------------- ADD ASSIGNMENT TABLE HERE ----------------------
  --
  -- !!!!!!!!!!!!!!!!! BE SURE TO CREATE THIS TABLE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  --
  -- TRUNCATE TABLE xcs_cp_TempPromoAssigned
  --
  -- CREATE TABLE xcs_cp_TempPromoAssigned (pk_promo_id bigint NOT NULL Primary Key clustered, creation_time datetime DEFAULT GETDATE());
  -- CREATE INDEX pk_temp_creatdate_ix on xcs_cp_TempPromoAssigned(creation_time)
  --
  -- !!!!!!!!!!!!!!!!! BE SURE TO CREATE THIS TABLE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  --- === === === ---

  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT ASSIGNED INTO xcs_cp_TempPromoAssigned'
  --
  -- Populate xcs_cp_TempPromoAssigned with the promo codes from #bc and assign them creation_time of now.
  --
  INSERT INTO xcs_cp_TempPromoAssigned (pk_promo_id, creation_time)
  SELECT pk_promo_id,
         GETDATE()
  FROM #bc
  ORDER BY pk_promo_id ASC

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT Assigned into xcs_cp_TempPromoAssigned', @row_cnt, @perf_string, @camp_id

  --### RELEASE SESSION APP LOCK ###--
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  --
END TRY
BEGIN CATCH
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
END CATCH

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start Add Primary Key to #bc'
ALTER TABLE #bc ADD Primary Key clustered (row_id)

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start FIRST CHECK FOR ALL Coupon CODES assigned to each queued record - OR ERROR CAMP'
--
-- If the count of #bc is different than the count of #msg (not enough promo codes for distribution), DELETE promo codes from xcs_cp_TempPromoAssigned that exist in #bc
--
IF (select count(*) from #bc) <> (select count(*) from #msg)
BEGIN
  --
  DELETE xcs_cp_TempPromoAssigned WHERE pk_promo_id IN (SELECT pk_promo_id FROM #bc)
  RAISERROR('***None or Not Enough promo codes available. Contact Client Services - Let Cust know to Import more promo codes.***', 16, 1)
  SET @err = @@ERROR
  GOTO err
  --
END

--### GET SESSION APP LOCK ###--
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';

IF (@result < 0) RETURN -1
BEGIN TRY
  --
  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE #join', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  PRINT convert(varchar,getdate(),120)+' -->> Start GET #join'
  --
  -- Populate #join with a join of #msg and #bc
  --
  SELECT pk_id,
         pk_promo_id,
         entity_id,
         msg_id,
         cust_id,
         camp_id,
         mode_id
  INTO #join
  FROM #msg m WITH(NOLOCK)
  JOIN #bc b WITH(NOLOCK) ON b.row_id = m.row_id

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH GET #join Populated Count', @row_cnt, @perf_string, @camp_id

  --### RELEASE SESSION APP LOCK ###--
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  --
END TRY
BEGIN CATCH
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
END CATCH

--- === === === ---

IF(@@error > 0) GOTO err

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start SECOND CHECK FOR ALL DynamicCoupon CODES assigned to each queued record - OR ERROR CAMP'
--
-- If the count of #join is different than the count of #msg, DELETE promo codes from xcs_cp_TempPromoAssigned that exist in
--
IF (SELECT count(*) FROM #join) <> (SELECT count(*) FROM #msg)
BEGIN
  --
  DELETE xcs_cp_TempPromoAssigned WHERE pk_promo_id IN (SELECT pk_promo_id FROM #bc)
  RAISERROR('***None or Not Enough promo codes available. Contact Client Services - Let Cust know to Import more promo codes.***', 16, 1)
  SET @err = @@ERROR
  GOTO err
  --
END

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start Add Primary Key to #bc'
ALTER TABLE #join ADD Primary Key clustered (pk_id)

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err

--- === === === ---

PRINT convert(varchar,getdate(),120)+' -->> Start pk_temp_join_ix'
CREATE INDEX pk_temp_join_ix on #join(pk_promo_id)

SELECT @err = @@error, @row_cnt = @@ROWCOUNT
IF(@err > 0) GOTO err


--------------------------------------------------------------------------------------------------
PRINT convert(varchar,getdate(),120)+' -->> START Promo JOIN Inserts For entity_id = 100 or entity_id = 114'
--------------------------------------------------------------------------------------------------
IF @entity_id = 100 -- e_recipient
BEGIN
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start Recipient Inserts'
  --- === === === ---
  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE Recipient Inserts', @row_cnt, @perf_string, @camp_id

  --### GET SESSION APP LOCK ###--
  EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';
  --- === === === ---
  IF (@result < 0) RETURN -1
  BEGIN TRY
    --
    PRINT convert(varchar,getdate(),120)+' -->> Start NEW JOINS from Promo to Recipient p_promo_to_recipient'
 
    --- === === === ---
    --
    -- Populate the e_promo_p_promo_to_recipient join with promo codes from #join.
    --
    INSERT INTO e_promo_p_promo_to_recipient(pk_promo_id, p_promo_to_recipient)
    SELECT DISTINCT pk_promo_id,
                    pk_id
    FROM #join j WITH(NOLOCK)
    ORDER BY pk_promo_id

    SELECT @err = @@error, @row_cnt = @@ROWCOUNT
    IF(@err > 0) GOTO err

    EXEC xcs_cp_perf_log @proc_name, 'FINISH NEW JOINS from Promo to Recipient p_promo_to_recipient', @row_cnt, @perf_string, @camp_id

    --### RELEASE SESSION APP LOCK ###--
    EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
    --
  END TRY
  BEGIN CATCH
    EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  END CATCH
END
ELSE IF @entity_id = 114 -- e_acquisition_history
BEGIN
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start Acquisition_History Inserts'
  --- === === === ---
  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE Acquisition_History Inserts', @row_cnt, @perf_string, @camp_id

  --### GET SESSION APP LOCK ###--
  EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';
  --- === === === ---
  IF (@result < 0) RETURN -1
  BEGIN TRY
    --
    PRINT convert(varchar,getdate(),120)+' -->> Start NEW JOINS from Promo to Acquisition_History e_promo_p_promo_to_acqhist'
 
    --- === === === ---
    --
    -- Populate the e_promo_p_promo_to_acqhist join with promo codes from #join.
    --
    INSERT INTO e_promo_p_promo_to_acqhist(pk_promo_id, p_promo_to_acqhist)
    SELECT DISTINCT pk_promo_id,
                    pk_id
    FROM #join j WITH(NOLOCK)
    ORDER BY pk_promo_id

    SELECT @err = @@error, @row_cnt = @@ROWCOUNT
    IF(@err > 0) GOTO err

    EXEC xcs_cp_perf_log @proc_name, 'FINISH NEW JOINS from Promo to Acquisition_History e_promo_p_promo_to_acqhist', @row_cnt, @perf_string, @camp_id

    --### RELEASE SESSION APP LOCK ###--
    EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
    --
  END TRY
  BEGIN CATCH
    EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  END CATCH
  --
END

--------------------------------------------------------------------------------------------------
PRINT convert(varchar,getdate(),120)+' -->> Start All Property Inserts'
--Start Message Data
--------------------------------------------------------------------------------------------------
-------------
EXEC xcs_cp_perf_log @proc_name, 'START PROMO INSERTS FROM #join', @row_cnt, @perf_string, @camp_id
--------------
--------------------------------------------------------------------------------------------------
PRINT convert(varchar,getdate(),120)+' -->> Start Promo Inserts'
--Start Message Data
--------------------------------------------------------------------------------------------------
--### GET SESSION APP LOCK ###--
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';

--- === === === ---

IF (@result < 0) RETURN -1
BEGIN TRY
  --
  -- Populate e_promo_entity_id from #join
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT ENTITY_ID INTO PROMO'
  INSERT INTO e_promo_p_entity_id(pk_promo_id, p_entity_id)
  SELECT pk_promo_id,
         entity_id
  FROM #join j WITH(NOLOCK)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT ENTITY_ID INTO PROMO', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  --
  -- Populate e_promo_p_campid from #join
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT CAMPID INTO PROMO'
  INSERT INTO e_promo_p_campid(pk_promo_id, p_campid)
  SELECT pk_promo_id,
         camp_id
  FROM #join j WITH(NOLOCK)
 
  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err
 
  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT CAMPID INTO PROMO', @row_cnt, @perf_string, @camp_id

  --- === === === --
 
  --
  --  Populate e_promo_p_msgid from #join
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT MSGID INTO PROMO'
  INSERT INTO e_promo_p_msgid(pk_promo_id, p_msgid)
  SELECT pk_promo_id,
         msg_id
  FROM #join j WITH(NOLOCK)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT MSGID INTO PROMO', @row_cnt, @perf_string, @camp_id
     
  --- === === === ---

  --
  -- Populate e_promo_p_email from #join
  --
  IF @entity_id = 100 -- e_recipient
  BEGIN
    --
    PRINT convert(varchar,getdate(),120)+' -->> Start INSERT RECIPIENT EMAIL INTO PROMO'
    INSERT INTO e_promo_p_email(pk_promo_id, p_email)
    SELECT j.pk_promo_id,
           r.p_email
    FROM #join j WITH(NOLOCK)
    join e_promo_p_promo_to_recipient p with(nolock) on p.pk_promo_id= j.pk_promo_id
    join e_recipient r with(nolock) on r.pk_recip_id = p.p_promo_to_recipient
   
    SELECT @err = @@error, @row_cnt = @@ROWCOUNT
    IF(@err > 0) GOTO err
   
    EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT RECIPIENT EMAIL INTO PROMO', @row_cnt, @perf_string, @camp_id
    --
  END
  ELSE IF @entity_id = 114 -- e_acquisition_history
  BEGIN
    --
    PRINT convert(varchar,getdate(),120)+' -->> Start INSERT ACQUISITION_HISTORY EMAIL INTO PROMO'
    INSERT INTO e_promo_p_email(pk_promo_id, p_email)
    SELECT j.pk_promo_id,
           a.p_email
    FROM #join j WITH(NOLOCK)
    join e_promo_p_promo_to_acqhist p with(nolock) on p.pk_promo_id= j.pk_promo_id
    join e_acquisition_history a with(nolock) on a.pk_acquisition_history_id = p.p_promo_to_acqhist
   
    SELECT @err = @@error, @row_cnt = @@ROWCOUNT
    IF(@err > 0) GOTO err
   
    EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT ACQUISITION_HISTORY EMAIL INTO PROMO', @row_cnt, @perf_string, @camp_id
    --
  END

  --- === === === --

  --### RELEASE SESSION APP LOCK ###--
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  --
END TRY
BEGIN CATCH
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
END CATCH
 
--- === === === ---

--
-- Populate e_promo_p_campaignmodeid from #join, If mode_id = 200 (Proofs made)
--
IF @mode_id = 200 -- only insert Proofs mode
BEGIN
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT CAMPAIGNMODEID INTO PROMO'
  INSERT INTO e_promo_p_campaignmodeid(pk_promo_id, p_campaignmodeid)
  SELECT pk_promo_id,
         mode_id
  FROM #join j WITH(NOLOCK)
 
  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err
 
  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT CAMPAIGNMODEID INTO PROMO', @row_cnt, @perf_string, @camp_id
  --
END

--- === === === ---

--### GET SESSION APP LOCK ###--
EXEC @result = sp_getapplock @Resource = @resource_name, @LockMode = 'Exclusive', @LockOwner = 'Session';

IF (@result < 0) RETURN -1
BEGIN TRY
  --
  EXEC xcs_cp_perf_log @proc_name, 'START POPULATE PROMO Assigned', @row_cnt, @perf_string, @camp_id

  --
  -- Populate e_promo_p_date_assigned from #join
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT DATE_ASSIGNED INTO PROMO'
  INSERT INTO e_promo_p_date_assigned(pk_promo_id, p_date_assigned)
  SELECT pk_promo_id,
         dbo.ConvertDateTimeFromServer(GETDATE(), 'Pacific Standard Time')
  FROM #join j WITH(NOLOCK)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT DATE_ASSIGNED INTO PROMO', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  --
  -- Populate e_promo_p_assigned from #join
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start INSERT ASSIGNED INTO PROMO'
  INSERT INTO e_promo_p_assigned(pk_promo_id, p_assigned)
  SELECT pk_promo_id,
         'Yes'
  FROM #join j WITH(NOLOCK)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  EXEC xcs_cp_perf_log @proc_name, 'FINISH INSERT ASSIGNED INTO PROMO', @row_cnt, @perf_string, @camp_id

  --- === === === ---

  --
  -- Delete from xcs_cp_TempPromoAssigned promo codes which creation time is older than 2 hrs ago
  --
  PRINT convert(varchar,getdate(),120)+' -->> Start DELETE xcs_cp_TempPromoAssigned > 2hr'
  DELETE xcs_cp_TempPromoAssigned
  WHERE GETDATE() > DATEADD(hour, 2, creation_time)

  SELECT @err = @@error, @row_cnt = @@ROWCOUNT
  IF(@err > 0) GOTO err

  --### RELEASE SESSION APP LOCK ###--
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
  --
END TRY
BEGIN CATCH
  EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
END CATCH

--- === === === ---
--------------
EXEC xcs_cp_perf_log @proc_name, 'END PROMO INSERTS FROM #join', @row_cnt, @perf_string, @camp_id
---------------

--------------------------------------------------------------------------------------------------
PRINT convert(varchar,getdate(),120)+' -->> END All Property Inserts'
--------------------------------------------------------------------------------------------------

END

done:

EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
EXEC xcs_cp_perf_log @proc_name, 'FINISH', @row_cnt, @perf_string, @camp_id
EXEC p_perf_log @proc_name, 'FINISH', @row_cnt, null, 0
RETURN 0

err:

EXEC sp_releaseapplock @Resource = @resource_name, @LockOwner = 'Session'
EXEC p_perf_log @proc_name, 'FINISH WITH ERROR', @row_cnt, null, 0
RETURN @err

