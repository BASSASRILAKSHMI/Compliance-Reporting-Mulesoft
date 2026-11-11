%dw 2.0
/**
 * report.dwl - every business rule of the regulatory report in one testable module.
 *
 *   Periods      nextCutoff, pendingPeriods, revisionPeriod
 *   File layout  fileName, headerLine, detailLine, trailerLine   (H / D / T, '|' separated, LF)
 *   Validation   recordIssues                                     (NS 9, NS 10)
 *   Integrity    sha256Hex, chainHash, secureToken                (FR9, hash chain, FR12)
 *   Analytics    deviationPct                                     (FR11)
 *
 * All local date-times are IST and carried as "yyyy-MM-dd HH:mm:ss" strings.
 */
import toHex, toBase64 from dw::core::Binaries
import hashWith, HMACWith from dw::Crypto

var TS_FORMAT  = "yyyy-MM-dd HH:mm:ss"
var IST_OFFSET = "+05:30"
var SEP        = "|"

// ------------------------------------------------------------------ time
fun ts(s: String): LocalDateTime = s as LocalDateTime {format: TS_FORMAT}
fun fmt(d: LocalDateTime): String = d as String {format: TS_FORMAT}
fun iso(s: String): String = (s replace " " with "T") ++ IST_OFFSET
fun nowIst(): String = fmt((now() >> "Asia/Kolkata") as LocalDateTime)

// first cutoff strictly after `start`
fun nextCutoff(start: String, cutoff: String): String = do {
    var s = ts(start)
    var sameDay = (s as Date) ++ (cutoff as LocalTime {format: "HH:mm:ss"})
    ---
    fmt(if (sameDay > s) sameDay else sameDay + |P1D|)
}

// every complete period between the bookmark and `nowTs`, oldest first, at most `max`
fun pendingPeriods(lastUpto: String, nowTs: String, cutoff: String, max: Number): Array = do {
    fun build(start: String, acc: Array): Array = do {
        var end = nextCutoff(start, cutoff)
        ---
        if (sizeOf(acc) >= max or ts(end) > ts(nowTs)) acc
        else build(end, acc << { periodStart: start, periodEnd: end, reportDate: (ts(end) as Date) as String })
    }
    ---
    build(lastUpto, [])
}

// the period whose cutoff falls on `reportDate`
fun revisionPeriod(reportDate: String, cutoff: String): Object = do {
    var end = (reportDate as Date) ++ (cutoff as LocalTime {format: "HH:mm:ss"})
    ---
    { periodStart: fmt(end - |P1D|), periodEnd: fmt(end), reportDate: reportDate }
}

// ------------------------------------------------------------------ formatting
fun money(n): String = (n default 0) as Number as String {format: "0.00", locale: "en_US"}
fun seq3(n): String = n as String {format: "000"}
fun clean(v): String = if (v == null) "" else v as String

fun fileName(entity: String, reportType: String, reportDate: String, sequence: Number, suffix: String = ".csv"): String =
    entity ++ "_" ++ reportType ++ "_" ++ (reportDate replace "-" with "") ++ "_" ++ seq3(sequence) ++ suffix

// H | entity code | entity name | report type | period date | generated at | sequence | currency
fun headerLine(h: Object): String =
    ["H", clean(h.entityCode), clean(h.entityName), clean(h.reportType), clean(h.reportDate),
     iso(clean(h.generatedAt)), seq3(h.sequenceNumber), clean(h.currency)]
    joinBy SEP

// D | serial | 18 business fields, in the mandated order
fun detailLine(r: Object, serial: Number): String =
    ["D", serial as String,
     clean(r.transactionId), clean(r.transactionDatetime), clean(r.accountNumber),
     clean(r.customerId), clean(r.customerName), clean(r.customerType),
     clean(r.transactionType), clean(r.channel), clean(r.currency), money(r.amount),
     clean(r.counterpartyName), clean(r.counterpartyCountry),
     clean(r.flagCode), clean(r.flagReason), clean(r.flaggedAt),
     clean(r.reviewedBy), clean(r.reviewStatus)]
    joinBy SEP

// T | record count | total amount | distinct customers | generated at | detail checksum (or NIL_REPORT)
fun trailerLine(t: Object): String =
    ["T", clean(t.recordCount), money(t.totalAmount), clean(t.customerCount), iso(clean(t.generatedAt)),
     if (t.recordCount == 0) "NIL_REPORT" else clean(t.detailChecksum)]
    joinBy SEP

// ------------------------------------------------------------------ validation
var TEXT_FIELDS = ["transactionId", "accountNumber", "customerId", "customerName", "customerType",
                   "transactionType", "channel", "currency", "counterpartyName", "counterpartyCountry",
                   "flagCode", "flagReason", "reviewedBy", "reviewStatus"]
var REQUIRED    = ["transactionId", "transactionDatetime", "accountNumber", "customerId", "amount", "flagCode", "flaggedAt"]

// returns { errors: [...], warnings: [...] } for one record
fun recordIssues(r: Object, currency: String, maxAmount: Number, missingPolicy: String): Object = do {
    var id = r.transactionId default "?"
    var missing  = REQUIRED filter (r[$] == null or (r[$] is String and isEmpty(r[$] as String)))
    var badChars = TEXT_FIELDS filter (r[$] != null and ((r[$] as String) matches /(?s).*[|\r\n].*/))
    var amt = r.amount default 0
    var errs = (missing map "$(id): required field '$($)' is empty")
            ++ (badChars map "$(id): field '$($)' contains a reserved character ('|' or line break)")
            ++ (if (amt < 0) ["$(id): negative amount $(amt as String)"] else [])
            ++ (if (amt > maxAmount) ["$(id): amount $(amt as String) exceeds the permitted maximum"] else [])
            ++ (if (r.currency != null and r.currency != currency) ["$(id): currency $(r.currency) not allowed in this $(currency) report"] else [])
            ++ (if ((r.customerMissing default false) and missingPolicy == "FAIL") ["$(id): customer $(r.customerId default '') not found"] else [])
    var warns = if ((r.customerMissing default false) and missingPolicy != "FAIL")
                  ["$(id): customer $(r.customerId default '') not found - reported as $(r.customerName default '')"] else []
    ---
    { errors: errs, warnings: warns }
}

// ------------------------------------------------------------------ integrity
fun sha256Hex(b: Binary): String = lower(toHex(hashWith(b, "SHA-256")))
fun sha256Text(s: String): String = sha256Hex(s as Binary {encoding: "UTF-8"})

// each issued report is linked to the previous one
fun chainHash(prev: String, fileChecksum: String): String = sha256Text(prev ++ ":" ++ fileChecksum)

// URL-safe, tamper-proof, expiring download token: runId.fileType.yyyyMMddHHmmss.hmacSha256
fun secureToken(runId: String, fileType: String, expiresAt: String, secret: String): String = do {
    var data = runId ++ "." ++ fileType ++ "." ++ (expiresAt replace /[-: ]/ with "")
    var sig  = lower(HMACWith(secret as Binary {encoding: "UTF-8"}, data as Binary {encoding: "UTF-8"}, "HmacSHA256"))
    ---
    data ++ "." ++ sig
}

// ------------------------------------------------------------------ analytics
// % difference against the trailing average of previous issued (non-revision) reports
fun deviationPct(current: Number, history: Array<Number>): Number | Null =
    if (sizeOf(history) == 0) null
    else do {
        var avg = sum(history) / sizeOf(history)
        ---
        if (avg == 0) (if (current == 0) 0 else 100)
        else ((current - avg) * 100 / avg) as String {format: "0.00", locale: "en_US"} as Number
    }
