-- =====================================================================
--  n03_bad_data.sql  -  Negative Scenario 10: value that cannot be rendered
--
--  Three bad records, all in TODAY's period. Each one alone must make the
--  run FAIL before any file is written (no malformed report is ever issued).
--    a) customer name contains the field separator '|'  -> breaks the layout
--    b) negative amount                                  -> out of range
--    c) non-INR currency in an INR report                -> totals meaningless
--  Remove them afterwards with n99_cleanup_negative.sql
-- =====================================================================
USE compliance;
SET time_zone = '+05:30';

INSERT INTO customers (customer_id, customer_name, customer_type) VALUES
 ('CUST-80001', 'Ravi | Sons Traders', 'CORPORATE');

INSERT INTO transactions VALUES
 ('TXN-99158001', TIMESTAMP(CURDATE(),'12:10:00'), '00268001', 'CUST-80001', 'CASH_DEPOSIT',  'BRANCH', 'INR',  450000.00, 'Self',            'IN'),
 ('TXN-99158002', TIMESTAMP(CURDATE(),'12:20:00'), '00268002', 'CUST-70030', 'WIRE_TRANSFER', 'ONLINE', 'INR',   -5000.00, 'Refund Reversal', 'IN'),
 ('TXN-99158003', TIMESTAMP(CURDATE(),'12:30:00'), '00268003', 'CUST-70030', 'WIRE_TRANSFER', 'ONLINE', 'USD',   25000.00, 'Delta Partners',  'US');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 ('TXN-99158001', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(CURDATE(),'12:10:05'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99158002', 'FLG-HIGH-VALUE',   'Amount above reporting threshold',                  TIMESTAMP(CURDATE(),'12:20:05'), 'RISK_ANALYST_04', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99158003', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(CURDATE(),'12:30:05'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT');
COMMIT;
