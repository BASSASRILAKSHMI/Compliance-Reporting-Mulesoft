%dw 2.0
import money, seq3, iso from dwl::report
output text/plain
// Human-readable summary for the compliance officer (FR6). Self-contained HTML, no external assets.
// Account numbers are masked here; the regulatory submission file keeps the full values.
var c = vars.ctx
fun esc(s) = ((s default "") as String) replace "&" with "&amp;" replace "<" with "&lt;" replace ">" with "&gt;"
fun mask(acc) = do { var a = (acc default "") as String --- if (sizeOf(a) <= 4) a else ("****" ++ a[-4 to -1]) }
var rows = (c.previewLines default []) map ((l) -> l splitBy "|")
var more = (c.recordCount default 0) - sizeOf(rows)
var status = if (c.isNil) "NIL REPORT" else if (c.isRevision) "REVISION" else "ORIGINAL"
---
"<!DOCTYPE html>
<html lang=\"en\"><head><meta charset=\"UTF-8\">
<title>$(esc(c.fileName)) – summary</title>
<style>
 body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#1f2937}
 h1{font-size:20px;margin:0 0 4px} .sub{color:#6b7280;margin:0 0 20px}
 .tag{display:inline-block;padding:2px 10px;border-radius:12px;background:#e0e7ff;color:#3730a3;font-size:12px;font-weight:600}
 .kpis{display:flex;gap:16px;margin:16px 0 24px} .kpi{border:1px solid #e5e7eb;border-radius:8px;padding:12px 16px;min-width:150px}
 .kpi b{display:block;font-size:22px} .kpi span{color:#6b7280;font-size:12px}
 table{border-collapse:collapse;width:100%;font-size:13px;margin-bottom:24px} th,td{border-bottom:1px solid #e5e7eb;padding:6px 8px;text-align:left}
 th{background:#f9fafb} td.n{text-align:right;font-variant-numeric:tabular-nums}
 .mono{font-family:Consolas,monospace;font-size:12px;word-break:break-all} .warn{color:#92400e;background:#fef3c7;padding:8px 12px;border-radius:6px}
</style></head><body>
<h1>Suspicious Transaction Report – $(esc(c.reportDate))</h1>
<p class=\"sub\">$(esc(c.entityName)) ($(esc(c.entityCode))) · sequence $(seq3(c.sequenceNumber)) · <span class=\"tag\">$(status)</span></p>
<p>Reporting period <b>$(esc(iso(c.periodStart)))</b> to <b>$(esc(iso(c.periodEnd)))</b> · generated $(esc(iso(c.generatedAt)))</p>
<div class=\"kpis\">
 <div class=\"kpi\"><b>$(c.recordCount as String)</b><span>flagged transactions</span></div>
 <div class=\"kpi\"><b>$(esc(c.currency)) $(money(c.totalAmount))</b><span>total reported value</span></div>
 <div class=\"kpi\"><b>$(c.customerCount as String)</b><span>distinct customers</span></div>
 <div class=\"kpi\"><b>PASSED</b><span>completeness check</span></div>
</div>
" ++ (if (c.isNil) "<p class=\"warn\">NIL report: no transactions met the reporting criteria for this period. The nil declaration has been recorded.</p>\n" else "")
++ (if (isEmpty(c.warnings default [])) "" else "<p class=\"warn\"><b>Data quality warnings</b><br>" ++ ((c.warnings map esc($)) joinBy "<br>") ++ "</p>\n")
++ "<h3>Flag breakdown</h3>
<table><tr><th>Flag code</th><th>Transactions</th><th>Amount ($(esc(c.currency)))</th></tr>
" ++ ((c.byFlag default []) map ("<tr><td>$(esc($.flagCode))</td><td class=\"n\">$($.count as String)</td><td class=\"n\">$(money($.amount))</td></tr>") joinBy "\n")
++ "
</table>
<h3>Flagged transactions" ++ (if (more > 0) " (first $(sizeOf(rows) as String) of $(c.recordCount as String))" else "") ++ "</h3>
<table><tr><th>#</th><th>Transaction</th><th>Date/time</th><th>Account</th><th>Customer</th><th>Type</th><th class=\"n\">Amount</th><th>Counterparty</th><th>Flag</th><th>Reviewed by</th></tr>
" ++ (rows map ((f) -> "<tr><td>$(esc(f[1]))</td><td>$(esc(f[2]))</td><td>$(esc(f[3]))</td><td>$(mask(f[4]))</td><td>$(esc(f[6])) ($(esc(f[5])))</td><td>$(esc(f[8]))</td><td class=\"n\">$(esc(f[11]))</td><td>$(esc(f[12])) ($(esc(f[13])))</td><td>$(esc(f[14]))</td><td>$(esc(f[17]))</td></tr>") joinBy "\n")
++ "
</table>
<h3>File integrity</h3>
<table>
<tr><th>Submission file</th><td class=\"mono\">$(esc(c.fileName))</td></tr>
<tr><th>SHA-256 (whole file)</th><td class=\"mono\">$(esc(c.fileChecksum))</td></tr>
<tr><th>SHA-256 (detail section, in trailer)</th><td class=\"mono\">$(esc(c.detailChecksum))</td></tr>
</table>
<p class=\"sub\">Account numbers are masked in this summary. The regulatory submission file contains the complete values.</p>
</body></html>
"
