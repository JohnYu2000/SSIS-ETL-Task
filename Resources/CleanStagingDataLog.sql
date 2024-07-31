USE [KoreAssignment_John_Yu]
GO

-- Execute the stored procedure
EXEC dbo.CleanStagingData;
GO

-- Output the execution results
SELECT
	GETDATE() AS [Execution Time],
	(SELECT COUNT(*) FROM stg.Users) AS [Total Records Processed],
	(SELECT COUNT(*) FROM stg.Errors) AS [Total Records Excluded];
GO

-- Output the excluded records
SELECT *
FROM stg.Errors;
GO