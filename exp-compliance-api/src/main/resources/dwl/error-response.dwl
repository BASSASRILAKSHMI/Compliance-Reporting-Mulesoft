%dw 2.0
output application/json
// downstream system APIs answer with { errorCode, message }: surface their message when present
var ds = error.errorMessage.payload default null
---
{
  errorCode: vars.errorCode default "INTERNAL_ERROR",
  message: (if (ds is Object) (ds.message default error.description) else error.description) default "Unexpected error",
  correlationId: correlationId
}
