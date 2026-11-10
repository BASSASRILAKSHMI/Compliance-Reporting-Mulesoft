# Regulatory Compliance Reporting – MuleSoft

Cognizant NPN MuleSoft Hackathon 2027 · **Use Case 12: Compliance – Regulatory Compliance Reporting**

Every night at 21:30 IST the integration reports all flagged (suspicious) transactions of the
business day to the compliance officer: it extracts them from the database, builds the
prescribed H/D/T submission file plus a readable summary, archives both immutably and emails them,
with full audit, no gaps, no overlaps and byte-identical regeneration.

## Architecture (API-led)

```
 Officer / Postman / AI agent (MCP)
              │
   ┌──────────▼───────────┐
   │  exp-compliance-api  │  Experience: re-run, runs, verify, secure download, hash-chain check
   └──────────┬───────────┘
   ┌──────────▼────────────────────┐  ◄── Scheduler 21:30 IST
   │ prc-compliance-reporting-api  │  Process: period control, paged extraction, completeness,
   └──────┬─────────────────┬──────┘           validation, H/D/T report, checksums, archive, alerts
   ┌──────▼──────────┐ ┌────▼─────────────────┐
   │ sys-compliance- │ │ sys-notification-api │  System: all SQL / all email
   │ db-api          │ └────┬─────────────────┘
   └──────┬──────────┘      │
        TiDB (MySQL)     Gmail SMTP
```

## Repository layout

| Folder | Contents |
|---|---|
| `db/` | Schema, seed data, least-privilege user, negative-scenario scripts |
| `compliance-domain/` | Domain project – shared HTTP listener for running all apps together in Studio |
| `sys-compliance-db-api/` | System API – database |
| `sys-notification-api/` | System API – email |
| `prc-compliance-reporting-api/` | Process API – nightly orchestration |
| `exp-compliance-api/` | Experience API – officer-facing endpoints |
| `docs/` | High Level Design, diagrams, demo script |

## Local ports (Studio)

| App | Port |
|---|---|
| exp-compliance-api | 8081 |
| prc-compliance-reporting-api | 8082 |
| sys-compliance-db-api | 8083 |
| sys-notification-api | 8084 |

On CloudHub every app listens on `8081` (the platform default) and is reached through its own URL.

## Secrets

Real credentials live only in each app's `config-secure-<env>.yaml`, encrypted with the
Mule Secure Properties tool. The encryption key is passed at runtime (`-Dmule.key=...` locally,
a protected property on CloudHub) and is never committed.
