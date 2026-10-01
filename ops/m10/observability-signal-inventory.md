# M10 Observability Signal Inventory

This artifact is local/dev verifiable readiness evidence. It is not staging, production, or client-delivery approval.

Run the machine-readable report through Docker:

```sh
docker compose exec platform-api php artisan platform:observability:report --format=json
```

## Signal Summary

| Signal | Local status | Data source | Validation |
| --- | --- | --- | --- |
| API request/error/latency | partial | health endpoints, logs, `partner_daily_usage_summaries` | `platform:observability:report` |
| DB health | ready local | PostgreSQL connection | `platform:smoke` |
| Cache health | ready local | Redis/Valkey cache check | `platform:smoke` |
| Queue lag | partial | `jobs`, worker command path | `platform:alerts:check --dry-run` |
| Partner sync lag | ready local | `sync_inbox`, `sync_outbox` | `platform:alerts:check --dry-run` |
| Booking failures | partial | daily summary/error counters where present | `platform:alerts:check --dry-run` |
| Checkout/wallet failures | partial | daily summary/error counters where present | `platform:alerts:check --dry-run` |
| Reward check failures | ready local | `reward_check_items` | `platform:alerts:check --dry-run` |
| Support access/security | ready local | support impersonation tables, `audit_logs` | `platform:observability:report` |
| Usage/billing sink | ready local | `partner_usage_meters`, `partner_usage_events`, `partner_daily_usage_summaries` | `platform:observability:report` |
| CDN ticket image metrics | blocked external | Cloudflare/CDN/R2 analytics | separate CDN/R2 slice |

## Required Labels

Metrics and alert payloads include partner/tenant-safe labels where applicable:

```text
platform
environment
module
partner_id
tenant_id
deployment_mode
package
endpoint
queue
game_id
```

## Redaction

Observability report and alert payloads recursively redact sensitive keys by name before output or local database/log delivery. Generated reports must not include webhook URLs, bearer tokens, API keys, DSNs, passwords, bank account data, or credential material.

## Production Boundary

The local/dev report verifies schema, command output, default policy coverage, labels, redaction, and local database/log delivery paths. Production delivery still needs real infrastructure ownership for webhook/email/Sentry/Grafana/Datadog/New Relic, Cloudflare analytics, CDN/R2 ticket image metrics, Horizon, Reverb, and secret management.
