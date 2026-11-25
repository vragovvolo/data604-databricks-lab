-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor demo: how a distributed query runs, and how to make it read less
-- MAGIC
-- MAGIC Needs `prep_day_before` to have run in this account. Attach to the SQL warehouse.

-- COMMAND ----------

USE CATALOG workspace;
-- Turn off the result cache so every run really reads data. Compare files and bytes read, not seconds.
SET use_cached_result = false;

-- COMMAND ----------

-- Before class: the plain copy must be untouched since prep_day_before built it.
-- If this says STOP, something rewrote the plain copy (clustering or compaction). Run prep_day_before again, then come back.
SELECT if(max_by(operation, version) LIKE 'CREATE%',
          'OK: the plain copy is untouched',
          'STOP: the plain copy was changed after the build. Run prep_day_before again') AS check_before_class
FROM (DESCRIBE HISTORY perf.lineitem_plain)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. The plan for the lab 02 join
-- MAGIC
-- MAGIC Look for: the scans, **ShuffleExchange** (the shuffle, MapReduce's middle step), **GroupingAgg** twice (partial
-- MAGIC then final: combine, then reduce), and **BroadcastHashJoin** for the small tables (nation, region).
-- MAGIC With Photon the names start with `Photon`, for example `PhotonGroupingAgg`.

-- COMMAND ----------

EXPLAIN FORMATTED
SELECT r.r_name AS region, year(o.o_orderdate) AS order_year,
       sum(l.l_extendedprice * (1 - l.l_discount)) AS revenue
FROM samples.tpch.lineitem AS l
JOIN samples.tpch.orders   AS o ON l.l_orderkey = o.o_orderkey
JOIN samples.tpch.customer AS c ON o.o_custkey = c.c_custkey
JOIN samples.tpch.nation   AS n ON c.c_nationkey = n.n_nationkey
JOIN samples.tpch.region   AS r ON n.n_regionkey = r.r_regionkey
GROUP BY ALL

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Now run the same join for real. Open "See performance" under the result for the Query Profile: tasks, rows and bytes per step.

-- COMMAND ----------

SELECT r.r_name AS region,
       year(o.o_orderdate) AS order_year,
       round(sum(l.l_extendedprice * (1 - l.l_discount)) / 1e6, 1) AS revenue_millions
FROM samples.tpch.lineitem AS l
JOIN samples.tpch.orders   AS o ON l.l_orderkey = o.o_orderkey
JOIN samples.tpch.customer AS c ON o.o_custkey = c.c_custkey
JOIN samples.tpch.nation   AS n ON c.c_nationkey = n.n_nationkey
JOIN samples.tpch.region   AS r ON n.n_regionkey = r.r_regionkey
GROUP BY ALL
ORDER BY region, order_year

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. No B-tree indexes: skip files instead
-- MAGIC
-- MAGIC MySQL finds one day's rows with a B-tree index. For every file, Delta keeps the min and max values
-- MAGIC of the table's first 32 columns (the default).
-- MAGIC If a file's range can't contain the value, the file is skipped. Clustering puts similar values in the same
-- MAGIC files, so the ranges are narrow and most files get skipped.

-- COMMAND ----------

DESCRIBE DETAIL perf.lineitem_plain

-- COMMAND ----------

DESCRIBE DETAIL perf.lineitem_by_shipdate

-- COMMAND ----------

-- Same query, unclustered copy. Open "See performance" (Query Profile) and note files read and pruned.
SELECT count(*) AS lines, round(sum(l_extendedprice), 2) AS revenue
FROM perf.lineitem_plain
WHERE l_shipdate = DATE'1995-06-17'

-- COMMAND ----------

-- Same query, clustered by l_shipdate. Same answer, far fewer files read.
SELECT count(*) AS lines, round(sum(l_extendedprice), 2) AS revenue
FROM perf.lineitem_by_shipdate
WHERE l_shipdate = DATE'1995-06-17'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Talking points: the answer is identical. The clustered table reads a handful of files instead of all of them.
-- MAGIC You choose clustering keys from the filters people actually use, the same way you choose index columns in MySQL.
