-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab 00: start here
-- MAGIC
-- MAGIC **Attach this notebook to the SQL warehouse** (top right: *Connect*, then *Serverless Starter Warehouse*).
-- MAGIC Every lab notebook runs on that warehouse, and so does the Genie chatbot you build at the end.
-- MAGIC
-- MAGIC Run a cell with **Shift + Enter**. Run the first cell now. The warehouse takes about a minute to start. If the cell says the warehouse is starting, wait and run the cell again.
-- MAGIC
-- MAGIC Free Edition has a daily compute limit. If a cell says the limit is reached, compute stays off for the rest of today. Tell a helper and do not keep re-running cells.

-- COMMAND ----------

SELECT 'hello, DATA 604' AS greeting

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Where am I?
-- MAGIC
-- MAGIC In MySQL a table lives in a database (MySQL treats DATABASE and SCHEMA as the same thing): `database.table`.
-- MAGIC Databricks adds one level on top, the **catalog**: `catalog.schema.table`.
-- MAGIC Unity Catalog governs all three levels, plus files (volumes), models and functions.

-- COMMAND ----------

SELECT current_catalog() AS my_catalog, current_schema() AS my_schema, current_user() AS me

-- COMMAND ----------

SHOW CATALOGS

-- COMMAND ----------

-- The built-in sample data lives in its own catalog. You will query samples.tpch in lab 02.
SHOW SCHEMAS IN samples

-- COMMAND ----------

SHOW TABLES IN samples.tpch

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create your lab schema and a volume for the CSV files
-- MAGIC
-- MAGIC A **volume** is a governed folder for files. Tables hold rows, volumes hold files.

-- COMMAND ----------

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS data604 COMMENT 'DATA 604 lab: City of Calgary building permits';
CREATE VOLUME IF NOT EXISTS data604.raw COMMENT 'Raw CSV files for the DATA 604 lab';
USE SCHEMA data604;

-- COMMAND ----------

-- Check: the schema and the volume exist (this cell errors if something is missing). A pass shows NULL in the result. A failure stops here with a message that says what to run.
SELECT
  assert_true((SELECT count(*) FROM information_schema.schemata WHERE schema_name = 'data604') = 1, 'schema data604 is missing: run the cell above, then this one'),
  assert_true((SELECT count(*) FROM information_schema.volumes WHERE volume_schema = 'data604' AND volume_name = 'raw') = 1, 'volume data604.raw is missing: run the cell above, then this one')

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Next
-- MAGIC
-- MAGIC Upload `permits_snapshot.csv` and `permits_updates.csv` into the volume:
-- MAGIC **Catalog** (left bar), then **workspace**, **data604**, **raw**, then **Upload to this volume**. Select both files at once (hold Cmd or Ctrl to pick the second). If raw does not show, refresh the page.
-- MAGIC
-- MAGIC Both options do this upload step. No CSV files on your laptop? Download them from the `data` folder of the GitHub repo.
-- MAGIC
-- MAGIC Option A (Git folder): if the upload fails, run `setup/fallback_load` on Serverless compute (not the SQL warehouse). It copies the same two files from the `data` folder of this Git folder.
-- MAGIC
-- MAGIC Option B (notebooks imported one at a time): use the upload. `setup/fallback_load` cannot find the data folder in that setup.
-- MAGIC
-- MAGIC Then open **01_load_and_explore**.
