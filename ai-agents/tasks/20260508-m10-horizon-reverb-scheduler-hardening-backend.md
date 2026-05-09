# 20260508-m10-horizon-reverb-scheduler-hardening - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-cloudflare-https-waf-cdn-r2-remediation` for local/dev readiness with accepted risks and opened the next M10 release-gate slice:

```text
20260508-m10-horizon-reverb-scheduler-hardening
```

Target Backend/Ops implementation first.

This slice must cover:

```text
Horizon dashboard and queue supervision readiness
queue worker profiles and queue ownership by workload
Reverb production deployment and scaling readiness
scheduler workload registration and operational runbook
Docker-only validation for queue, scheduler, and realtime commands
local/dev vs staging/production boundary
QA acceptance criteria for what is real evidence vs remaining production blockers
```

Coordinator also requires this P3 cleanup before or inside this task:

```text
update load-tests/README.md so ticket-image CDN coverage documents CDN_BASE_URL plus IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
```

## Objective

Implement verifiable local/dev readiness for queue supervision, Horizon, Reverb, and scheduler operations without claiming staging or production approval.

The goal is to make M10 runtime hardening measurable through Docker-only commands and safe artifacts:

```text
queue worker profile catalog and queue ownership by workload
Horizon dashboard/supervision readiness or explicit blockers if package/runtime is not available
Reverb realtime deployment readiness and scaling/runbook boundaries
scheduler workload registration and schedule:list evidence
bounded queue/scheduler/realtime validation commands
safe env placeholders and redacted readiness output
ops runbooks for worker, scheduler, Horizon, and Reverb
tests that prevent command/profile/docs regressions
cleanup of load-tests/README.md P3 image-path wording
```

This slice is not staging, production, client delivery, real Horizon production access approval, real Reverb public websocket approval, or final M10 release approval.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/backend-console-commands.md`
- `docs/api-conventions.md`
- `docs/events.md`
- `docs/openapi.yaml`
- `document/01_SYSTEM_OVERVIEW.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/13_REWARD_RESULT_ENGINE.md`
- `document/14_MAINTENANCE_SUPPORT_ACCESS.md`
- `document/15_EXECUTION_PLAN.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/observability-signal-inventory.md`
- `ops/m10/alert-channel-runbook.md`
- `ops/m10/dashboards/platform-overview.json`
- `load-tests/README.md`
- `compose.yaml`
- `scripts/platform-api-worker-once.sh`
- `scripts/platform-api-schedule-list.sh`
- `apps/platform-api/composer.json`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/config/queue.php`
- `apps/platform-api/app/Console/Commands/**`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/M10ProductionObservabilityAlertingTest.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`

## Scope

Implement a focused Backend/Ops slice for Horizon/Reverb/scheduler hardening.

Approved implementation scope:

```text
apps/platform-api/**
apps/platform-api/.env.example
compose.yaml
scripts/**
ops/m10/**
load-tests/README.md
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
.github/workflows/platform-api-m10.yml only if updating existing Docker-only M10 validation for this slice
ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
```

Expected implementation areas:

```text
Docker-safe readiness command, such as platform:runtime:readiness --format=json
queue worker profile catalog covering current PLATFORM_WORKER_QUEUES
queue ownership mapping by workload/domain and priority class
Horizon readiness checks, dashboard/supervisor runbook, safe auth/access boundary, and explicit blockers where real production supervision is unavailable
Reverb readiness checks, env boundary, auth endpoint/runbook validation, process/profile guidance, and explicit blockers where real websocket infrastructure is unavailable
scheduler registration for safe/idempotent workloads or explicit documented blockers for workloads not ready to schedule
schedule:list evidence for registered local/dev scheduler workloads
bounded Docker helper scripts for queue, schedule, runtime readiness, and realtime/Horizon checks
ops artifacts under ops/m10/**
tests for readiness command output, queue profile docs, schedule registration, Reverb/Horizon boundaries, and README P3 cleanup
```

Recommended ops artifacts:

```text
ops/m10/horizon-queue-supervision.md
ops/m10/queue-worker-profiles.json
ops/m10/reverb-deployment-readiness.md
ops/m10/scheduler-workload-runbook.md
ops/m10/runtime-hardening-readiness.md
```

Use existing Laravel and project patterns. If official Laravel Horizon/Reverb packages are already available or safely added, wire them conservatively. If a package/runtime is not available in this repository, do not fake readiness; emit explicit blockers and document the exact production evidence required.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not change public API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not bundle migration rehearsal/cutover/rollback, license/dependency production-readiness, npm audit remediation, or back-office production-readiness cleanup unless Coordinator explicitly approves.
- Do not claim staging, production, client delivery, real Horizon production dashboard approval, real process-manager supervision, real Reverb public websocket delivery, real Reverb scale/load approval, real scheduler production SLOs, or final M10 release approval unless QA verifies real evidence.
- Do not expose Horizon dashboard publicly without a documented local/dev-only guard and production access policy.
- Do not add non-Laravel/off-stack external services or a second operational database without Coordinator approval.
- Do not commit real Reverb secrets, app keys, Horizon credentials, bearer tokens, DSNs, Cloudflare/R2 secrets, production URLs, private certificates, passwords, or signed URLs.
- Do not move tenant logo/theme/payment/domain/feature config into env.
- Do not run long-lived queue workers, scheduler loops, Horizon, or Reverb in a way that leaves unmanaged processes running after validation. Use bounded Docker commands for validation.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Horizon, Reverb, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
apps/platform-api/.env.example
compose.yaml
scripts/**
ops/m10/**
load-tests/README.md
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-bootstrap-seeders.md
.github/workflows/platform-api-m10.yml only if updating existing Docker-only M10 validation for this slice
ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
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
document/**
.github/** except .github/workflows/platform-api-m10.yml if needed for Docker-only M10 validation
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, build, test, runtime, migration, queue, scheduler, Horizon, Reverb, k6, and readiness validation commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Clean up the accepted P3 doc mismatch in `load-tests/README.md`:

```text
ticket-image CDN coverage requires CDN_BASE_URL plus IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
normal API BASE_URL is ignored for ticket-image CDN/R2 coverage
```

5. Inspect current queue, scheduler, realtime, compose, and console command foundations:

```text
compose.yaml platform-api-worker/platform-api-scheduler profiles
PLATFORM_WORKER_QUEUES in apps/platform-api/.env.example
apps/platform-api/config/queue.php
apps/platform-api/config/platform.php realtime settings
apps/platform-api/routes/console.php
apps/platform-api/app/Console/Commands/**
scripts/platform-api-worker-once.sh
scripts/platform-api-schedule-list.sh
AdminOperations realtime auth endpoints
```

6. Add a Docker-runnable runtime readiness command, preferably:

```text
php artisan platform:runtime:readiness --format=json
```

The command should output safe JSON for queue worker profiles, Horizon, Reverb, scheduler registration, helper scripts, blockers, validation commands, and `production_approved=false`.

7. The runtime readiness output must:

```text
not emit raw secrets or production URLs
not call external services
not start long-lived workers
not claim production approval
include local/dev verifiable status
include explicit blockers for missing Horizon/Reverb/package/process-manager/production evidence
include Docker validation commands
```

8. Define queue worker profiles and queue ownership by workload. Cover at minimum:

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

Ensure report/build jobs cannot be documented as sharing priority with booking/checkout/reward critical paths.

9. Add or update bounded Docker helper scripts where useful. Scripts must call Docker Compose or Docker only and must not run PHP/Artisan on the host.
10. Add scheduler workload registration for safe/idempotent workloads where appropriate. Candidate commands already present:

```text
stock:reservations:expire
sync:sold:process
rewards:process-checks
commission:calculate
platform:alerts:check --dry-run or documented non-mutating local mode
```

If a workload is not safe to schedule yet, document the blocker instead of registering it.

11. Ensure `schedule:list` provides useful local/dev evidence for registered workloads.
12. For Horizon readiness:

```text
verify whether Laravel Horizon is installed/configured
if installed, document dashboard route/access boundary and supervisor config expectations
if not installed, emit explicit blockers such as horizon_package_missing and horizon_supervisor_not_configured
do not expose a production dashboard or claim production supervision without real evidence
```

13. For Reverb readiness:

```text
verify Reverb env placeholders and realtime auth endpoint behavior
document app id/key/secret boundary without exposing raw secrets
add Docker/profile/runbook guidance for Reverb runtime if safe
emit explicit blockers where real websocket infrastructure, TLS, host, scaling, and load evidence are unavailable
```

14. Preserve admin/customer realtime auth API routes and response contracts. Do not change OpenAPI.
15. Update docs/runbooks only where needed to reflect Docker commands, local/dev readiness, and remaining production blockers.
16. Add tests for:

```text
runtime readiness command safe JSON
queue worker profile catalog and required queues
scheduler workload registration or explicit blockers
Horizon/Reverb readiness blockers and production boundary
load-tests/README.md TICKET_IMAGE_CDN_IMAGE_PATH cleanup
Docker Compose profile guardrails
no Cloudflare/CDN/R2 regression in existing M10 readiness tests
```

17. Run Docker-only validation commands.
18. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
```

## Acceptance Criteria

- `load-tests/README.md` documents `CDN_BASE_URL` plus `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`.
- Docker Compose config remains valid.
- Queue worker profile catalog covers every queue in `PLATFORM_WORKER_QUEUES`.
- Queue ownership separates critical customer/checkout/reward queues from report/build/monitoring workloads.
- `platform:runtime:readiness --format=json` or the chosen equivalent emits safe machine-readable local/dev readiness.
- Runtime readiness JSON keeps `production_approved=false`.
- Runtime readiness JSON does not expose Reverb secrets, Horizon credentials, tokens, production URLs, DSNs, or other sensitive values.
- Horizon readiness is either locally verifiable or explicitly blocked with clear production evidence requirements.
- Reverb readiness is either locally verifiable or explicitly blocked with clear production evidence requirements.
- Scheduler workloads are registered only when safe/idempotent, and unsafe/not-ready workloads are explicit blockers.
- `schedule:list` is useful for QA evidence.
- Bounded queue worker validation can run through Docker without host Artisan and without long-lived unmanaged processes.
- Existing realtime auth endpoints remain compatible with current tests and OpenAPI.
- Existing Cloudflare/CDN/R2 readiness tests remain green.
- No customer/back-office/source-of-truth contract drift is introduced.
- Full platform-api regression passes.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6/Horizon/Reverb commands.

Required setup:

```sh
docker compose config --quiet
docker compose --profile worker --profile scheduler config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
```

Required Backend regression:

```sh
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

Required runtime commands:

```sh
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
docker compose run --rm platform-api php artisan list
```

If Horizon/Reverb commands or Docker profiles are added, validate them only with bounded Docker commands such as `php artisan <command> --help`, `php artisan list`, or `docker compose --profile <profile> config --quiet`. Do not leave long-lived Horizon/Reverb/worker/scheduler processes running.

Required static/helper validation:

```sh
git status --short
sh -n scripts/platform-api-worker-once.sh
sh -n scripts/platform-api-schedule-list.sh
sh -n scripts/platform-runtime-readiness.sh
jq empty ops/m10/queue-worker-profiles.json
rg -n "TICKET_IMAGE_CDN_IMAGE_PATH|IMAGE_PATH|CDN_BASE_URL|BASE_URL" load-tests/README.md
rg -n "platform:runtime:readiness|Horizon|horizon|Reverb|reverb|schedule:list|queue:work|PLATFORM_WORKER_QUEUES" apps/platform-api docs/m10-deployment-monitoring-load-test.md ops/m10 scripts compose.yaml
rg -n "secret|password|token|private_key|BEGIN PRIVATE KEY|Bearer " apps/platform-api docs/m10-deployment-monitoring-load-test.md ops/m10 scripts load-tests/README.md
```

If a listed static artifact is not created because Backend chose a different safe equivalent, document the equivalent validation in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-horizon-reverb-scheduler-hardening-backend-handoff.md
```

Must include:

```text
what was done
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
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
