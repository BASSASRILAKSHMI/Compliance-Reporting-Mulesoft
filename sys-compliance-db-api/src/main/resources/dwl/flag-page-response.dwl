%dw 2.0
output application/json
// payload = up to (limit + 1) rows. The extra row only tells us another page exists.
var limit   = vars.pageParams.pageLimit
var hasMore = sizeOf(payload) > limit
var rows    = if (hasMore) payload[0 to limit - 1] else payload
var last    = rows[-1]
fun iso(ts) = if (ts == null) null else (ts replace " " with "T") ++ "+05:30"
---
{
  records: rows map {
    flagSeq:             $.flag_seq as Number,
    transactionId:       $.transaction_id,
    transactionDatetime: iso($.transaction_datetime),
    accountNumber:       $.account_number,
    customerId:          $.customer_id,
    customerName:        $.customer_name,
    customerType:        $.customer_type,
    customerMissing:     ($.customer_missing as Number) == 1,
    transactionType:     $.transaction_type,
    channel:             $.channel,
    currency:            $.currency,
    amount:              $.amount as Number,
    counterpartyName:    $.counterparty_name,
    counterpartyCountry: $.counterparty_country,
    flagCode:            $.flag_code,
    flagReason:          $.flag_reason,
    flaggedAt:           iso($.flagged_at),
    reviewedBy:          $.reviewed_by,
    reviewStatus:        $.review_status
  },
  count:   sizeOf(rows),
  hasMore: hasMore,
  nextCursor: if (hasMore) {
    afterFlaggedAt:     last.flagged_at,
    afterTransactionId: last.transaction_id,
    afterFlagCode:      last.flag_code
  } else null
}
