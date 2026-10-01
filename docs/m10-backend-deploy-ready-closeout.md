# M10 Backend Deploy Ready Closeout

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-backend-only-deploy-ready-closeout-backend
Status: Ready for QA

## Scope

This closeout covers `apps/platform-api` backend deploy-readiness only. It does not include Back Office implementation, Customer frontend changes, staging approval, production approval, client delivery, Gate 5, or final M10 release approval.

No API paths, methods, schemas, or response semantics were changed. No `apps/back-office/**`, `apps/customer/**`, `document/**`, `.github/**`, `compose.yaml`, `docs/openapi.yaml`, or `docs/docker-runtime-policy.md` files were edited by this closeout.

## Executive Summary

The backend is ready for QA review as a local/dev deploy-readiness package:

| Area | Status | Evidence |
| --- | --- | --- |
| OpenAPI/app route parity | ready_local | 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented |
| Route registration | ready_local | `route:list` passed with 284 Laravel routes shown |
| Full backend suite | ready_local | 152 tests, 4140 assertions |
| Permissions and tenant isolation | ready_local | RBAC, admin scope, tenant host/session, support impersonation, and cross-tenant tests pass |
| Models/migrations/seeders | ready_local | Eloquent model compliance and `migrate:fresh --seed` pass |
| Request validation | ready_local | validation-before-mutation/idempotency tests pass |
| Idempotency and audit | ready_local | same-key conflict, redaction, audit, and no raw secret persistence tests pass |
| Outbox/inbox and queues | ready_local | sync/outbox/inbox feature tests pass; queue worker profile catalog is valid |
| Scheduler | ready_local | `schedule:list` shows five bounded local/dev workloads |
| Runtime image/templates | ready_local_with_external_supervision_blockers | Dockerfile has development and production targets; production process supervision still external |
| Horizon | blocked_external | package/config/supervisors/dashboard policy not present |
| Reverb | blocked_external | package/runtime/TLS/public host/scaling not present |
| Observability and alerts | ready_local_with_external_followups | local report/dry-run pass; external delivery/APM/edge signals remain external |
| Cloudflare/HTTPS/WAF/CDN/R2 | blocked_external | local templates/verifier pass; real account/zone/token/CDN/R2/image path missing |
| Load-test fixtures/scripts | ready_local_with_external_cdn_blocker | fixture command and k6 script inspection pass; ticket-image CDN run needs real CDN/R2 image |
| Migration/cutover/rollback | blocked_external | local dry-run/readiness pass; real snapshots, old-data source, staging rehearsal, release tags, cutover, rollback missing |
| Mail/payment/LINE/secret manager | blocked_external | backend boundaries are guarded; provider credentials and production secret owner remain external |

## Route Parity

Route parity was reconfirmed against `docs/openapi.yaml` using Docker `route:list --json`:

```text
OPENAPI_ROUTES=279
APP_ROUTES=279
MISSING_IN_APP=0
UNDOCUMENTED_IN_APP=0
```

`docker compose exec -T platform-api php artisan route:list` passed and showed 284 Laravel routes, including framework health/storage routes outside the OpenAPI app-route parity count.

## Backend Compliance

Permissions and tenant isolation:

- Admin APIs enforce bearer session, `X-Admin-Scope`, tenant scope where required, and permission checks server-side.
- Menu visibility remains informational only; backend authorization remains the source of truth.
- Public/customer APIs resolve tenant by host and authenticated customer sessions remain tenant-bound.
- Partner sync validates partner/tenant headers and payload tenant identity.
- Support impersonation blocks sensitive actions and records audit/outbox evidence.

Models, migrations, and seeders:

- Application-source data access uses concrete Eloquent models and model query builders.
- `BackendModelComplianceTest` passes with all application migration tables represented except Laravel runtime tables.
- `migrate:fresh --seed` passes with default RBAC/menu, central bootstrap admin, and three demo tenants.
- Seeded local credentials remain local/QA only and are not production approval.

Request validation:

- Dedicated module validators and shared header validation are present for retryable writes and reports.
- Validation failures return the standard `validation_failed` API envelope.
- Focused tests prove invalid report exports and wallet adjustments do not store idempotency success rows or mutate business state.

Idempotency and audit:

- `Idempotency-Key` behavior follows same actor/route/key/payload replay and changed-payload `idempotency_conflict`.
- The admin password/2FA P1 remediation covers sensitive fingerprints and no second mutation on conflicts.
- Audit redaction recursively covers passwords, reset tokens, TOTP secrets/codes, recovery codes, provider secrets, support tokens, LINE state/code, webhook payload secrets, and other secret-like keys.

Outbox/inbox and events:

- Cross-module event boundaries use PostgreSQL-backed outbox/inbox rows.
- Partner stock allocation/sync, sold sync, reward, commission, maintenance, and support access tests verify outbox/inbox or audit evidence where applicable.
- Redis/Valkey can transport queue/cache work but is not the source of truth.

## Runtime Readiness

Docker/runtime:

- `apps/platform-api/Dockerfile` has `development` and `production` targets.
- `apps/platform-api/.env.example` contains backend infrastructure placeholders for DB, Redis, queue, S3/R2/CDN, Cloudflare, Reverb, metrics/alerts, migration rehearsal, and local seed credentials.
- Tenant business configuration stays database-backed, not env-backed.

Queue workers:

- `platform:runtime:readiness --format=json` reports queue workers `ready_local`.
- 22 configured queues map to a valid `ops/m10/queue-worker-profiles.json` catalog.
- Critical booking/checkout/reward/stock queues are separated from report-build and monitoring/background queues.
- Bounded `queue:work --once --tries=1 --timeout=30 --queue=default` validation passed and started no long-lived worker.

Scheduler:

- `schedule:list` passed and shows:
  - `stock:reservations:expire --limit=100`
  - `stock:sold:sync --limit=100`
  - `reward:check --chunk=100`
  - `commission:calculate --limit=100`
  - `platform:alerts:check --dry-run --format=json`
- Runtime readiness reports scheduler `ready_local`.

Horizon and Reverb:

- Horizon remains `blocked_external`: package, config, supervisors, dashboard access policy, and production process manager are missing.
- Reverb remains `blocked_external`: package, runtime profile, TLS/public host, and scaling/load evidence are missing.
- Admin/customer realtime auth endpoints remain registered and tested at the API boundary, but public websocket delivery is not approved.

## Observability And Alerts

Local/dev readiness is present:

- `platform:observability:report --format=json` returned `ready_local`.
- `platform:alerts:check --dry-run --format=json` returned `ok`, evaluated 24 policies across 3 demo partners, detected 0 alerts, and delivered 0 events.
- Seeders create partner monitoring profiles, health checks, usage meters, and alert policies.
- Alert payloads include partner/tenant-safe labels and redaction.

External production follow-ups remain:

- Webhook/email/Sentry/Grafana/Datadog/New Relic credentials and delivery QA.
- Cloudflare analytics, CDN/R2 ticket-image metrics, Horizon queue supervision, Reverb runtime signals, and production secret management.

## Cloudflare, CDN, And R2

Local/dev readiness is guarded:

- `platform:cloudflare:readiness --format=json` returned `blocked_external`.
- Local `.test` tenant domains are guarded and safe for local QA.
- WAF/rate-limit and cache-bypass templates exist and validate locally.
- Readiness output redacts configured values and does not call Cloudflare or R2.

Production blockers:

- Cloudflare account ID, zone ID, API token, real DNS/proxy/SSL/HTTPS evidence.
- Real WAF/cache rule deployment evidence.
- CDN base URL, R2 endpoint/bucket/credentials, and a real ticket image object path.
- Ticket-image CDN spike must use explicit `CDN_BASE_URL` plus `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`; API `BASE_URL` is intentionally not accepted as CDN evidence.

## Load-Test Readiness

Local/dev fixture and script readiness passed:

- `load-tests:k6:prepare` passed and prepared M10 baseline fixtures in the platform-api container.
- Docker k6 `inspect` passed for:
  - `customer-stock-search.js`
  - `concurrent-booking-same-stock.js`
  - `checkout-wallet-consistency.js`
  - `reward-checking-queue-chunk.js`
  - `partner-tenant-burst-sync.js`
  - `reward-publish-spike.js`
  - `ticket-image-cdn-spike.js`

Baseline execution was not used as production load evidence. The ticket-image scenario remains blocked until real CDN/R2 image evidence is supplied. Generated bearer tokens and env artifacts are local/runtime artifacts and were not committed.

## Migration, Cutover, Rollback, And Secret Boundary

Local/dev dry-run readiness passed:

- `platform:migration:rehearsal --dry-run --format=json` returned `blocked_external` with local/dev strategy and fixtures ready.
- Old-data migration strategy and synthetic seeded fixture boundary are ready local/dev.
- Helper scripts for migration rehearsal, cutover preflight, and rollback drill are Docker-only.

External blockers remain:

- Real database snapshot and restore rehearsal.
- Real object-storage metadata snapshot.
- Real old-data source inventory and credentials.
- Production secret manager owner and references.
- Release image tag, previous image tag, staging rehearsal, cutover window, rollback drill, and Cloudflare/CDN/R2 production evidence.

## Provider Boundaries

| Provider/Gate | Backend status | External blocker |
| --- | --- | --- |
| Mail/password reset delivery | ready_local_with_boundary | provider credentials and delivery policy missing |
| Payment/topup providers | guarded_local_dev | provider activation credentials and settlement/reconciliation evidence missing |
| LINE auth | guarded_provider | LINE credentials, callback URL, token exchange, and account-linking policy missing |
| Production secret manager | blocked_external | approved secret manager owner/references missing |

## Docker Validation Results

All application commands were run through Docker.

| Command | Result |
| --- | --- |
| `docker compose up -d postgres valkey platform-api` | passed |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | passed |
| `docker compose run --rm platform-api php artisan test` | passed: 152 tests, 4140 assertions |
| `docker compose exec -T platform-api php artisan route:list` | passed: 284 Laravel routes shown |
| OpenAPI route parity script using Docker route JSON | passed: 279/279/0/0 |
| `docker compose exec -T platform-api php artisan platform:smoke` | passed after reseed |
| `docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json` | passed, status `blocked_external` for Horizon/Reverb |
| `docker compose exec -T platform-api php artisan platform:observability:report --format=json` | passed, status `ready_local` |
| `docker compose exec -T platform-api php artisan platform:alerts:check --dry-run --format=json` | passed, status `ok` |
| `docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json` | passed, status `blocked_external` |
| `docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json` | passed, status `blocked_external` |
| `docker compose run --rm platform-api php artisan load-tests:k6:prepare --base-url=http://host.docker.internal:8000 --tenant-host=k6-alpha.newpaotang.test` | passed |
| `docker compose run --rm platform-api php artisan schedule:list` | passed |
| `docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default` | passed |
| `docker compose run --rm platform-api php artisan list` | passed |
| Docker k6 inspect commands for seven scenario scripts | passed |
| `docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest` | passed: 5 tests, 94 assertions |
| `docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest` | passed: 1 test, 37 assertions |
| `docker compose run --rm platform-api php artisan test --filter=M10ProductionObservabilityAlertingTest` | passed: 5 tests, 81 assertions |
| `docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test` | passed: 5 tests, 136 assertions |
| `docker compose run --rm platform-api php artisan test --filter=M10MigrationRehearsalCutoverRollbackTest` | passed: 3 tests, 110 assertions |
| `docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest` | passed: 4 tests, 68 assertions |

## Release Gate Position

Backend-only local/dev deploy-readiness is ready for QA. Production release remains blocked by external evidence and approvals listed in `ops/m10/backend-deploy-ready-blocker-matrix.md`. Gate 5 and final release are not triggered by this closeout.
