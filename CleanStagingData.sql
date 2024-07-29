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
END
GO