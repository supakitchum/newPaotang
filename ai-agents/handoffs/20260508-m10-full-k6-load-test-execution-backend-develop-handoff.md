# Handoff: M10 Full k6 Load Test Execution - Backend Develop

Date: 2026-05-08
Task: `20260508-m10-full-k6-load-test-execution-backend`
Agent: Backend Develop
Status: Completed

## ทำอะไรไป

- เพิ่ม Docker-only workflow สำหรับเตรียม fixture และรัน k6 baseline smoke/local-dev โดยไม่ commit secret
- เพิ่ม Artisan command `load-tests:k6:prepare` สำหรับสร้าง baseline fixture, bearer tokens, env artifact และ JSON fixture metadata
- เพิ่ม profile helper สำหรับ k6 (`K6_PROFILE=smoke|baseline|release-candidate`) และปรับ 7 scenario scripts ให้ใช้ env/fixture artifact เดียวกัน
- เพิ่ม backend implementation สำหรับ Partner Sync API ที่อยู่ใน `docs/openapi.yaml` แล้ว เพื่อให้ `partner-tenant-burst-sync.js` รันกับ API จริงได้
- เพิ่ม automated backend tests ครอบคลุม fixture command, token hash handling, stock search, checkout, reward checking และ partner sync idempotency/tenant mismatch
- อัปเดต load-test docs ให้ระบุ runner, artifact policy, threshold profile และ CDN blocker สำหรับ ticket image scenario

## Backend Files Changed

- `apps/platform-api/app/Console/Commands/PrepareK6BaselineCommand.php`
- `apps/platform-api/app/Modules/Partner/Http/Controllers/PartnerSyncController.php`
- `apps/platform-api/app/Modules/Partner/Services/PartnerSyncService.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `apps/platform-api/tests/Feature/M10K6LoadTestExecutionTest.php`

## Load Test / Ops Files Changed

- `load-tests/k6/lib/profile.js`
- `load-tests/k6/customer-stock-search.js`
- `load-tests/k6/concurrent-booking-same-stock.js`
- `load-tests/k6/checkout-wallet-consistency.js`
- `load-tests/k6/partner-tenant-burst-sync.js`
- `load-tests/k6/reward-publish-spike.js`
- `load-tests/k6/reward-checking-queue-chunk.js`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `load-tests/README.md`
- `load-tests/results/.gitignore`
- `scripts/k6-prepare-baseline-fixtures.sh`
- `scripts/k6-run-baseline.sh`
- `docs/m10-deployment-monitoring-load-test.md`

## API Endpoints Implemented

- `GET /api/v1/partner-sync/allocations`
- `POST /api/v1/partner-sync/events`

No OpenAPI contract was changed. The new routes implement paths already present in `docs/openapi.yaml`.

## Permissions / Tenant Checks Enforced

- Partner Sync requires bearer token matched against `partner_api_clients.secret_hash`.
- Partner Sync requires `X-Partner-Id` and `X-Tenant-Id` headers.
- Partner must be active.
- Tenant must belong to the partner and must be `active` or `maintenance`.
- Incoming partner sync event `tenant_id` and `partner_id` must match the request headers.
- Duplicate partner sync events are de-duped through `sync_inbox.event_id`.
- Reward checking queue scenario uses central admin bearer token and `X-Admin-Scope: central`.
- Customer stock/search and checkout scenarios continue to use tenant-host/request-scoped backend auth and existing tenant isolation.

## Fixture / Secret Handling

- Fixture command emits generated metadata to:
  - `load-tests/results/k6-baseline-env.json`
  - `load-tests/results/k6-baseline.env`
- Generated bearer tokens are written only to ignored runtime artifacts for k6 execution.
- Database stores only token hashes for generated admin/customer/partner access tokens.
- `load-tests/results/.gitignore` keeps generated env files, summaries, and local run artifacts out of git.

## k6 Scenarios Covered

| Scenario | Backing API status | Local smoke result |
| --- | --- | --- |
| `customer-stock-search.js` | API-backed | Passed |
| `concurrent-booking-same-stock.js` | API-backed | Passed |
| `checkout-wallet-consistency.js` | API-backed | Passed |
| `partner-tenant-burst-sync.js` | API-backed | Passed |
| `reward-publish-spike.js` | API-backed | Passed |
| `reward-checking-queue-chunk.js` | API-backed | Passed |
| `ticket-image-cdn-spike.js` | Runnable template | Skipped locally until CDN/R2 image env is supplied |

Latest k6 summary artifacts:

- `load-tests/results/20260508T070830Z/customer-stock-search.summary.json`
- `load-tests/results/20260508T070830Z/concurrent-booking-same-stock.summary.json`
- `load-tests/results/20260508T070830Z/checkout-wallet-consistency.summary.json`
- `load-tests/results/20260508T070830Z/partner-tenant-burst-sync.summary.json`
- `load-tests/results/20260508T070830Z/reward-publish-spike.summary.json`
- `load-tests/results/20260508T070830Z/reward-checking-queue-chunk.summary.json`
- `load-tests/results/20260508T070830Z/ticket-image-cdn-spike.skipped.json`

Smoke metrics from latest run:

| Scenario | Checks | p95 | http_req_failed |
| --- | ---: | ---: | ---: |
| `customer-stock-search` | 20/20 | 42.60 ms | 0% |
| `concurrent-booking-same-stock` | 6/6 | 80.37 ms | 0% |
| `checkout-wallet-consistency` | 6/6 | 74.73 ms | 0% |
| `partner-tenant-burst-sync` | 84/84 | 44.11 ms | 0% |
| `reward-publish-spike` | 38/38 | 45.92 ms | 0% |
| `reward-checking-queue-chunk` | 6/6 | 56.27 ms | 0% |

## Commands / Tests Run

All runtime, PHP, Composer, Artisan, test, and k6 commands were run through Docker/container commands.

- `docker compose config --quiet` - passed
- `docker compose up -d postgres valkey platform-api` - passed
- `docker compose run --rm platform-api composer install` - passed
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - passed
- `docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest` - passed, 1 test / 37 assertions
- `docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest` - passed, 3 tests / 67 assertions
- `docker compose run --rm platform-api php artisan test --filter=M10` - passed, 6 tests / 131 assertions
- `docker compose run --rm platform-api php artisan test` - passed, 121 tests / 2998 assertions
- `docker compose exec platform-api php artisan route:list` - passed, new partner sync routes present
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - passed before smoke
- `docker compose exec platform-api php artisan platform:smoke` - passed
- `docker run --rm grafana/k6:latest version` - passed
- k6 inspect via `docker run --rm grafana/k6:latest inspect` for all 7 scripts - passed
- `scripts/k6-prepare-baseline-fixtures.sh` - passed, generated ignored fixture artifacts
- `scripts/k6-run-baseline.sh` - passed for 6 API-backed scenarios, ticket image scenario skipped with blocker artifact

## Known Risks / Questions

- Ticket image CDN spike is blocked locally until real `CDN_BASE_URL` and `IMAGE_PATH` are provided from Cloudflare/R2 or equivalent CDN test fixture.
- Release-candidate k6 profile is wired but not executed in this local/dev pass; it should be run only against an approved staging/load-test environment.
- Generated k6 env artifacts contain bearer tokens by design and must remain ignored/runtime-only.
- Partner Sync API implementation is intentionally scoped to load-test readiness and OpenAPI-shaped paths; deeper production sync processing can be expanded by a future task if Orchestrator asks for it.

## Next Agent

Orchestrator
