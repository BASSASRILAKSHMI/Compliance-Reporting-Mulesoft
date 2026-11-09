-- =====================================================================
--  n02_missing_customer.sql  -  Negative Scenario 9: missing reference data
--
--  A flagged transaction points to customer CUST-99999, which does NOT
--  exist in the customers table.
--  The PDF's INNER JOIN would silently drop this row from BOTH queries,
--  so the completeness check would wrongly pass.
--  Expected (our design): LEFT JOIN keeps the row, it is reported with the
--  documented placeholder customer_name = 'UNKNOWN_CUSTOMER' and
--  customer_type = 'UNKNOWN', and the email lists it under data warnings.
--  (If missing.customer.policy=FAIL is configured, the run fails instead.)
--
--  Lands in TODAY's period.
-- =====================================================================
USE compliance;
SET time_zone = '+05:30';

INSERT INTO transactions VALUES
 ('TXN-99159001', TIMESTAMP(CURDATE(),'11:30:00'), '00269001', 'CUST-99999', 'WIRE_TRANSFER', 'ONLINE', 'INR', 615000.00, 'Unity Overseas Ltd', 'AE');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 ('TXN-99159001', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',
  TIMESTAMP(CURDATE(),'11:30:08'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT');
COMMIT;
