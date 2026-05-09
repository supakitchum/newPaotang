# 20260508-m10-production-observability-alerting - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved `20260508-m10-full-k6-load-test-execution` for local/dev readiness and instructed Orchestrator to open the next M10 release-gate slice:

```text
20260508-m10-production-observability-alerting
```

Backend Develop reports observability and alert-channel readiness foundations are complete. Validate this slice without granting staging, production, client-delivery, Cloudflare/CDN/R2, Horizon/Reverb, migration, license, dependency, or back-office production-readiness approval.

## Objective

Verify that Backend implemented a Docker-only, QA-verifiable local/dev foundation for production observability and alert-channel readiness:

```text
observability signal inventory
safe JSON observability report command
alert policy evaluation command with dry-run
local database/log alert event path
partner/tenant labels
secret redaction
dashboard/runbook artifacts
schema/model/test coverage
clear local/dev vs production boundary
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-full-k6-load-test-execution-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-m10-production-observability-alerting-planning-orchestrator-handoff.md`
- `ai-agents/tasks/20260508-m10-production-observability-alerting-backend.md`
- `ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-console-commands.md`
- `docs/backend-model-layer.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/observability-signal-inventory.md`
- `ops/m10/alert-channel-runbook.md`
- `ops/m10/dashboards/platform-overview.json`
- `ops/m10/dashboards/partner-health.json`
- `scripts/platform-observability-report.sh`
- `scripts/platform-alerts-check.sh`
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Validate Backend/Ops implementation for M10 production observability and alert-channel readiness.

Inspect at minimum:

```text
apps/platform-api/.env.example
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/app/Console/Commands/PlatformObservabilityReportCommand.php
apps/platform-api/app/Console/Commands/PlatformAlertsCheckCommand.php
apps/platform-api/app/Models/PartnerUsageEvent.php
apps/platform-api/app/Models/PartnerDailyUsageSummary.php
apps/platform-api/app/Models/PartnerAlertEvent.php
apps/platform-api/app/Shared/Observability/ObservabilityCatalog.php
apps/platform-api/app/Shared/Observability/ObservabilityRedactor.php
apps/platform-api/app/Shared/Observability/ObservabilityReportService.php
apps/platform-api/app/Shared/Observability/AlertEvaluationService.php
apps/platform-api/database/migrations/2026_05_08_000001_create_observability_alerting_tables.php
apps/platform-api/database/seeders/DemoTenantSeeder.php
apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php
apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php
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

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not approve staging, production, client delivery, Cloudflare, HTTPS, WAF, CDN/R2, Horizon, Reverb, migration rehearsal, production secret management, Meno license, npm audit, or back-office production-readiness gates.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, or runtime commands on the host machine.
- Do not copy real secrets, webhook URLs, DSNs, tokens, passwords, API keys, production credentials, or production URLs into QA reports/artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md
ai-agents/reports/artifacts/20260508-m10-production-observability-alerting-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md and ai-agents/reports/artifacts/20260508-m10-production-observability-alerting-qa/**
```

If a defect requires implementation, docs, schema, command, secret-redaction, alert-channel, artifact, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, and runtime commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
files changed
schema/model/service changes
observability signal inventory summary
alert policy/channel summary
dashboard/runbook artifacts
local/dev vs production boundary
Docker validation commands and results
known risks and blockers
release gates still open
```

5. Verify schema/model readiness:

```text
partner_usage_events
partner_daily_usage_summaries
partner_alert_events
PartnerUsageEvent
PartnerDailyUsageSummary
PartnerAlertEvent
```

Confirm migrations are additive and do not remove or mutate existing business tables unexpectedly.

6. Verify command registration and output:

```text
platform:observability:report --format=json
platform:alerts:check --dry-run --format=json
```

Both commands must emit safe JSON and must not require external production credentials.

7. Verify alert database/log path:

```text
platform:alerts:check --format=json
```

If no current seed data triggers events, rely on focused tests for event writes and record the limitation. Do not fabricate production alert delivery.

8. Verify observability signal inventory covers:

```text
API request/error/latency
DB health
cache health
queue lag
partner sync lag
booking failures
checkout/wallet failures
reward checking failures
support access/security audit
usage/billing sink
CDN ticket image metrics as external blocker
```

9. Verify required default alert policy keys exist in app/tests/docs/ops artifacts:

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

10. Verify partner/tenant labels and security boundaries:

```text
partner_id and tenant_id labels where applicable
foreign keys or tenant-scoped models for alert events where applicable
no tenant logo/theme/payment/domain/feature config moved to env
no API routes or public HTTP contracts added or changed for this slice
```

11. Verify secret redaction:

```text
webhook URLs
tokens
DSNs
passwords
API keys
bank/account credentials
authorization headers
```

Reports, alerts, docs, scripts, and QA artifacts must contain only safe placeholders or redacted values.

12. Verify dashboard/runbook artifacts:

```text
ops/m10/observability-signal-inventory.md
ops/m10/alert-channel-runbook.md
ops/m10/dashboards/platform-overview.json
ops/m10/dashboards/partner-health.json
```

Dashboard JSON must parse as valid JSON. Artifacts must state local/dev vs production integration boundaries.

13. Verify docs:

```text
docs/m10-deployment-monitoring-load-test.md documents observability/alerting commands and blockers
docs/backend-console-commands.md includes new commands
docs/backend-architecture-compliance.md documents Shared observability primitives if used
docs/backend-model-layer.md includes new models/tables if applicable
docs/backend-bootstrap-seeders.md documents seeded policy/default behavior if applicable
```

14. Verify no forbidden areas were changed by this slice:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
document/**
load-tests/**
```

The workspace is noisy; fail only when evidence ties forbidden drift to this slice.

15. Run Docker validation commands.
16. Capture or summarize safe command output under:

```text
ai-agents/reports/artifacts/20260508-m10-production-observability-alerting-qa/**
```

Do not copy secrets into artifacts. Redact any sensitive-looking values.

17. Write QA report to:

```text
ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- New schema/model changes are additive and scoped to observability/alerting readiness.
- `M10ProductionObservabilityAlertingTest` passes.
- `M10DeploymentReadinessTest` passes.
- `ConsoleCommandStructureTest` passes.
- Full platform-api test suite passes.
- `route:list` passes and shows no public API contract drift attributable to this slice.
- `platform:smoke` passes.
- `platform:observability:report --format=json` passes and emits safe JSON.
- `platform:alerts:check --dry-run --format=json` passes and emits safe JSON.
- Local database/log alert event path is implemented or test-covered with precise limitations recorded.
- Required default alert policy keys are present.
- Observability signal inventory maps required signals to status/data source/validation.
- Partner/tenant labels are present where applicable.
- Secret redaction prevents webhook/token/DSN/password/API key leakage in output/artifacts.
- `.env.example` contains only infrastructure-level observability/alert placeholders and no tenant logo/theme/payment/domain/feature config.
- Dashboard templates parse as JSON.
- Runbook/artifacts clearly state external alert delivery, real dashboards, CDN/R2 metrics, Horizon, and production integration remain open gates.
- No customer/back-office/source-of-truth contract drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, and runtime commands.

Required Docker validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=M10
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:observability:report --format=json
docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json
docker compose exec platform-api php artisan platform:alerts:check --format=json
```

Required static checks:

```sh
git status --short
bash -n scripts/platform-observability-report.sh
bash -n scripts/platform-alerts-check.sh
jq empty ops/m10/dashboards/platform-overview.json
jq empty ops/m10/dashboards/partner-health.json
rg -n "PLATFORM_(OBSERVABILITY|ALERT)|SENTRY|DATADOG|NEW_RELIC|GRAFANA|WEBHOOK|SECRET|TOKEN|PASSWORD|DSN" apps/platform-api/.env.example docs/m10-deployment-monitoring-load-test.md ops/m10 scripts apps/platform-api/app apps/platform-api/tests
rg -n "logo|theme|payment|domain|feature" apps/platform-api/.env.example
rg -n "api_error_rate_high|booking_fail_rate_high|checkout_fail_rate_high|sync_lag_high|queue_lag_high|reward_check_failure|permission_denied_spike|cross_tenant_access_attempt" apps/platform-api/app apps/platform-api/database apps/platform-api/tests docs/m10-deployment-monitoring-load-test.md docs/backend-bootstrap-seeders.md ops/m10
rg -n "platform:observability:report|platform:alerts:check" apps/platform-api/app apps/platform-api/tests docs/backend-console-commands.md docs/m10-deployment-monitoring-load-test.md ops/m10 scripts
```

Interpretation notes:

```text
Secret scans may match safe placeholders and variable names. QA must distinguish placeholders/redacted output from real secret leakage.
If platform:alerts:check --format=json writes no alert events because no seeded thresholds are breached, record that focused tests cover event writes and mark production delivery still open.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
schema/model review
observability report command review
alert check command review
local alert event path review
signal inventory review
default policy coverage review
partner/tenant label review
secret redaction review
env boundary review
dashboard/runbook artifact review
docs/release-boundary review
route-list/API contract review
test results
static check results
customer/back-office no-change review
release gates still open
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```
