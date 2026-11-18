-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor: reset between the 9:00 and 17:00 sessions
-- MAGIC
-- MAGIC Drops the lab tables so the next session starts clean. Keeps the volume with the uploaded CSVs and `perf`
-- MAGIC (the prebuilt demo tables). Not needed if you use a separate instructor account per session.
-- MAGIC Then, in the UI: delete this session's Genie Agent, clear notebook outputs (**Edit**, **Clear all outputs**),
-- MAGIC and sign the second user out. At 16:45 run `SELECT 1` to wake the warehouse.

-- COMMAND ----------

USE CATALOG workspace;
DROP VIEW IF EXISTS data604.latest_updates;
DROP TABLE IF EXISTS data604.permits;
DROP TABLE IF EXISTS data604.permit_updates;
DROP TABLE IF EXISTS data604.communities;
DROP FUNCTION IF EXISTS data604.mask_cost;

-- COMMAND ----------

SHOW TABLES IN data604

-- COMMAND ----------

SELECT assert_true((SELECT count(*) FROM information_schema.tables WHERE table_schema = 'data604'
                    AND table_name IN ('permits', 'permit_updates', 'communities', 'latest_updates')) = 0,
                   'lab tables still exist: run the first cell again') AS reset_ok,
       assert_true((SELECT count(*) FROM information_schema.tables WHERE table_schema = 'perf') = 2, 'perf tables missing: rerun prep_day_before') AS perf_ok
