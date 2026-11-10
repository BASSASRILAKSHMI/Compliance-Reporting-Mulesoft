%dw 2.0
output application/json
var r = payload[0]
---
{
  reportType:         r.report_type,
  entityCode:         r.entity_code,
  lastReportedUpto:   r.last_reported_upto,
  lastSuccessfulRun:  r.last_successful_run,
  lastSequenceNumber: (r.last_sequence_number default 0) as Number,
  updatedAt:          r.updated_at
}
