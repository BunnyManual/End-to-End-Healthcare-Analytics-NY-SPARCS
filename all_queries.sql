--Complete SQL Scripts for Healthcare Analysis Project
--This file contains all the SQL queries used in the end-to-end analysis of the NY Hospital Inpatient Discharges dataset. The queries are written for PostgreSQL.

--Phase 1: Data Acquisition & Setup
--1. Table Creation
--This query sets up the initial table structure in the health_data_project database. All columns are initially loaded as TEXT to prevent errors from special characters or formatting before cleaning.

CREATE TABLE inpatient_discharges (
    "Hospital Service Area" TEXT,
    "Hospital County" TEXT,
    "Operating Certificate Number" BIGINT,
    "Permanent Facility Id" BIGINT,
    "Facility Name" TEXT,
    "Age Group" VARCHAR(50),
    "Zip Code - 3 digits" VARCHAR(10),
    "Gender" VARCHAR(20),
    "Race" VARCHAR(50),
    "Ethnicity" VARCHAR(50),
    "Length of Stay" TEXT,
    "Type of Admission" TEXT,
    "Patient Disposition" TEXT,
    "Discharge Year" INTEGER,
    "CCSR Diagnosis Code" TEXT,
    "CCSR Diagnosis Description" TEXT,
    "CCSR Procedure Code" TEXT,
    "CCSR Procedure Description" TEXT,
    "APR DRG Code" INTEGER,
    "APR DRG Description" TEXT,
    "APR MDC Code" INTEGER,
    "APR MDC Description" TEXT,
    "APR Severity of Illness Code" INTEGER,
    "APR Severity of Illness Description" TEXT,
    "APR Risk of Mortality" TEXT,
    "APR Medical Surgical Description" TEXT,
    "Payment Typology 1" TEXT,
    "Payment Typology 2" TEXT,
    "Payment Typology 3" TEXT,
    "Birth Weight" TEXT,
    "Emergency Department Indicator" VARCHAR(10),
    "Total Charges" TEXT,
    "Total Costs" TEXT
);

--Phase 2: Data Cleaning & Preparation
--2. Cleaning and Converting 'Total Charges' and 'Total Costs'
--Removes commas from the currency columns and converts them to a precise NUMERIC data type.

-- Step 1: Remove commas
UPDATE inpatient_discharges
SET 
    "Total Charges" = REPLACE("Total Charges", ',', ''),
    "Total Costs" = REPLACE("Total Costs", ',', '');

-- Step 2: Alter column types to NUMERIC
ALTER TABLE inpatient_discharges
ALTER COLUMN "Total Charges" TYPE NUMERIC(15, 2) USING ("Total Charges"::NUMERIC(15, 2)),
ALTER COLUMN "Total Costs" TYPE NUMERIC(15, 2) USING ("Total Costs"::NUMERIC(15, 2));

--3. Cleaning and Converting 'Length of Stay'
--Standardizes the '120+' value to 120 and converts the column to an INTEGER data type.

-- Step 1: Standardize '120+'
UPDATE inpatient_discharges
SET "Length of Stay" = '120'
WHERE "Length of Stay" = '120+';

-- Step 2: Alter column type to INTEGER
ALTER TABLE inpatient_discharges
ALTER COLUMN "Length of Stay" TYPE INTEGER USING ("Length of Stay"::INTEGER);

--4. Cleaning and Converting 'Birth Weight'
--Handles non-numeric values like 'UNKN' by setting them to NULL, then converts the column to an INTEGER data type.

-- Step 1: Identify non-numeric values
SELECT DISTINCT "Birth Weight" 
FROM inpatient_discharges 
WHERE "Birth Weight" IS NOT NULL AND "Birth Weight" ~ '[^0-9]';

-- Step 2: Convert non-numeric text to NULL
UPDATE inpatient_discharges
SET "Birth Weight" = NULL
WHERE "Birth Weight" = 'UNKN';

-- Step 3: Alter column type to INTEGER
ALTER TABLE inpatient_discharges
ALTER COLUMN "Birth Weight" TYPE INTEGER USING ("Birth Weight"::INTEGER);

--5. Investigating Missing Location Data
--This query was used to assess the extent of missing data in key location fields.

SELECT 
    COUNT(*) AS total_rows,
    COUNT("Hospital Service Area") AS service_area_count,
    COUNT("Zip Code - 3 digits") AS zip_code_count
FROM inpatient_discharges;

--6. Standardizing Facility Names (Investigation)
--This query lists all unique facility names to help identify inconsistencies that need to be merged.

SELECT "Facility Name", COUNT(*)
FROM inpatient_discharges
GROUP BY "Facility Name"
ORDER BY "Facility Name";

--7. Feature Engineering: Creating 'hospital_system' Column
--Adds a new column and then populates it by grouping individual facilities into larger parent health systems.

-- Step 1: Add the new column
ALTER TABLE inpatient_discharges
ADD COLUMN hospital_system TEXT;

-- Step 2: Populate the column using a CASE statement
UPDATE inpatient_discharges
SET hospital_system = CASE
    WHEN "Facility Name" LIKE 'Montefiore%' THEN 'Montefiore Health System'
    WHEN "Facility Name" LIKE 'Mount Sinai%' THEN 'Mount Sinai Health System'
    WHEN "Facility Name" LIKE 'New York-Presbyterian%' OR "Facility Name" LIKE 'New York - Presbyterian%' OR "Facility Name" LIKE 'NewYork-Presbyterian%' THEN 'NewYork-Presbyterian'
    -- ... other cases as defined in the project ...
    ELSE 'Independent/Other'
END;

--8. Data Quality Check: Identifying Duplicate Records
--This query identifies sets of rows that are 100% identical across all columns.

SELECT COUNT(*) AS number_of_duplicate_sets
FROM (
    SELECT COUNT(*)
    FROM inpatient_discharges
    GROUP BY
        "Hospital Service Area", "Hospital County", "Operating Certificate Number", "Permanent Facility Id",
        "Facility Name", "Age Group", "Zip Code - 3 digits", "Gender", "Race", "Ethnicity",
        "Length of Stay", "Type of Admission", "Patient Disposition", "Discharge Year",
        "CCSR Diagnosis Code", "CCSR Diagnosis Description", "CCSR Procedure Code", "CCSR Procedure Description",
        "APR DRG Code", "APR DRG Description", "APR MDC Code", "APR MDC Description",
        "APR Severity of Illness Code", "APR Severity of Illness Description", "APR Risk of Mortality",
        "APR Medical Surgical Description", "Payment Typology 1", "Payment Typology 2", "Payment Typology 3",
        "Birth Weight", "Emergency Department Indicator", "Total Charges", "Total Costs", "hospital_system"
    HAVING COUNT(*) > 1
) AS duplicate_counts;

--9. Data Quality Action: Deleting Duplicate Records
--This query uses the ctid system column to remove all but one copy of any identical rows.

DELETE FROM inpatient_discharges
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT
            ctid,
            ROW_NUMBER() OVER(PARTITION BY "Hospital Service Area", "Hospital County", "Operating Certificate Number", "Permanent Facility Id", "Facility Name", "Age Group", "Zip Code - 3 digits", "Gender", "Race", "Ethnicity", "Length of Stay", "Type of Admission", "Patient Disposition", "Discharge Year", "CCSR Diagnosis Code", "CCSR Diagnosis Description", "CCSR Procedure Code", "CCSR Procedure Description", "APR DRG Code", "APR DRG Description", "APR MDC Code", "APR MDC Description", "APR Severity of Illness Code", "APR Severity of Illness Description", "APR Risk of Mortality", "APR Medical Surgical Description", "Payment Typology 1", "Payment Typology 2", "Payment Typology 3", "Birth Weight", "Emergency Department Indicator", "Total Charges", "Total Costs", "hospital_system") AS rn
        FROM
            inpatient_discharges
    ) sub
    WHERE rn > 1
);

--Phase 3: Exploratory Data Analysis (EDA)
--These queries were used to extract aggregated data for visualization in Python.

--10. EDA: Distribution of Length of Stay
--Extracts patient counts for each length of stay from 1 to 30 days.

SELECT "Length of Stay", COUNT(*) as patient_count
FROM inpatient_discharges
WHERE "Length of Stay" <= 30 AND "Length of Stay" > 0
GROUP BY "Length of Stay"
ORDER BY "Length of Stay";

--11. EDA: Top 15 Most Common Diagnoses
--Extracts the top 15 diagnoses by patient volume.

SELECT "CCSR Diagnosis Description" as diagnosis, COUNT(*) as number_of_cases
FROM inpatient_discharges
WHERE "CCSR Diagnosis Description" IS NOT NULL
GROUP BY diagnosis
ORDER BY number_of_cases DESC
LIMIT 15;

--12. EDA: Illness Severity vs. Hospital Charges
--Calculates the number of cases and average charge for each level of illness severity, sorted logically.

SELECT "APR Severity of Illness Description" as severity_level, COUNT(*) as number_of_cases,
AVG("Total Charges") as average_charge
FROM inpatient_discharges
WHERE "APR Severity of Illness Description" IS NOT NULL
GROUP BY severity_level
ORDER BY
    CASE
        WHEN "APR Severity of Illness Description" = 'Minor' THEN 1
        WHEN "APR Severity of Illness Description" = 'Moderate' THEN 2
        WHEN "APR Severity of Illness Description" = 'Major' THEN 3
        WHEN "APR Severity of Illness Description" = 'Extreme' THEN 4
        ELSE 5
    END;
