-- =====================================================================
--  n99_cleanup_negative.sql  -  removes all data added by the n0x scripts
--  (only rows that have NOT been reported yet; reported rows are evidence
--   and are left alone)
-- =====================================================================
USE compliance;

DELETE FROM transaction_flags
WHERE report_status = 'PENDING_REPORT'
  AND (transaction_id LIKE 'TXN-HV-%'
       OR transaction_id IN ('TXN-99121500','TXN-99159001','TXN-99158001','TXN-99158002','TXN-99158003'));

DELETE t FROM transactions t
LEFT JOIN transaction_flags f ON f.transaction_id = t.transaction_id
WHERE f.transaction_id IS NULL
  AND (t.transaction_id LIKE 'TXN-HV-%'
       OR t.transaction_id IN ('TXN-99121500','TXN-99159001','TXN-99158001','TXN-99158002','TXN-99158003'));

DELETE c FROM customers c
LEFT JOIN transactions t ON t.customer_id = c.customer_id
WHERE c.customer_id = 'CUST-80001' AND t.transaction_id IS NULL;

COMMIT;
