-- =====================================================================
--  Use Case 12 - Regulatory Compliance Reporting
--  01_schema.sql  :  creates all tables in the `compliance` database
--
--  Target DB : TiDB Cloud Starter (MySQL 8.0 compatible). Also runs on MySQL 8.
--  Run order : 01_schema.sql  ->  02_seed_data.sql
--  Safe to re-run: drops and recreates every table (ALL DATA IS LOST).
--
--  Tables
--    Bank source data (read by Mule)   : customers, transactions, transaction_flags
--    Integration data (written by Mule): compliance_report_control,
--                                        compliance_report_runs,
--                                        compliance_report_archive
--
--  Deviations from the PDF DDL are marked  [EXT-n]  and explained inline.
--  They are listed again in the HLD "Design decisions" section.
-- =====================================================================

USE compliance;

-- All timestamps in this project are Indian Standard Time.
SET time_zone = '+05:30';

DROP TABLE IF EXISTS compliance_report_archive;
DROP TABLE IF EXISTS compliance_report_runs;
DROP TABLE IF EXISTS compliance_report_control;
DROP TABLE IF EXISTS transaction_flags;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS customers;

-- ---------------------------------------------------------------------
-- customers  [EXT-1]  used by the PDF queries but not defined in the PDF
-- ---------------------------------------------------------------------
CREATE TABLE customers (
  customer_id    VARCHAR(20)  PRIMARY KEY,
  customer_name  VARCHAR(120) NOT NULL,
  customer_type  VARCHAR(20)  NOT NULL,          -- INDIVIDUAL | CORPORATE
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- transactions  [EXT-1]  used by the PDF queries but not defined in the PDF
--   No foreign key to customers on purpose: in a real bank these come from
--   different systems, and Negative Scenario 9 (missing customer) must be
--   reproducible.
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
  transaction_id        VARCHAR(30)   PRIMARY KEY,
  transaction_datetime  TIMESTAMP     NOT NULL,
  account_number        VARCHAR(20)   NOT NULL,
  customer_id           VARCHAR(20)   NOT NULL,
  transaction_type      VARCHAR(30)   NOT NULL,  -- CARD_PAYMENT | WIRE_TRANSFER | CASH_DEPOSIT ...
  channel               VARCHAR(20)   NOT NULL,  -- ONLINE | BRANCH | ATM | MOBILE
  currency              CHAR(3)       NOT NULL,
  amount                DECIMAL(18,2) NOT NULL,
  counterparty_name     VARCHAR(120),
  counterparty_country  CHAR(2),
  KEY idx_txn_customer (customer_id)
);

-- ---------------------------------------------------------------------
-- transaction_flags  (PDF DDL + index)
--   report_status : PENDING_REPORT -> REPORTED (set by Mule in the same DB
--                   transaction that advances the control table)
-- ---------------------------------------------------------------------
CREATE TABLE transaction_flags (
  flag_seq         BIGINT       AUTO_INCREMENT PRIMARY KEY,
  transaction_id   VARCHAR(30)  NOT NULL,
  flag_code        VARCHAR(30)  NOT NULL,
  flag_reason      VARCHAR(255),
  flagged_at       TIMESTAMP    NOT NULL,
  reviewed_by      VARCHAR(40),
  review_status    VARCHAR(20),
  report_status    VARCHAR(25)  NOT NULL,
  reported_run_id  VARCHAR(40),
  UNIQUE KEY uk_txn_flag (transaction_id, flag_code),
  -- [EXT-2] the extraction query filters on these two columns every night
  KEY idx_flag_status_time (report_status, flagged_at),
  KEY idx_flag_run (reported_run_id),
  CONSTRAINT fk_flag_txn FOREIGN KEY (transaction_id)
    REFERENCES transactions (transaction_id)
);

-- ---------------------------------------------------------------------
-- compliance_report_control  (the "bookmark")
--   [EXT-3] PRIMARY KEY is (report_type, entity_code) instead of report_type
--           alone, so more than one reporting entity can be supported.
-- ---------------------------------------------------------------------
CREATE TABLE compliance_report_control (
  report_type           VARCHAR(20) NOT NULL,
  entity_code           VARCHAR(20) NOT NULL,
  last_reported_upto    TIMESTAMP   NOT NULL,   -- exclusive end of last reported period
  last_successful_run   VARCHAR(40),
  last_sequence_number  INT         DEFAULT 0,
  updated_at            TIMESTAMP,
  PRIMARY KEY (report_type, entity_code)
);

-- ---------------------------------------------------------------------
-- compliance_report_runs  (audit record - one row per run, success or failure)
--
--   [EXT-4] sequence_number is NULLABLE.
--           The PDF has it NOT NULL inside the unique key
--           (report_type, entity_code, period_start, sequence_number).
--           A run row is inserted when the run STARTS. If that run fails and is
--           retried, the retry would need the same sequence number -> unique key
--           violation. So the sequence is assigned only when a report is actually
--           ISSUED. Failed runs keep NULL, and MySQL/TiDB unique keys allow many
--           NULLs, so issued reports still can never share a sequence number.
--
--   [EXT-5] record_count / total_amount / completeness_ok get defaults so a run
--           that fails before extraction can still be recorded.
--
--   [EXT-6] extra audit columns:
--           report_date        business date the period closes on
--           detail_checksum    SHA-256 of the D records (goes in the trailer)
--           file_checksum      (PDF column) SHA-256 of the whole submission file
--           prev_chain_hash /
--           chain_hash         tamper-evident hash chain across all issued runs
--           revision_of_run_id run this one revises (NULL for originals)
--           delivery_method    ATTACHMENT | SECURE_LINK
--           volume_deviation_pct / previous-period comparison (FR11)
--           error_code / error_message for failed runs
--           ai_summary         advisory AI narrative (never part of the submission)
-- ---------------------------------------------------------------------
CREATE TABLE compliance_report_runs (
  run_id               VARCHAR(40)   PRIMARY KEY,
  report_type          VARCHAR(20)   NOT NULL,
  entity_code          VARCHAR(20)   NOT NULL,
  report_date          DATE,                                    -- [EXT-6]
  period_start         TIMESTAMP     NOT NULL,
  period_end           TIMESTAMP     NOT NULL,
  sequence_number      INT           NULL,                      -- [EXT-4]
  is_revision          BOOLEAN       DEFAULT FALSE,
  revision_of_run_id   VARCHAR(40),                             -- [EXT-6]
  record_count         INT           NOT NULL DEFAULT 0,        -- [EXT-5]
  total_amount         DECIMAL(18,2) NOT NULL DEFAULT 0.00,     -- [EXT-5]
  customer_count       INT,
  completeness_ok      BOOLEAN       NOT NULL DEFAULT FALSE,    -- [EXT-5]
  is_nil_report        BOOLEAN       DEFAULT FALSE,
  output_file_path     VARCHAR(300),
  archive_file_path    VARCHAR(300),
  file_checksum        VARCHAR(80),
  detail_checksum      VARCHAR(80),                             -- [EXT-6]
  prev_chain_hash      VARCHAR(80),                             -- [EXT-6]
  chain_hash           VARCHAR(80),                             -- [EXT-6]
  delivery_method      VARCHAR(20),                             -- [EXT-6]
  volume_deviation_pct DECIMAL(9,2),                            -- [EXT-6]
  notification_status  VARCHAR(20),     -- PENDING | SENT | FAILED
  triggered_by         VARCHAR(60)   NOT NULL,   -- SCHEDULER | user:<name> | SENTINEL
  run_status           VARCHAR(20)   NOT NULL,   -- STARTED | SUCCESS | FAILED
  error_code           VARCHAR(60),                             -- [EXT-6]
  error_message        VARCHAR(1000),                           -- [EXT-6]
  ai_summary           TEXT,                                    -- [EXT-6]
  started_at           TIMESTAMP     NULL,
  completed_at         TIMESTAMP     NULL,
  correlation_id       VARCHAR(50),
  UNIQUE KEY uk_report_period (report_type, entity_code, period_start, sequence_number),
  KEY idx_runs_status (report_type, entity_code, run_status, completed_at)
);

-- ---------------------------------------------------------------------
-- compliance_report_archive  [EXT-7]  durable copy of every issued file
--   Why: CloudHub workers have an ephemeral disk. Files written by the File
--   connector are lost on restart/redeploy, so the File connector writes the
--   working + archive copies, and this table keeps the permanent, byte-exact
--   copy used for verification, reproduction and the secure download link.
--   The application only ever INSERTs here (see 04_security.sql for the
--   grant-level enforcement). The composite primary key makes a second write
--   of the same file fail instead of overwriting it.
--   Note: TiDB limits a single row to about 6 MB, so files above that size
--   are stored in several chunks (chunk_no 0, 1, 2 ...).
-- ---------------------------------------------------------------------
CREATE TABLE compliance_report_archive (
  run_id        VARCHAR(40)  NOT NULL,
  file_type     VARCHAR(20)  NOT NULL,         -- SUBMISSION | SUMMARY | SIGNATURE
  chunk_no      INT          NOT NULL DEFAULT 0,
  file_name     VARCHAR(200) NOT NULL,
  content       LONGBLOB     NOT NULL,
  file_size     BIGINT       NOT NULL,         -- size of the whole file, same on every chunk
  checksum      VARCHAR(80)  NOT NULL,         -- SHA-256 of the whole file
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (run_id, file_type, chunk_no),
  KEY idx_archive_name (file_name)
);
