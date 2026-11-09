-- =====================================================================
--  n01_late_flag.sql  -  Late / backdated flag (Trap 7, sentinel feature)
--
--  An analyst confirms a flag TODAY, but its flagged_at falls inside P1
--  (T-4), a period that has ALREADY been reported.
--  The normal window query will never pick it up (its window has moved on).
--  Expected: the late-flag sentinel detects it, alerts the compliance officer
--            and offers a REVISION run for that date (sequence 002).
--
--  Run ONLY AFTER the P1 report (T-4) has been issued.
-- =====================================================================
USE compliance;
SET time_zone = '+05:30';
SET @D0 = DATE_SUB(CURDATE(), INTERVAL 4 DAY);

INSERT INTO transactions VALUES
 ('TXN-99121500', TIMESTAMP(@D0,'19:45:10'), '00221999', 'CUST-70029', 'WIRE_TRANSFER', 'ONLINE', 'INR', 1475000.00, 'Blackwater Capital Ltd', 'VG');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 ('TXN-99121500', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction (late review)',
  TIMESTAMP(@D0,'19:45:30'), 'RISK_ANALYST_08', 'CONFIRMED', 'PENDING_REPORT');
COMMIT;
