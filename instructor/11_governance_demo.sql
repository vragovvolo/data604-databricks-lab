-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor demo: governance with Unity Catalog
-- MAGIC
-- MAGIC Needs labs 00 to 04 run in this account. One account is enough: the GRANT goes to the built-in group
-- MAGIC `account users`, so every cell runs without a second user. Say what a second user would see.

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA data604;

-- COMMAND ----------

-- Expect workspace_admins = true. If it is false, the mask hides costs from you too: stop and ask.
SELECT current_user() AS me,
       is_account_group_member('admins') AS account_admins,
       is_member('admins') AS workspace_admins

-- COMMAND ----------

SHOW GRANTS ON TABLE permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. GRANT is the same SQL as in MySQL
-- MAGIC
-- MAGIC Say it, do not show it: a user without these grants gets PERMISSION_DENIED on this table.

-- COMMAND ----------

GRANT USE CATALOG ON CATALOG workspace TO `account users`;
GRANT USE SCHEMA ON SCHEMA workspace.data604 TO `account users`;
GRANT SELECT ON TABLE workspace.data604.permits TO `account users`;
SHOW GRANTS ON TABLE permits;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. A column mask: only admins see project cost
-- MAGIC
-- MAGIC The rule lives with the table. Every query, dashboard and Genie answer gets it, with no copy of the data.

-- COMMAND ----------

CREATE OR REPLACE FUNCTION mask_cost(cost DECIMAL(14,2))
RETURNS DECIMAL(14,2)
RETURN CASE WHEN is_account_group_member('admins') OR is_member('admins') THEN cost ELSE NULL END;

ALTER TABLE permits ALTER COLUMN est_project_cost SET MASK mask_cost;

-- COMMAND ----------

-- As the instructor (an admin) you see the five largest costs. Anyone who is not an admin sees the same rows with the cost column empty.
SELECT permit_num, community_name, est_project_cost FROM permits ORDER BY est_project_cost DESC NULLS LAST LIMIT 5

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Lineage
-- MAGIC
-- MAGIC **Catalog**, then **permits**, then **Lineage**: `permit_updates`, `permits` and `communities`, and the notebooks
-- MAGIC and queries that wrote them. Nobody drew this by hand.

-- COMMAND ----------

-- Clean-up: removes the mask and the grants. Between sessions, also run reset_between_sessions.
ALTER TABLE permits ALTER COLUMN est_project_cost DROP MASK;
REVOKE SELECT ON TABLE workspace.data604.permits FROM `account users`;
REVOKE USE SCHEMA ON SCHEMA workspace.data604 FROM `account users`;
REVOKE USE CATALOG ON CATALOG workspace FROM `account users`;
DROP FUNCTION IF EXISTS mask_cost;
