-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab 02: the SQL you know, then much bigger data
-- MAGIC
-- MAGIC Attach to the **Serverless Starter Warehouse**. Run the catch-up cell first if you skipped lab 01.
-- MAGIC The part 1 numbers are for the September 30 snapshot. If you already ran lab 03, yours include October and November.

-- COMMAND ----------

-- Catch-up: builds the permits table from the volume if it is missing or empty. Safe to run any time.
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS data604;
USE SCHEMA data604;
CREATE TABLE IF NOT EXISTS permits (
  permit_num STRING NOT NULL, status STRING, applied_date DATE, issued_date DATE, completed_date DATE,
  permit_type STRING, permit_class STRING, work_class STRING, housing_units INT,
  est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING
);
INSERT INTO permits
SELECT permit_num, status, applied_date, issued_date, completed_date, permit_type, permit_class, work_class, housing_units, est_project_cost, total_sqft, community_code, community_name
FROM read_files(
  '/Volumes/workspace/data604/raw/permits_snapshot.csv',
  format => 'csv', header => true, escape => '"', mode => 'FAILFAST',
  schema => 'permit_num STRING, status STRING, applied_date DATE, issued_date DATE, completed_date DATE, permit_type STRING, permit_class STRING, work_class STRING, housing_units INT, est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING')
WHERE (SELECT count(*) FROM permits) = 0;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Part 1: Calgary permits
-- MAGIC
-- MAGIC **Where are the new homes?** Housing units on new-construction permits issued in 2026 (up to September 30).

-- COMMAND ----------

SELECT community_name, sum(housing_units) AS new_units, count(*) AS permits
FROM permits
WHERE work_class = 'New' AND issued_date >= DATE'2026-01-01'
GROUP BY ALL
ORDER BY new_units DESC
LIMIT 10

-- COMMAND ----------

-- Applications per month. Use the chart option on the result (Visualization) to draw it as a line chart.
SELECT date_trunc('MONTH', applied_date) AS month, count(*) AS applications
FROM permits
GROUP BY ALL
ORDER BY month

-- COMMAND ----------

-- How long from application to permit? median() is built in.
SELECT permit_type,
       count(*) AS issued,
       median(datediff(issued_date, applied_date)) AS median_days
FROM permits
WHERE issued_date IS NOT NULL
GROUP BY ALL
ORDER BY issued DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Top 3 per group.** MySQL 8 has window functions but no `QUALIFY`, so you would wrap this in a subquery.
-- MAGIC `QUALIFY` filters on a window function directly.

-- COMMAND ----------

SELECT permit_class, permit_num, community_name, work_class, est_project_cost
FROM permits
WHERE est_project_cost IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY permit_class ORDER BY est_project_cost DESC) <= 3
ORDER BY permit_class, est_project_cost DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Your turn:** which 5 communities had the most demolition permits applied for in 2025?
-- MAGIC (`work_class = 'Demolition'`). Write your query in the cell below. The answer is in `solutions/solutions`.

-- COMMAND ----------

-- Replace the line below with your query.
SELECT 'your query here' AS your_turn


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Part 2: same SQL, bigger data
-- MAGIC
-- MAGIC `samples.tpch` is the TPC-H benchmark: an order-processing schema in third normal form.
-- MAGIC `region` has `nation`, `nation` has `customer`, `customer` has `orders`, and each order has many `lineitem` rows.
-- MAGIC
-- MAGIC How big is `lineitem`?

-- COMMAND ----------

DESCRIBE DETAIL samples.tpch.lineitem

-- COMMAND ----------

SELECT count(*) AS lineitem_rows FROM samples.tpch.lineitem

-- COMMAND ----------

-- Revenue by region and year: a five-table join over every line item.
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
-- MAGIC This is the SQL you would write in MySQL. The difference is underneath: the warehouse split the scan
-- MAGIC into many tasks that ran in parallel, then shuffled rows so each task could add up its share of the groups.
-- MAGIC That is MapReduce's idea, done by a query engine. Your instructor will open the Query Profile for this query.

-- COMMAND ----------

-- Optional: the plan for the same join. Look for ShuffleExchange (the shuffle), GroupingAgg twice (partial, then final)
-- and BroadcastHashJoin (the small tables are copied to every task). Names may start with Photon.
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
-- MAGIC Next: **03_delta_merge_history**.

-- COMMAND ----------

-- Check: TPC-H is reachable and big.
SELECT assert_true(count(*) = 29999795, 'samples.tpch.lineitem should have 29,999,795 rows') AS tpch_ok
FROM samples.tpch.lineitem
