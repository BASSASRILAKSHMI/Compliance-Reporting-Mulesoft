%dw 2.0
/**
 * token.dwl - verifies secure download tokens issued by prc-compliance-reporting-api.
 * Token format:  <runId>.<fileType>.<yyyyMMddHHmmss expiry, IST>.<hex HMAC-SHA256 of the first three parts>
 * Must stay in step with secureToken() in prc .../dwl/report.dwl.
 */
import HMACWith from dw::Crypto
import try from dw::Runtime

fun nowIst(): LocalDateTime = (now() >> "Asia/Kolkata") as LocalDateTime

fun checkToken(token: String, secret: String, nowLdt: LocalDateTime): Object = do {
    var parts = token splitBy "."
    ---
    if (sizeOf(parts) != 4) { valid: false, status: 403, reason: "MALFORMED_TOKEN" }
    else do {
        var data     = parts[0 to 2] joinBy "."
        var expected = lower(HMACWith(secret as Binary {encoding: "UTF-8"}, data as Binary {encoding: "UTF-8"}, "HmacSHA256"))
        // signature is checked BEFORE the expiry is parsed, so a forged/garbage token never reaches the parser
        ---
        if (expected != lower(parts[3])) { valid: false, status: 403, reason: "INVALID_SIGNATURE" }
        else do {
            var parsed = try(() -> parts[2] as LocalDateTime {format: "yyyyMMddHHmmss"})
            ---
            if (parsed.success == false)                 { valid: false, status: 403, reason: "MALFORMED_TOKEN" }
            else if ((parsed.result as LocalDateTime) < nowLdt) { valid: false, status: 410, reason: "LINK_EXPIRED", expiredAt: (parsed.result as LocalDateTime) as String {format: "yyyy-MM-dd HH:mm:ss"} }
            else { valid: true, runId: parts[0], fileType: parts[1], expiresAt: (parsed.result as LocalDateTime) as String {format: "yyyy-MM-dd HH:mm:ss"} }
        }
    }
}
