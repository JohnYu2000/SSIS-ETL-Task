# SSIS-ETL-Task

**Table of Contents**
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation and Configuration](#installation-and-configuration)
    - [Usage](#usage)
- [Design](#design)
	- [Data Cleaning](#data-cleaning)
	- [Optimization](#optimization)
    - [Challenges Faced](#challenges-faced)
- [Execution Report](#execution-report)
- [Appendix](#appendix)
    - [Input Source File (.xlsx)](#input-source-file-xlsx)
    - [Data Cleaning Script](#data-cleaning-script)

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

# Design
## Data Cleaning
The data cleaning process is a critical step in ensuring the accuracy and integrity of the data before it is loaded into the production database. Below are the key steps and criteria used in the data cleaning script:
1. **Dropping and Recreating Index**:
	* **Reason**: The index on `prod.Users` is dropped and recreated to improve the performance of the Lookup Transformation during the incremental load process.
2. **Handling Duplicate Records**:
	* **Criteria**: Duplicate records are identified based on `UserID` or `Email`.
	* **Method**: A Common Table Expression (CTE) is used to identify duplicates, and only the first occurrence of each duplicate is retained. Subsequent duplicates are removed.
3. **Identifying and Handling Erroneous Records**:
	* **Null Values**: Records with null values in any of the fields is flagged for further investigation.
	* **Special Characters**: Records containing special characters in `FullName` or `Email` are flagged as errors.
	* **Future Dates**: Records with future dates in `RegistrationDate` or `LastLoginDate` are invalid and removed.
	* **Negative Values**: Records with negative values in `UserID`, `Age`, or `PurchaseTotal` are removed.
	* **Invalid Email Format**: Records with invalid email formats are identified and removed.
	* **Old Dates**: Records with dates older than 100 years are considered invalid.
	* **Outlier Purchase Totals**: Outlier purchase totals are identified using the Interquartile Range (IQR) method, and records outside the calculated limits are removed.
4. **Inserting Erroneous Records into `stg.Errors`**:
	* **Purpose**: Erroneous records are inserted into the `stg.Errors` table for review and analysis. This helps in identifying patterns and potential issues in the source data.
5. **Invalid Data Type Invalid Dates, and Old Date Format Handling**:
	* **Note**: Criteria for handling incorrect data types, invalid dates, and dates in the wrong format are not included in the data cleaning script. This is because these issues are addressed during the data conversion step in the *Extract and Load Data to Staging* data flow using the Data Conversion Transformation.

## Optimization

1. **Nonclustered Index for Lookup Transformation**:
    * **Purpose**: The nonclustered index on `UserID` in the `prod.Users` table is used to improve the performance of the Lookup Transformation during the incremental load process.
    * **Significance**: Indexes enhance the speed of data retrieval operations, making the Lookup Transformation more efficient by quickly finding matching records.
2. **SET NOCOUNT ON**:
    * **Purpose**: Prevents the SQL Server from sending messages about the number of rows affected by a T-SQL statement.
    * **Significance**: This improves the performance of the stored procedure by reducing network traffic between the server and the client.
3. **Transaction Wrapping**:
    * **Purpose**: Ensures all operations within the transaction are completed successfully before committing the changes to the database.
    * **Significance**: If any part of the transaction fails, all changes are rolled back, maintaining data integrity and consistency.
4. **Using the OUTPUT keyword**:
    * **Purpose**: Captures the deleted records and inserts them into the `stg.Errors` table.
    * **Significance**: This allows for auditing and analyzing erroneous records separately, helping in understanding data quality issues.
5. **Batch Processing**:
    * **Importance**: Handling data in batches can significantly improve performance and manageability, especially with large datasets. However, in this case, the script processes all data in a single transaction for simplicity and atomicity.

## Challenges Faced
1. **Execution Logging**:
    * **Initial Approach**: Intended to use SSIS Script Tasks and RowCount Transformations for logging.
    * **Issues**: Faced configuration difficulties and inaccurate counts.
    * **Solution**: Switched to using a SQL script to gather logging information from the stored procedure, simplifying the process and ensuring accuracy.
2. **Handling Erroneous Records**:
    * **Challenges**: Deciding the best approach to handle erroneous records.
    * **Solution**: Chose to insert erroneous records into a separate table (`stg.Errors`) for developer review, minimizing assumptions and providing clear visibility into data quality issues.

# Execution report

### Data Source
The input data was sourced from the `input.xlsx` file

### Records Processed
* **Total Records Successfully Processed**: 18
* **Total Records Excluded**: 14

### Excluded Records and Reasons
| StgID | UserID | FullName | Age | Email | RegistrationDate | LastLoginDate | PurchaseTotal | Reason |
| --- | --- | --- | --- | --- | --- | -- | --- | --- |
| 2 | 111 | Alice Johnson | NULL | alicejohnson@example.com | 2022-07-15 | NULL | NULL | Age is NULL |
| 3 | 112 | Bob Marley | 27 | bobmarley@example.com | 2021-05-20 | 2023-02-28 | NULL | PurchaseTotal is NULL |
| 4 | 113 | Cathy Smith | NULL | cathysmith@example.com | 2019-10-12 | 2023-02-27 | 210.5 | Age is NULL |
| 5 | NULL | Null User | 25 | NULL | 2020-12-01 | 2023-02-25 | 100 | UserID is NULL |
| 7 | 115 | Eva Green | NULL | evagreen@example.com | 2018-08-22 | 2023-02-23 | NULL | Age is NULL |
| 14 | 121 | Kevin Yolt | NULL | kevinyolt@example.com | 2021-03-14 | 2023-02-17 | NULL | Age is NULL |
| 24 | 130 | Invalid Date | 29 | invaliddatetest@example.com | NULL | 2023-02-08 | 180 | RegistrationDate is NULL |
| 25 | 131 | Special Characters Name | 34 | special$$name@example.com | 2021-04-17 | 2023-02-07 | 200.5 | Email contains special characters |
| 27 | 133 | Future Date | 25 | futuredate@example.com | 2024-01-01 | 2025-01-02 | 160 | LastLoginDate is in the future |
| 28 | 134 | Negative Age | -1 | negativeage@example.com | 2021-08-15 | 2023-02-04 | 130 | Age is negative |
| 29 | 135 | Very Old Date | 90 | veryolddate@example.com | 1920-01-01 | 2023-02-03 | 100 | RegistrationDate is older than 100 years |
| 30 | 136 | Extra Large Total | 27 | extralargetotal@example.com | 2020-10-10 | 2023-02-02 | 1000000 | PurchaseTotal is an outlier |
| 31 | 137 | Incorrect Email | 28 | notanemail | 2021-11-11 | 2023-02-01 | 190 | Email format is invalid |
| 35 | 140 | Test2 | 24 | test2@example.com | 2024-07-29 | 2023-07-01 | 100 | RegistrationDate is after LastLoginDate |

# Appendix

## Input Source File (.xlsx)
| UserID | FullName | Age | Email | RegistrationDate | LastLoginDate | PurchaseTotal |
| --- | --- | --- | --- | --- | --- | --- |
| 101 | John Doe | 30 | johndoe@example.com | 2021-01-10 | 2023-03-01 | 150 |
| 111 | Alice Johnson | | alicejohnson@example.com | 2022-07-15 | | |
| 112 | Bob Marley | 27 | bobmarley@example.com | 2021-05-20 | 2023-02-28 | |
| 113 | Cathy Smith | null | cathysmith@example.com | 2019-10-12 | 2023-02-27 | 210.5 |
| | Null User | 25 | | 2020-12-01 | 2023-02-25 | 100 |
| 114 | Derek Nowak | 29 | dereknowak@example.com | 2020-03-17 | 2023-02-24 | 180.75 |
| 115 | Eva Green | null | evagreen@example.com | 2018-08-22 | 2023-02-23 | |
| 116 | Frank Poe | 34 | frankpoe@example.com | 2019-11-13 | 2023-02-22 | 190.4 |
| 101 | John Doe | 30 | johndoe@example.com | 2023-01-10 | 2023-03-01 | 200 |
| 117 | George Kay | 28 | georgekay@example.com | 2021-06-07 | 2023-02-21 | 170 |
| 118 | Hanna Lux | 32 | hannalux@example.com | 2019-02-18 | 2023-02-20 | 220.15 |
| 119 | Ian Volt | 26 | ianvolt@example.com | 2020-07-23 | 2023-02-19 | 130 |
| 120 | Julia Nex | 24 | julianex@example.com | 2022-01-12 | 2023-02-18 | 145.6 |
| 121 | Kevin Yolt | abc | kevinyolt@example.com | 2021-03-14 | 2023-02-17 | |
| 122 | Lana Molt | 31 | lanamolt@example.com | 2020-09-09 | 2023-02-16 | 155.3 |
| 123 | Mike Dolt | 33 | mikedolt@example.com | 2018-05-05 | 2023-02-15 | 205 |
| 124 | Nina Colt | 27 | ninacolt@example.com | 2019-07-29 | 2023-02-14 | 160.75 |
| 125 | Oscar Holt | 29 | oscarholt@example.com | 2022-11-11 | 2023-02-13 | 175.45 |
| 126 | Patty Jolt | 31 | pattyjolt@example.com | 2018-12-13 | 2023-02-12 | 185.9 |
| 127 | Quincy Molt | 34 | quincymolt@example.com | 2020-04-17 | 2023-02-11 | 195.25 |
| 128 | Rita Bolt | 36 | ritabolt@example.com | 2021-08-21 | 2023-02-10 | 210.5 |
| 112 | Bob Marley | 27 | bobmarley@example.com | 2021-05-20 | 2023-02-28 | |
| 129 | Steve Jolt | 38 | stevejolt@example.com | 2019-01-01 | 2023-02-09 | 225.75 |
| 130 | Invalid Date | 29 | invaliddatetest@example.com | 2022-02-30 | 2023-02-08 | 180 |
| 131 | Special Characters Name | 34 | special$$name@example.com | 2021-04-17 | 2023-02-07 | 200.5 |
| 132 | Old Format | 30 | oldformat@example.com | 07/05/2019 | 2023-02-06 | 150.5 |
| 133 | Future Date | 25 | futuredate@example.com | 2024-01-01 | 2025-01-02 | 160 |
| 134 | Negative Age | -1 | negativeage@example.com | 2021-08-15 | 2023-02-04 | 130 |
| 135 | Very Old Date | 90 | veryolddate@example.com | 1920-01-01 | 2023-02-03 | 100 |
| 136 | Extra Large Total | 27 | extralargetotal@example.com | 2020-10-10 | 2023-02-02 | 1000000 |
| 137 | Incorrect Email | 28 | notanemail | 2021-11-11 | 2023-02-01 | 190 |
| 138 | Duplicate ID | 27 | duplicateid@example.com | 2019-03-15 | 2023-01-31 | 200 |
| 101 | John Doe | 30 | johndoe@example.com | 2024-01-10 | 2023-03-01 | 250 |
| 139 | DateTimeFormat | 24 | datetimeformat@example.com | 29-07-2024 13:03:32 | 29-07-2024 13:04:20 | 100 |
| 140 | Incorrect Causality | 24 | incorrectcausality@example.com | 2024-07-29 | 2023-07-01 | 100 |

## Data Cleaning Script
```sql
-- ##########################################################################
-- Author: Junye (John) Yu
-- Description: This stored procedure is used to perform data cleaning for
--              the staging table. This query is invoked immediately after
--              the "Extract and Load Data to Staging" data flow task is
--              complete.
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
CREATE NONCLUSTERED INDEX IX_UserID
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
		PurchaseTotal FLOAT,
		Reason NVARCHAR(255)
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

		-- Process data in batches
		DECLARE @BatchSize INT = 10000;
		DECLARE @MinStgID INT, @MaxStgID INT;

		SELECT @MinStgID = MIN(StgID), @MaxStgID = MAX(StgID) FROM stg.Users;

		WHILE @MinStgID IS NOT NULL AND @MinStgID <= @MaxStgID
		BEGIN
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
				DELETED.PurchaseTotal,
				-- Determine the reason for record exclusion and log it in the stg.Errors table.
				CASE
					WHEN DELETED.UserID IS NULL THEN 'UserID is NULL'
					WHEN DELETED.FullName IS NULL THEN 'FullName is NULL'
					WHEN DELETED.Age IS NULL Then 'Age is NULL'
					WHEN DELETED.Email IS NULL THEN 'Email is NULL'
					WHEN DELETED.RegistrationDate IS NULL THEN 'RegistrationDate is NULL'
					WHEN DELETED.LastLoginDate IS NULL THEN 'LastLoginDate is NULL'
					WHEN DELETED.PurchaseTotal IS NULL THEN 'PurchaseTotal is NULL'
					WHEN DELETED.FullName LIKE '%[^a-zA-Z0-9 ]%' THEN 'FullName contains special characters'
					WHEN DELETED.Email LIKE '%[^a-zA-Z0-9@._-]%' THEN 'Email contains special characters'
					WHEN DELETED.RegistrationDate > GETDATE() THEN 'RegistrationDate is in the future'
					WHEN DELETED.LastLoginDate > GETDATE() THEN 'LastLoginDate is in the future'
					WHEN DELETED.RegistrationDate > DELETED.LastLoginDate THEN 'RegistrationDate is after LastLoginDate'
					WHEN DELETED.UserID < 0 THEN 'UserID is negative'
					WHEN DELETED.Age < 0 THEN 'Age is negative'
					WHEN DELETED.PurchaseTotal < 0 THEN 'PurchaseTotal is negative'
					WHEN DELETED.Email NOT LIKE '%_@__%.__%' THEN 'Email format is invalid'
					WHEN DELETED.RegistrationDate < DATEADD(YEAR, -100, GETDATE()) THEN 'RegistrationDate is older than 100 years'
					WHEN DELETED.LastLoginDate < DATEADD(YEAR, -100, GETDATE()) THEN 'LastLoginDate is older than 100 years'
					WHEN DELETED.PurchaseTotal < @LowerLimit THEN 'PurchaseTotal is an outlier'
					WHEN DELETED.PurchaseTotal > @UpperLimit THEN 'PurchaseTotal is an outlier'
					ELSE 'Unknown reason'
				END AS Reason
			INTO
				stg.Errors
			WHERE
				-- Process records in batches to handle large datasets efficiently.
				StgID BETWEEN @MinStgID AND @MinStgID + @BatchSize - 1
				AND (
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
				);
			SET @MinStgID = @MinStgID + @BatchSize;
		END

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