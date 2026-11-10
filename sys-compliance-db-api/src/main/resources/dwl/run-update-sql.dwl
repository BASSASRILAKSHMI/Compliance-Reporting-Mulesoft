%dw 2.0
output application/java
// Builds a safe dynamic UPDATE for PATCH /runs/{runId}.
// Only whitelisted properties become columns; values are always bound as named
// parameters, never concatenated into the SQL text -> no SQL injection.
var columns = {
  recordCount:        "record_count",
  totalAmount:        "total_amount",
  customerCount:      "customer_count",
  completenessOk:     "completeness_ok",
  isNilReport:        "is_nil_report",
  outputFilePath:     "output_file_path",
  archiveFilePath:    "archive_file_path",
  fileChecksum:       "file_checksum",
  detailChecksum:     "detail_checksum",
  prevChainHash:      "prev_chain_hash",
  chainHash:          "chain_hash",
  deliveryMethod:     "delivery_method",
  volumeDeviationPct: "volume_deviation_pct",
  notificationStatus: "notification_status",
  runStatus:          "run_status",
  errorCode:          "error_code",
  errorMessage:       "error_message",
  aiSummary:          "ai_summary",
  completedAt:        "completed_at"
}
var body   = payload filterObject ((v, k) -> columns[k as String] != null)
fun cut(s: String) = if (sizeOf(s) > 1000) s[0 to 999] else s
var values = body mapObject ((v, k) ->
  if ((k as String) == "errorMessage" and v != null) { (k): cut(v as String) }
  else { (k): v })
var setClause = (keysOf(body) map ((k) -> columns[k as String] ++ " = :" ++ (k as String))) joinBy ", "
---
{
  fieldCount: sizeOf(keysOf(body)),
  sql:        "UPDATE compliance_report_runs SET " ++ setClause ++ " WHERE run_id = :runId",
  params:     values ++ { runId: vars.runId }
}
