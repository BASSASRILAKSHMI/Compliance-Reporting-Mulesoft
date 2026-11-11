%dw 2.0
output application/json
// Request to an OpenAI-compatible chat endpoint (Groq).
// PRIVACY: only aggregates are sent - never names, account numbers or transaction ids.
var c = vars.ctx
var facts = {
  report:            "Suspicious Transaction Report",
  businessDate:      c.reportDate,
  isRevision:        c.isRevision,
  isNilReport:       c.isNil,
  currency:          c.currency,
  flaggedRecords:    c.recordCount,
  totalValue:        c.totalAmount,
  distinctCustomers: c.customerCount,
  breakdownByFlag:   c.byFlag,
  trailingAverageRecords:  vars.deviation.average,
  volumeDeviationPercent:  vars.deviation.pct,
  deviationAboveThreshold: vars.deviation.flagged,
  customersWithMissingMasterData: sizeOf((c.warnings default []) filter ($ contains "not found"))
}
---
{
  model: p('ai.model'),
  temperature: 0.2,
  max_tokens: 220,
  messages: [
    {
      role: "system",
      content: "You are a bank compliance analyst writing a short briefing for the compliance officer about today's suspicious transaction report. Use ONLY the figures provided. Write 3 to 4 plain sentences, no bullet points, no greetings. Mention the dominant flag type by share of value. If deviationAboveThreshold is true, say whether the change looks more like genuine activity or an upstream extraction or flagging problem, and why, based on the breakdown. If customersWithMissingMasterData is above zero, mention it. Never invent names, accounts or numbers."
    },
    { role: "user", content: write(facts, "application/json", {indent: false}) }
  ]
}
