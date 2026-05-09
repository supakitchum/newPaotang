# M10 Alert Channel Runbook

This runbook documents alert-channel readiness for local/dev QA. It does not approve production alert delivery.

## Local Dry Run

```sh
docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json
```

Dry run evaluates default policies and emits safe JSON. It does not write `partner_alert_events` and does not call external providers.

## Local Database / Log Delivery

```sh
docker compose exec platform-api php artisan platform:alerts:check --format=json
```

When `PLATFORM_ALERTS_ENABLED=true`, triggered policies write local rows to `partner_alert_events` and write a redacted log entry. External webhook/email/Sentry/Grafana/Datadog/New Relic delivery is intentionally not attempted in this slice.

## Default Policy Coverage

The default local policy catalog covers at least:

```text
api_error_rate_high
booking_fail_rate_high
checkout_fail_rate_high
sync_lag_high
queue_lag_high
reward_check_failure
permission_denied_spike
cross_tenant_access_attempt
```

Additional placeholder policies are present for CDN hit ratio, storage quota, API rate-limit count, payment callback failure, and partner health.

## Channel Behavior

| Channel | Local/dev behavior | Production gate |
| --- | --- | --- |
| database | Writes `partner_alert_events` when not dry-run and alerts are enabled | Ready as local event path |
| log | Writes redacted warning log when not dry-run and an alert triggers | Ready as local event path |
| webhook | Placeholder only; URL is redacted if configured | Needs real URL, secret management, retry policy, delivery QA |
| email | Placeholder only | Needs provider credentials and deliverability QA |
| Sentry | Placeholder only | Needs DSN/project and production secret management |
| Grafana | Dashboard templates only | Needs datasource, token, import, and alert contact point QA |
| Datadog/New Relic | Template/blocker only | Needs account/API keys and production agent deployment |

## Open Release Gates

Production observability remains blocked on external credentials and infrastructure. Keep these gates separate:

```text
Cloudflare HTTPS/WAF/rate-limit/CDN/R2 integration
real CDN/R2 ticket image load test
Horizon/Reverb hardening
scheduler workload registration
migration rehearsal/cutover/rollback
production secret management
Meno license compliance
npm audit remediation
back-office production-readiness risks
maintenance bypass list endpoint
backend menu category/icon fields
```
