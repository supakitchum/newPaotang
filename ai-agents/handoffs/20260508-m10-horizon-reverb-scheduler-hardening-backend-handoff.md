# 20260508-m10-horizon-reverb-scheduler-hardening - Backend Develop Handoff

Date: 2026-05-08
Agent: Backend Develop
Next Agent: Orchestrator

## What Was Done

- Added local/dev runtime hardening readiness for queues, Horizon, Reverb, scheduler, helper scripts, blockers, and Docker validation commands through `platform:runtime:readiness`.
- Added a queue worker profile catalog covering every queue currently listed by `PLATFORM_WORKER_QUEUES`.
- Registered bounded/idempotent scheduler workloads for reservation expiration, sold sync, reward checks, commission calculation, and dry-run alert checks.
- Added ops runbooks for Horizon queue supervision, Reverb deployment readiness, scheduler workloads, and runtime hardening.
- Updated M10 docs and backend console command docs with Docker-only runtime readiness evidence.
- Completed the P3 load-test README cleanup for ticket-image CDN coverage.

## Backend Files Changed

```text
apps/platform-api/app/Console/Commands/PlatformRuntimeReadinessCommand.php
apps/platform-api/app/Shared/Runtime/RuntimeReadinessService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/routes/console.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php
scripts/platform-api-worker-once.sh
scripts/platform-runtime-readiness.sh
ops/m10/horizon-queue-supervision.md
ops/m10/queue-worker-profiles.json
ops/m10/reverb-deployment-readiness.md
ops/m10/runtime-hardening-readiness.md
ops/m10/runtime-readiness.md
ops/m10/scheduler-workload-runbook.md
load-tests/README.md
docs/backend-console-commands.md
docs/m10-deployment-monitoring-load-test.md
ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
```

## API Endpoints Implemented

No new HTTP API endpoints were added.

Existing realtime auth endpoints were preserved and are reported by readiness output:

```text
POST /api/v1/admin/central/realtime/auth
POST /api/v1/admin/tenant/realtime/auth
```

No OpenAPI, permissions, status enum, or public API contract files were changed.

## Permissions/Tenant Checks Enforced

- No tenant scope, auth, RBAC, middleware, or public API behavior was bypassed.
- Runtime readiness only inspects route presence and configuration state; it does not call external services, start long-lived processes, or expose raw secrets.
- Realtime auth endpoints remain behind existing admin auth and tenant-scope behavior.
- Scheduler registration uses existing console commands and bounded chunk/dry-run flags; no cross-tenant shortcut was introduced.

## load-tests/README.md P3 Cleanup

`load-tests/README.md` now states that `ticket-image-cdn-spike.js` coverage requires:

```text
CDN_BASE_URL plus IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
```

It also states that normal API `BASE_URL` is intentionally ignored for ticket-image CDN/R2 coverage.

## Queue Worker Profile And Ownership Summary

`ops/m10/queue-worker-profiles.json` covers all 22 queues from `PLATFORM_WORKER_QUEUES`:

```text
partner-inbox-high
partner-inbox-normal
stock-allocation
stock-sold-events
stock-recall
stock-sync
reservation-expiration
checkout-finalize
central-outbox
affiliate-commission
reward-validate
reward-check-high
reward-check-normal
reward-summary
reward-publish
reward-notification
report-build
webhook-dispatch
notification
usage-metering
partner-monitoring
default
```

Critical customer/checkout/reward/stock queues are separated from report/build/monitoring queues. `report-build`, `affiliate-commission`, `notification`, `usage-metering`, `partner-monitoring`, and `default` are documented as background/non-critical pools and are not shared with booking/checkout/reward critical paths.

## Horizon Readiness Approach And Blockers

The readiness service checks for Laravel Horizon package/config/dashboard route presence and reports local/dev status only.

Current blockers:

```text
horizon_package_missing
horizon_config_missing
horizon_supervisor_not_configured
horizon_dashboard_access_policy_not_verified
horizon_production_process_manager_missing
```

No Horizon dashboard was exposed and no production supervision was claimed.

## Reverb Readiness Approach And Blockers

The readiness service checks for Reverb package presence, redacted env/config shape, and existing admin realtime auth route presence. Raw app key, secret, host, URL, or token values are not emitted.

Current blockers:

```text
reverb_package_missing
reverb_runtime_profile_not_configured
reverb_tls_and_public_host_not_verified
reverb_scaling_and_load_not_verified
```

No public websocket, TLS, scaling, or client-delivery realtime approval was claimed.

## Scheduler Workload Registration And Blockers

Registered local/dev scheduler workloads:

```text
* * * * *      php artisan stock:reservations:expire --limit=100
* * * * *      php artisan stock:sold:sync --limit=100
*/5 * * * *    php artisan reward:check --chunk=100
*/10 * * * *   php artisan commission:calculate --limit=100
*/5 * * * *    php artisan platform:alerts:check --dry-run --format=json
```

Runtime readiness reports `missing_required_workloads=[]` and scheduler status `ready_local`.

## Runtime Readiness JSON Summary

`docker compose exec platform-api php artisan platform:runtime:readiness --format=json` returned:

```text
status=blocked_external
production_approved=false
queue_workers.status=ready_local
horizon.status=blocked_external
reverb.status=blocked_external
scheduler.status=ready_local
helpers.status=ready_local
configured_queue_count=22
missing_configured_queues=[]
unknown_catalog_queues=[]
```

The blocked status is expected because Horizon/Reverb production evidence is intentionally not available in this local/dev slice.

## Docker Validation

Passed:

```sh
docker compose config --quiet
docker compose --profile worker --profile scheduler config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan list
sh -n scripts/platform-api-worker-once.sh
sh -n scripts/platform-api-schedule-list.sh
sh -n scripts/platform-runtime-readiness.sh
jq empty ops/m10/queue-worker-profiles.json
rg -n "TICKET_IMAGE_CDN_IMAGE_PATH|IMAGE_PATH|CDN_BASE_URL|BASE_URL" load-tests/README.md
rg -n "platform:runtime:readiness|Horizon|horizon|Reverb|reverb|schedule:list|queue:work|PLATFORM_WORKER_QUEUES" apps/platform-api docs/m10-deployment-monitoring-load-test.md ops/m10 scripts compose.yaml
rg -n "secret|password|token|private_key|BEGIN PRIVATE KEY|Bearer " apps/platform-api docs/m10-deployment-monitoring-load-test.md ops/m10 scripts load-tests/README.md
```

Full regression result:

```text
135 passed, 3363 assertions
```

Note: `platform:smoke` first failed after full regression because the test suite had mutated seeded monitoring/login data. I reran `migrate:fresh --seed --env=testing` through Docker and reran `platform:smoke`; it passed with app/database/cache/queue/monitoring-defaults/seeded-logins all `ok`.

The secret scan reported expected source/test placeholder matches and redaction test fixtures; no private key or committed Bearer literal was introduced by this task.

## Remaining Staging/Production Blockers

```text
Laravel Horizon package/config is not installed.
Horizon dashboard access policy and process-manager supervision are not approved.
Laravel Reverb package/runtime profile is not installed.
Reverb public websocket host, TLS, scaling, and load evidence are not available.
No staging/production runtime supervision evidence exists yet.
No client-delivery realtime approval exists yet.
No final M10 release approval is claimed.
```

## Known Risks / Questions

- Workspace remains broadly dirty/untracked from multi-agent work; unrelated `apps/customer/**`, `apps/back-office/**`, `document/**`, decisions, reports, and older handoffs were not touched by this task.
- `platform:runtime:readiness` intentionally reports `blocked_external` until Horizon/Reverb production infrastructure evidence exists.
- Scheduler cadence is local/dev evidence only; production SLOs and process-manager ownership remain separate release gates.

## Next Agent

Orchestrator
