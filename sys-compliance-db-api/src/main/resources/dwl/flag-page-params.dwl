%dw 2.0
output application/java
// Builds the named parameters of the paged extraction query.
// A cursor of ("1970-01-02 00:00:00", "", "") means "from the first row".
var q = attributes.queryParams
var limit = (q.limit default p('flags.pageSize')) as Number
---
{
  periodStart:         q.periodStart,
  periodEnd:           q.periodEnd,
  mode:                q.mode default "PENDING",
  runId:               q.runId default "",
  afterFlaggedAt:      q.afterFlaggedAt default "1970-01-02 00:00:00",
  afterTransactionId:  q.afterTransactionId default "",
  afterFlagCode:       q.afterFlagCode default "",
  missingCustomerName: p('report.missingCustomer.name'),
  missingCustomerType: p('report.missingCustomer.type'),
  pageLimit:           limit,
  fetchLimit:          limit + 1
}
