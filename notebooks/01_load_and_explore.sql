-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab 01: load a dataset
-- MAGIC
-- MAGIC The data: City of Calgary building permits applied for from January 2025 to September 2026,
-- MAGIC rebuilt as of **September 30, 2026** from the permit dates (see `data/README.md`). In lab 03 you will apply the changes since then.
-- MAGIC
-- MAGIC *Contains information licensed under the Open Government Licence – City of Calgary.*
-- MAGIC
-- MAGIC Attach to the **Serverless Starter Warehouse** and run the cells in order.

-- COMMAND ----------

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS data604;      -- in case you skipped lab 00
CREATE VOLUME IF NOT EXISTS data604.raw;
USE SCHEMA data604;

-- COMMAND ----------

-- The files you uploaded into the volume. Both CSVs should be listed.
LIST '/Volumes/workspace/data604/raw/'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Look at the file before loading it
-- MAGIC
-- MAGIC `read_files` reads files straight from the volume and guesses the column types.

-- COMMAND ----------

SELECT *
FROM read_files('/Volumes/workspace/data604/raw/permits_snapshot.csv', format => 'csv', header => true, escape => '"')
LIMIT 10

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create the table, then load it
-- MAGIC
-- MAGIC In MySQL you would write `CREATE TABLE` and then `LOAD DATA INFILE`. Here it is `CREATE TABLE`
-- MAGIC and `INSERT OVERWRITE ... SELECT FROM read_files(...)`. We pin the column types so nothing is left to guessing.
-- MAGIC `OVERWRITE` replaces the rows instead of adding to them, so running the cell twice is safe.
-- MAGIC
-- MAGIC Tables you create here are **Delta tables** by default: Parquet files plus a transaction log. More on that in lab 03.

-- COMMAND ----------

CREATE OR REPLACE TABLE permits (
  permit_num       STRING NOT NULL,
  status           STRING,
  applied_date     DATE,
  issued_date      DATE,
  completed_date   DATE,
  permit_type      STRING,
  permit_class     STRING,
  work_class       STRING,
  housing_units    INT,
  est_project_cost DECIMAL(14,2),
  total_sqft       DECIMAL(12,2),
  community_code   STRING,
  community_name   STRING
);

-- COMMAND ----------

INSERT OVERWRITE permits
SELECT permit_num, status, applied_date, issued_date, completed_date, permit_type, permit_class, work_class, housing_units, est_project_cost, total_sqft, community_code, community_name
FROM read_files(
  '/Volumes/workspace/data604/raw/permits_snapshot.csv',
  format => 'csv', header => true, escape => '"', mode => 'FAILFAST',
  schema => 'permit_num STRING, status STRING, applied_date DATE, issued_date DATE, completed_date DATE, permit_type STRING, permit_class STRING, work_class STRING, housing_units INT, est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING'
);

-- COMMAND ----------

-- Check: every row arrived.
SELECT assert_true(count(*) = 42925, 'expected 42,925 permits: re-run the CREATE and INSERT cells') AS loaded_ok,
       count(*) AS permits
FROM permits

-- COMMAND ----------

DESCRIBE TABLE permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## First look
-- MAGIC
-- MAGIC `GROUP BY ALL` groups by every column that is not an aggregate, so you don't repeat the column list.

-- COMMAND ----------

SELECT status, count(*) AS permits
FROM permits
GROUP BY ALL
ORDER BY permits DESC

-- COMMAND ----------

SELECT permit_type, work_class,
       count(*) AS permits,
       count(est_project_cost) AS with_cost,
       round(avg(est_project_cost)) AS avg_cost
FROM permits
GROUP BY ALL
ORDER BY permits DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Try it:** open **Catalog** in the left bar, then **workspace**, **data604**, **permits**.
-- MAGIC Look at *Sample Data*, *Details* and *History*. You will come back to *History* in lab 03.
-- MAGIC
-- MAGIC Next: **02_sql_at_scale**.
