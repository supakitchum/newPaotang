# QA Report: 20260508-m10-deployment-monitoring-load-test

## QA Verdict

PASS WITH RISKS

The M10 backend/ops foundation is implemented and measurable for local/dev QA. Docker image build, Compose roles, health endpoints, `platform:smoke`, monitoring defaults, focused tests, full backend regression, worker/scheduler command paths, CI/docs, and k6 scaffold syntax all passed.

This is not staging, production, or client-delivery approval. Full load-test execution, production Cloudflare/HTTPS/CDN/R2, observability backend, scheduler workloads, Horizon/Reverb hardening, license/dependency closure, and migration rehearsal data remain release gates.

## Scope Reviewed

- M10 backend task and QA task.
- Backend handoff and Orchestrator QA handoff.
- Main plan and M10 source documents.
- Back-office approval and accepted risk carry-forward.
- `compose.yaml`
- `apps/platform-api/Dockerfile`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/health.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Console/Commands/PlatformSmokeCommand.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/HealthController.php`
- `apps/platform-api/database/seeders/DemoTenantSeeder.php`
- `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/BootstrapSeederTest.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `.github/workflows/platform-api-m10.yml`
- `docs/m10-deployment-monitoring-load-test.md`
- `ops/m10/runtime-readiness.md`
- `scripts/platform-api-smoke.sh`
- `scripts/platform-api-worker-once.sh`
- `scripts/platform-api-schedule-list.sh`
- `load-tests/README.md`
- `load-tests/k6/*.js`

## Docker Runtime Policy

PASS. `docs/docker-runtime-policy.md` confirms Docker Compose is the only supported runtime. All PHP, Composer, Artisan, migration, test, queue, scheduler, smoke, build, and k6 commands were run through Docker. Host usage was limited to file inspection, `git`, `curl`, and report/artifact writing.

## Scope Drift Findings

PASS WITH WORKSPACE NOISE.

M10-owned files are in approved backend/ops scope: `apps/platform-api/**`, `compose.yaml`, `.github/workflows/**`, `load-tests/**`, `ops/**`, `scripts/**`, and M10 backend docs.

The workspace remains broadly dirty/untracked from earlier multi-agent slices. Current `git diff --name-only` still shows unrelated changes under `apps/customer/**`, `document/**`, and shared agent files. Those were already present as workspace noise in prior QA context and are not attributed to this M10 backend slice. No M10 evidence showed edits to `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, or back-office/customer source as part of this slice.

## Compose / Runtime Roles

PASS.

- `platform-api` HTTP runtime preserved on port 8000.
- `platform-api-worker` profile exists with explicit configurable `PLATFORM_WORKER_QUEUES`.
- `platform-api-scheduler` profile exists and runs `schedule:run` loop through Docker.
- `platform-api-smoke` profile exists and runs `php artisan platform:smoke`.
- `postgres` and `valkey` health dependencies are preserved.
- `customer` and `back-office` local services remain in `compose.yaml`.
- Workspace root is mounted read-only at `/workspace:ro` for guardrail checks.

## Docker Image / Build Review

PASS.

`apps/platform-api/Dockerfile` has `base`, `development`, and `production` targets. The production target copies app code and installs optimized Composer dependencies. No Composer/package lock changes or language dependency upgrades were introduced by this QA review. `docker compose build platform-api` passed.

## Health Endpoint Review

PASS.

Routes exist and returned `200 OK` under Docker runtime:

- `GET /health`
- `GET /health/live`
- `GET /health/ready`
- `GET /api/v1/health`
- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

`route:list` showed 197 routes including both root health aliases and versioned health routes. `HealthController` returns app/database/cache status only and does not expose secrets.

## platform:smoke Review

PASS.

`platform:smoke` checks app config, DB connectivity, Redis-backed cache, queue config, monitoring defaults, and seeded central/tenant login viability. Both modes passed:

```text
platform:smoke - app/database/cache/queue/monitoring-defaults/seeded-logins ok
platform:smoke --no-seed-login - app/database/cache/queue/monitoring-defaults ok
```

`docker compose --profile smoke run --rm platform-api-smoke` also passed.

## Monitoring / Usage Defaults

PASS.

`DemoTenantSeeder` and `PartnerProvisioningService` both create monitoring profile, usage meters, `default_health` alert policy, health check, and billing plan binding defaults. Required meters are present in code/tests/docs:

```text
api_requests
booking_requests
checkout_requests
orders
sold_tickets
stock_synced
image_bandwidth_gb
storage_gb
queue_jobs
sync_events
```

Focused tests verified defaults for seeded demo partners and provisioning paths.

## Env Template Boundary

PASS.

`.env.example` additions are infrastructure/runtime level: DB, Redis/Valkey, queue, cache/session, worker queues, S3/R2/CDN placeholders, Reverb placeholders, metrics toggles, and approved local seed overrides. The required scan for `LOGO|THEME|PAYMENT|DOMAIN|FEATURE` returned no matches, so tenant-level logo/theme/payment/domain/feature config was not moved into env.

## Load-Test Scaffold Review

PASS WITH RISKS.

All seven required k6 scaffold files exist and passed `docker run ... grafana/k6:latest inspect`:

- `customer-stock-search.js`
- `concurrent-booking-same-stock.js`
- `checkout-wallet-consistency.js`
- `partner-tenant-burst-sync.js`
- `reward-publish-spike.js`
- `reward-checking-queue-chunk.js`
- `ticket-image-cdn-spike.js`

Scripts use configurable `BASE_URL`, default to a Docker-hosted local API target where applicable, and fail early when required fixture data/tokens are missing. Full scenario execution was not claimed because fixture data, bearer tokens, production-like stock/game data, and CDN/object-storage setup were out of scope.

Risk: default `host.docker.internal` targets are convenient on Docker Desktop but may need runner-specific mapping on Linux CI/load-test runners before actual `k6 run` execution.

## CI Workflow Review

PASS.

`.github/workflows/platform-api-m10.yml` uses Docker-only commands for build, dependency install, migration/seed, full tests, reseed, smoke, and scheduler list. No host PHP/Composer/Artisan project commands were found outside Docker.

## Docs / Migration / Cutover / Rollback

PASS.

`docs/m10-deployment-monitoring-load-test.md` and `ops/m10/runtime-readiness.md` document Docker-only runtime roles, health/smoke checks, monitoring/usage defaults, load-test prerequisites, migration rehearsal, cutover, rollback, accepted BO risks, and release gates not yet satisfied. Cloudflare/HTTPS/CDN and production observability are documented as gates, not as completed approval.

## Docker Validation Commands And Results

PASS.

```text
docker compose config --quiet - PASS
docker compose build platform-api - PASS
docker compose up -d postgres valkey platform-api - PASS
docker compose run --rm platform-api composer install - PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing - PASS
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest - PASS, 5 tests / 94 assertions
docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest - PASS, 4 tests / 53 assertions
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest - PASS, 3 tests / 45 assertions
docker compose run --rm platform-api php artisan test - PASS, 120 tests / 2923 assertions
docker compose exec platform-api php artisan route:list - PASS, 197 routes
curl -I /health, /health/live, /health/ready - PASS, 200 OK
curl -I /api/v1/health, /api/v1/health/live, /api/v1/health/ready - PASS, 200 OK
docker compose exec platform-api php artisan platform:smoke - PASS
docker compose exec platform-api php artisan platform:smoke --no-seed-login - PASS
docker compose run --rm platform-api php artisan queue:work --once --tries=1 - PASS, exited 0
docker compose run --rm platform-api php artisan schedule:list - PASS, no scheduled tasks defined
docker compose --profile smoke run --rm platform-api-smoke - PASS
docker run --rm grafana/k6:latest version - PASS
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect <7 scripts> - PASS
```

Note: an initial QA attempt to run `M10DeploymentReadinessTest`, `BootstrapSeederTest`, and `ConsoleCommandStructureTest` in parallel caused expected PostgreSQL schema refresh collisions. Sequential reruns passed and are the results recorded above.

## Accepted Risks Carried Forward

- BO hydration mismatch warnings/errors around SSR protected shell and Meno/Waves mutations.
- Stale marker protected-shell behavior before client redirect, previously sampled without final leak/loop.
- Meno license notice missing before staging, production, or client delivery.
- npm audit vulnerabilities remain production-readiness work.
- Default seed credentials are local QA only.
- `migrate:fresh --seed` is destructive and local/test only.
- Maintenance bypass list endpoint remains absent.
- Backend menu category/icon fields remain absent.
- Nuxt DEP0180 and media-33 runtime warnings remain.
- Screenshot CDP timeout limitation remains from BO visual QA.

## Release Gates Still Not Satisfied

- Production process manager/web server image hardening.
- Horizon dashboard and queue supervision.
- Reverb production deployment.
- Cloudflare account/API integration, HTTPS enforcement, and WAF/rate-limit rules.
- Real CDN/R2/object-storage ticket image load test.
- Real old-data migration scripts and rehearsal data.
- Production secret management.
- Meno license compliance.
- npm audit remediation.
- Full M10 load-test execution with prepared fixtures, auth tokens, thresholds, and runner ownership.
- Scheduler workload registration; `schedule:list` currently reports no scheduled tasks.

## Defects

No blocking defects found in the M10 backend/ops foundation.

## Recommendation For Coordinator

Coordinator can accept this M10 backend/ops foundation as `PASS WITH RISKS` for local/dev QA readiness. Do not treat this as production/staging/client-delivery approval. Route follow-up ownership for real load-test fixture execution, production observability, Cloudflare/CDN, scheduler workload registration, Horizon/Reverb hardening, license, dependency, and migration rehearsal gates.

## Next Agent

Coordinator
