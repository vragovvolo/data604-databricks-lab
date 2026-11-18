# From MySQL to Databricks: one page

| In MySQL or MariaDB | In Databricks |
|---|---|
| `database.table` (DATABASE and SCHEMA mean the same thing) | `catalog.schema.table`, governed by Unity Catalog |
| `SHOW DATABASES`, `USE db` | `SHOW CATALOGS`, `SHOW SCHEMAS`, `USE CATALOG c`, `USE SCHEMA s` |
| `LOAD DATA INFILE 'f.csv' INTO TABLE t` | `INSERT INTO t SELECT * FROM read_files('/Volumes/c/s/v/f.csv', format => 'csv', header => true)` |
| Files on the server's disk | Files in a **volume**: a governed folder, `/Volumes/catalog/schema/volume/` |
| `INSERT ... ON DUPLICATE KEY UPDATE` | `MERGE INTO t USING s ON ... WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...` |
| `AUTO_INCREMENT` | `BIGINT GENERATED ALWAYS AS IDENTITY` |
| `PRIMARY KEY`, `FOREIGN KEY` enforced by InnoDB | Informational: declared, used by tools like Genie, **not enforced**. `NOT NULL` and `CHECK` are enforced |
| `CREATE INDEX` (B-tree) | No B-tree indexes. Per-file min and max statistics plus `CLUSTER BY` let queries skip files |
| Redo log and binlog | The Delta transaction log: one atomic commit per statement, every version kept |
| Restore last night's backup | `RESTORE TABLE t TO VERSION AS OF n` and `SELECT ... FROM t VERSION AS OF n` |
| Row locks | No row locks. Optimistic concurrency: each commit is checked for conflicts, and a conflicting writer fails and retries |
| `EXPLAIN` | `EXPLAIN FORMATTED`, plus the Query Profile in the UI |
| `GRANT SELECT ON db.t TO 'user'@'host'` | ``GRANT SELECT ON TABLE c.s.t TO `user@example.com` `` |
| Views for row-level security | Row filters and column masks attached to the table |
| Subquery for top N per group | `QUALIFY row_number() OVER (PARTITION BY g ORDER BY x DESC) <= n` |
| `GROUP BY a, b` | `GROUP BY ALL` |
| One server does the work | Many workers in parallel: scan, shuffle, aggregate (the MapReduce idea, run by a SQL engine) |

## How today connects to the course

| Course topic | What you saw today |
|---|---|
| SQL: aggregations, joins | The same SQL on 45,676 permits and on TPC-H with millions of rows |
| Indexing | No B-tree indexes: file statistics and clustering skip the files that can't match |
| ER diagrams and normalization | TPC-H's normalized schema, and the `communities` table you split out of `permits` |
| Keys and data quality | Keys are not enforced, so duplicates break `MERGE` and a code with two meanings breaks joins |
| Concurrency and transactions | Each statement is one atomic commit. `RESTORE` writes a new version, so the history is kept |
| MapReduce and Hadoop | A SQL query runs as parallel tasks with a shuffle in the middle |
| Why it matters for AI | A chatbot like Genie is only as good as the keys, definitions and comments you give it |
