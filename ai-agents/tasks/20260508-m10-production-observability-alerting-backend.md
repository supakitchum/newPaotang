# 20260508-m10-production-observability-alerting - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-full-k6-load-test-execution` for local/dev k6 execution readiness with accepted risks.

Open the next M10 release-gate slice:

```text
20260508-m10-production-observability-alerting
```

Target Backend/Ops implementation first. This slice must cover production observability and alert-channel readiness without claiming staging, production, client-delivery, Cloudflare/CDN/R2, Horizon/Reverb, migration, license, dependency, or back-office risk approval.

## Objective

Implement verifiable production observability and alert-channel readiness foundations for `platform-api`.

The goal is to make observability measurable and QA-verifiable through Docker-only local/dev commands while producing clear artifacts for the later production deployment:

```text
metrics/log/error/health signal inventory
partner/tenant-safe metrics labels and secret redaction rules
alert policy evaluation and alert event path
local/dev alert channel dry-run or database/log delivery path
dashboard artifact templates
operational runbook
Docker-only validation
explicit local/dev vs staging/production boundary
```

This slice is not production approval. If real external alert delivery requires credentials or infrastructure not available in this workspace, implement a safe local/dev dry-run or database/log path and document the production blocker and owner.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-full-k6-load-test-execution-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-approval-coordinator-handoff.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-orchestrator-handoff.md`
- `ai-agents/decisions/20260508-m10-deployment-monitoring-load-test-approval-decision.md`
- `ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md`
- `ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md`
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
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Implement a focused backend/ops slice for production observability and alert-channel readiness.

Approved implementation scope:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md
```

Expected implementation areas:

```text
observability signal inventory for API, DB, cache, queue, partner sync, booking, checkout, reward, support access, security, and usage/billing signals
safe local/dev observability report command, such as platform:observability:report
safe local/dev alert evaluation command, such as platform:alerts:check --dry-run
alert event storage or local database/log delivery path if missing
daily usage summary or metrics sink readiness if missing
default alert policy coverage for high error rate, sync lag, queue lag, checkout/booking failures, reward check failures, permission denied spikes, and cross-tenant attempts where data exists
dashboard templates or JSON/Markdown artifacts under ops/m10/**
alert-channel runbook including dry-run, database/log channel, and production external-channel blockers
environment template placeholders for infrastructure-level observability/alert settings only
tests for command registration, signal inventory, alert evaluation, tenant/partner labels, and secret redaction
```

Use the repo's existing Modular Monolith structure. Domain-owned services should live under `App\Modules\<Domain>\Services`; shared observability primitives may live under `App\Shared` only when they are genuinely cross-cutting and documented.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not change public customer flow.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, or business rules.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not claim staging, production, client delivery, Cloudflare, HTTPS, WAF, CDN/R2, Horizon, Reverb, migration rehearsal, production secret management, Meno license, npm audit, or back-office production-readiness approval.
- Do not implement Cloudflare/CDN/R2, Horizon, Reverb, scheduler workload registration, migration rehearsal/cutover/rollback, license, dependency, or back-office cleanup in this slice.
- Do not add a second operational database, analytics database, search engine, or external observability vendor dependency without a Coordinator decision.
- Do not commit real webhook URLs, API keys, Sentry DSNs, Grafana tokens, Slack/Teams secrets, production credentials, bearer tokens, passwords, or production URLs.
- Do not move tenant logo/theme/payment/domain/feature config into env.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/events.md
document/**
compose.yaml unless a local/dev observability helper profile is impossible without it
.github/** unless only adding Docker-only M10 observability validation to an existing M10 workflow
load-tests/** except references in docs if needed
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, runtime, migration, queue, scheduler, and observability validation commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect current monitoring and usage tables/models/services/tests before editing:

```text
partner_monitoring_profiles
partner_usage_meters
partner_alert_policies
partner_health_checks
partner_usage_events if present
partner_daily_usage_summaries if present
partner_alert_events if present
```

5. Add missing schema/models/services only as needed for this slice, such as alert events, daily usage summaries, or a safe metrics sink. Keep migrations backward-compatible.
6. Add or update a production-readiness observability service that can inventory and report:

```text
API request/error/latency signal readiness
DB/cache/queue health signal readiness
partner monitoring profile readiness
usage meter readiness
partner/tenant health check readiness
alert policy readiness
known missing production integrations
```

7. Add a Docker-runnable command, such as:

```text
php artisan platform:observability:report --format=json
```

The report must avoid secrets and should be suitable for QA artifact capture.

8. Add a Docker-runnable alert check command, such as:

```text
php artisan platform:alerts:check --dry-run --format=json
```

It should evaluate local/dev default policies and either write safe local alert events or output dry-run results. It must not require real external credentials.

9. Implement or document alert-channel readiness for:

```text
database/log local channel
webhook/email/Sentry/Grafana/Datadog/New Relic production placeholders or blockers
channel enabled/disabled behavior
redaction of secrets/PII
tenant and partner labels in alert payloads where applicable
```

10. Add or update infrastructure-level env placeholders in `.env.example` only if needed. Acceptable examples:

```text
PLATFORM_OBSERVABILITY_ENABLED
PLATFORM_OBSERVABILITY_ENV
PLATFORM_ALERTS_ENABLED
PLATFORM_ALERT_CHANNELS
PLATFORM_ALERT_WEBHOOK_URL
PLATFORM_ALERT_DRY_RUN
```

Do not put tenant logo/theme/payment/domain/feature settings in env and do not include real secrets.

11. Add dashboard/runbook artifacts under `ops/m10/**`, for example:

```text
ops/m10/observability-signal-inventory.md
ops/m10/alert-channel-runbook.md
ops/m10/dashboards/platform-overview.json
ops/m10/dashboards/partner-health.json
```

Artifacts may be templates if real Grafana/Datadog credentials are not available. They must clearly state what is verifiable locally and what remains a production integration gate.

12. Update M10 docs and backend docs with the commands, artifacts, release boundary, and remaining blockers.
13. Add tests for:

```text
observability command registration/output shape
alert check command registration/output shape
default alert policies and alert event path
secret redaction in report/alert payloads
partner/tenant label presence where applicable
no tenant config moved to env
```

14. Run Docker-only validation commands.
15. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Observability signal inventory exists and maps required signals to current status, owner, data source, and local/dev validation command.
- A Docker-runnable observability report command exists, emits safe JSON, and does not leak secrets or production credentials.
- A Docker-runnable alert check command exists, supports dry-run, and does not require real external alert credentials.
- Local/dev alert event or database/log delivery path is implemented or a precise blocker is documented.
- Production external alert delivery requirements are documented without claiming production delivery unless QA can verify it.
- Dashboard/runbook artifacts exist under `ops/m10/**`.
- Partner/tenant labels are included where applicable.
- Default alert policies cover at least:

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

- Existing partner monitoring profile, usage meter, alert policy, and health check defaults remain intact.
- Full platform-api tests pass.
- `platform:smoke` passes.
- No API contract drift, customer flow drift, back-office flow drift, permission drift, tenant isolation drift, or business-rule drift is introduced.
- Docs clearly state this slice is observability/alerting readiness, not staging/production/client-delivery approval.
- Gates kept separate remain open:

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

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.

Minimum required validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:observability:report --format=json
docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json
```

If you choose different command names, document the exact names and reason in the Backend handoff, and include equivalent Docker-only validation.

Useful static checks:

```sh
rg -n "PLATFORM_(OBSERVABILITY|ALERT)|SENTRY|DATADOG|NEW_RELIC|GRAFANA|WEBHOOK|SECRET|TOKEN|PASSWORD|DSN" apps/platform-api/.env.example docs/m10-deployment-monitoring-load-test.md ops/m10 scripts apps/platform-api/app apps/platform-api/tests
rg -n "logo|theme|payment|domain|feature" apps/platform-api/.env.example
rg -n "api_error_rate_high|queue_lag_high|sync_lag_high|reward_check_failure|permission_denied_spike|cross_tenant_access_attempt" apps/platform-api app docs ops/m10
```

Static check interpretation must distinguish safe placeholders from real secrets. Do not paste real secrets into the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-production-observability-alerting-backend-handoff.md
```

Must include:

```text
what was done
files changed
schema/model/service changes
observability signal inventory summary
alert policy/channel summary
dashboard/runbook artifacts
local/dev vs production boundary
Docker validation commands and results
known risks and blockers
release gates still open
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
