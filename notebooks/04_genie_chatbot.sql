-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DATA 604 lab 04: build your first chatbot with Genie
-- MAGIC
-- MAGIC A Genie Agent answers questions in plain English by writing SQL over tables you choose.
-- MAGIC It uses the table and column descriptions from Unity Catalog, primary and foreign keys (saved as join relationships),
-- MAGIC and the instructions and example SQL you give it. It does not train a model on your data.
-- MAGIC **So the quality of its answers depends on your data management.** That is what this lab shows.
-- MAGIC
-- MAGIC Attach to the **Serverless Starter Warehouse**.

-- COMMAND ----------

-- Catch-up: brings permits to the state at the end of lab 03. Safe to run even if you finished lab 03.
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
MERGE INTO permits AS t
USING (
  SELECT permit_num, status, applied_date, issued_date, completed_date, permit_type, permit_class, work_class, housing_units, est_project_cost, total_sqft, community_code, community_name
  FROM read_files(
    '/Volumes/workspace/data604/raw/permits_updates.csv',
    format => 'csv', header => true, escape => '"', mode => 'FAILFAST',
    schema => 'permit_num STRING, status STRING, applied_date DATE, issued_date DATE, completed_date DATE, permit_type STRING, permit_class STRING, work_class STRING, housing_units INT, est_project_cost DECIMAL(14,2), total_sqft DECIMAL(12,2), community_code STRING, community_name STRING, status_changed_on DATE, event_seq INT')
  QUALIFY row_number() OVER (PARTITION BY permit_num ORDER BY status_changed_on DESC, event_seq DESC) = 1
) AS s
ON t.permit_num = s.permit_num
-- Only rows that are behind are updated, so re-running this never undoes your work in step 1.
WHEN MATCHED AND (t.status IS DISTINCT FROM s.status OR t.issued_date IS DISTINCT FROM s.issued_date
                  OR t.completed_date IS DISTINCT FROM s.completed_date) THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

SELECT assert_true(count(*) = 45676, 'expected 45,676 permits') AS rows_ok,
       assert_true(count_if(status = 'Completed') = 27375, 'statuses look wrong: run lab 03 from the top') AS statuses_ok
FROM permits

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Step 1: normalize a communities table (Monday's lecture, for real)
-- MAGIC
-- MAGIC `permits` repeats each community's name on every row. Move communities into their own table with a primary key.
-- MAGIC First check that the key really identifies one community:

-- COMMAND ----------

SELECT community_code, count(DISTINCT community_name) AS names, collect_set(community_name) AS which_names
FROM permits
GROUP BY ALL
HAVING count(DISTINCT community_name) > 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC One code, two meanings: `UND` is used for **University District** (next door to campus) and for **Undefined**.
-- MAGIC A key with two meanings makes every join and count on it wrong, for people and for chatbots.
-- MAGIC Give the undefined rows their own code:

-- COMMAND ----------

UPDATE permits SET community_code = 'UNK'
WHERE community_code = 'UND' AND community_name = 'Undefined';

-- COMMAND ----------

-- Primary and foreign keys are informational in Databricks: declared, used by tools like Genie, not enforced.
-- NOT NULL and CHECK constraints are enforced.
ALTER TABLE permits DROP CONSTRAINT IF EXISTS permits_community_fk;
ALTER TABLE permits DROP CONSTRAINT IF EXISTS permits_pk;

CREATE OR REPLACE TABLE communities (
  community_code STRING NOT NULL COMMENT 'Community code used by the City of Calgary. UNK means the community is not recorded.',
  community_name STRING NOT NULL COMMENT 'Community (neighbourhood) name, upper case, for example BELTLINE or UNIVERSITY DISTRICT.',
  CONSTRAINT communities_pk PRIMARY KEY (community_code)
) COMMENT 'One row per Calgary community.';

INSERT INTO communities
SELECT DISTINCT community_code, community_name FROM permits;

ALTER TABLE permits ADD CONSTRAINT permits_pk PRIMARY KEY (permit_num);
ALTER TABLE permits ADD CONSTRAINT permits_community_fk FOREIGN KEY (community_code) REFERENCES communities (community_code);

-- COMMAND ----------

SELECT assert_true(count(*) = 287, 'expected 287 communities') AS communities_ok,
       assert_true(count(*) = count(DISTINCT community_code), 'community_code must be unique') AS key_ok
FROM communities

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Step 2: create the Genie Agent and ask before you document anything
-- MAGIC
-- MAGIC 1. In the left bar, click **Genie Agents**, then **New** (upper right).
-- MAGIC 2. Choose the tables `workspace.data604.permits` and `workspace.data604.communities`, then click **Create**.
-- MAGIC 3. Under **Configure**, **Settings**, check that the default warehouse is the **Serverless Starter Warehouse**.
-- MAGIC 4. Ask: **How many permits are open?** Then ask: **How many permits are active?**
-- MAGIC    Write down both numbers, and open the SQL Genie wrote for each answer.
-- MAGIC
-- MAGIC Nothing tells Genie yet what "open" or "active" means, so it has to guess. When we tested this, it looked for
-- MAGIC the words "open" and "active" in the status values, found neither, and answered 0. Read the SQL to see what your agent guessed.

-- COMMAND ----------

-- The statuses Genie had to choose from.
SELECT status, count(*) AS permits FROM permits GROUP BY ALL ORDER BY permits DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Step 3: document the data
-- MAGIC
-- MAGIC Comments live in Unity Catalog with the table, so every tool and every person sees the same definitions.

-- COMMAND ----------

COMMENT ON TABLE permits IS 'City of Calgary building permits applied for from January 2025 to November 13 2026. One row per permit. Source: City of Calgary open data, Open Government Licence - City of Calgary.';

ALTER TABLE permits ALTER COLUMN permit_num COMMENT 'Permit number, unique per permit, for example BP2026-01234.';
ALTER TABLE permits ALTER COLUMN status COMMENT 'Current status. Closed statuses: Completed, Cancelled, Refused, Expired, File Closed. Every other status means the permit is still open.';
ALTER TABLE permits ALTER COLUMN applied_date COMMENT 'Date the application was received.';
ALTER TABLE permits ALTER COLUMN issued_date COMMENT 'Date the permit was issued (approved). Empty if not issued yet.';
ALTER TABLE permits ALTER COLUMN completed_date COMMENT 'Date the work was completed. Empty if not completed.';
ALTER TABLE permits ALTER COLUMN permit_type COMMENT 'Permit type: Residential Improvement Project, Single Construction Permit, Commercial / Multi Family Project, Demolition, or (rarely) Environmental Restoration Permit.';
ALTER TABLE permits ALTER COLUMN permit_class COMMENT 'Residential, Non-Residential or Unspecified.';
ALTER TABLE permits ALTER COLUMN work_class COMMENT 'New means new construction. Improvement means renovation or an addition. Demolition means the building is removed. Unspecified means the City did not record it.';
ALTER TABLE permits ALTER COLUMN housing_units COMMENT 'Number of dwelling units the permit creates. New homes are permits with work_class New and housing_units above 0.';
ALTER TABLE permits ALTER COLUMN est_project_cost COMMENT 'Estimated project cost in Canadian dollars, declared by the applicant. Can be empty.';
ALTER TABLE permits ALTER COLUMN community_code COMMENT 'Calgary community code. Join to communities.community_code.';
ALTER TABLE permits ALTER COLUMN community_name COMMENT 'Community (neighbourhood) name, upper case.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Now start a **new chat** in your Genie Agent and ask **How many permits are open?** again. Read the SQL.
-- MAGIC The comment on `status` lists the closed statuses, so Genie no longer has to guess what "open" means.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Step 4: tell Genie what "active" means, then ask again
-- MAGIC
-- MAGIC Open and closed describe the data, so they went in a column comment that every tool can read.
-- MAGIC "Active" is a business rule, and only the City can say which statuses count. So it goes in the agent's instructions.
-- MAGIC
-- MAGIC 1. In your Genie Agent, open **Configure**, then the **Text** tab, and add this instruction:
-- MAGIC    *A permit is active if its status is Issued Permit, Pre Backfill Phase, Pre Board Phase or Final Phase.*
-- MAGIC 2. Start a **new chat** and ask **How many permits are active?** again. Compare the SQL with the first answer.
-- MAGIC 3. Then try one or two of these:
-- MAGIC    - Which 5 communities got the most new housing units from permits issued in 2026?
-- MAGIC    - What is the median number of days from application to issue for Single Construction Permits?
-- MAGIC    - How many permits were issued in University District in 2026?
-- MAGIC    - Show monthly applications for 2025 and 2026 as a line chart.
-- MAGIC
-- MAGIC Check every answer the way you would check a classmate's query: read the SQL. The cells below have the right answers.

-- COMMAND ----------

-- The right answers with the City's definitions: 15,620 open, 11,353 active.
SELECT count_if(status NOT IN ('Completed', 'Cancelled', 'Refused', 'Expired', 'File Closed')) AS open_permits,
       count_if(status IN ('Issued Permit', 'Pre Backfill Phase', 'Pre Board Phase', 'Final Phase')) AS active_permits
FROM permits

-- COMMAND ----------

-- Top 5 communities by new housing units on permits issued in 2026 (RANGEVIEW leads with 810).
SELECT c.community_name, sum(p.housing_units) AS new_units
FROM permits AS p
JOIN communities AS c USING (community_code)
WHERE p.work_class = 'New' AND year(p.issued_date) = 2026
GROUP BY ALL
ORDER BY new_units DESC
LIMIT 5

-- COMMAND ----------

SELECT
  (SELECT median(datediff(issued_date, applied_date)) FROM permits
   WHERE permit_type = 'Single Construction Permit' AND issued_date IS NOT NULL) AS median_days_single_construction,
  (SELECT count(*) FROM permits
   WHERE community_name = 'UNIVERSITY DISTRICT' AND year(issued_date) = 2026) AS university_district_issued_2026

-- COMMAND ----------

SELECT
  assert_true((SELECT count(*) FROM permits WHERE status NOT IN ('Completed', 'Cancelled', 'Refused', 'Expired', 'File Closed')) = 15620, 'open permits should be 15,620') AS open_ok,
  assert_true((SELECT count(*) FROM permits WHERE status IN ('Issued Permit', 'Pre Backfill Phase', 'Pre Board Phase', 'Final Phase')) = 11353, 'active permits should be 11,353') AS active_ok,
  assert_true((SELECT median(datediff(issued_date, applied_date)) FROM permits WHERE permit_type = 'Single Construction Permit' AND issued_date IS NOT NULL) = 19, 'median days should be 19') AS median_ok,
  assert_true((SELECT count(*) FROM permits WHERE community_name = 'UNIVERSITY DISTRICT' AND year(issued_date) = 2026) = 20, 'University District should have 20') AS ud_ok

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## What you just did
-- MAGIC
-- MAGIC You fixed a broken key, declared keys, wrote down what the data means, and gave Genie one business rule.
-- MAGIC The chatbot got both definitions right without any change to the model. Most failures of AI systems on company data look like this, and the fix is data management.
