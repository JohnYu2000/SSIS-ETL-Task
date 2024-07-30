# SSIS-ETL-Task

**Table of Contents**
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation and Configuration](#installation-and-configuration)
    - [Usage](#usage)

# Overview
This SSIS ETL project is designed to extract user data from an Excel source, transform and clean the data, and incrementally load it into a production SQL Server database. This project is composed of three main parts:

1. **Extract and Load Data to Staging (Data Flow)**
2. **Execute SQL Task for Data Cleaning**
3. **Incremental Load to Production (Data Flow)**

# Project Structure

1. **Extract and Load Data to Staging (Data Flow)**
    * **Excel Source**: Loads user data from an Excel file in string format.
    * **Data Conversion Transformation**: Converts the fields from string format to their respective data types.
    * **OLE DB Destination**: Loads the converted data into the `stg.Users` staging table.
2. **Execute SQL Task**
    * **Data Cleaning Script**: Executes a SQL script to clean the data in the `stg.Users` table. This script performs necessary data cleaning operations such as removing duplicates, handling null values, standardizing data formats, and storing erroneous records into the `stg.Errors` table.
3. **Incremental Load to Production (Data Flow)**
    * **OLE DB Source**: Extracts cleaned data from the `stg.Users` table.
    * **Lookup Transformation**: Separates new records from existing records by performing a lookup against the `prod.Users` table.
        * **Lookup Match Output**: Updates existing records in the `prod.Users` table.
        * **Lookup No Match Output**: Inserts new records into the `prod.Users` table.

# Getting Started
## Prerequisites
* SQL Server Management Studio 20
* Visual Studio 2022
* SQL Server Integration Services (SSIS)
* Excel file with user data

## Installation and Configuration
1. **Clone the Repository**:
    ```sh
    git clone https://github.com/JohnYu2000/SSIS-ETL-Task.git
    ```
2. **Open the Solution**:
    * Open the solution file (.sln) in Visual Studio 2022.
3. **Configure Connection Managers**:
    * Update the connection strings in the SSIS package to point to your SQL Server Instance
    * Update the connection strings in the SSIS package to point to your Excel file location.
4. **Restore the Database**:

    A backup of the database is provided as a ZIP file. Unzip the file and restore the database in SQL Server Management Studio using the provided backup. To restore the database:
    1. Open SQL Server Management Studio and connect to your SQL Server Instance.
    2. Right-click on the `Databases` node and select `Restore Database...`.
    3. Select `Device` and click on the `...` button to browse for the backup file.
    4. Add the unzipped `.bak` file and proceed with the restore process.

## Usage
1. **Run the Extract and Load Data to Staging (Data Flow)**:
    * Execute the data flow to load and transform data from the Excel source into the `stg.Users` staging table.
2. **Run the Execute SQL Task**:
    * Execute the SQL script to clean the data in the `stg.Users` table.
3. **Run the Incremental Load to Production**:
    * Execute the data flow to load cleaned data from the `stg.Users` table into the `prod.Users` table, performing insertions and updates as necessary.

# SQL Scripts
## Data Cleaning Script
```sql
-- ##########################################################################
-- Author: Junye (John) Yu
-- Description: This stored procedure is used to perform data cleaning for
--				the staging table. This query is invoked immediately after
--				the "Extract and Load Data to Staging" data flow task is
--				complete.
-- ##########################################################################

USE [KoreASsignment_John_Yu]
GO

-- ##########################################################################
-- Drop existing index on prod.Users if it exists.
-- This index is used to improve the performance of the Lookup Transformation
-- when performing Incremental Load to Production.
-- ##########################################################################
IF EXISTS (SELECT name
		   FROM sys.indexes
		   WHERE name = 'IX_UserID'
		   AND object_id = OBJECT_ID('prod.Users'))
BEGIN
	DROP INDEX IX_UserID ON prod.Users;
END
GO

-- Create a clustered index on UserID for prod.Users.
CREATE CLUSTERED INDEX IX_UserID
ON prod.Users (UserID);
GO

-- ##########################################################################
-- Ensure stg.Errors table exists to store erroneous records for review.
-- If the table exists, truncate it to remove previous error records.
-- ##########################################################################
IF EXISTS (SELECT *
		   FROM sys.objects
		   WHERE object_id = OBJECT_ID(N'stg.Errors')
		   AND type IN (N'U'))
BEGIN
	TRUNCATE TABLE stg.Errors;
END
ELSE
BEGIN
	-- Create the stg.Errors table to store erroneous records.
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

-- ##########################################################################
-- Description: This stored procedure performs data cleaning immediately
--              after data is extracted and loaded into the staging table.
-- ##########################################################################
CREATE PROCEDURE dbo.CleanStagingData
AS
BEGIN
	-- Prevents the message about the number of rows affected by a T-SQL
	-- statement from being returned.
	SET NOCOUNT ON;

	-- Start a transaction to ensure atomicity.
	BEGIN TRANSACTION;

	BEGIN TRY
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

		-- Declare variables to find purchaseTotals that are outliers.
		DECLARE
			@Q1 FLOAT,
			@Q3 FLOAT,
			@IQR FLOAT,
			@LowerLimit FLOAT,
			@UpperLimit FLOAT;

		-- Calculate the first quartile (Q1).
		SELECT @Q1 = PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY PurchaseTotal) OVER ()
		FROM stg.Users;

		-- Calculate the third quartile (Q3).
		SELECT @Q3 = PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY PurchaseTotal) OVER ()
		FROM stg.Users;

		-- Calculate the Interquartile Range (IQR)
		SET @IQR = @Q3 - @Q1;

		-- Calculate the lower and upper limits for outliers.
		SET @LowerLimit = @Q1 - 1.5 * @IQR;
		SET @UpperLimit = @Q3 + 1.5 * @IQR;

		-- Delete erroneous records from stg.Users and insert them into stg.Errors.
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
			-- Remove records with special characters in FullName or Email.
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
			-- Remove records with very old dates (over 100 years old)
			OR RegistrationDate < DATEADD(YEAR, -100, GETDATE())
			OR LastLoginDate < DATEADD(YEAR, -100, GETDATE())
			-- Remove records with outlier purchase totals.
			OR PurchaseTotal < @LowerLimit
			OR PurchaseTotal > @UpperLimit
		-- Commit the transaction if everything is successful.
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		-- Rollback the transaction if any error occurs.
		ROLLBACK TRANSACTION;

		-- Handle errors by capturing error information.
		DECLARE
			@ErrorMessage NVARCHAR(4000),
			@ErrorSeverity INT,
			@ErrorState INT;
		SELECT
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();
		-- Raise the error with the captured information.
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
	END CATCH
END
GO
```