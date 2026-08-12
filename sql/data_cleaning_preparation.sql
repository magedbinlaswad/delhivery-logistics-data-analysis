/* =========================================================
   DELHIVERY LOGISTICS DATA
   SQL DATA CLEANING & PREPARATION WORKFLOW

   Purpose:
   Clean, validate, and prepare logistics data for
   downstream analysis and visualization in BI tools.

   Workflow:
   Raw Data
      ↓
   Data Profiling
      ↓
   Data Quality Checks
      ↓
   Cleaning
      ↓
   Grain Definition
      ↓
   OD-Level Transformation
      ↓
   Feature Engineering
      ↓
   Geographic Enrichment
      ↓
   Final Validation
      ↓
   BI-Ready Dataset
   ========================================================= */



/* =========================================================
   1. DATA OVERVIEW

   Purpose:
   Understand the overall size of the dataset and compare
   the number of raw records with the number of unique trips.

   This provides an initial understanding of the dataset
   before performing any cleaning or transformation.
   ========================================================= */

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT trip_uuid) AS Total_Trips
FROM delhivery.delhivery_data;



/* =========================================================
   2. DATA TYPE VALIDATION

   Purpose:
   Review the data type assigned to each column.

   Correct data types are important because:
   - Dates should support date/time calculations.
   - Numeric fields should support mathematical operations.
   - Text fields should store categorical information.

   This check is performed before modifying the dataset.
   ========================================================= */

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE

FROM INFORMATION_SCHEMA.COLUMNS

WHERE TABLE_SCHEMA = 'delhivery'
  AND TABLE_NAME = 'delhivery_data'

ORDER BY ORDINAL_POSITION;



/* =========================================================
   3. MISSING VALUES CHECK

   Purpose:
   Identify NULL values in key analytical fields.

   Missing values are not automatically removed.
   Each missing value should be evaluated based on its
   business importance and impact on the analysis.
   ========================================================= */

SELECT
    COUNT(*) AS Total_Rows,

    SUM(
        CASE
            WHEN trip_uuid IS NULL THEN 1
            ELSE 0
        END
    ) AS Trip_Null,

    SUM(
        CASE
            WHEN source_name IS NULL THEN 1
            ELSE 0
        END
    ) AS Source_Null,

    SUM(
        CASE
            WHEN destination_name IS NULL THEN 1
            ELSE 0
        END
    ) AS Destination_Null,

    SUM(
        CASE
            WHEN actual_time IS NULL THEN 1
            ELSE 0
        END
    ) AS Actual_Time_Null,

    SUM(
        CASE
            WHEN osrm_time IS NULL THEN 1
            ELSE 0
        END
    ) AS OSRM_Time_Null,

    SUM(
        CASE
            WHEN actual_distance_to_destination IS NULL
                THEN 1
            ELSE 0
        END
    ) AS Distance_Null

FROM delhivery.delhivery_data;



/* =========================================================
   4. CATEGORICAL VALUE VALIDATION

   Purpose:
   Review unique categorical values and identify
   inconsistent labels, spelling differences, extra spaces,
   or unexpected categories.

   Example:
   FTL, ftl, FTL_ or FTL with trailing spaces should not
   represent separate business categories.
   ========================================================= */

SELECT DISTINCT route_type
FROM delhivery.delhivery_data;


SELECT DISTINCT data
FROM delhivery.delhivery_data;


SELECT DISTINCT is_cutoff
FROM delhivery.delhivery_data;



/* =========================================================
   5. INVALID VALUE & DATE LOGIC CHECK

   Purpose:
   Detect potentially invalid numerical values such as
   zero or negative travel times and distances.

   Also validate the chronological relationship between
   OD start and end timestamps.

   Important:
   A suspicious value is investigated before it is
   automatically removed or modified.
   ========================================================= */

SELECT

    SUM(
        CASE
            WHEN actual_time <= 0 THEN 1
            ELSE 0
        END
    ) AS Invalid_Actual_Time,

    SUM(
        CASE
            WHEN osrm_time <= 0 THEN 1
            ELSE 0
        END
    ) AS Invalid_OSRM_Time,

    SUM(
        CASE
            WHEN actual_distance_to_destination <= 0
                THEN 1
            ELSE 0
        END
    ) AS Invalid_Actual_Distance,

    SUM(
        CASE
            WHEN osrm_distance <= 0 THEN 1
            ELSE 0
        END
    ) AS Invalid_OSRM_Distance,

    SUM(
        CASE
            WHEN segment_actual_time < 0 THEN 1
            ELSE 0
        END
    ) AS Negative_Segment_Time,

    SUM(
        CASE
            WHEN segment_osrm_time < 0 THEN 1
            ELSE 0
        END
    ) AS Negative_Segment_OSRM_Time

FROM delhivery.delhivery_data;


-- Check invalid chronological records

SELECT *
FROM delhivery.delhivery_data
WHERE od_end_time < od_start_time;



/* =========================================================
   6. DUPLICATE RECORD CHECK

   Purpose:
   Detect true duplicate records across the complete
   business record.

   trip_uuid alone cannot be considered a duplicate key
   because one trip may legitimately contain multiple
   segment-level records.

   ROW_NUMBER() is used to identify repeated copies of
   otherwise identical records.
   ========================================================= */

WITH Duplicate_Check AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                data,
                trip_creation_time,
                route_schedule_uuid,
                route_type,
                trip_uuid,
                source_center,
                source_name,
                destination_center,
                destination_name,
                od_start_time,
                od_end_time,
                start_scan_to_end_scan,
                is_cutoff,
                cutoff_factor,
                cutoff_timestamp,
                actual_distance_to_destination,
                actual_time,
                osrm_time,
                osrm_distance,
                factor,
                segment_actual_time,
                segment_osrm_time,
                segment_osrm_distance,
                segment_factor

            ORDER BY trip_uuid

        ) AS rn

    FROM delhivery.delhivery_data
)

SELECT
    COUNT(*) AS Duplicate_Rows

FROM Duplicate_Check

WHERE rn > 1;



/* =========================================================
   7. CREATE CLEAN WORKING DATASET

   Purpose:
   Preserve the original raw dataset and perform all
   cleaning operations on a separate working table.

   Keeping raw data unchanged makes the cleaning process
   traceable and allows the original source to be recovered
   whenever validation is required.
   ========================================================= */

SELECT *
INTO delhivery.delhivery_data_clean
FROM delhivery.delhivery_data;



/* ---------------------------------------------------------
   Allow invalid segment time values to be stored as NULL.

   NULL is preferred over inventing or guessing a corrected
   duration when the true value cannot be determined.
   --------------------------------------------------------- */

ALTER TABLE delhivery.delhivery_data_clean
ALTER COLUMN segment_actual_time FLOAT NULL;


UPDATE delhivery.delhivery_data_clean

SET segment_actual_time = NULL

WHERE segment_actual_time < 0;



/* ---------------------------------------------------------
   Standardize important text fields.

   TRIM removes unnecessary leading and trailing spaces
   that could create duplicate categorical values.
   --------------------------------------------------------- */

UPDATE delhivery.delhivery_data_clean

SET
    source_name = TRIM(source_name),
    destination_name = TRIM(destination_name),
    route_type = TRIM(route_type),
    data = TRIM(data);



/* =========================================================
   8. DEFINE DATA GRAIN

   Purpose:
   Understand what each row represents before analysis.

   The raw dataset contains multiple records associated
   with trips and Origin-Destination movements.

   This step compares:
   - Raw records
   - Unique trips
   - Unique Origin-Destination pairs

   Defining the correct grain prevents incorrect counting
   and aggregation in downstream BI reports.
   ========================================================= */

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT trip_uuid) AS Total_Trips

FROM delhivery.delhivery_data_clean;



SELECT
    COUNT(*) AS Total_OD_Pairs

FROM
(
    SELECT
        trip_uuid,
        source_name,
        destination_name,
        od_start_time,
        od_end_time

    FROM delhivery.delhivery_data_clean

    GROUP BY
        trip_uuid,
        source_name,
        destination_name,
        od_start_time,
        od_end_time

) AS OD_Grain;



/* =========================================================
   9. CREATE OD-LEVEL ANALYTICAL DATASET

   Purpose:
   Transform multiple cumulative/segment records into
   one analytical record per Origin-Destination movement.

   ROW_NUMBER() identifies the final record associated
   with each OD movement.

   Important:
   Actual time, OSRM time, and distance values are taken
   from the SAME final record.

   Independent MAX() calculations are avoided because
   maximum values from different columns may originate
   from different records and create inconsistent results.
   ========================================================= */

;WITH Ranked_OD AS
(
    SELECT
        trip_uuid,
        route_type,

        source_center,
        source_name,

        destination_center,
        destination_name,

        od_start_time,
        od_end_time,

        actual_time,
        osrm_time,

        actual_distance_to_destination,
        osrm_distance,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                trip_uuid,
                source_name,
                destination_name,
                od_start_time,
                od_end_time

            ORDER BY actual_time DESC

        ) AS rn

    FROM delhivery.delhivery_data_clean
)

SELECT
    trip_uuid,
    route_type,

    source_center,
    source_name,

    destination_center,
    destination_name,

    od_start_time,
    od_end_time,

    actual_time
        AS final_actual_time,

    osrm_time
        AS final_osrm_time,

    actual_distance_to_destination
        AS final_actual_distance,

    osrm_distance
        AS final_osrm_distance

INTO delhivery.delhivery_od_clean

FROM Ranked_OD

WHERE rn = 1;



/* =========================================================
   10. FEATURE ENGINEERING

   Purpose:
   Create analytical features required by the BI layer.

   These columns support:
   - Travel duration analysis
   - Delay analysis
   - Delay segmentation
   - Daily analysis
   - Monthly analysis
   - Day-of-week analysis
   - Hourly analysis

   The objective is to prepare reusable row-level features,
   while KPI calculations and visual analysis remain in
   the BI/reporting layer.
   ========================================================= */

ALTER TABLE delhivery.delhivery_od_clean

ADD
    od_duration_minutes INT NULL,

    delay_minutes FLOAT NULL,
    delay_percentage FLOAT NULL,
    delay_category VARCHAR(30) NULL,

    od_date DATE NULL,
    od_year INT NULL,
    od_month INT NULL,
    od_day INT NULL,
    od_day_name VARCHAR(20) NULL,
    od_hour INT NULL;



UPDATE delhivery.delhivery_od_clean

SET

    od_duration_minutes =
        DATEDIFF(
            MINUTE,
            od_start_time,
            od_end_time
        ),

    delay_minutes =
        final_actual_time - final_osrm_time,

    delay_percentage =
        (
            (final_actual_time - final_osrm_time)
            * 100.0
        )
        / NULLIF(final_osrm_time, 0),

    delay_category =
        CASE

            WHEN final_actual_time - final_osrm_time <= 0
                THEN 'No Delay'

            WHEN final_actual_time - final_osrm_time <= 30
                THEN '1-30 Min'

            WHEN final_actual_time - final_osrm_time <= 60
                THEN '31-60 Min'

            WHEN final_actual_time - final_osrm_time <= 120
                THEN '1-2 Hours'

            WHEN final_actual_time - final_osrm_time <= 360
                THEN '2-6 Hours'

            WHEN final_actual_time - final_osrm_time <= 720
                THEN '6-12 Hours'

            ELSE 'More Than 12 Hours'

        END,

    od_date =
        CAST(od_start_time AS DATE),

    od_year =
        YEAR(od_start_time),

    od_month =
        MONTH(od_start_time),

    od_day =
        DAY(od_start_time),

    od_day_name =
        DATENAME(WEEKDAY, od_start_time),

    od_hour =
        DATEPART(HOUR, od_start_time);



/* =========================================================
   11. GEOGRAPHIC ENRICHMENT

   Purpose:
   Add state-level geographic attributes to support
   geographic analysis and map visualizations in BI tools.

   A separate mapping table is used instead of manually
   embedding geographic logic into the main dataset.

   This creates:
   - source_state
   - destination_state

   These fields can later support maps such as:
   - OD volume by source state
   - OD volume by destination state
   - Average delay by state
   ========================================================= */


/* ---------------------------------------------------------
   Create Center-to-State mapping table.

   Note:
   The complete mapping should be populated and validated
   against the actual centers in the dataset.
   --------------------------------------------------------- */

CREATE TABLE delhivery.center_state_map
(
    center_name VARCHAR(255) PRIMARY KEY,
    state_name VARCHAR(100)
);



/* ---------------------------------------------------------
   Example mapping records.

   Additional centers should be added after geographic
   validation.
   --------------------------------------------------------- */

INSERT INTO delhivery.center_state_map
(
    center_name,
    state_name
)

VALUES
    ('Bangalore_Nelmngla_H', 'Karnataka'),
    ('Gurgaon_Bilaspur_HB', 'Haryana');



/* ---------------------------------------------------------
   Add state attributes to analytical table.
   --------------------------------------------------------- */

ALTER TABLE delhivery.delhivery_od_clean

ADD
    source_state VARCHAR(100) NULL,
    destination_state VARCHAR(100) NULL;



/* ---------------------------------------------------------
   Map source and destination centers to their states.
   --------------------------------------------------------- */

UPDATE od

SET
    source_state = src.state_name,
    destination_state = dst.state_name

FROM delhivery.delhivery_od_clean AS od

LEFT JOIN delhivery.center_state_map AS src
    ON od.source_name = src.center_name

LEFT JOIN delhivery.center_state_map AS dst
    ON od.destination_name = dst.center_name;



/* =========================================================
   12. FINAL VALIDATION & BI-READY VIEW

   Purpose:
   Perform final quality checks after all transformations.

   The final dataset is validated for:
   - Missing critical values
   - Duplicate OD records
   - Transformation completeness

   A final SQL View is then created as the reporting layer
   consumed by Power BI, Looker Studio, Excel, or other
   analytical tools.

   KPI calculations and business analysis are intentionally
   performed in the BI layer rather than in this SQL
   preparation workflow.
   ========================================================= */


/* ---------------------------------------------------------
   Final NULL validation
   --------------------------------------------------------- */

SELECT
    COUNT(*) AS Total_Rows,

    SUM(
        CASE
            WHEN trip_uuid IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_Trip,

    SUM(
        CASE
            WHEN source_name IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_Source,

    SUM(
        CASE
            WHEN destination_name IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_Destination,

    SUM(
        CASE
            WHEN final_actual_time IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_Actual_Time,

    SUM(
        CASE
            WHEN final_osrm_time IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_OSRM_Time,

    SUM(
        CASE
            WHEN delay_minutes IS NULL THEN 1
            ELSE 0
        END
    ) AS Null_Delay,

    SUM(
        CASE
            WHEN source_state IS NULL THEN 1
            ELSE 0
        END
    ) AS Unmapped_Source_State,

    SUM(
        CASE
            WHEN destination_state IS NULL THEN 1
            ELSE 0
        END
    ) AS Unmapped_Destination_State

FROM delhivery.delhivery_od_clean;



/* ---------------------------------------------------------
   Final OD duplicate validation

   Expected result:
   No records should be returned.
   --------------------------------------------------------- */

SELECT
    trip_uuid,
    source_name,
    destination_name,
    od_start_time,
    od_end_time,

    COUNT(*) AS Duplicate_Count

FROM delhivery.delhivery_od_clean

GROUP BY
    trip_uuid,
    source_name,
    destination_name,
    od_start_time,
    od_end_time

HAVING COUNT(*) > 1;



/* ---------------------------------------------------------
   Create final BI-ready View
   --------------------------------------------------------- */

CREATE VIEW delhivery.vw_delivery_analysis
AS

SELECT
    trip_uuid,
    route_type,

    source_center,
    source_name,
    source_state,

    destination_center,
    destination_name,
    destination_state,

    od_start_time,
    od_end_time,
    od_duration_minutes,

    final_actual_time,
    final_osrm_time,

    final_actual_distance,
    final_osrm_distance,

    delay_minutes,
    delay_percentage,
    delay_category,

    od_date,
    od_year,
    od_month,
    od_day,
    od_day_name,
    od_hour

FROM delhivery.delhivery_od_clean;
