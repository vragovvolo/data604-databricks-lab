# DATA 604 Databricks lab

Hands-on lab for the Databricks guest workshop in DATA 604 *Working with Data at Scale*, University of Calgary, November 25 2026.

You will load City of Calgary building permits into Databricks, query them with the SQL you already know, apply a batch of changes with `MERGE`, travel back in time, and build a small chatbot over your own tables with Genie.

Teaching material prepared by Volo Vragov (Databricks). This is not an official Databricks repository.

## Before class (about 10 minutes)

1. **Create a free Databricks account** at [databricks.com/learn/free-edition](https://www.databricks.com/learn/free-edition). You can sign in with an email code, Google or Microsoft. A personal Google account or personal email is the simplest choice. If you prefer not to create an account, pair with a classmate and work together on their laptop.
2. **Log in once**, open **SQL Editor** in the left bar, and run `SELECT 1`. If you get a result, you are ready.
3. **Download the two data files** to your laptop: [`data/permits_snapshot.csv`](data/permits_snapshot.csv) and [`data/permits_updates.csv`](data/permits_updates.csv). Open each file on GitHub and click *Download raw file*.
4. Bring your laptop and charger.

## In class: open the lab

**Option A, Git folder (recommended).** In Databricks, open **Workspace**, go to your home folder, click **Create**, then **Git folder**. Paste `https://github.com/vragovvolo/data604-databricks-lab` and click **Create**. Open `notebooks/00_start_here`.

**Option B, no Git.** On GitHub click **Code**, then **Download ZIP**, and unzip it. In Databricks open **Workspace**, then your home folder, then **Import**, and import each `.sql` file from `notebooks/`. With this option, upload the two CSV files from your laptop (step 3 above), because the fallback loader needs the Git folder.

Attach every lab notebook to the **Serverless Starter Warehouse** (top right, **Connect**).

| Notebook | What you do |
|---|---|
| `notebooks/00_start_here` | Warm up the warehouse, see how catalogs, schemas and tables are organized, create your schema and volume |
| `notebooks/01_load_and_explore` | Load the permits CSV into a Delta table and explore it |
| `notebooks/02_sql_at_scale` | Familiar SQL on the permits, then the same SQL on TPC-H with millions of rows |
| `notebooks/03_delta_merge_history` | Dedupe change events, `MERGE` them, use time travel, undo a mistake with `RESTORE` |
| `notebooks/04_genie_chatbot` | Fix a broken key, declare keys, document the data, build and improve a Genie Agent |
| `solutions/solutions` | Answers to the exercises |

The `instructor/` folder is for the instructor. Don't run those notebooks: one of them deletes the lab tables.

## If something goes wrong

- **Can't upload the CSV files?** Open `setup/fallback_load`, attach it to **Serverless** compute (it is Python), and click **Run all**. It copies the files from the Git folder (option A) into your volume.
- **Fell behind?** Labs 02 to 04 start with a catch-up cell that rebuilds what the earlier labs created. Lab 01 creates the schema and volume if you skipped lab 00.
- **First query is slow?** The warehouse is starting. Give it a minute and run the cell again.
- **`read_files` says the path does not exist?** Check that both files are in **Catalog**, **workspace**, **data604**, **raw** with exactly these names.
- **A check cell fails** (`assert_true`)? Run the notebook again from the top. Lab 03 starts from a clean copy on purpose.

## Keep learning for free

- Databricks Free Edition stays free for learning: [databricks.com/learn/free-edition](https://www.databricks.com/learn/free-edition)
- Free self-paced training: [databricks.com/learn/training/home](https://www.databricks.com/learn/training/home)
- University Alliance for students: finish a Databricks course for a student badge and 25% off a certification ([databricks.com/university](https://www.databricks.com/university))
- One-page summary of today: [CHEATSHEET.md](CHEATSHEET.md)

## Data and license

The data comes from the City of Calgary [Building Permits](https://data.calgary.ca/Business-and-Economic-Activity/Building-Permits/c2es-76ed) open dataset. See [data/README.md](data/README.md) for what was kept and how the September 30 snapshot was rebuilt.

*Contains information licensed under the [Open Government Licence – City of Calgary](https://data.calgary.ca/stories/s/Open-Calgary-Terms-of-Use/u45n-7awa).*

The files in `data/` are derived from that dataset: some columns were removed, the September 30 snapshot was rebuilt, and the change events were reconstructed. The City of Calgary does not endorse this material.

Data: Open Government Licence – City of Calgary. Code and notebooks: [Apache License 2.0](LICENSE).
