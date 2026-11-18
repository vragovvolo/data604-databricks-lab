-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab 03: Delta tables, MERGE and time travel
-- MAGIC
-- MAGIC Since September 30 the city issued and completed thousands of permits, and new applications came in.
-- MAGIC The city's permit system would send those changes as a file of **change events**.
-- MAGIC You will apply them with one `MERGE`, then look back in time.
-- MAGIC
-- MAGIC Attach to the **Serverless Starter Warehouse**.

-- COMMAND ----------

-- Start from a clean copy so the version numbers below match yours (also works as a catch-up).
-- Careful: this drops permits. If you already did lab 04, run lab 04 again from the top afterwards.
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS data604;
USE SCHEMA data604;
DROP TABLE IF EXISTS permits;
CREATE TABLE permits (
  permit_num STRING NOT NULL, status STRING, applied_date DATE, issued_date DATE, completed_date DATE,
  permit_type STRING, permit_class STRING, work_class STRING, housing_units INT,
  est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING
);
INSERT INTO permits
SELECT permit_num, status, applied_date, issued_date, completed_date, permit_type, permit_class, work_class, housing_units, est_project_cost, total_sqft, community_code, community_name
FROM read_files(
  '/Volumes/workspace/data604/raw/permits_snapshot.csv',
  format => 'csv', header => true, escape => '"', mode => 'FAILFAST',
  schema => 'permit_num STRING, status STRING, applied_date DATE, issued_date DATE, completed_date DATE, permit_type STRING, permit_class STRING, work_class STRING, housing_units INT, est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## A Delta table is Parquet files plus a transaction log
-- MAGIC
-- MAGIC Every statement that changes the table is one atomic commit to the log, and gets a new **version** number.
-- MAGIC MySQL keeps a redo log and a binlog next to the table. In Delta, the log *is* the table's source of truth,
-- MAGIC which is why you can read old versions.

-- COMMAND ----------

DESCRIBE HISTORY permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Load the change events

-- COMMAND ----------

CREATE OR REPLACE TABLE permit_updates AS
SELECT permit_num, status, applied_date, issued_date, completed_date, permit_type, permit_class, work_class, housing_units, est_project_cost, total_sqft, community_code, community_name, status_changed_on, event_seq
FROM read_files(
  '/Volumes/workspace/data604/raw/permits_updates.csv',
  format => 'csv', header => true, escape => '"', mode => 'FAILFAST',
  schema => 'permit_num STRING, status STRING, applied_date DATE, issued_date DATE, completed_date DATE, permit_type STRING, permit_class STRING, work_class STRING, housing_units INT, est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING, status_changed_on DATE, event_seq INT');

SELECT assert_true(count(*) = 8534, 'expected 8,534 change events: check that permits_updates.csv is in the volume') AS events_ok, count(*) AS events
FROM permit_updates;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Good data handling: check the key before you merge
-- MAGIC
-- MAGIC A permit can change more than once in the window: a new application that is then issued, or a permit that is
-- MAGIC issued and then completed. If the source has two rows for one key,
-- MAGIC `MERGE` cannot know which one wins, and it stops with an error.
-- MAGIC Primary keys on Databricks are **informational**: nothing stops duplicates from arriving, so you check.

-- COMMAND ----------

SELECT permit_num, count(*) AS events, collect_list(status) AS statuses
FROM permit_updates
GROUP BY ALL
HAVING count(*) > 1
ORDER BY events DESC, permit_num
LIMIT 20

-- COMMAND ----------

SELECT assert_true(count(*) = 1195, 'expected 1,195 permits with more than one event: run lab 03 from the top') AS duplicates_found, count(*) AS permits_with_many_events
FROM (SELECT permit_num FROM permit_updates GROUP BY ALL HAVING count(*) > 1)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Optional:** remove the `--` in front of the next three lines and run it to see the error.
-- MAGIC Then put the `--` back.

-- COMMAND ----------

-- MERGE INTO permits AS t USING permit_updates AS s ON t.permit_num = s.permit_num
-- WHEN MATCHED THEN UPDATE SET *
-- WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

-- Keep only the latest event per permit. event_seq breaks ties when two events share a date.
-- A view is a saved query, kept in your schema. The MERGE below reads from it.
CREATE OR REPLACE VIEW latest_updates AS
SELECT * EXCEPT (status_changed_on, event_seq)
FROM permit_updates
QUALIFY row_number() OVER (PARTITION BY permit_num ORDER BY status_changed_on DESC, event_seq DESC) = 1;

SELECT assert_true(count(*) = 7263, 'expected 7,263 permits after the dedupe: run lab 03 from the top') AS dedupe_ok, count(*) AS permits
FROM latest_updates;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## MERGE: update the permits that changed, insert the new ones
-- MAGIC
-- MAGIC MySQL has `INSERT ... ON DUPLICATE KEY UPDATE`. `MERGE` is the SQL-standard version, and it can also delete.
-- MAGIC Expect 4,512 updated rows and 2,751 inserted rows in the result. If you run it a second time, it reports
-- MAGIC 7,263 updated and 0 inserted and adds a version. That is fine, and the checks below still pass.

-- COMMAND ----------

MERGE INTO permits AS t
USING latest_updates AS s
ON t.permit_num = s.permit_num
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *

-- COMMAND ----------

SELECT assert_true(count(*) = 45676, 'expected 45,676 permits after the merge: run lab 03 from the top') AS merge_ok, count(*) AS permits
FROM permits

-- COMMAND ----------

DESCRIBE HISTORY permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Time travel: what changed since September 30?
-- MAGIC
-- MAGIC Version 1 is the table right after the first load. Join today's table to version 1 of itself to see which permits
-- MAGIC were issued or closed since September 30. (Statuses without a date, like Hold, are not in the change file.)

-- COMMAND ----------

SELECT sep30.status AS status_on_sep_30, cur.status AS status_now, count(*) AS permits
FROM permits VERSION AS OF 1 AS sep30
JOIN permits AS cur USING (permit_num)
WHERE sep30.status <> cur.status
GROUP BY ALL
ORDER BY permits DESC

-- COMMAND ----------

SELECT assert_true(count(*) = 4505, 'expected 4,505 permits issued or closed since September 30: run lab 03 from the top') AS time_travel_ok, count(*) AS changed
FROM permits VERSION AS OF 1 AS sep30
JOIN permits AS cur USING (permit_num)
WHERE sep30.status <> cur.status

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Oops: an UPDATE without a WHERE clause
-- MAGIC
-- MAGIC Everyone does this once. In MySQL you would reach for last night's backup. Here, run it on purpose,
-- MAGIC then run the `RESTORE` cell right after it, even if you are short on time. Lab 04 needs the restored table.

-- COMMAND ----------

UPDATE permits SET status = 'Completed';

SELECT status, count(*) AS permits FROM permits GROUP BY ALL;

-- COMMAND ----------

-- Put the table back the way it was right after the MERGE (version 2).
RESTORE TABLE permits TO VERSION AS OF 2;

SELECT status, count(*) AS permits FROM permits GROUP BY ALL ORDER BY permits DESC;

-- COMMAND ----------

SELECT assert_true(count_if(status = 'Completed') = 27375, 'expected 27,375 completed permits after the restore: run lab 03 from the top') AS restore_ok
FROM permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC `RESTORE` does not erase history. It writes a **new** version that matches version 2, so the mistake stays
-- MAGIC in the history for anyone to audit. Check the last rows:

-- COMMAND ----------

DESCRIBE HISTORY permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Why this matters for machine learning
-- MAGIC
-- MAGIC Train a model on `permits VERSION AS OF 2` and record that version next to the model. Anyone can then rebuild
-- MAGIC the same training set, as long as that version is still kept. Old versions don't last forever: by default
-- MAGIC `VACUUM` can delete their files after 7 days, and Databricks may run `VACUUM` for you on managed tables.
-- MAGIC To retrain on the same rows next year, save the training set as its own table, for example with
-- MAGIC `CREATE TABLE permits_training DEEP CLONE permits VERSION AS OF 2`.
-- MAGIC
-- MAGIC Two writers at the same time? Delta uses **optimistic concurrency**: writers don't take row locks like InnoDB.
-- MAGIC Each writer prepares its files and tries to commit the next version, and Delta checks the commit for conflicts.
-- MAGIC If two commits change the same rows, one of them fails with an error and has to be retried.
-- MAGIC
-- MAGIC Next: **04_genie_chatbot**.
