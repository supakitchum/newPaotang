# 20260508-m10-horizon-reverb-scheduler-hardening - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved `20260508-m10-cloudflare-https-waf-cdn-r2-remediation` for local/dev readiness with accepted risks and instructed Orchestrator to open:

```text
20260508-m10-horizon-reverb-scheduler-hardening
```

Backend Develop reports the Horizon/Reverb/scheduler hardening slice is complete. Validate the local/dev readiness foundation without granting staging, production, client delivery, real Horizon supervision, real Reverb public websocket, real scheduler SLO, or final M10 release approval.

## Objective

Verify that Backend implemented a Docker-only, QA-verifiable local/dev runtime hardening foundation:

```text
platform:runtime:readiness safe JSON command
queue worker profile catalog and queue ownership by workload
Horizon readiness blockers and dashboard/supervision boundary
Reverb readiness blockers, redacted config, and realtime auth route boundary
scheduler workload registration and schedule:list evidence
bounded queue/scheduler/realtime helper scripts
load-tests/README.md P3 cleanup for TICKET_IMAGE_CDN_IMAGE_PATH
runtime docs/runbooks
no API/customer/back-office/source-of-truth contract drift
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md`
- `ai-agents/tasks/20260508-m10-horizon-reverb-scheduler-hardening-backend.md`
- `ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/backend-console-commands.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/api-conventions.md`
- `docs/events.md`
- `docs/openapi.yaml`
- `document/01_SYSTEM_OVERVIEW.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/13_REWARD_RESULT_ENGINE.md`
- `document/15_EXECUTION_PLAN.md`
- `compose.yaml`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/config/queue.php`
- `apps/platform-api/app/Console/Commands/PlatformRuntimeReadinessCommand.php`
- `apps/platform-api/app/Shared/Runtime/RuntimeReadinessService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `scripts/platform-api-worker-once.sh`
- `scripts/platform-api-schedule-list.sh`
- `scripts/platform-runtime-readiness.sh`
- `ops/m10/queue-worker-profiles.json`
- `ops/m10/horizon-queue-supervision.md`
- `ops/m10/reverb-deployment-readiness.md`
- `ops/m10/runtime-hardening-readiness.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/scheduler-workload-runbook.md`
- `load-tests/README.md`

## Scope

Validate Backend/Ops implementation for M10 Horizon/Reverb/scheduler hardening.

Inspect at minimum:

```text
apps/platform-api/app/Console/Commands/PlatformRuntimeReadinessCommand.php
apps/platform-api/app/Shared/Runtime/RuntimeReadinessService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/console.php
apps/platform-api/config/platform.php
apps/platform-api/config/queue.php
apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
compose.yaml
scripts/platform-api-worker-once.sh
scripts/platform-api-schedule-list.sh
scripts/platform-runtime-readiness.sh
ops/m10/queue-worker-profiles.json
ops/m10/horizon-queue-supervision.md
ops/m10/reverb-deployment-readiness.md
ops/m10/runtime-hardening-readiness.md
ops/m10/runtime-readiness.md
ops/m10/scheduler-workload-runbook.md
load-tests/README.md
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, ops, scripts, load-tests, compose, workflows, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, realtime auth contract, or business rules.
- Do not approve staging, production, client delivery, real Horizon dashboard/supervision, real process-manager setup, real Reverb public websocket/TLS/scaling/load, production scheduler leadership/SLOs, migration rehearsal, Meno license, npm audit, back-office production-readiness, or final M10 release.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, Horizon, Reverb, k6, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.
- Do not start long-lived worker, scheduler, Horizon, or Reverb processes for validation.
- Do not copy real Reverb secrets, app keys, Horizon credentials, tokens, DSNs, private certificates, production URLs, passwords, bearer tokens, or signed URLs into QA reports/artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md
ai-agents/reports/artifacts/20260508-m10-horizon-reverb-scheduler-hardening-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md and ai-agents/reports/artifacts/20260508-m10-horizon-reverb-scheduler-hardening-qa/**
```

If a defect requires implementation, docs, queue profile, scheduler registration, command, runtime readiness logic, Reverb/Horizon package/config, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, Horizon, Reverb, k6, Cloudflare, wrangler, aws, and runtime commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
files changed
load-tests/README.md P3 cleanup
queue worker profile and ownership summary
Horizon readiness approach and blockers
Reverb readiness approach and blockers
scheduler workload registration and blockers
runtime readiness JSON summary
Docker validation
remaining staging/production blockers
known risks
```

5. Verify command registration and safe output:

```text
platform:runtime:readiness --format=json
```

The command must emit safe JSON, avoid external calls, avoid starting long-lived processes, report blockers, and keep `production_approved=false`.

6. Verify runtime readiness JSON fields:

```text
status is blocked_external while Horizon/Reverb production evidence is missing
boundary.local_dev_verifiable=true
boundary.external_services_called=false
boundary.long_lived_processes_started=false
boundary.horizon_dashboard_publicly_exposed=false
boundary.reverb_public_websocket_approved=false
boundary.production_approved=false
queue_workers.status=ready_local
scheduler.status=ready_local
helpers.status=ready_local
horizon.status=blocked_external unless real local package/config evidence exists
reverb.status=blocked_external unless real local package/runtime evidence exists
blockers include clear Horizon/Reverb production evidence blockers
```

7. Verify queue profile catalog:

```text
ops/m10/queue-worker-profiles.json parses
all PLATFORM_WORKER_QUEUES are present exactly once in queue_ownership
worker_profiles are non-empty and map queues to owners
critical customer/checkout/stock/reward queues are separated from report-build/usage-metering/partner-monitoring/default
report-build is not in the same profile as checkout-finalize or reward-check-high
```

Required queues:

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

8. Verify scheduler registration:

```text
schedule:list includes stock:reservations:expire --limit=100
schedule:list includes stock:sold:sync --limit=100
schedule:list includes reward:check --chunk=100
schedule:list includes commission:calculate --limit=100
schedule:list includes platform:alerts:check --dry-run --format=json
registered workloads are bounded/chunked/dry-run as documented
withoutOverlapping or equivalent overlap guard is used
```

9. Verify helper scripts:

```text
scripts/platform-api-worker-once.sh uses docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30
scripts/platform-api-schedule-list.sh uses docker compose run --rm platform-api php artisan schedule:list
scripts/platform-runtime-readiness.sh uses docker compose exec platform-api php artisan platform:runtime:readiness --format=json
no helper runs PHP/Artisan directly on host
```

10. Verify Horizon boundary:

```text
if Horizon package/config is absent, readiness reports horizon_package_missing and horizon_config_missing
dashboard route is not publicly exposed without policy
runbook states production process-manager/supervisor/access-policy evidence is still required
```

11. Verify Reverb boundary:

```text
readiness reports configured booleans and [CONFIGURED]/[REDACTED]/null only
raw REVERB_APP_ID, REVERB_APP_KEY, REVERB_APP_SECRET, host, URL, or token values do not appear in output
admin central and tenant realtime auth route presence remains true
existing realtime auth tests still pass
runbook states TLS/public host/scaling/load evidence is still required
```

12. Verify docs/runbooks:

```text
load-tests/README.md documents CDN_BASE_URL plus IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
load-tests/README.md states normal API BASE_URL is intentionally ignored for ticket-image CDN/R2 coverage
docs/m10-deployment-monitoring-load-test.md documents platform:runtime:readiness and Horizon/Reverb/scheduler blockers
docs/backend-console-commands.md lists platform:runtime:readiness
ops/m10 runtime artifacts preserve local/dev vs production boundary
```

13. Verify no forbidden API/customer/back-office/source-of-truth drift is attributable to this slice.
14. Capture or summarize safe command output under:

```text
ai-agents/reports/artifacts/20260508-m10-horizon-reverb-scheduler-hardening-qa/**
```

Do not copy secrets into artifacts. Redact any sensitive-looking values.

15. Write QA report to:

```text
ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- `M10HorizonReverbSchedulerHardeningTest` passes.
- `M10DeploymentReadinessTest` passes.
- `M10ProductionObservabilityAlertingTest` passes.
- `M10CloudflareHttpsWafCdnR2Test` passes.
- `AdminOperationsTest` passes.
- `MaintenanceTest` passes.
- `ConsoleCommandStructureTest` passes.
- Full platform-api test suite passes.
- `route:list` passes and shows no public API contract drift attributable to this slice.
- `platform:smoke` passes after seeded DB is restored if needed.
- `platform:runtime:readiness --format=json` passes and emits safe JSON.
- Runtime readiness output keeps `production_approved=false`.
- Runtime readiness output does not expose Reverb secrets, Horizon credentials, tokens, production URLs, DSNs, private keys, or bearer tokens.
- Queue catalog covers all configured queues and separates critical paths from reporting/monitoring pools.
- Scheduler workloads are visible through `schedule:list` and are bounded/chunked/dry-run as documented.
- Bounded queue worker command exits without leaving a long-lived worker.
- Horizon and Reverb remain explicit blockers unless real local package/runtime evidence exists.
- Helper scripts are Docker-only.
- `load-tests/README.md` P3 cleanup is complete.
- No customer/back-office/source-of-truth contract drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, Horizon, Reverb, k6, Cloudflare, wrangler, aws, and runtime commands.

Required Docker validation:

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
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan list
```

Required fake Reverb redaction probe:

```sh
docker compose run --rm -e REVERB_APP_ID=qa-reverb-app-id-redaction -e REVERB_APP_KEY=qa-reverb-key-redaction -e REVERB_APP_SECRET=qa-reverb-secret-redaction -e REVERB_HOST=wss://reverb.fake-redaction.test -e REVERB_PORT=443 -e REVERB_SCHEME=https platform-api php artisan platform:runtime:readiness --format=json
```

Required helper/static validation:

```sh
git status --short
sh -n scripts/platform-api-worker-once.sh
sh -n scripts/platform-api-schedule-list.sh
sh -n scripts/platform-runtime-readiness.sh
jq empty ops/m10/queue-worker-profiles.json
rg -n "TICKET_IMAGE_CDN_IMAGE_PATH|IMAGE_PATH|CDN_BASE_URL|BASE_URL" load-tests/README.md
rg -n "platform:runtime:readiness|Horizon|horizon|Reverb|reverb|schedule:list|queue:work|PLATFORM_WORKER_QUEUES" apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts compose.yaml load-tests/README.md
rg -n "secret|password|token|private_key|BEGIN PRIVATE KEY|Bearer " apps/platform-api docs/m10-deployment-monitoring-load-test.md docs/backend-console-commands.md ops/m10 scripts load-tests/README.md ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
rg -n "qa-reverb-app-id-redaction|qa-reverb-key-redaction|qa-reverb-secret-redaction|reverb.fake-redaction.test" ai-agents/reports/artifacts/20260508-m10-horizon-reverb-scheduler-hardening-qa ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md
```

Interpretation notes:

```text
The final rg for fake Reverb values should return no matches after QA writes redacted artifacts/report. If it returns matches because QA intentionally recorded the forbidden-value checklist, redact those values and re-run.
Secret scans may match safe placeholders, env names, docs examples, local seed-password placeholders, and redaction test fixture names. QA must distinguish placeholders/redacted output from real secret leakage.
Do not run real long-lived Horizon/Reverb/scheduler/worker processes.
Do not run real Cloudflare/wrangler/aws commands on the host.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-horizon-reverb-scheduler-hardening-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
runtime readiness command review
safe output/redaction review
queue worker profile and ownership review
Horizon readiness/blocker review
Reverb readiness/blocker review
scheduler registration review
helper script review
load-tests/README.md P3 cleanup review
docs/runbook boundary review
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
