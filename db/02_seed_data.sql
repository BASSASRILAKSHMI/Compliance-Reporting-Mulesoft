-- =====================================================================
--  Use Case 12 - Regulatory Compliance Reporting
--  02_seed_data.sql  :  sample bank data + control row
--
--  Run after 01_schema.sql. Dates are RELATIVE TO TODAY so the data is
--  always "recent" whenever the script is run.
--
--  Reporting period rule (business-day cutoff = 21:00 IST):
--      period for business date D  =  [ D-1 21:00:00 ,  D 21:00:00 )
--      start inclusive, end exclusive  -> no gaps, no overlaps
--
--  Let T = today.  The script creates five consecutive periods:
--
--  Period  Business date  What it demonstrates                     Expected
--  ------  -------------  ---------------------------------------  ------------------------------
--  P1      T-4            Happy path - the exact 3 rows of the     3 records, 2378500.00, 3 cust
--                         PDF sample report (ENT0091_STR_..._001)
--  P2      T-3            Nil report - no flags at all             0 records, 0.00, 0 cust
--  P3      T-2            Boundary start (flag at exactly 21:00:00 5 records, 5355000.00, 4 cust
--                         of T-3), boundary end (20:59:59),
--                         one transaction with TWO flags
--  P4      T-1            Volume spike for deviation alert,        12 records, 9417000.00, 12 cust
--                         flag at exactly 21:00:00 of T-2 (belongs
--                         to P4, NOT P3)
--  P5      T (today)      Tonight's scheduled run                   2 records, 1330000.00, 2 cust
--
--  Control table starts at T-5 21:00, i.e. "everything before P1 is
--  already reported". The first run therefore reports P1.
--  Expected figures can be re-checked any time with 99_expected_results.sql
-- =====================================================================

USE compliance;
SET time_zone = '+05:30';

SET @T  = CURDATE();
SET @D0 = DATE_SUB(@T, INTERVAL 4 DAY);   -- P1 business date
SET @D1 = DATE_SUB(@T, INTERVAL 3 DAY);   -- P2
SET @D2 = DATE_SUB(@T, INTERVAL 2 DAY);   -- P3
SET @D3 = DATE_SUB(@T, INTERVAL 1 DAY);   -- P4
SET @D4 = @T;                              -- P5 (today)
SET @DP = DATE_SUB(@T, INTERVAL 5 DAY);   -- day before P1

-- ---------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------
INSERT INTO customers (customer_id, customer_name, customer_type) VALUES
 ('CUST-77219', 'Meena Raghavan',            'INDIVIDUAL'),
 ('CUST-81140', 'Ganesh Iyer',               'INDIVIDUAL'),
 ('CUST-66207', 'Sunrise Exports Pvt Ltd',   'CORPORATE'),
 ('CUST-70011', 'Arjun Malhotra',            'INDIVIDUAL'),
 ('CUST-70012', 'Lakshmi Textiles Pvt Ltd',  'CORPORATE'),
 ('CUST-70013', 'Farhan Qureshi',            'INDIVIDUAL'),
 ('CUST-70014', 'Deccan Agro Traders LLP',   'CORPORATE'),
 ('CUST-70015', 'Priya Nair',                'INDIVIDUAL'),
 ('CUST-70016', 'Kavya Reddy',               'INDIVIDUAL'),
 ('CUST-70017', 'Horizon Logistics Ltd',     'CORPORATE'),
 ('CUST-70018', 'Rohit Verma',               'INDIVIDUAL'),
 ('CUST-70019', 'Sana Sheikh',               'INDIVIDUAL'),
 ('CUST-70020', 'Vikram Rao',                'INDIVIDUAL'),
 ('CUST-70021', 'Godavari Steel Works Ltd',  'CORPORATE'),
 ('CUST-70022', 'Anjali Deshpande',          'INDIVIDUAL'),
 ('CUST-70023', 'Coastal Seafoods Exports',  'CORPORATE'),
 ('CUST-70024', 'Imran Khan Pathan',         'INDIVIDUAL'),
 ('CUST-70025', 'Nikhil Joshi',              'INDIVIDUAL'),
 ('CUST-70026', 'Meridian Pharma Pvt Ltd',   'CORPORATE'),
 ('CUST-70027', 'Swathi Kulkarni',           'INDIVIDUAL'),
 ('CUST-70028', 'Blue Lotus Hotels Pvt Ltd', 'CORPORATE'),
 ('CUST-70029', 'Harish Chandra',            'INDIVIDUAL'),
 ('CUST-70030', 'Zenith Software Labs',      'CORPORATE');

-- ---------------------------------------------------------------------
-- P1  (T-4)  the 3 transactions from the PDF sample report
-- ---------------------------------------------------------------------
INSERT INTO transactions VALUES
 ('TXN-99120455', TIMESTAMP(@D0,'14:22:07'), '00214578', 'CUST-77219', 'CARD_PAYMENT',  'ONLINE', 'INR',  248500.00, 'Global Gadgets Online', 'SG'),
 ('TXN-99120781', TIMESTAMP(@D0,'16:40:55'), '00219004', 'CUST-81140', 'WIRE_TRANSFER', 'BRANCH', 'INR', 1150000.00, 'Orient Trading FZE',    'AE'),
 ('TXN-99121033', TIMESTAMP(@D0,'18:05:12'), '00221876', 'CUST-66207', 'CASH_DEPOSIT',  'BRANCH', 'INR',  980000.00, 'Self',                  'IN');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 ('TXN-99120455', 'FLG-HIGH-VALUE',   'Amount above reporting threshold',                  TIMESTAMP(@D0,'14:22:09'), 'RISK_ANALYST_04', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99120781', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D0,'16:41:02'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99121033', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D0,'18:05:20'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT');

-- ---------------------------------------------------------------------
-- Ordinary (NOT flagged) transactions on every day.
-- They must never appear in any report - proves the query filters correctly.
-- ---------------------------------------------------------------------
INSERT INTO transactions VALUES
 ('TXN-99120100', TIMESTAMP(@D0,'10:12:44'), '00231001', 'CUST-70016', 'UPI_PAYMENT',   'MOBILE', 'INR',   1250.00, 'Ratnadeep Supermarket', 'IN'),
 ('TXN-99120200', TIMESTAMP(@D0,'12:30:05'), '00231002', 'CUST-70025', 'CARD_PAYMENT',  'ONLINE', 'INR',   8999.00, 'Flipkart Internet',     'IN'),
 ('TXN-99125001', TIMESTAMP(@D1,'09:45:10'), '00231003', 'CUST-70022', 'UPI_PAYMENT',   'MOBILE', 'INR',    430.00, 'Chai Point',            'IN'),
 ('TXN-99125002', TIMESTAMP(@D1,'13:05:51'), '00231004', 'CUST-70030', 'NEFT_TRANSFER', 'ONLINE', 'INR',  65000.00, 'AWS India Pvt Ltd',     'IN'),
 ('TXN-99125003', TIMESTAMP(@D1,'18:20:33'), '00231005', 'CUST-70027', 'ATM_WITHDRAWAL','ATM',    'INR',  10000.00, 'Self',                  'IN'),
 ('TXN-99135001', TIMESTAMP(@D2,'11:00:00'), '00231006', 'CUST-70029', 'UPI_PAYMENT',   'MOBILE', 'INR',   2200.00, 'Apollo Pharmacy',       'IN'),
 ('TXN-99145001', TIMESTAMP(@D3,'16:16:16'), '00231007', 'CUST-70024', 'CARD_PAYMENT',  'ONLINE', 'INR',  15499.00, 'Amazon Seller Services','IN'),
 ('TXN-99155001', TIMESTAMP(@D4,'08:30:00'), '00231008', 'CUST-70023', 'NEFT_TRANSFER', 'ONLINE', 'INR',  42000.00, 'Coastal Ice Plant',     'IN');

-- P2 (T-3): intentionally NO flagged transactions -> NIL report

-- ---------------------------------------------------------------------
-- P3  (T-2)   window [T-3 21:00:00 , T-2 21:00:00)
-- ---------------------------------------------------------------------
INSERT INTO transactions VALUES
 ('TXN-99130001', TIMESTAMP(@D1,'20:59:50'), '00241001', 'CUST-70011', 'WIRE_TRANSFER', 'ONLINE', 'INR',  760000.00, 'Lionrock Holdings Ltd',   'HK'),
 ('TXN-99130002', TIMESTAMP(@D2,'11:15:30'), '00241002', 'CUST-70012', 'WIRE_TRANSFER', 'BRANCH', 'INR', 1890000.00, 'Al Noor General Trading', 'AE'),
 ('TXN-99130003', TIMESTAMP(@D2,'15:02:11'), '00241003', 'CUST-70013', 'CASH_DEPOSIT',  'BRANCH', 'INR',  495000.00, 'Self',                    'IN'),
 ('TXN-99130004', TIMESTAMP(@D2,'20:59:50'), '00241004', 'CUST-70014', 'WIRE_TRANSFER', 'ONLINE', 'INR',  320000.00, 'Sunshine Imports Co',     'CN');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 -- flagged at EXACTLY the period start -> belongs to P3 (start is inclusive)
 ('TXN-99130001', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D1,'21:00:00'), 'RISK_ANALYST_01', 'CONFIRMED', 'PENDING_REPORT'),
 -- one transaction, TWO flags -> two D records, but one distinct customer
 ('TXN-99130002', 'FLG-HIGH-VALUE',   'Amount above reporting threshold',                  TIMESTAMP(@D2,'11:15:34'), 'RISK_ANALYST_03', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99130002', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D2,'11:15:36'), 'RISK_ANALYST_03', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99130003', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D2,'15:02:20'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT'),
 -- last second of the period -> still P3 (end is exclusive)
 ('TXN-99130004', 'FLG-HIGH-VALUE',   'Amount above reporting threshold',                  TIMESTAMP(@D2,'20:59:59'), 'RISK_ANALYST_05', 'CONFIRMED', 'PENDING_REPORT');

-- ---------------------------------------------------------------------
-- P4  (T-1)   window [T-2 21:00:00 , T-1 21:00:00)   -> volume spike (12)
-- ---------------------------------------------------------------------
INSERT INTO transactions VALUES
 ('TXN-99140001', TIMESTAMP(@D2,'20:59:58'), '00251001', 'CUST-70015', 'CARD_PAYMENT',  'ONLINE', 'INR',  275000.00, 'Lux Watches International', 'CH'),
 ('TXN-99140002', TIMESTAMP(@D3,'09:10:15'), '00251002', 'CUST-70016', 'WIRE_TRANSFER', 'ONLINE', 'INR',  840000.00, 'Pacific Rim Ventures',      'SG'),
 ('TXN-99140003', TIMESTAMP(@D3,'09:55:40'), '00251003', 'CUST-70017', 'CASH_DEPOSIT',  'BRANCH', 'INR',  990000.00, 'Self',                      'IN'),
 ('TXN-99140004', TIMESTAMP(@D3,'10:42:03'), '00251004', 'CUST-70018', 'WIRE_TRANSFER', 'BRANCH', 'INR', 1250000.00, 'Gulf Star Trading LLC',     'AE'),
 ('TXN-99140005', TIMESTAMP(@D3,'11:30:27'), '00251005', 'CUST-70021', 'CASH_DEPOSIT',  'BRANCH', 'INR',  970000.00, 'Self',                      'IN'),
 ('TXN-99140006', TIMESTAMP(@D3,'12:05:09'), '00251006', 'CUST-70022', 'CARD_PAYMENT',  'ONLINE', 'INR',  312000.00, 'Crypto Exchange Global',    'MT'),
 ('TXN-99140007', TIMESTAMP(@D3,'13:48:51'), '00251007', 'CUST-70023', 'WIRE_TRANSFER', 'ONLINE', 'INR', 1680000.00, 'Ocean Bridge Holdings',     'CY'),
 ('TXN-99140008', TIMESTAMP(@D3,'14:20:00'), '00251008', 'CUST-70024', 'CASH_DEPOSIT',  'ATM',    'INR',  480000.00, 'Self',                      'IN'),
 ('TXN-99140009', TIMESTAMP(@D3,'15:33:18'), '00251009', 'CUST-70025', 'WIRE_TRANSFER', 'MOBILE', 'INR',  560000.00, 'Northwind Trading Ltd',     'HK'),
 ('TXN-99140010', TIMESTAMP(@D3,'17:01:44'), '00251010', 'CUST-70026', 'WIRE_TRANSFER', 'BRANCH', 'INR', 1390000.00, 'Medline Distributors FZE',  'AE'),
 ('TXN-99140011', TIMESTAMP(@D3,'18:47:29'), '00251011', 'CUST-70027', 'CARD_PAYMENT',  'ONLINE', 'INR',  265000.00, 'Royal Casino Online',       'MT'),
 ('TXN-99140012', TIMESTAMP(@D3,'20:12:36'), '00251012', 'CUST-70028', 'CASH_DEPOSIT',  'BRANCH', 'INR',  405000.00, 'Self',                      'IN');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 -- flagged at EXACTLY 21:00:00 of T-2 -> belongs to P4, must NOT appear in P3
 ('TXN-99140001', 'FLG-HIGH-VALUE',   'Amount above reporting threshold',                  TIMESTAMP(@D2,'21:00:00'), 'RISK_ANALYST_04', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140002', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D3,'09:10:22'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140003', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D3,'09:55:47'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140004', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D3,'10:42:10'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140005', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D3,'11:30:35'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140006', 'FLG-HIGH-RISK-MERCHANT', 'Payment to high risk merchant category',      TIMESTAMP(@D3,'12:05:15'), 'RISK_ANALYST_06', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140007', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D3,'13:48:58'), 'RISK_ANALYST_01', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140008', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D3,'14:20:09'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140009', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D3,'15:33:25'), 'RISK_ANALYST_03', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140010', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D3,'17:01:50'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140011', 'FLG-HIGH-RISK-MERCHANT', 'Payment to high risk merchant category',      TIMESTAMP(@D3,'18:47:33'), 'RISK_ANALYST_06', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99140012', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D3,'20:12:44'), 'RISK_ANALYST_05', 'CONFIRMED', 'PENDING_REPORT');

-- ---------------------------------------------------------------------
-- P5  (today)  window [T-1 21:00:00 , T 21:00:00)  -> tonight's scheduled run
-- ---------------------------------------------------------------------
INSERT INTO transactions VALUES
 ('TXN-99150001', TIMESTAMP(@D4,'09:05:12'), '00261001', 'CUST-70019', 'WIRE_TRANSFER', 'ONLINE', 'INR',  910000.00, 'Silverline Commodities', 'AE'),
 ('TXN-99150002', TIMESTAMP(@D4,'10:40:30'), '00261002', 'CUST-70020', 'CASH_DEPOSIT',  'BRANCH', 'INR',  420000.00, 'Self',                   'IN');

INSERT INTO transaction_flags (transaction_id, flag_code, flag_reason, flagged_at, reviewed_by, review_status, report_status) VALUES
 ('TXN-99150001', 'FLG-CROSS-BORDER', 'Cross border transfer to monitored jurisdiction',   TIMESTAMP(@D4,'09:05:20'), 'RISK_ANALYST_02', 'CONFIRMED', 'PENDING_REPORT'),
 ('TXN-99150002', 'FLG-STRUCTURING',  'Multiple deposits below threshold within 24 hours', TIMESTAMP(@D4,'10:40:41'), 'RISK_ANALYST_07', 'CONFIRMED', 'PENDING_REPORT');

-- ---------------------------------------------------------------------
-- Control row: everything up to T-5 21:00 is already reported
-- ---------------------------------------------------------------------
INSERT INTO compliance_report_control
  (report_type, entity_code, last_reported_upto, last_successful_run, last_sequence_number, updated_at)
VALUES
  ('STR', 'ENT0091', TIMESTAMP(@DP,'21:00:00'), NULL, 0, NOW());

COMMIT;
