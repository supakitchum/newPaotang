# 20260508-m10-production-observability-alerting Handoff

## Agent

Backend Develop

## Task

Implement M10 production observability and alert-channel readiness foundations for `apps/platform-api` with Docker-only validation, without claiming staging, production, Cloudflare/CDN/R2, Horizon/Reverb, migration, license, dependency, or back-office approval.

## What Was Done

- Added local/dev observability signal inventory and safe machine-readable report command.
- Added local/dev alert policy evaluation command with dry-run mode and safe database/log delivery path.
- Added additive observability tables for usage events, daily usage summaries, and alert events.
- Added Eloquent models for all new observability tables.
- Expanded demo/provisioning defaults so each partner keeps existing monitoring defaults and now receives required M10 alert policies.
- Added partner/tenant-safe labels and recursive secret redaction for observability reports and alert payloads.
- Added dashboard/runbook artifacts under `ops/m10/**`.
- Added scripts that run the new observability commands through Docker Compose.
- Added focused tests for command output shape, default policy coverage, alert event writes, redaction, labels, env boundary, and ops artifacts.

## Files Changed

Backend:

```text
apps/platform-api/.env.example
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/app/Console/Commands/PlatformObservabilityReportCommand.php
apps/platform-api/app/Console/Commands/PlatformAlertsCheckCommand.php
apps/platform-api/app/Models/PartnerUsageEvent.php
apps/platform-api/app/Models/PartnerDailyUsageSummary.php
apps/platform-api/app/Models/PartnerAlertEvent.php
apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php
apps/platform-api/app/Shared/Observability/ObservabilityCatalog.php
apps/platform-api/app/Shared/Observability/ObservabilityRedactor.php
apps/platform-api/app/Shared/Observability/ObservabilityReportService.php
apps/platform-api/app/Shared/Observability/AlertEvaluationService.php
apps/platform-api/database/migrations/2026_05_08_000001_create_observability_alerting_tables.php
apps/platform-api/database/seeders/DemoTenantSeeder.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php
```

Docs/Ops:

```text
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ops/m10/observability-signal-inventory.md
ops/m10/alert-channel-runbook.md
ops/m10/dashboards/platform-overview.json
ops/m10/dashboards/partner-health.json
scripts/platform-observability-report.sh
scripts/platform-alerts-check.sh
```

## Schema / Model / Service Changes

- Added `partner_usage_events` as a local usage-event sink with partner/tenant labels.
- Added `partner_daily_usage_summaries` as a local daily metrics summary sink.
- Added `partner_alert_events` as the local database alert event delivery path.
- Added models:
  - `PartnerUsageEvent`
  - `PartnerDailyUsageSummary`
  - `PartnerAlertEvent`
- Added shared observability services:
  - `ObservabilityCatalog`
  - `ObservabilityRedactor`
  - `ObservabilityReportService`
  - `AlertEvaluationService`
- Updated partner provisioning and demo seeding to preserve existing defaults and seed M10 alert policies.

## Observability Signal Inventory Summary

`platform:observability:report --format=json` reports:

```text
API request/error/latency: partial local readiness
DB health: ready local
Cache health: ready local
Queue lag: partial local readiness
Partner sync lag: ready local
Booking failures: partial local readiness
Checkout/wallet failures: partial local readiness
Reward checking failures: ready local
Support access/security audit: ready local
Usage/billing sink: ready local
Ticket image CDN metrics: blocked external
```

The latest local report returned `ready_local`, 3 partners, 30 active usage meters, 39 active alert policies, and no missing required alert policies.

## Alert Policy / Channel Summary

Required default alert policies covered:

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

Local channels:

```text
dry-run JSON output
database rows in partner_alert_events when not dry-run
redacted Laravel log warning when not dry-run and an alert triggers
```

External channels are placeholders/blockers only:

```text
webhook
email
Sentry
Grafana
Datadog
New Relic
Cloudflare/CDN/R2 analytics
```

## Permissions / Tenant Checks Enforced

- No API routes or public HTTP contract were added or changed.
- Commands are local/dev operational commands only.
- Alert/report payloads include `partner_id` and `tenant_id` labels where applicable.
- Alert event rows are partner/tenant scoped through foreign keys and tenant-scoped models.
- No tenant logo/theme/payment/domain/feature settings were moved to env.
- Secret-bearing keys including webhook URLs, tokens, DSNs, passwords, and API keys are redacted before report/alert output.

## Dashboard / Runbook Artifacts

```text
ops/m10/observability-signal-inventory.md
ops/m10/alert-channel-runbook.md
ops/m10/dashboards/platform-overview.json
ops/m10/dashboards/partner-health.json
```

Dashboard JSON files are templates only. They document intended metrics/datasource shape but do not claim Grafana/Datadog/New Relic production integration.

## Local/Dev Vs Production Boundary

This slice proves local/dev readiness for:

```text
schema readiness
command registration
safe JSON report output
dry-run alert evaluation
local database/log alert path
partner/tenant labels
secret redaction
dashboard/runbook templates
Docker-only validation
```

This slice does not approve:

```text
staging
production
client delivery
external alert delivery
Cloudflare/CDN/R2
Horizon/Reverb
migration rehearsal/cutover/rollback
production secret management
license/dependency gates
back-office production-readiness
```

## Validation

All runtime/package/Artisan/test commands were run through Docker.

```text
docker compose config --quiet: PASS
docker compose up -d postgres valkey platform-api: PASS
docker compose run --rm platform-api composer install: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest: PASS, 5 tests / 81 assertions
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest: PASS, 3 tests / 74 assertions
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest: PASS, 5 tests / 94 assertions
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest: PASS, 7 tests / 1123 assertions
docker compose run --rm platform-api php artisan test --filter=M10: PASS, 11 tests / 212 assertions
docker compose run --rm platform-api php artisan test: PASS, 126 tests / 3137 assertions
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS after full suite reseed
docker compose exec platform-api php artisan route:list: PASS, 199 routes
docker compose exec platform-api php artisan platform:smoke: PASS
docker compose exec platform-api php artisan platform:observability:report --format=json: PASS, status ready_local
docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json: PASS, 3 partners / 24 policies evaluated / 0 events delivered
bash -n scripts/platform-observability-report.sh: PASS
bash -n scripts/platform-alerts-check.sh: PASS
jq empty ops/m10/dashboards/platform-overview.json: PASS
jq empty ops/m10/dashboards/partner-health.json: PASS
```

Static checks:

```text
No tenant logo/theme/payment/domain/feature env keys found in apps/platform-api/.env.example.
Alert policy keys are present in app/tests/docs/ops artifacts.
Secret/static scan found only safe placeholders, existing local seed placeholders, and existing k6 token variable names; no real production credentials were added.
```

## Known Risks

- Booking/checkout failure policies are locally evaluable only where daily summary/error counters exist; production instrumentation feeds are still needed.
- API latency/error-rate production accuracy needs external APM or edge metrics.
- Queue lag local evaluation uses Laravel queue tables; Horizon dashboard/supervision remains a separate gate.
- CDN ticket image metrics require Cloudflare/CDN/R2 integration and real ticket image path.
- Webhook/email/Sentry/Grafana/Datadog/New Relic delivery is placeholder-only until production credentials, secret management, retry policy, and QA delivery evidence exist.
- Workspace remains broadly dirty/untracked from prior multi-agent work; this handoff lists only this slice's intended files.

## Questions For Coordinator

None for this slice. Production external alert delivery and dashboard datasource selection need a future Coordinator/Orchestrator slice.

## Release Gates Still Open

```text
Cloudflare HTTPS/WAF/rate-limit/CDN/R2 integration
real CDN/R2 ticket image load test
Horizon/Reverb hardening
scheduler workload registration
migration rehearsal/cutover/rollback
production secret management
Meno license compliance
npm audit remediation
back-office hydration/stale-marker/menu metadata risks
maintenance bypass list endpoint
backend menu category/icon fields
```

## Next Agent

Orchestrator
