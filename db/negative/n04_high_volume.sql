-- =====================================================================
--  n04_high_volume.sql  -  Negative Scenario 7: very large reporting day
--
--  Generates 20,000 flagged transactions in TODAY's period
--  (00:00:00 to about 16:40, one every 3 seconds).
--  Expected: Mule streams them with a fixed fetch size, never holds the
--  full result in memory, and the file still has 20,000 D records + the
--  extra seed rows, with trailer totals matching the aggregate query.
--  No recursion settings are needed: rows are generated from a 0-9 digit
--  table cross-joined five times (100,000 combinations, LIMIT 20000).
--  Remove them afterwards with n99_cleanup_negative.sql
-- =====================================================================
USE compliance;
SET time_zone = '+05:30';

INSERT INTO transactions
SELECT CONCAT('TXN-HV-', LPAD(n, 6, '0')),
       TIMESTAMP(CURDATE(), '00:00:00') + INTERVAL (n * 3) SECOND,
       CONCAT('009', LPAD(n MOD 50000, 5, '0')),
       CONCAT('CUST-700', LPAD(11 + (n MOD 20), 2, '0')),   -- spreads over CUST-70011..70030
       IF(n MOD 2 = 0, 'WIRE_TRANSFER', 'CASH_DEPOSIT'),
       IF(n MOD 3 = 0, 'BRANCH', 'ONLINE'),
       'INR',
       200000.00 + (n MOD 997) * 1000,
       IF(n MOD 2 = 0, 'Bulk Test Counterparty', 'Self'),
       IF(n MOD 2 = 0, 'AE', 'IN')
FROM (
  SELECT a.d + b.d*10 + c.d*100 + e.d*1000 + g.d*10000 + 1 AS n
  FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) g
) nums
WHERE n <= 20000;

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status)
SELECT t.transaction_id,
       IF(t.transaction_type = 'WIRE_TRANSFER', 'FLG-CROSS-BORDER', 'FLG-STRUCTURING'),
       IF(t.transaction_type = 'WIRE_TRANSFER', 'Cross border transfer to monitored jurisdiction',
                                                'Multiple deposits below threshold within 24 hours'),
       t.transaction_datetime + INTERVAL 5 SECOND,
       'RISK_ANALYST_BULK', 'CONFIRMED', 'PENDING_REPORT'
FROM transactions t
WHERE t.transaction_id LIKE 'TXN-HV-%';
COMMIT;
