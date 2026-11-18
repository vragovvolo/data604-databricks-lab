-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor: prebuild the day before (Nov 24), once per instructor account
-- MAGIC
-- MAGIC Builds two copies of TPC-H `lineitem` for the "no indexes, skip files" demo, so nothing heavy runs live.
-- MAGIC Both copies have about 32 files, so the comparison is fair: the plain copy is spread randomly, the other is
-- MAGIC clustered by ship date. Then pruning is easy to see in the Query Profile.
-- MAGIC Attach to the SQL warehouse. Expect a few minutes.

-- COMMAND ----------

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS perf COMMENT 'Instructor-only tables for the performance demo';

-- COMMAND ----------

-- REPARTITION(32) writes 32 files with rows spread at random, so every file covers every ship date.
CREATE OR REPLACE TABLE perf.lineitem_plain
AS SELECT /*+ REPARTITION(32) */ * FROM samples.tpch.lineitem;

-- COMMAND ----------

CREATE OR REPLACE TABLE perf.lineitem_by_shipdate
CLUSTER BY (l_shipdate)
TBLPROPERTIES ('delta.targetFileSize' = '32mb')
AS SELECT * FROM samples.tpch.lineitem;

OPTIMIZE perf.lineitem_by_shipdate;

-- COMMAND ----------

-- Both tables should have the same row count and many files. Only the second one lists clusteringColumns.
DESCRIBE DETAIL perf.lineitem_plain;

-- COMMAND ----------

DESCRIBE DETAIL perf.lineitem_by_shipdate;

-- COMMAND ----------

SELECT
  assert_true((SELECT count(*) FROM perf.lineitem_plain) = (SELECT count(*) FROM samples.tpch.lineitem), 'plain copy row count') AS plain_ok,
  assert_true((SELECT count(*) FROM perf.lineitem_by_shipdate) = (SELECT count(*) FROM samples.tpch.lineitem), 'clustered copy row count') AS clustered_ok

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Then run `10_performance_demo` once end to end and note the files read on each table for the speaker notes.
-- MAGIC Also run labs 00 to 04 once in this account so a finished copy exists as a fallback, then run `reset_between_sessions`.
