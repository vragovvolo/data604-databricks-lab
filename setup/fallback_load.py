# Databricks notebook source
# MAGIC %md
# MAGIC # Setup: copy the lab CSV files into your volume
# MAGIC
# MAGIC Run this once, at the end of lab 00. It copies the two CSV files from this Git folder into
# MAGIC `/Volumes/workspace/data604/raw/`. It creates the schema and the volume too, if they are missing.
# MAGIC
# MAGIC **Attach this notebook to Serverless compute** (not the SQL warehouse: this one is Python), then **Run all**.
# MAGIC Then open lab 01, or go back to it and continue from the `LIST` cell.

# COMMAND ----------

import shutil
from pathlib import Path

catalog, schema, volume = "workspace", "data604", "raw"
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.{schema}")
spark.sql(f"CREATE VOLUME IF NOT EXISTS {catalog}.{schema}.{volume}")

def find_data_dir() -> Path:
    """The repo's data folder: one level up from this notebook (works in a Git folder or an imported repo folder)."""
    for base in (Path.cwd().parent, Path.cwd()):
        if (base / "data" / "permits_snapshot.csv").exists():
            return base / "data"
    nb = dbutils.notebook.entry_point.getDbutils().notebook().getContext().notebookPath().get()
    return Path("/Workspace" + nb).parent.parent / "data"


data_dir = find_data_dir()
missing = [n for n in ("permits_snapshot.csv", "permits_updates.csv") if not (data_dir / n).exists()]
assert not missing, (f"Can't find {missing} in {data_dir}. "
                     "This is expected if you imported the notebooks one at a time (Option B), because the data folder is not imported. "
                     "Upload the two CSV files: lab 00, Next section, then Catalog, workspace, data604, raw, Upload to this volume.")
target = Path(f"/Volumes/{catalog}/{schema}/{volume}")
for name in ("permits_snapshot.csv", "permits_updates.csv"):
    shutil.copyfile(data_dir / name, target / name)
    print(f"copied {name}: {(target / name).stat().st_size:,} bytes")

# COMMAND ----------

display(dbutils.fs.ls(str(target)))
