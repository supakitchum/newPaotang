# QA Report

## Task

`20260508-m10-horizon-reverb-scheduler-hardening`

QA verdict: PASS WITH RISKS.

Backend/Ops implementation satisfies the local/dev acceptance criteria for runtime readiness, queue ownership, scheduler registration, Horizon/Reverb blockers, Docker helper scripts, and the load-test README cleanup. The remaining risks are expected release gates for real Horizon supervision, Reverb public websocket/TLS/scaling, production scheduler SLOs, and final M10 approval.

## Scope Tested

- Docker runtime policy for package, migration, test, queue, scheduler, and Artisan commands.
- `platform:runtime:readiness --format=json` safe output and release boundary.
- Queue worker profile catalog coverage and critical/background queue separation.
- Horizon readiness blockers and dashboard exposure boundary.
- Reverb redaction, blocker state, and existing realtime auth route presence.
- Scheduler registration through `schedule:list`.
- Helper scripts for bounded worker, schedule list, and runtime readiness.
- `load-tests/README.md` cleanup for ticket-image CDN image-path env names.
- Route list/API drift, smoke check, focused regression, and full platform API regression.

Artifacts:

`ai-agents/reports/artifacts/20260508-m10-horizon-reverb-scheduler-hardening-qa/`

## Files Inspected

- `apps/platform-api/app/Console/Commands/PlatformRuntimeReadinessCommand.php`
- `apps/platform-api/app/Shared/Runtime/RuntimeReadinessService.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/config/queue.php`
- `apps/platform-api/tests/Feature/M10HorizonReverbSchedulerHardeningTest.php`
- `compose.yaml`
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
- `docs/m10-deployment-monitoring-load-test.md`
- `docs/backend-console-commands.md`

## Commands Run

Docker/runtime:

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
docker compose run --rm [sanitized fake Reverb env] platform-api php artisan platform:runtime:readiness --format=json
```

Static/helper:

```sh
git status --short
sh -n scripts/platform-api-worker-once.sh
sh -n scripts/platform-api-schedule-list.sh
sh -n scripts/platform-runtime-readiness.sh
jq empty ops/m10/queue-worker-profiles.json
rg for runtime, queue, scheduler, Horizon, Reverb, README cleanup, and sensitive-key patterns
final rg for sanitized fake Reverb values in QA report/artifacts
```

## Test Results

- Docker compose config and worker/scheduler profile config: PASS.
- Composer install: PASS.
- `migrate:fresh --seed --env=testing`: PASS.
- `M10HorizonReverbSchedulerHardeningTest`: PASS, 4 tests / 68 assertions.
- `M10DeploymentReadinessTest`: PASS, 5 tests / 94 assertions.
- `M10ProductionObservabilityAlertingTest`: PASS, 5 tests / 81 assertions.
- `M10CloudflareHttpsWafCdnR2Test`: PASS, 5 tests / 136 assertions.
- `AdminOperationsTest`: PASS, 7 tests / 95 assertions.
- `MaintenanceTest`: PASS, 2 tests / 37 assertions.
- `ConsoleCommandStructureTest`: PASS, 3 tests / 80 assertions.
- Full platform API suite: PASS, 135 tests / 3363 assertions.
- `route:list`: PASS, 199 routes; no new HTTP endpoint attributable to this slice.
- `platform:smoke`: PASS after reseed.
- `schedule:list`: PASS; required bounded/chunked/dry-run workloads are visible.
- `queue:work --once --tries=1 --timeout=30 --queue=default`: PASS and exited without a long-lived worker.
- `artisan list`: PASS; `platform:runtime:readiness` is registered.

## Runtime Readiness Review

- Overall status: `blocked_external`, expected because Horizon/Reverb production evidence is unavailable.
- `production_approved=false`.
- `boundary.local_dev_verifiable=true`.
- `boundary.external_services_called=false`.
- `boundary.long_lived_processes_started=false`.
- `boundary.horizon_dashboard_publicly_exposed=false`.
- `boundary.reverb_public_websocket_approved=false`.
- `queue_workers.status=ready_local`; configured queue count is 22.
- `scheduler.status=ready_local`; `missing_required_workloads=[]`.
- `helpers.status=ready_local`.
- Horizon remains blocked with `horizon_package_missing`, `horizon_config_missing`, supervisor, access-policy, and process-manager blockers.
- Reverb remains blocked with package/runtime/TLS/public-host/scaling/load blockers.

## Safe Output / Redaction Review

- Fake Reverb probe used sanitized fake app id, key, secret, host, port, and scheme.
- Raw fake value leak count: `0`.
- Reverb output uses configured booleans plus `[CONFIGURED]`, `[REDACTED]`, or `null`.
- Static secret scan matches expected source/test placeholders, env names, redaction fixtures, and token-handling code; no private key, committed bearer token, or raw fake Reverb value was found in QA artifacts after sanitization.

## Queue / Scheduler / Helpers

- `ops/m10/queue-worker-profiles.json`: valid JSON.
- Queue ownership covers all 22 `PLATFORM_WORKER_QUEUES` exactly once.
- `missing=none`, `unknown=none`, duplicate ownership/profile queues `none`.
- `report-build` is in `growth-reporting`, separate from `checkout-finalize` and `reward-check-high`.
- Scheduler contains:
  - `stock:reservations:expire --limit=100`
  - `stock:sold:sync --limit=100`
  - `reward:check --chunk=100`
  - `commission:calculate --limit=100`
  - `platform:alerts:check --dry-run --format=json`
- `routes/console.php` uses `withoutOverlapping()` for all five workloads.
- Helper scripts use `docker compose` and do not run PHP/Artisan directly on host.

## Docs / Runbooks

- `load-tests/README.md` now documents `CDN_BASE_URL` plus `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`.
- `load-tests/README.md` states normal API `BASE_URL` is intentionally ignored for ticket-image CDN/R2 coverage.
- `docs/m10-deployment-monitoring-load-test.md` documents runtime readiness, Horizon/Reverb blockers, and scheduler boundaries.
- `docs/backend-console-commands.md` lists `platform:runtime:readiness`.
- Ops runbooks preserve local/dev vs staging/production boundaries.

## Defects

None found in this QA pass.

## Risks / Not Tested

- Real Horizon package/config, dashboard access policy, supervisor/process-manager setup, and production queue SLOs were not approved or tested.
- Real Reverb package/runtime, public websocket host, TLS, scaling, pub-sub behavior, and load evidence were not approved or tested.
- Real scheduler production leadership/SLOs and final M10 release approval remain open gates.
- Workspace has broad dirty/untracked multi-agent changes; QA did not edit implementation, docs, tasks, handoffs, ops, scripts, compose, customer, back-office, or source-of-truth contract files.

## Recommendation

Coordinator can approve this slice for local/dev readiness with the stated release gates still open. Do not treat this as staging, production, client-delivery, Horizon supervision, Reverb public websocket, or final M10 approval.

## Next Agent

Coordinator

