-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab answers
-- MAGIC
-- MAGIC Try the exercises yourself first. Attach to the **Serverless Starter Warehouse**.

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA data604;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Lab 02: the 5 communities with the most demolition permits applied for in 2025

-- COMMAND ----------

SELECT community_name, count(*) AS demolition_permits
FROM permits
WHERE work_class = 'Demolition' AND year(applied_date) = 2025
GROUP BY ALL
ORDER BY demolition_permits DESC
LIMIT 5

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Lab 03 stretch: which permits did the MERGE insert?
-- MAGIC
-- MAGIC An anti join against version 1 finds rows that did not exist on September 30.

-- COMMAND ----------

SELECT cur.permit_num, cur.applied_date, cur.status, cur.community_name
FROM permits AS cur
LEFT ANTI JOIN permits VERSION AS OF 1 AS sep30 USING (permit_num)
ORDER BY cur.applied_date DESC
LIMIT 20

-- COMMAND ----------

SELECT count(*) AS inserted_by_merge
FROM permits AS cur
LEFT ANTI JOIN permits VERSION AS OF 1 AS sep30 USING (permit_num)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Lab 04: the reference answers for the Genie questions
-- MAGIC
-- MAGIC | Question | Answer |
-- MAGIC |---|---|
-- MAGIC | How many permits are open? (open = not Completed, Cancelled, Refused, Expired or File Closed) | 15,620 |
-- MAGIC | How many permits are active? (active = Issued Permit, Pre Backfill Phase, Pre Board Phase or Final Phase) | 11,353 |
-- MAGIC | Top community for new housing units on permits issued in 2026 | RANGEVIEW, 810 units |
-- MAGIC | Median days from application to issue, Single Construction Permits | 19 |
-- MAGIC | Permits issued in University District in 2026 | 20 |
-- MAGIC
-- MAGIC If Genie gets a different number, read its SQL and find the difference. Usually it picked a different
-- MAGIC definition (which statuses count as open, which date counts as "in 2026"). Fix the definition in a comment or
-- MAGIC an instruction, not in the question.
