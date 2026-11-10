%dw 2.0
// Shared mapping of a compliance_report_runs row (snake_case) to the API's Run type (camelCase).

fun bool(v) = v match {
  case b is Boolean -> b
  case n is Number  -> n == 1
  case s is String  -> (s == "1") or (lower(s) == "true")
  else -> false
}

fun num(v) = if (v == null) null else v as Number

fun mapRun(r) = {
  runId:              r.run_id,
  reportType:         r.report_type,
  entityCode:         r.entity_code,
  reportDate:         r.report_date,
  periodStart:        r.period_start,
  periodEnd:          r.period_end,
  sequenceNumber:     num(r.sequence_number),
  isRevision:         bool(r.is_revision),
  revisionOfRunId:    r.revision_of_run_id,
  recordCount:        (r.record_count default 0) as Number,
  totalAmount:        (r.total_amount default 0) as Number,
  customerCount:      num(r.customer_count),
  completenessOk:     bool(r.completeness_ok),
  isNilReport:        bool(r.is_nil_report),
  outputFilePath:     r.output_file_path,
  archiveFilePath:    r.archive_file_path,
  fileChecksum:       r.file_checksum,
  detailChecksum:     r.detail_checksum,
  prevChainHash:      r.prev_chain_hash,
  chainHash:          r.chain_hash,
  deliveryMethod:     r.delivery_method,
  volumeDeviationPct: num(r.volume_deviation_pct),
  notificationStatus: r.notification_status,
  triggeredBy:        r.triggered_by,
  runStatus:          r.run_status,
  errorCode:          r.error_code,
  errorMessage:       r.error_message,
  aiSummary:          r.ai_summary,
  startedAt:          r.started_at,
  completedAt:        r.completed_at,
  correlationId:      r.correlation_id
}
