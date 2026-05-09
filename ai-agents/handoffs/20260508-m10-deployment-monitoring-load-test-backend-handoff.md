# 20260508 M10 Deployment Monitoring Load-Test - Backend Develop Handoff

Task: `20260508-m10-deployment-monitoring-load-test-backend`
Agent: Backend Develop
Date: 2026-05-08
Next Agent: Orchestrator

## ทำอะไรไป

- Implemented M10 backend/runtime readiness foundations for `apps/platform-api` without changing customer/back-office apps and without changing `docs/openapi.yaml`.
- Added Docker runtime roles for API, worker, scheduler, and one-shot smoke in `compose.yaml`.
- Added production Dockerfile target for platform API image build path while keeping local development target intact.
- Added root health aliases matching OpenAPI (`/health`, `/health/live`, `/health/ready`) alongside existing `/api/v1/health*` routes.
- Added `platform:smoke` command to validate app config, DB, cache, queue config, seeded logins, and monitoring defaults.
- Extended demo/provisioning monitoring defaults to include partner monitoring profile, usage meters, alert policy, and health check defaults.
- Added M10 deployment/monitoring/load-test documentation, CI guardrail workflow, Docker helper scripts, and k6 scaffolding.
- Added M10-focused tests and updated affected console/seeder tests.

## backend files changed

- `compose.yaml`
- `.github/workflows/platform-api-m10.yml`
- `apps/platform-api/Dockerfile`
- `apps/platform-api/.env.example`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/health.php`
- `apps/platform-api/app/Console/Commands/PlatformSmokeCommand.php`
- `apps/platform-api/app/Console/README.md`
- `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
- `apps/platform-api/database/seeders/DemoTenantSeeder.php`
- `apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php`
- `apps/platform-api/tests/Feature/BootstrapSeederTest.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `docs/backend-console-commands.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `load-tests/README.md`
- `load-tests/k6/customer-stock-search.js`
- `load-tests/k6/concurrent-booking-same-stock.js`
- `load-tests/k6/checkout-wallet-consistency.js`
- `load-tests/k6/partner-tenant-burst-sync.js`
- `load-tests/k6/reward-publish-spike.js`
- `load-tests/k6/reward-checking-queue-chunk.js`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `ops/m10/runtime-readiness.md`
- `scripts/platform-api-smoke.sh`
- `scripts/platform-api-worker-once.sh`
- `scripts/platform-api-schedule-list.sh`

## API endpoints implemented

- `GET /health`
- `GET /health/live`
- `GET /health/ready`

Existing versioned endpoints remain available:

- `GET /api/v1/health`
- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

No business API contract changes were made.

## permissions/tenant checks enforced

- No RBAC bypasses were added.
- No tenant-scope bypasses were added.
- Root health endpoints are intentionally public readiness endpoints matching OpenAPI and use the existing `HealthController`.
- Env template additions are infrastructure/runtime only; tenant logo/theme/payment/domain/feature config remains database-owned.
- Full feature suite passed after changes, including auth, RBAC, tenant isolation, wallet, checkout, reward, stock, audit, support, and report tests.

## runtime/deployment approach

- `platform-api`: HTTP API service.
- `platform-api-worker`: queue worker profile using explicit backend queue list via `PLATFORM_WORKER_QUEUES`.
- `platform-api-scheduler`: scheduler loop profile using Docker-only `php artisan schedule:run`.
- `platform-api-smoke`: one-shot smoke profile using `php artisan platform:smoke`.
- Platform API container mounts workspace read-only at `/workspace` for local Docker guardrail tests that validate repo-level files.
- CI workflow runs build, up, composer install, migrate/seed, full tests, reseed for smoke, smoke, and schedule list through Docker only.

## monitoring/usage readiness approach

- Demo seeder and partner provisioning now create aligned default usage meters:
  `api_requests`, `booking_requests`, `checkout_requests`, `orders`, `sold_tickets`, `stock_synced`, `image_bandwidth_gb`, `storage_gb`, `queue_jobs`, `sync_events`.
- Demo seeder now creates `default_health` alert policy for each demo partner.
- `platform:smoke` checks active monitoring profile, usage meter, alert policy, and health check records.

## load-test scaffolding summary

Added 7 k6 scaffolds:

- `customer-stock-search.js`
- `concurrent-booking-same-stock.js`
- `checkout-wallet-consistency.js`
- `partner-tenant-burst-sync.js`
- `reward-publish-spike.js`
- `reward-checking-queue-chunk.js`
- `ticket-image-cdn-spike.js`

Scripts require Docker execution and explicit env/data for write-heavy or data-dependent scenarios. They fail early when required values are missing instead of pretending a scenario passed.

## migration/cutover/rollback docs summary

Documented in `docs/m10-deployment-monitoring-load-test.md`:

- Docker-only command boundary
- API/worker/scheduler/smoke runtime roles
- Health and smoke checks
- Monitoring and usage-metering defaults
- Load-test scenario prerequisites
- Migration rehearsal checklist
- Cutover checklist
- Rollback checklist
- Accepted risks carried forward
- Release gates not yet satisfied

## commands/tests run

- `docker compose config --quiet` - PASS
- `docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest` - PASS, 5 tests / 94 assertions
- `docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest` - PASS, 4 tests / 53 assertions
- `docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest` - PASS, 3 tests / 45 assertions
- `docker compose build platform-api` - PASS
- `docker compose up -d postgres valkey platform-api` - PASS
- `docker compose run --rm platform-api composer install` - PASS
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - PASS
- `docker compose run --rm platform-api php artisan test` - PASS, 120 tests / 2923 assertions
- `docker compose exec platform-api php artisan route:list` - PASS, 197 routes
- `curl -I --max-time 10 http://localhost:8000/health` - PASS, `200 OK`
- `curl -I --max-time 10 http://localhost:8000/health/live` - PASS, `200 OK`
- `curl -I --max-time 10 http://localhost:8000/health/ready` - PASS, `200 OK`
- `docker compose exec platform-api php artisan platform:smoke` - PASS after seeded DB rebuild
- `docker compose run --rm platform-api php artisan queue:work --once --tries=1` - PASS, exited 0
- `docker compose run --rm platform-api php artisan schedule:list` - PASS, no scheduled tasks defined
- `docker run --rm grafana/k6:latest version` - PASS, k6 image available after pull
- `docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect <script>` for all 7 scripts - PASS
- Static forbidden env scan for tenant logo/theme/payment/domain/feature env keys - PASS, no matches

## known risks/questions

- Full PHPUnit suite refreshes the database; seed-dependent smoke must run after a seed/reseed. CI now performs a reseed before `platform:smoke`.
- Actual k6 scenario execution is not claimed as complete because load-test fixture data, bearer tokens, and production-like tenant stock/game setup are not part of this Backend Develop slice. A short attempted stock-search run before fixture setup returned validation failure due missing game data; scaffolds now require explicit `GAME_ID`.
- `schedule:list` currently reports no scheduled tasks. Runtime command path is validated, but scheduler workload registration remains a follow-up if Orchestrator assigns scheduled jobs.
- Production Cloudflare/HTTPS, CDN/R2, real observability backend, alert delivery, and production rollback automation remain release-gate work beyond this slice.
- Carry-forward risks from prior approval materials remain: BO hydration/stale marker risks, Meno license, npm audit, local seed credentials, destructive local/testing migrate command, support bypass list absence, backend menu category/icon absence, Nuxt warnings, screenshot CDP timeout.

## follow-up slices

- Back Office Develop: surface health/usage/alert/readiness UI only after Orchestrator assigns BO task.
- Customer Develop: validate public health/CDN/load-test tenant fixture needs only after Orchestrator assigns customer task.
- QA Tester: run M10 QA pass with Docker validation, k6 fixture plan, and release-gate checklist.
- Orchestrator/Coordinator: decide production monitoring backend, alert channels, CDN/R2 env strategy, and load-test fixture ownership.

## Next Agent

Orchestrator
