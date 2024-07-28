USE [KoreASsignment_John_Yu]
GO

-- Create a stored procedure for data cleaning
CREATE PROCEDURE dbo.CleanStagingData
AS
BEGIN
	-- Remove duplicate records based on UserID or Email
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
END
GO