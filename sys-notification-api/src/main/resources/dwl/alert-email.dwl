%dw 2.0
output application/java
// Operational alert email (failed run, completeness mismatch, missed schedule,
// unusual volume deviation, late flags, delivery failure).
var a = payload
var toList = a.to default ((p('alerts.distribution.list') default "") splitBy "," map trim($) filter (sizeOf($) > 0))
var scope = [a.reportType, a.entityCode, a.periodStart] filter ($ != null) joinBy " "
var subject = "[ALERT][$(a.severity)] $(a.alertType)" ++ (if (isEmpty(scope)) "" else " – " ++ scope)
var nowIst = (now() >> "Asia/Kolkata") as String {format: "yyyy-MM-dd'T'HH:mm:ssxxx"}
---
{
  to:      toList,
  subject: subject,
  body: ([
    "Regulatory Reporting Integration – operational alert",
    "",
    "Severity      : $(a.severity)",
    "Alert type    : $(a.alertType)",
    "Title         : $(a.title)",
    "Run ID        : $(a.runId default '-')",
    "Report        : $(a.reportType default '-') / $(a.entityCode default '-')",
    "Period        : $(a.periodStart default '-') to $(a.periodEnd default '-')",
    "Raised at     : $(nowIst)",
    "Correlation ID: $(a.correlationId default '-')",
    "",
    "Details",
    a.details,
    ""
  ] ++ (if (a.severity == "CRITICAL") [
    "The control timestamp was NOT advanced for the failed period, so the period will be",
    "retried rather than skipped. No partial report has been issued.",
    ""
  ] else []) ++ [
    "Regulatory Reporting Integration"
  ] joinBy "\n"),
  attachments: []
}
