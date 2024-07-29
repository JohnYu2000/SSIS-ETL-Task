USE [KoreASsignment_John_Yu]
GO

-- Create a table to isolate records with errors
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.Errors') AND type in (N'U'))
BEGIN
	CREATE TABLE stg.Errors (
		ErrorID INT IDENTITY(1,1) PRIMARY KEY,
		StgID INT,
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

	-- Isolate records with null values in non-nullable fields.
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		UserID IS NULL
		OR FullName IS NULL
		OR Age IS NULL
		OR Email IS NULL
		OR RegistrationDate IS NULL
		OR LastLoginDate IS NULL
		OR PurchaseTotal IS NULL;
	
	DELETE FROM stg.Users
	WHERE
		UserID IS NULL
		OR FullName IS NULL
		OR Age IS NULL
		OR Email IS NULL
		OR RegistrationDate IS NULL
		OR LastLoginDate IS NULL
		OR PurchaseTotal IS NULL;

	-- Isolate records with special characters in FullName or Email
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		FullName LIKE '%[^a-zA-Z0-9 ]%'
		OR Email LIKE '%[^a-zA-Z0-9@._-]%';

	DELETE FROM stg.Users
	WHERE
		FullName LIKE '%[^a-zA-Z0-9 ]%'
		OR Email LIKE '%[^a-zA-Z0-9@._-]%';

	-- Isolate records with future dates
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		RegistrationDate > GETDATE()
		OR LastLoginDate > GETDATE()
		OR RegistrationDate > LastLoginDate;

	DELETE FROM stg.Users
	WHERE
		RegistrationDate > GETDATE()
		OR LastLoginDate > GETDATE()
		OR RegistrationDate > LastLoginDate;

	-- Isolate records with negative age
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		Age < 0;

	DELETE FROM stg.Users
	WHERE
		Age < 0;

	-- Isolate records with invalid email format
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		Email NOT LIKE '%_@__%.__%';

	DELETE FROM stg.Users
	WHERE
		Email NOT LIKE '%_@__%.__%';

	-- Isolate records with very old dates (over 100 years old)
	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		RegistrationDate < DATEADD(YEAR, -100, GETDATE())
		OR LastLoginDate < DATEADD(YEAR, -100, GETDATE());

	DELETE FROM stg.Users
	WHERE
		RegistrationDate < DATEADD(YEAR, -100, GETDATE())
		OR LastLoginDate < DATEADD(YEAR, -100, GETDATE());

	-- Isolate records with outlier PurchaseTotals
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

	INSERT INTO stg.Errors (StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal)
	SELECT
		StgID, UserID, FullName, Age, Email, RegistrationDate, LastLoginDate, PurchaseTotal
	FROM
		stg.Users
	WHERE
		PurchaseTotal < @LowerLimit OR PurchaseTotal > @UpperLimit;

	DELETE FROM stg.Users
	WHERE
		PurchaseTotal < @LowerLimit OR PurchaseTotal > @UpperLimit;
END
GO