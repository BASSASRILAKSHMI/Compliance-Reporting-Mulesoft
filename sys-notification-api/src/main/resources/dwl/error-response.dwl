%dw 2.0
output application/json
---
{
  errorCode: vars.errorCode default "INTERNAL_ERROR",
  message: error.description default "Unexpected error",
  correlationId: correlationId
}
