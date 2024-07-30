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
- [SQL Scripts](#sql-scripts)

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

# SQL Scripts
## Data Cleaning Script
```sql

```