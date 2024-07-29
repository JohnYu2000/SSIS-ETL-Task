USE [KoreASsignment_John_Yu]
GO

-- Create a table to isolate records with errors
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.Errors') AND type in (N'U'))
BEGIN
	CREATE TABLE stg.Errors (
		StgID INT PRIMARY KEY,
		UserID INT,
		FullName NVARCHAR(255),
		Age INT,
		Email NVARCHAR(255),
		RegistrationDate DATE,
		LastLoginDate DATE,
		PurchaseTotal FLOAT
	);
END
GO

-- Create a stored procedure for data cleaning
CREATE PROCEDURE dbo.CleanStagingData
AS
BEGIN
	-- Remove duplicate records based on UserID or Email
	-- NOTE: Duplicate records will not be pushed into the stg.Errors table.
	;WITH CTE_Duplicates AS (
		SELECT
			StgID,
			UserID,
			Email,
			ROW_NUMBER() OVER (PARTITION BY UserID, Email ORDER BY StgID) AS RowNum
		FROM stg.Users
	)
	DELETE FROM stg.Users
	WHERE StgID IN (SELECT StgID FROM CTE_Duplicates WHERE RowNum > 1);

	-- Declare variables to be used to find purchaseTotals that are outliers.
	DECLARE
		@Q1 FLOAT,
		@Q3 FLOAT,
		@IQR FLOAT,
		@LowerLimit FLOAT,
		@UpperLimit FLOAT;

	-- Calculate the first quartile (Q1)
	SELECT @Q1 = PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY PurchaseTotal) OVER ()
	FROM stg.Users;

	-- Calculate the third quartile (Q3)
	SELECT @Q3 = PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY PurchaseTotal) OVER ()
	FROM stg.Users;

	-- Calculate the IQR
	SET @IQR = @Q3 - @Q1;

	-- Calculate the lower and upper limits
	SET @LowerLimit = @Q1 - 1.5 * @IQR;
	SET @UpperLimit = @Q3 + 1.5 * @IQR;

	-- DELETE records from Staging Table and capture the delted records using OUTPUT
	DELETE FROM stg.Users
	OUTPUT
		DELETED.StgID,
		DELETED.UserID,
		DELETED.FullName,
		DELETED.Age,
		DELETED.Email,
		DELETED.RegistrationDate,
		DELETED.LastLoginDate,
		DELETED.PurchaseTotal
	INTO
		stg.Errors
	WHERE
		-- Remove records with null values.
		UserID IS NULL
		OR FullName IS NULL
		OR Age IS NULL
		OR Email IS NULL
		OR RegistrationDate IS NULL
		OR LastLoginDate IS NULL
		OR PurchaseTotal IS NULL
		-- Remove records with special characters.
		OR FullName LIKE '%[^a-zA-Z0-9 ]%'
		OR Email LIKE '%[^a-zA-Z0-9@._-]%'
		-- Remove records with future dates.
		OR RegistrationDate > GETDATE()
		OR LastLoginDate > GETDATE()
		OR RegistrationDate > LastLoginDate
		-- Remove records with negative values.
		OR UserID < 0
		OR Age < 0
		OR PurchaseTotal < 0
		-- Remove records with invalid email format.
		OR Email NOT LIKE '%_@__%.__%'
		-- Remove records with very old dates.
		OR RegistrationDate < DATEADD(YEAR, -100, GETDATE())
		OR LastLoginDate < DATEADD(YEAR, -100, GETDATE())
		-- Remove records with outlier purchase totals.
		OR PurchaseTotal < @LowerLimit
		OR PurchaseTotal > @UpperLimit
END
GO