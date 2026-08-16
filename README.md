# 🚚 Delhivery Logistics: Performance & Delay Analysis

## 📋 Project Overview
This project focuses on analyzing the operational efficiency of **Delhivery**, a major logistics and supply chain provider. The primary objective is to process raw, complex logistics data, track Origin-Destination (OD) movements accurately, and build an interactive dashboard to monitor delivery performance, route efficiency, and operational bottlenecks.

## 🛠️ Tech Stack
* **Data Processing & Cleaning:** SQL Server (T-SQL)
* **Data Visualization:** Looker Studio
* **Core Skills Applied:** Data Profiling, Feature Engineering, Window Functions, Dimensional Modeling, and Data Storytelling.

## 📊 Interactive Dashboard
*(Click the image below to view the interactive Looker Studio report)*

[![Delhivery Dashboard](https://github.com/magedbinlaswad/delhivery-logistics-data-analysis/blob/504b40dd35e7e502d02b4aafc16aec2e780e446e/Looker-Studio/delhivery-logistics-dashboard.png)

## ⚙️ Data Pipeline & SQL Workflow
The raw dataset contained multiple segment-level records with inconsistencies, missing values, and duplicates. A robust SQL pipeline was built to transform this raw data into a clean, BI-ready dataset:

1. **Data Profiling & Quality Checks:** Handled missing values, flagged negative time durations, and identified true duplicates using window functions (`ROW_NUMBER()`).
2. **Grain Definition (OD-Level):** Grouped and transformed granular segment records into a single analytical record per Origin-Destination movement to prevent data duplication in BI tools.
3. **Feature Engineering:** Calculated precise delay durations, created delay segmentation categories (e.g., *1-30 Min*, *1-2 Hours*, *More Than 12 Hours*), and extracted time-series dimensions for trend analysis.
4. **Geographic Enrichment:** Mapped source and destination centers to their respective states to enable regional performance tracking.

## 💡 Key Business Insights
The final Looker Studio dashboard provides stakeholders with immediate visibility into:
* **Delivery Status Overview:** A clear ratio of *Delayed*, *On-Time*, and *Early* deliveries.
* **Delay Distribution:** A granular breakdown of delay severities to help operations teams prioritize interventions.
* **Route Type Efficiency:** Volume comparison between Full Truck Load (FTL) and Carting operations.
* **Geographic Bottlenecks:** Identification of the Top 10 states experiencing the highest average delivery delays.

## 📁 Repository Structure
* `sql_workflow.sql`: The complete T-SQL script containing the data cleaning, validation, and transformation logic.
* `delhivery-logistics-dashboard.png`: High-resolution screenshot of the final BI dashboard.
* `README.md`: Project documentation.
