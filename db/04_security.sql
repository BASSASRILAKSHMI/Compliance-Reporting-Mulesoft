-- =====================================================================
--  04_security.sql  :  least-privilege DB user for the Mule application
--
--  Why: the archive must be immutable (FR8, Negative Scenario 6).
--  TiDB does not support triggers, so immutability is enforced with GRANTS:
--  the Mule app's user can INSERT and SELECT on compliance_report_archive
--  but has NO UPDATE / DELETE right on it. Any overwrite attempt fails at
--  the database itself - even if the application has a bug.
--
--  BEFORE RUNNING (TiDB Cloud Starter):
--    1. Replace <PREFIX> with the prefix of your TiDB user.
--       Your admin user looks like  3pTAoNNxxxx.root  -> prefix = 3pTAoNNxxxx
--       TiDB Starter requires every user name to start with that prefix.
--    2. Replace <STRONG_PASSWORD> with a new password (save it in Notepad).
--    3. Run this script as the .root user.
--  Then use  <PREFIX>.mule_app  as the DB user in Mule (secure.properties).
-- =====================================================================

CREATE USER IF NOT EXISTS '<PREFIX>.mule_app'@'%' IDENTIFIED BY '<STRONG_PASSWORD>';

-- bank source data: read only (Mule never changes bank transactions)
GRANT SELECT                 ON compliance.customers                 TO '<PREFIX>.mule_app'@'%';
GRANT SELECT                 ON compliance.transactions              TO '<PREFIX>.mule_app'@'%';

-- flags: read + mark as REPORTED
GRANT SELECT, UPDATE         ON compliance.transaction_flags         TO '<PREFIX>.mule_app'@'%';

-- integration tables
GRANT SELECT, INSERT, UPDATE ON compliance.compliance_report_control TO '<PREFIX>.mule_app'@'%';
GRANT SELECT, INSERT, UPDATE ON compliance.compliance_report_runs    TO '<PREFIX>.mule_app'@'%';

-- archive: INSERT + SELECT only  ->  can never be overwritten or deleted
GRANT SELECT, INSERT         ON compliance.compliance_report_archive TO '<PREFIX>.mule_app'@'%';

FLUSH PRIVILEGES;

-- Check:
-- SHOW GRANTS FOR '<PREFIX>.mule_app'@'%';
