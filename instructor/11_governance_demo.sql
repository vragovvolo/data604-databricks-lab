-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor demo: governance with Unity Catalog
-- MAGIC
-- MAGIC Needs labs 00 to 04 run in this account. For the second-user part, add your spare account first:
-- MAGIC **Settings**, **Identity and access**, **Users**, **Add user**. Replace all six `second.user@example.com` values
-- MAGIC (three GRANT lines and three REVOKE lines) with the spare account, using Find and replace in your workspace copy only.
-- MAGIC Do not commit the change.

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
-- MAGIC Before running the GRANT cells, open a private browser window, sign in as the spare account, open the SQL editor, pick the Serverless Starter Warehouse and run `SELECT * FROM workspace.data604.permits`. Expect PERMISSION_DENIED. Then sign out of the spare account and come back here.

-- COMMAND ----------

GRANT USE CATALOG ON CATALOG workspace TO `second.user@example.com`;
GRANT USE SCHEMA ON SCHEMA workspace.data604 TO `second.user@example.com`;
GRANT SELECT ON TABLE workspace.data604.permits TO `second.user@example.com`;
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

-- As the instructor you see the five largest costs. In the second user's window the same query shows rows with the cost column empty.
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
REVOKE SELECT ON TABLE workspace.data604.permits FROM `second.user@example.com`;
REVOKE USE SCHEMA ON SCHEMA workspace.data604 FROM `second.user@example.com`;
REVOKE USE CATALOG ON CATALOG workspace FROM `second.user@example.com`;
DROP FUNCTION IF EXISTS mask_cost;
