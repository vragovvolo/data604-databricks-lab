# Lab data

Source: City of Calgary [Building Permits](https://data.calgary.ca/Business-and-Economic-Activity/Building-Permits/c2es-76ed) (dataset `c2es-76ed`), permits applied for from January 1 2025 to November 13 2026, downloaded November 14 2026.

*Contains information licensed under the [Open Government Licence – City of Calgary](https://data.calgary.ca/stories/s/Open-Calgary-Terms-of-Use/u45n-7awa).*

## Files

| File | Rows | What it is |
|---|---|---|
| `permits_snapshot.csv` | 42,925 | Permits applied for up to September 30 2026, rebuilt as of September 30 (see below) |
| `permits_updates.csv` | 8,534 | Change events from October 1 to November 13 2026 for 7,263 permits: new applications, issues and completions. Full row plus `status_changed_on` and `event_seq` |
| `expected_counts.json` | | The numbers the lab's check cells assert on |

## Columns

`permit_num`, `status`, `applied_date`, `issued_date`, `completed_date`, `permit_type`, `permit_class`, `work_class`, `housing_units`, `est_project_cost`, `total_sqft`, `community_code`, `community_name`.

Changes from the source: the free-text description, applicant and contractor names, addresses, coordinates and geometry are not included. Column names are snake_case, dates are ISO (`yyyy-mm-dd`), and whitespace in text was collapsed.

## How the September 30 snapshot was rebuilt

The open dataset only has each permit's current state, so the snapshot is reconstructed from the permit dates:

- a permit issued after September 30 is shown as `In Review`, with no issue or completion date
- a permit completed after September 30 is shown as `Issued Permit` with no completion date if it was issued by then, and as `In Review` if it never was (for example, cancelled or refused in October)
- statuses that carry no date (for example Hold or the inspection phases) keep today's value, so changes between them are not in the updates file

`In Review` is a placeholder for "not issued yet", not the exact status on September 30.

The updates file has one event per dated milestone after September 30: the application (for new permits), the issue date and the completion date. The last event of each permit carries its current row. A new application that is issued and completed in the window has three events. `event_seq` orders events that share a date. Replaying the latest event per permit onto the snapshot gives exactly the current dataset.

Rebuild both files with `tools/build_permits_csv.py`.
