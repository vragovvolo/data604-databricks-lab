"""Build the DATA 604 lab CSVs from the City of Calgary Building Permits open data (dataset c2es-76ed).

Runs on a laptop (Free Edition cannot reach data.calgary.ca). Standard library only.

Outputs (in --out-dir):
  permits_snapshot.csv   permits applied from --start to --cutoff, rebuilt "as of" --cutoff
  permits_updates.csv    change events after --cutoff up to --asof (full row image + status_changed_on)
  expected_counts.json   numbers the lab notebooks assert on

The snapshot is rebuilt from the permit dates. A permit issued after the cutoff is shown as not yet issued
("In Review"). A permit completed after the cutoff is shown as "Issued Permit" if it was issued by then, and as
"In Review" if it never was (cancelled or refused later). Statuses that carry no date (Hold, inspection phases)
keep today's value, so changes between them are not in the feed. The free-text description is not published
(it can hold names, phone numbers and addresses).

Contains information licensed under the Open Government Licence – City of Calgary.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import shutil
import ssl
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import dataclass, asdict, replace
from datetime import date
from pathlib import Path

API = "https://data.calgary.ca/resource/c2es-76ed.csv"
SOURCE_FIELDS = [
    "permitnum", "statuscurrent", "applieddate", "issueddate", "completeddate",
    "permittype", "permitclassmapped", "workclassgroup",
    "housingunits", "estprojectcost", "totalsqft", "communitycode", "communityname",
]
PAGE = 20000
PRE_ISSUE_STATUS = "In Review"          # shown for permits not yet issued at the cutoff
ISSUED_STATUS = "Issued Permit"
RECEIVED_STATUS = "Application Received"


@dataclass(frozen=True)
class Permit:
    permit_num: str
    status: str
    applied_date: str
    issued_date: str
    completed_date: str
    permit_type: str
    permit_class: str
    work_class: str
    housing_units: str
    est_project_cost: str
    total_sqft: str
    community_code: str
    community_name: str


COLUMNS = list(Permit.__dataclass_fields__)
UPDATE_COLUMNS = COLUMNS + ["status_changed_on", "event_seq"]


def fetch(raw_dir: Path, start: str, asof: str, refresh: bool) -> Path:
    raw = raw_dir / f"permits_raw_{start}_{asof}.csv"
    if raw.exists() and not refresh:
        return raw
    where = f"applieddate >= '{start}T00:00:00' AND applieddate <= '{asof}T23:59:59'"
    rows: list[dict[str, str]] = []
    offset = 0
    while True:
        query = urllib.parse.urlencode({
            "$select": ",".join(SOURCE_FIELDS), "$where": where,
            "$order": "permitnum", "$limit": PAGE, "$offset": offset,
        })
        page = list(csv.DictReader(io.StringIO(get_text(f"{API}?{query}"))))
        rows.extend(page)
        if len(page) < PAGE:
            break
        offset += PAGE
        time.sleep(1)
    with raw.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=SOURCE_FIELDS)
        w.writeheader()
        w.writerows(rows)
    return raw


def get_text(url: str) -> str:
    """HTTP GET as text. Falls back to curl when Python's CA bundle can't verify the chain."""
    req = urllib.request.Request(url, headers={"User-Agent": "data604-lab-builder"})
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.read().decode("utf-8")
    except urllib.error.URLError as err:
        if not isinstance(err.reason, ssl.SSLError) or not shutil.which("curl"):
            raise
        out = subprocess.run(["curl", "-sSf", "--max-time", "180", "-A", "data604-lab-builder", url],
                             check=True, capture_output=True)
        return out.stdout.decode("utf-8")


def iso(value: str) -> str:
    return value[:10] if value else ""


def clean_text(value: str) -> str:
    return " ".join(value.split())


def number(value: str) -> str:
    if not value:
        return ""
    f = float(value)
    return str(int(f)) if f.is_integer() else f"{f:.2f}"


def load(raw: Path) -> list[Permit]:
    seen: set[str] = set()
    out: list[Permit] = []
    with raw.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            num = r["permitnum"].strip()
            if not num or num in seen:
                continue
            seen.add(num)
            out.append(Permit(
                permit_num=num,
                status=clean_text(r["statuscurrent"]),
                applied_date=iso(r["applieddate"]),
                issued_date=iso(r["issueddate"]),
                completed_date=iso(r["completeddate"]),
                permit_type=clean_text(r["permittype"]),
                permit_class=clean_text(r["permitclassmapped"]),
                work_class=clean_text(r["workclassgroup"]),
                housing_units=number(r["housingunits"]),
                est_project_cost=number(r["estprojectcost"]),
                total_sqft=number(r["totalsqft"]),
                community_code=clean_text(r["communitycode"]),
                community_name=clean_text(r["communityname"]),
            ))
    return out


def as_of(p: Permit, cutoff: str) -> Permit:
    """State of a permit at the end of the cutoff day, rebuilt from its dates."""
    if p.issued_date and p.issued_date > cutoff:
        return replace(p, status=PRE_ISSUE_STATUS, issued_date="", completed_date="")
    if p.completed_date and p.completed_date > cutoff:
        if p.issued_date:
            return replace(p, status=ISSUED_STATUS, completed_date="")
        return replace(p, status=PRE_ISSUE_STATUS, completed_date="")  # closed later without ever being issued
    return p


def events_after(p: Permit, cutoff: str, is_new: bool) -> list[dict[str, str]]:
    """Change events after the cutoff: full row image + status_changed_on + event_seq (1, 2, ...).

    The dated milestones after the cutoff are the application (new permits only), the issue date and the
    completion date. Each one is an event. The last event carries the permit's current row.
    """
    marks: list[tuple[str, str]] = []
    if is_new:
        marks.append(("applied", p.applied_date))
    if p.issued_date and p.issued_date > cutoff:
        marks.append(("issued", p.issued_date))
    if p.completed_date and p.completed_date > cutoff:
        marks.append(("completed", p.completed_date))
    ev: list[tuple[Permit, str]] = []
    for k, (kind, on) in enumerate(marks):
        if k == len(marks) - 1:
            row = p                                    # the latest milestone shows today's state
        elif kind == "applied":
            row = replace(p, status=RECEIVED_STATUS, issued_date="", completed_date="")
        else:                                          # issued, with a later completion still to come
            row = replace(p, status=ISSUED_STATUS, completed_date="")
        ev.append((row, on))
    # Same-day milestones (applied and issued on one day) tie on the date, so event_seq orders them.
    return [{**asdict(row), "status_changed_on": on, "event_seq": str(i)} for i, (row, on) in enumerate(ev, 1)]


def write_csv(path: Path, columns: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=columns, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-dir", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--start", default="2025-01-01")
    ap.add_argument("--cutoff", default="2026-09-30")
    ap.add_argument("--asof", default="2026-11-13")
    ap.add_argument("--refresh", action="store_true")
    a = ap.parse_args()
    date.fromisoformat(a.start), date.fromisoformat(a.cutoff), date.fromisoformat(a.asof)

    permits = load(fetch(a.raw_dir, a.start, a.asof, a.refresh))
    old = [p for p in permits if p.applied_date <= a.cutoff]
    new = [p for p in permits if p.applied_date > a.cutoff]

    snapshot = [as_of(p, a.cutoff) for p in old]
    events = [e for p in old for e in events_after(p, a.cutoff, is_new=False)]
    events += [e for p in new for e in events_after(p, a.cutoff, is_new=True)]
    events.sort(key=lambda e: (e["status_changed_on"], e["permit_num"], int(e["event_seq"])))

    latest: dict[str, dict[str, str]] = {}
    for e in sorted(events, key=lambda e: (e["permit_num"], e["status_changed_on"], int(e["event_seq"]))):
        latest[e["permit_num"]] = e  # the last event per permit wins
    snap_by_num = {p.permit_num: asdict(p) for p in snapshot}
    changed = sum(1 for n, e in latest.items()
                  if n in snap_by_num and any(snap_by_num[n][c] != e[c] for c in COLUMNS))
    matched = sum(1 for n in latest if n in snap_by_num)
    inserted = len(latest) - matched
    final = {**snap_by_num, **{n: {c: e[c] for c in COLUMNS} for n, e in latest.items()}}

    codes: dict[str, set[str]] = {}
    for row in final.values():
        if row["community_code"]:
            codes.setdefault(row["community_code"], set()).add(row["community_name"])

    # Answers the lab asserts on (the lab recodes the 'Undefined' rows of community code UND to UNK).
    closed = {"Completed", "Cancelled", "Refused", "Expired", "File Closed"}  # the lab's definition of closed
    rows = [dict(r, community_code="UNK" if r["community_name"] == "Undefined" else r["community_code"])
            for r in final.values()]
    issued_2026 = [r for r in rows if r["issued_date"].startswith("2026")]
    new_units: Counter[str] = Counter()
    for r in issued_2026:
        if r["work_class"] == "New" and r["housing_units"]:
            new_units[r["community_name"]] += int(float(r["housing_units"]))
    days = sorted((date.fromisoformat(r["issued_date"]) - date.fromisoformat(r["applied_date"])).days
                  for r in rows if r["issued_date"] and r["permit_type"] == "Single Construction Permit")
    mid = len(days) // 2
    answers = {
        "status_changed_rows": sum(1 for n, r in final.items()
                                   if n in snap_by_num and snap_by_num[n]["status"] != r["status"]),
        "open_permits": sum(1 for r in rows if r["status"] not in closed),
        "active_permits": sum(1 for r in rows if r["status"] in {"Issued Permit", "Pre Backfill Phase", "Pre Board Phase", "Final Phase"}),
        "issued_2026": len(issued_2026),
        "top5_new_units_2026": new_units.most_common(5),
        "median_days_to_issue_single_construction": (days[mid] if len(days) % 2 else (days[mid - 1] + days[mid]) / 2),
        "university_district_issued_2026": sum(1 for r in issued_2026 if r["community_name"] == "UNIVERSITY DISTRICT"),
        "communities_after_fix": len({r["community_code"] for r in rows if r["community_code"]}),
    }

    a.out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(a.out_dir / "permits_snapshot.csv", COLUMNS, [asdict(p) for p in snapshot])
    write_csv(a.out_dir / "permits_updates.csv", UPDATE_COLUMNS, events)
    expected = {
        "source": "City of Calgary Building Permits (c2es-76ed), Open Government Licence – City of Calgary",
        "start": a.start, "cutoff": a.cutoff, "asof": a.asof,
        "snapshot_rows": len(snapshot),
        "update_events": len(events),
        "update_permits": len(latest),
        "permits_with_multiple_events": sum(1 for c in Counter(e["permit_num"] for e in events).values() if c > 1),
        "merge_matched_rows": matched,
        "merge_changed_rows": changed,
        "merge_inserted_rows": inserted,
        "final_rows": len(final),
        "communities_before_fix": len(codes),
        "community_codes_with_multiple_names": sorted(k for k, v in codes.items() if len(v) > 1),
        "answers": answers,
        "snapshot_status_counts": dict(Counter(p.status for p in snapshot).most_common()),
        "final_status_counts": dict(Counter(r["status"] for r in final.values()).most_common()),
    }
    (a.out_dir / "expected_counts.json").write_text(json.dumps(expected, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({k: v for k, v in expected.items() if not k.endswith("status_counts")}, indent=2))


if __name__ == "__main__":
    main()
