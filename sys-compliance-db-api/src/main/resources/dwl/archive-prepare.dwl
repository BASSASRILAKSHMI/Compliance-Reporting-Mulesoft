%dw 2.0
import toHex, fromBase64 from dw::core::Binaries
import hashWith from dw::Crypto
output application/java
// Decodes the uploaded file, re-computes its SHA-256 and splits it into chunks.
// Chunks are cut on the base64 TEXT every 4,000,000 characters = exactly 3,000,000 bytes
// (a multiple of 3), so the base64 of the chunks can later be simply concatenated
// to rebuild the base64 of the whole file.
var b64       = (payload.contentBase64 default "") replace /\s+/ with ""
var bytes     = fromBase64(b64)
var actual    = lower(toHex(hashWith(bytes, "SHA-256")))
var chunkSize = 4000000
var total     = sizeOf(b64)
var chunkCnt  = if (total == 0) 1 else ceil(total / chunkSize)
---
{
  runId:            payload.runId,
  fileType:         payload.fileType,
  fileName:         payload.fileName,
  expectedChecksum: lower(payload.checksum default ""),
  actualChecksum:   actual,
  fileSize:         sizeOf(bytes),
  chunks: (0 to chunkCnt - 1) map ((i) -> {
    chunkNo: i,
    content: fromBase64(
      if (total == 0) ""
      else b64[(i * chunkSize) to (min([(i + 1) * chunkSize, total]) - 1)]
    )
  })
}
