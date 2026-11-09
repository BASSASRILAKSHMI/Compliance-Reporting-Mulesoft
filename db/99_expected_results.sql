-- =====================================================================
--  99_expected_results.sql  :  what each run SHOULD report
--  Read-only. Run any time to check the Mule output against the database.
--  Uses the PDF's completeness aggregate, with report_status ignored so the
--  figures stay valid after periods have been reported.
-- =====================================================================

USE compliance;
SET time_zone = '+05:30';

-- 1. Control table (the bookmark)
SELECT report_type, entity_code, last_reported_upto, last_successful_run, updated_at
FROM compliance_report_control;

-- 2. Expected totals per business date (cutoff 21:00 IST)
--    business_date = the date on which the period's 21:00 cutoff falls
SELECT
  DATE(DATE_ADD(f.flagged_at, INTERVAL 3 HOUR))  AS business_date,
  MIN(f.flagged_at)                              AS first_flag,
  MAX(f.flagged_at)                              AS last_flag,
  COUNT(*)                                       AS record_count,
  SUM(t.amount)                                  AS total_amount,
  COUNT(DISTINCT t.customer_id)                  AS customer_count,
  SUM(f.report_status = 'PENDING_REPORT')        AS still_pending
FROM transaction_flags f
JOIN transactions t ON t.transaction_id = f.transaction_id
GROUP BY DATE(DATE_ADD(f.flagged_at, INTERVAL 3 HOUR))
ORDER BY business_date;
-- (Adding 3 hours maps 21:00:00 -> 00:00 next day, so a flag at exactly
--  21:00:00 is counted in the NEXT business date - same as the >= / < rule.)

-- 3. Run history
SELECT run_id, report_date, sequence_number, is_revision, record_count,
       total_amount, customer_count, is_nil_report, run_status,
       notification_status, triggered_by, LEFT(file_checksum, 16) AS checksum16
FROM compliance_report_runs
ORDER BY started_at;
