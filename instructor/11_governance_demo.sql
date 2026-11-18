-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Instructor demo: governance with Unity Catalog
-- MAGIC
-- MAGIC Needs labs 00 to 04 run in this account. For the second-user part, add your spare account first:
-- MAGIC **Settings**, **Identity and access**, **Users**, **Add user**. Replace `second.user@example.com` below
-- MAGIC in your workspace copy only. Do not commit a real address to the public repo.

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA data604;

-- COMMAND ----------

SELECT current_user() AS me,
       is_account_group_member('admins') AS account_admins,
       is_member('admins') AS workspace_admins

-- COMMAND ----------

SHOW GRANTS ON TABLE permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. GRANT is the same SQL as in MySQL
-- MAGIC
-- MAGIC Before running this, show that the second user gets PERMISSION_DENIED on `SELECT * FROM workspace.data604.permits`.

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

-- As the instructor (admin) you still see costs. Switch to the second user's browser and run the same query.
SELECT permit_num, community_name, est_project_cost FROM permits WHERE est_project_cost IS NOT NULL LIMIT 5

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
