# SSIS-ETL-Task

**Table of Contents**
- [Overview](#overview)
    - [Data Flow Structure](#data-flow-structure)
- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Files](#files)
    - [Installation and Configuration](#installation-and-configuration)
    - [Usage](#usage)
- [Design](#design)
	- [Data Cleaning](#data-cleaning)
	- [Optimization](#optimization)
    - [Challenges Faced](#challenges-faced)
- [Execution Report](#execution-report)

# Overview
This SSIS ETL project is designed to extract user data from an Excel source, transform and clean the data, and incrementally load it into a production SQL Server database. This project is composed of three main parts:

1. **Extract and Load Data to Staging (Data Flow)**
2. **Execute SQL Task for Data Cleaning**
3. **Incremental Load to Production (Data Flow)**

## Data Flow Structure

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

## Files

After cloning this repository you should have the following files.

* **Resources/**
    * **CleanStagingData.sql**: SQL script to create the stored procedure for data cleaning.
    * **CleanStagingDataLog.sql**: SQL script to log the number of records processed and excluded.
    * **input.xlsx**: Source file containing input data for testing purposes.
* **SSIS-ETL-Task/**: This folder was initialized when creating the Integration Services Project.
* **.gitignore**
* **backup.zip**: ZIP file containing a backup of the database, including the `stg.Errors`, `stg.Users`, and `prod.Users` tables, and the `CleanStagingData` stored procedure.
* **README.md**
* **SSIS-ETL-Task.sln**: Solution file containing the SSIS project.

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

I used the methodologies listed below to developing my data cleaning logic.

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

I used the techniques listed below to optimize my stored procedure.

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
The input data was sourced from `input.xlsx`.

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

# Known Issues
* **Slow Performance**:
    * **Issue**: The SSIS package runs very slowly.
    * **Assumption**: The slow performance is presumed to be due to my laptop's hardware limitations rather than the SSIS configurations.