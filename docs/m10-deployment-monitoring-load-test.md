# M10 Deployment Monitoring Load Test

## Purpose

This document records the first backend/ops foundation for Milestone 10. It makes release-readiness measurable for local/dev and QA, but it is not staging, production, or client-delivery approval.

## Runtime Services

Docker Compose is the only supported runtime. The backend roles are:

```text
platform-api: HTTP API runtime on port 8000
platform-api-worker: queue worker profile using the shared platform-api codebase
platform-api-scheduler: scheduler loop profile using the shared platform-api codebase
platform-api-smoke: one-shot platform:smoke readiness profile
postgres: PostgreSQL
valkey: Redis-compatible cache/queue/lock/session service
customer: preserved local customer service, frozen for current backend-only closeout
back-office: preserved local back-office service, phase-next and excluded from current backend-only closeout
```

Current phase boundary, dated 2026-05-09: M10 closeout now targets backend deploy-readiness only. Back-office build/deploy/readiness work is deferred to the next phase and must not block backend release-gate review.

Worker and scheduler examples:

```sh
docker compose --profile worker up platform-api-worker
docker compose --profile scheduler up platform-api-scheduler
docker compose --profile smoke run --rm platform-api-smoke
docker compose run --rm platform-api php artisan queue:work --once --tries=1
docker compose run --rm platform-api php artisan schedule:list
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
```

## Docker-only commands

All runtime, package, build, migration, queue, scheduler, test, and load-test commands must use Docker:

```sh
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, migrations, queue workers, or schedulers directly on the host machine.

## Image And Runtime Roles

`apps/platform-api/Dockerfile` has:

```text
base: PHP extensions and Composer
development: bind-mounted local runtime for Docker Compose
production: copied application code and optimized Composer autoload
```

The production target is a build artifact foundation. Production-grade web serving, process supervision, Horizon, Reverb, and managed deployment are still release-gate work.

## Runtime Hardening Readiness

Local/dev runtime hardening is measured by:

```sh
docker compose exec platform-api php artisan platform:runtime:readiness --format=json
scripts/platform-runtime-readiness.sh
scripts/platform-api-worker-once.sh
scripts/platform-api-schedule-list.sh
```

The runtime readiness report covers queue worker profiles, queue ownership, Horizon blockers, Reverb blockers, scheduler registration, helper scripts, Docker validation commands, and `production_approved=false`.

Runtime artifacts:

```text
ops/m10/runtime-hardening-readiness.md
ops/m10/queue-worker-profiles.json
ops/m10/horizon-queue-supervision.md
ops/m10/reverb-deployment-readiness.md
ops/m10/scheduler-workload-runbook.md
```

Horizon and Reverb are explicit blockers until their packages, profiles, access policies, TLS/public hosts, scaling evidence, and process-manager supervision are approved. Queue worker validation remains bounded with `queue:work --once`; do not leave unmanaged long-lived workers, scheduler loops, Horizon, or Reverb processes running during validation.

## Migration Rehearsal, Cutover, And Rollback Readiness

Local/dev migration rehearsal readiness is measured by:

```sh
docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
scripts/platform-migration-rehearsal.sh
scripts/platform-cutover-preflight.sh
scripts/platform-rollback-drill.sh
```

The migration rehearsal report covers old-data migration strategy, synthetic/seeded rehearsal fixtures, database and object-storage snapshot requirements, cutover checklist, rollback drill boundaries, production secret-management placeholders, Docker validation commands, and `production_approved=false`.

Migration/cutover/rollback artifacts:

```text
ops/m10/old-data-migration-strategy.md
ops/m10/migration-rehearsal-runbook.md
ops/m10/migration-rehearsal-fixtures.md
ops/m10/cutover-runbook.md
ops/m10/rollback-drill-runbook.md
ops/m10/snapshot-requirements.md
ops/m10/production-secret-boundary.md
```

The local/dev rehearsal uses synthetic and seeded data only. Real old-data sources, real production snapshots, object-storage metadata snapshots, production secret-management, staging rehearsal, production cutover, and production rollback remain explicit blockers. Do not run host PHP/Artisan, psql, pg_dump, cloud CLIs, destructive production migrations, or real data imports from this workspace.

## Environment Variable Boundaries

Environment templates cover infrastructure config only:

```text
DB_*
REDIS_*
QUEUE_CONNECTION
REDIS_QUEUE
PLATFORM_WORKER_QUEUES
CACHE_STORE
SESSION_DRIVER
APP_URL and platform site URLs
S3/R2/CDN placeholders
Cloudflare readiness placeholders
REVERB placeholders
PLATFORM_METRICS_* toggles
approved local seed credential overrides
```

Tenant-level values must remain in database-backed tenant config, not env files:

```text
site name
logo
theme colors
payment channels
commission rules
menus and permissions
domains
feature flags
maintenance settings
```

## Cloudflare And HTTPS Readiness Gates

Public launch is blocked until these are verified outside local Docker:

```text
Cloudflare proxy enabled for every public tenant domain
HTTPS redirect active
Full strict SSL or equivalent origin certificate configured
custom domain DNS and SSL readiness recorded before status=active
payment/webhook routes use cache-bypass rules
ticket images are served through CDN/object storage, not Laravel per request
```

Local/dev readiness can be measured without calling Cloudflare:

```sh
docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json
scripts/platform-cloudflare-readiness.sh
```

The command emits redacted Cloudflare/R2 config presence, domain readiness, WAF/cache artifact status, ticket-image CDN prerequisites, blockers, and `production_approved=false`.

Configured Cloudflare/CDN/R2 values are reported as booleans or constant placeholders only; account IDs, zone IDs, tokens, API base URLs, CDN hosts, R2 endpoints, buckets, keys, and ticket-image object paths must not appear raw in readiness JSON.

Safe infrastructure placeholders:

```text
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_ZONE_ID
CLOUDFLARE_API_TOKEN
CLOUDFLARE_API_BASE_URL
CLOUDFLARE_DRY_RUN
CLOUDFLARE_PROXY_REQUIRED
CLOUDFLARE_HTTPS_REQUIRED
R2_ENDPOINT
R2_BUCKET
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
CDN_BASE_URL
TICKET_IMAGE_CDN_REQUIRED
TICKET_IMAGE_CDN_IMAGE_PATH
```

Cloudflare/CDN/R2 ops artifacts:

```text
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/cloudflare-waf-rate-limit-rules.json
ops/m10/cloudflare-cache-bypass-rules.json
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
```

The WAF/rate-limit template covers public tenant pages, public stock/search/result endpoints, customer auth/booking/checkout, admin/back-office APIs, partner sync, payment/topup webhooks, and support/impersonation-sensitive paths. The cache-bypass template covers `/api/**`, webhooks/payment callbacks, admin/auth/session-protected paths, tenant maintenance dynamic pages, partner sync, and immutable static/ticket-image cache policies.

## Health And Smoke Checks

HTTP health endpoints:

```text
GET /health
GET /health/live
GET /health/ready
GET /api/v1/health
GET /api/v1/health/live
GET /api/v1/health/ready
```

Docker smoke command:

```sh
docker compose exec platform-api php artisan platform:smoke
```

Run the seed-dependent smoke check after a successful seed. If the full PHPUnit suite ran immediately before smoke, rebuild the seeded local/testing database first because the feature suite uses database refreshes:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec platform-api php artisan platform:smoke
```

`platform:smoke` checks:

```text
app config visibility
database connectivity
Redis/Valkey-backed cache connectivity
queue connection visibility
seeded local central admin and tenant owner credential viability
partner monitoring profile, usage meter, alert policy, and health check readiness
```

Use `--no-seed-login` only for pre-seed dependency checks:

```sh
docker compose run --rm platform-api php artisan platform:smoke --no-seed-login
```

## Monitoring And Usage-Metering Readiness

Partner provisioning and demo seeders must create:

```text
partner_monitoring_profiles
partner_usage_meters
partner_usage_events
partner_daily_usage_summaries
partner_alert_policies
partner_alert_events
partner_health_checks
partner_billing_plan_bindings
```

Default usage meters:

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

Metrics labels must include partner and tenant context where implemented:

```text
platform=newpaotang
module
partner_id
tenant_id
deployment_mode
endpoint
queue
game_id
```

Daily usage summary and usage event tables are local/dev readiness sinks for QA-verifiable metrics artifacts. Production collection jobs and external analytics feeds remain release-gate work; this slice does not add a second analytics database.

M10 production observability/alerting readiness adds local/dev verifiable commands and artifacts without claiming production delivery:

```sh
docker compose exec platform-api php artisan platform:observability:report --format=json
docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json
```

`platform:observability:report` emits a redacted JSON signal inventory for API, DB, cache, queue, partner sync, booking, checkout, reward, support access, security, and usage/billing signals. `platform:alerts:check --dry-run` evaluates default policies without writing events or calling external providers. Running the alert command without `--dry-run` can write safe local `partner_alert_events` rows and redacted log entries when `PLATFORM_ALERTS_ENABLED=true`.

Dashboard/runbook templates live under:

```text
ops/m10/observability-signal-inventory.md
ops/m10/alert-channel-runbook.md
ops/m10/dashboards/platform-overview.json
ops/m10/dashboards/partner-health.json
```

The local database/log channel is verifiable in this repository. Webhook, email, Sentry, Grafana, Datadog, New Relic, Cloudflare analytics, CDN/R2 ticket image metrics, Horizon, Reverb, and production secret management remain release gates.

## Load-Test Scaffolding

Scripts live under `load-tests/k6/**`. Run fixture setup and k6 execution through Docker only:

```sh
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
```

`scripts/k6-prepare-baseline-fixtures.sh` runs `php artisan load-tests:k6:prepare` inside the `platform-api` Docker service and writes generated env/fixture artifacts to `load-tests/results/`. Generated bearer tokens stay in ignored local artifacts and are not committed.

`scripts/k6-run-baseline.sh` runs k6 through `grafana/k6` Docker with `K6_PROFILE=smoke` by default. Larger `baseline` and `release-candidate` profiles are available through `K6_PROFILE`.

Scenarios:

```text
customer-stock-search.js: public tenant stock search peak reads
concurrent-booking-same-stock.js: same stock reservation contention; requires customer token and stock id
checkout-wallet-consistency.js: wallet checkout contention; requires prepared reservation/customer wallet data
partner-tenant-burst-sync.js: partner sync/event burst path with partner bearer token and tenant headers
reward-publish-spike.js: result-day published reward read spike; requires published game/result
reward-checking-queue-chunk.js: reward check batch visibility; requires central admin token and reward result
ticket-image-cdn-spike.js: CDN/object-storage image spike placeholder; requires CDN base URL and image path
```

The first six scenarios are covered by the local/dev baseline fixture command. The scripts intentionally fail fast when required data is missing. They do not fake pass results.

`ticket-image-cdn-spike.js` is runnable when `CDN_BASE_URL` and either `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` point at a real CDN/object-storage ticket image. Local/dev does not provision Cloudflare/R2 ticket images, so the baseline runner emits `ticket-image-cdn-spike.skipped.json` with that blocker instead of claiming coverage.

`ticket-image-cdn-spike.js` intentionally ignores normal API `BASE_URL`. The scenario and `scripts/k6-run-baseline.sh` only claim ticket-image CDN/R2 coverage when explicit `CDN_BASE_URL` and `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` are supplied.

## Migration Rehearsal Checklist

```text
snapshot database and object storage metadata
run docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json
run docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing only in local/test rehearsal
verify additive migrations before destructive changes
run smoke checks after migrations
run queue worker once and scheduler list checks
verify monitoring defaults and seed login checks
record migration duration and rollback compatibility
```

## Cutover Checklist

```text
build API image once
deploy API, worker, scheduler, and frontend images from one release tag
run platform:migration:rehearsal --dry-run before production-safe migration
run production-safe migrations
pause or drain queues only when required
verify /health, /health/live, /health/ready
run platform:smoke with production-safe seed-login check disabled unless approved credentials exist
verify Cloudflare HTTPS and cache-bypass rules
verify tenant maintenance switch can isolate a tenant without redeploy
monitor queue lag, DB health, Redis/Valkey health, API p95/p99, error rate, and sync lag
```

## Rollback Checklist

```text
record previous image tag before deploy
keep database changes backward-compatible across at least one release
run platform:migration:rehearsal --dry-run and migrate:status during drill evidence capture
disable risky features with database feature flags
pause or drain queue workers if data compatibility is uncertain
enable tenant maintenance for affected tenant only
roll back API, worker, and scheduler images for the current backend-only closeout
include customer and back-office images only in a later frontend/full-platform release phase
re-run health and smoke checks after rollback
record residual data repair tasks for Coordinator review
```

## Accepted Risks Carried Forward

Back-office risks below are historical and phase-next. They do not block the current backend-only deploy-ready closeout unless they reveal a backend contract defect.

From the approved Back-office Operations Page Slice 1 chain:

```text
Vue hydration mismatch warnings/errors around protected shell and Meno/Waves mutations
stale marker can SSR-render a protected shell before final client redirect in sampled routes
Meno license notice missing before staging, production, or client delivery
npm audit vulnerabilities remain production-readiness concern
default seed credentials are local QA only
migrate:fresh --seed is destructive and local/test only
maintenance bypass list endpoint remains absent
backend menu category/icon fields remain absent
Nuxt DEP0180 and media-33 runtime warnings
PNG screenshot capture limited by local CDP timeout behavior
```

## Release Gates Not Yet Satisfied

```text
production process manager/web server image hardening
Horizon dashboard and queue supervision
Reverb production deployment
Cloudflare account/API integration
real Cloudflare DNS/proxy/SSL/HTTPS evidence
real CDN/object-storage ticket image load test
real old-data migration scripts and rehearsal data
real database/object-storage snapshots and restore rehearsal evidence
real production cutover and rollback drill evidence
production secret management
Meno license compliance
npm audit remediation
full M10 load-test execution with measured thresholds
```
