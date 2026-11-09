# Database scripts – Use Case 12 Regulatory Compliance Reporting

Target: **TiDB Cloud Starter** (MySQL 8.0 compatible), database `compliance`.
All timestamps are **IST (+05:30)**. Business-day cutoff is **21:00 IST**.

## Run order

| # | Script | When |
|---|--------|------|
| 1 | `01_schema.sql` | Creates all 6 tables. Re-running **drops all data**. |
| 2 | `02_seed_data.sql` | Sample bank data + control row. Dates are relative to *today*. |
| 3 | `04_security.sql` | Once. Creates the least-privilege `mule_app` user (edit `<PREFIX>` / `<STRONG_PASSWORD>` first). |
| – | `99_expected_results.sql` | Any time. Shows what each run *should* report, plus run history. |

To reset everything for a fresh demo: run `01_schema.sql` then `02_seed_data.sql` again.

In DBeaver: open the script → **Alt + X** (Execute script) runs every statement.
In the TiDB web SQL Editor only the statement under the cursor runs, so use DBeaver.

## Seeded periods (T = the day the seed script is run)

| Period | Business date | Demonstrates | Records | Total (INR) | Customers |
|---|---|---|---|---|---|
| P1 | T-4 | Happy path – the exact rows of the PDF sample report | 3 | 2,378,500.00 | 3 |
| P2 | T-3 | NIL report | 0 | 0.00 | 0 |
| P3 | T-2 | Boundary start (21:00:00 exactly), boundary end (20:59:59), one txn with two flags | 5 | 5,355,000.00 | 4 |
| P4 | T-1 | Volume spike (deviation alert); flag at 21:00:00 of T-2 belongs here, not P3 | 12 | 9,417,000.00 | 12 |
| P5 | T | Tonight's scheduled run | 2 | 1,330,000.00 | 2 |

Control row starts at **T-5 21:00**, so the first run reports P1.

## Negative-scenario scripts (`negative/`)

| Script | Scenario | Expected behaviour |
|---|---|---|
| `n01_late_flag.sql` | Backdated flag inside an already-reported period (run after P1 is reported) | Late-flag sentinel alerts and offers a revision (seq 002) |
| `n02_missing_customer.sql` | NS 9 – customer record missing | Reported with placeholder `UNKNOWN_CUSTOMER` (or run fails, by config) – never silently dropped |
| `n03_bad_data.sql` | NS 10 – `|` in a name, negative amount, USD in an INR report | Run fails before any file is written |
| `n04_high_volume.sql` | NS 7 – 20,000 flags in today's period | Streamed with fetch size, complete file, no memory error |
| `n99_cleanup_negative.sql` | Removes the unreported rows added above | – |

## Changes to the PDF DDL (all marked `[EXT-n]` in `01_schema.sql`)

- **EXT-1** `customers` and `transactions` tables created (used by the PDF queries but not defined).
- **EXT-2** Index on `transaction_flags (report_status, flagged_at)` for the nightly query.
- **EXT-3** Control table primary key is `(report_type, entity_code)` to allow several entities.
- **EXT-4** `sequence_number` is nullable: assigned only when a report is issued, so a failed run + retry don't collide on the unique key.
- **EXT-5** Defaults on `record_count`, `total_amount`, `completeness_ok` so early failures can be recorded.
- **EXT-6** Extra audit columns: report date, detail checksum, hash chain, revision link, delivery method, volume deviation, error details, AI summary.
- **EXT-7** `compliance_report_archive` table – durable, insert-only copy of every issued file (CloudHub disk is ephemeral). Overwrite blocked by primary key; update/delete blocked by grants (`04_security.sql`).

## Tested

Scripts were executed end to end on a MySQL-compatible engine:
expected figures above verified with `99_expected_results.sql`; the PDF extraction
query on P1 returns exactly the 3 sample rows; with the `mule_app` user,
UPDATE and DELETE on the archive are denied and a duplicate INSERT is rejected.
