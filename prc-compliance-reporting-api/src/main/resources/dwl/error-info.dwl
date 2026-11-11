%dw 2.0
output application/java
// Turns any Mule error raised during a run into a stable { code, message } for the audit record and alert.
var errNs = error.errorType.namespace default "MULE"
var errId = error.errorType.identifier default "UNKNOWN"
// error body returned by our own system APIs: { errorCode, message, correlationId }
var downstream = error.errorMessage.payload default null
var dsCode = if (downstream is Object) downstream.errorCode default null else null
var dsMsg  = if (downstream is Object) downstream.message default null else null
var code = errNs match {
  case "APP"  -> errId
  case "HTTP" -> dsCode default (if (errId == "BAD_GATEWAY") "EMAIL_DELIVERY_FAILED" else "DEPENDENCY_" ++ errId)
  case "FILE" -> "FILE_" ++ errId
  case "OS"   -> "RUN_LOCK_" ++ errId
  else        -> errNs ++ "_" ++ errId
}
---
{
  code:    code,
  message: (dsMsg default error.description default "Unexpected error") as String
}
