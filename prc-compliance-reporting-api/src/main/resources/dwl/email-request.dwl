%dw 2.0
import iso from dwl::report
import toBase64 from dw::core::Binaries
output application/json
// Request body for sys-notification-api POST /notifications/compliance-report
var c = vars.ctx
var d = vars.delivery
---
{
  runStatus:           "SUCCESS",
  runId:               vars.runId,
  reportType:          c.reportType,
  entityCode:          c.entityCode,
  entityName:          c.entityName,
  periodDate:          c.reportDate,
  periodStart:         iso(c.periodStart),
  periodEnd:           iso(c.periodEnd),
  sequenceNumber:      c.sequenceNumber,
  isRevision:          c.isRevision,
  revisionOfRunId:     vars.revisionOfRunId,
  completedAt:         iso(c.generatedAt),
  currency:            c.currency,
  recordCount:         c.recordCount,
  totalAmount:         c.totalAmount,
  customerCount:       c.customerCount,
  completenessOutcome: "PASSED (" ++ (c.recordCount as String) ++ " records match the independent aggregate)",
  isNilReport:         c.isNil,
  flagSummary:         c.byFlag,
  volumeDeviation:     vars.deviation.flagged,
  volumeDeviationPercent: vars.deviation.pct,
  submissionFileName:  c.fileName,
  summaryFileName:     c.summaryFileName,
  fileChecksum:        c.fileChecksum,
  archiveFilePath:     c.archivePath,
  deliveryMethod:      d.method,
  secureLink:          d.link,
  secureLinkExpiresAt: if (d.expiresAt == null) null else iso(d.expiresAt),
  // the summary is always attached; the submission file only when within the size limit
  attachments: (if (d.method == "ATTACHMENT")
                  [{ fileName: c.fileName, contentType: "text/csv", contentBase64: toBase64(vars.fileBytes) }]
                else [])
               ++ [{ fileName: c.summaryFileName, contentType: "text/html", contentBase64: toBase64(vars.summaryBytes) }],
  dataWarnings:        c.warnings,
  aiSummary:           vars.aiSummary
}
