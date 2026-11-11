%dw 2.0
output application/java
// Renders the "Compliance Notification Email Format" prescribed by the use case.
// Plain text, line for line as in the specification; three optional blocks are added:
// secure-link delivery (FR12), data-quality warnings and an AI briefing (advisory only).
var r = payload
fun money(n) = (n default 0) as String {format: "#,##0.00"}
fun lines(arr) = arr joinBy "\n"
var toList = r.to default ((p('compliance.distribution.list') default "") splitBy "," map trim($) filter (sizeOf($) > 0))
var revision = if (r.isRevision default false) " (REVISION)" else ""
var subject = "$(r.reportType) $(r.runStatus) – $(r.entityCode) $(r.periodDate)" ++
              (if (r.isRevision default false) " (REVISION)" else "")

var nilBlock = if (r.isNilReport default false)
  lines([
    "• This is a NIL report. No transactions met the reporting criteria for",
    "  this period. The nil declaration has been recorded."
  ]) else null

var flagBlock = if (isEmpty(r.flagSummary default []))
  "• None"
  else lines((r.flagSummary default []) map ((f) ->
    "• $(f.flagCode) – $(f.count as String) transaction(s), $(r.currency) $(money(f.amount))"))

var deviationBlock = if (r.volumeDeviation default false)
  lines([
    "Attention: the reported volume differs from the trailing average by",
    "$((r.volumeDeviationPercent default 0) as String {format: '+#,##0.00;-#,##0.00'})%. Please confirm that this reflects genuine",
    "activity rather than an extraction problem."
  ]) else null

var deliveryBlock = if ((r.deliveryMethod default "ATTACHMENT") == "SECURE_LINK")
  lines([
    "Delivery",
    "The submission file exceeds the configured attachment size limit and is",
    "available through a secure, time-limited link instead of an attachment:",
    "  $(r.secureLink default '')",
    "  Link expires at: $(r.secureLinkExpiresAt default '')"
  ]) else null

var warningBlock = if (isEmpty(r.dataWarnings default [])) null
  else lines(["Data Quality Warnings"] ++ ((r.dataWarnings default []) map ("• " ++ $)))

var aiBlock = if (isEmpty(r.aiSummary default "")) null
  else lines([
    "AI Compliance Briefing (advisory only – not part of the regulatory submission)",
    r.aiSummary
  ])

var sections = [
  "Dear Compliance Officer,",
  "",
  "The scheduled regulatory report has been generated with status",
  "$(r.runStatus).",
  "",
  "Run ID: $(r.runId)",
  "Report Type: $(r.reportType)",
  "Reporting Entity: $(r.entityName) ($(r.entityCode))",
  "Reporting Period: $(r.periodStart) to $(r.periodEnd)",
  "Sequence Number: $((r.sequenceNumber as String {format: '000'}))$(revision)",
  "Generated At: $(r.completedAt)",
  "",
  "Report Contents",
  "• Flagged transactions reported : $(r.recordCount as String)",
  "• Total reported value        : $(r.currency) $(money(r.totalAmount))",
  "• Distinct customers          : $(r.customerCount as String)",
  "• Completeness check              : $(r.completenessOutcome)"
]
++ (if (nilBlock != null) [nilBlock] else [])
++ ["", "Flag Breakdown", flagBlock]
++ (if (deviationBlock != null) ["", deviationBlock] else [])
++ (if (warningBlock != null) ["", warningBlock] else [])
++ [
  "",
  "File Integrity",
  "• Submission file : $(r.submissionFileName)",
  "• Checksum        : $(r.fileChecksum)",
  "• Archived at : $(r.archiveFilePath)"
]
++ (if (deliveryBlock != null) ["", deliveryBlock] else [])
++ (if (aiBlock != null) ["", aiBlock] else [])
++ [
  "",
  "Please verify the checksum before onward submission to the regulator.",
  "",
  "Regards,",
  "Regulatory Reporting Integration"
]
---
{
  to:      toList,
  subject: subject,
  body:    lines(sections),
  // the caller decides what to attach (in SECURE_LINK mode it sends only the small summary)
  attachments: r.attachments default []
}
