# 20260509 M10 Backend Completion And Release Gate Closure - Backend Develop Handoff

## ทำอะไรไป

- Closed safe backend-owned M10 API gaps without changing `docs/openapi.yaml`.
- Implemented central billing binding, partner monitoring update, partner usage update, central sync log, tenant domain, tenant sync log, tenant price-rule archive, and customer topup cancel backend paths.
- Corrected central read permission checks for billing plans and alert policies to match `docs/permissions.md`.
- Added focused feature tests for new backend paths, tenant scoping, RBAC, idempotency, audit writes, sync log redaction, and customer topup cancellation.
- Produced completion summary doc and release gate ledger.
- Did not edit `apps/back-office/**` or frontend `apps/customer/**`.

## Backend files changed

- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/BoMenuCompletionController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php`
- `apps/platform-api/app/Modules/Commerce/Http/Controllers/CustomerCommerceController.php`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php`
- `apps/platform-api/tests/Feature/BoMenuCompletionBackendGapTest.php`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-backend-handoff.md`

Note: workspace git state is already broad/noisy and `apps/platform-api` appears untracked as a tree in this worktree, so ordinary `git diff` does not show these file-level edits.

## API endpoints implemented

Central admin:

- `PATCH /admin/central/partner-monitoring/{monitoring_profile_id}`
- `PATCH /admin/central/partner-usage/{usage_meter_id}`
- `GET /admin/central/billing-bindings`
- `GET /admin/central/billing-bindings/{billing_binding_id}`
- `PATCH /admin/central/billing-bindings/{billing_binding_id}`
- `GET /admin/central/sync-logs`

Tenant admin:

- `DELETE /admin/tenant/price-rules/{price_rule_id}`
- `GET /admin/tenant/domains`
- `POST /admin/tenant/domains`
- `GET /admin/tenant/domains/{domain_id}`
- `PATCH /admin/tenant/domains/{domain_id}`
- `DELETE /admin/tenant/domains/{domain_id}`
- `POST /admin/tenant/domains/{domain_id}/verify`
- `GET /admin/tenant/sync-logs`

Customer:

- `DELETE /customer/topups/{topup_id}`

## Backend/API parity findings

- Before closure: OpenAPI routes 279, app routes 226, missing in app 53, undocumented in app 0.
- After closure: OpenAPI routes 279, app routes 241, missing in app 38, undocumented in app 0.
- Safe backend gap reduction: 15 routes closed.
- Remaining 38 missing routes are grouped in `ops/m10/backend-release-gate-ledger.md`.

## Permission/event/ERD/status parity findings

- Permission checks now follow `docs/permissions.md` for new routes and for central billing-plan/alert-policy reads.
- Tenant-owned routes are scoped through active tenant admin context and tenant-scoped Eloquent queries.
- Customer topup cancel is scoped to authenticated customer tenant context and `payment_write` maintenance boundary.
- Existing ERD-backed tables/models are reused; no schema/migration changes were added.
- Status validation follows `docs/status-enums.md` for monitoring profiles, usage meters, billing bindings, tenant domains, sync logs, and topups.
- Admin audit actions written: `partner_monitoring.updated`, `partner_usage.updated`, `billing_binding.updated`, `price_rule.archived`, `domain.created`, `domain.updated`, `domain.removed`, `domain.verification_requested`.
- Sync log payload output uses existing audit redaction.
- No new outbox event contract was introduced.

## Safe backend gaps closed

- Central monitoring/usage PATCH gaps now update existing operational rows with idempotency and audit.
- Central billing bindings now list, show, and update existing binding rows.
- Central and tenant sync logs now expose redacted outbox/inbox records with tenant filtering.
- Tenant price-rule DELETE now archives the rule idempotently.
- Tenant domains now support CRUD plus local-only readiness verification and active-domain guardrails.
- Customer topup DELETE now cancels pending/processing topups idempotently and cancels pending/processing payment rows.

## Remaining blockers and whether internal or external

Internal or contract/persistence decision required:

- Tenant payment settings/channels: requires approved persistence/security model.
- Tenant SEO, SEO pages, redirects, public news/public stores/public SEO page: requires approved content/source-of-truth model.
- Customer realtime auth: requires approved Reverb runtime package/profile and public websocket policy.

External or Coordinator/Ops required:

- Asset upload/commit routes: require R2/storage presign policy and lifecycle guardrails.
- Admin 2FA/password reset/change: require security, recovery-code, mail/provider, and credential lifecycle approval.
- LINE auth: requires LINE credentials and callback policy.
- Runtime readiness: Horizon/Reverb packages, production supervision, TLS/public host, scaling, and dashboard policy.
- Cloudflare/CDN/R2: account/zone/token, CDN base URL, R2 endpoint/bucket, and real ticket image path.
- Migration/cutover/rollback: real snapshots, old-data source credentials, release tags, cutover window, rollback drill.

## Release-gate ledger summary

- Backend safe API closure: `ready_local`
- Route registration: `ready_local`
- Full backend tests: `ready_local`
- RBAC/tenant isolation for implemented routes: `ready_local`
- Runtime smoke: `ready_local` after runtime reseed
- Runtime readiness: `blocked_external`
- Observability: `ready_local` with external production follow-ups
- Cloudflare/CDN/R2: `blocked_external`
- Migration rehearsal/cutover/rollback: `blocked_external`
- Gate 5: not triggered

Full details: `ops/m10/backend-release-gate-ledger.md`

## Commands/tests run

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
docker compose run --rm platform-api php artisan test --filter=CustomerTopupTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json
docker compose exec -T platform-api php artisan platform:observability:report --format=json
docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json
docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Results:

- `BoMenuCompletionBackendGapTest`: passed, 3 tests, 161 assertions.
- `CustomerTopupTest`: passed, 1 test, 27 assertions.
- Full suite: passed, 141 tests, 3709 assertions.
- `route:list`: passed, 246 routes shown.
- `platform:smoke`: passed after reseeding runtime data.
- `platform:runtime:readiness`: command passed, reported `blocked_external`.
- `platform:observability:report`: command passed, reported `ready_local`.
- `platform:cloudflare:readiness`: command passed, reported `blocked_external`.
- `platform:migration:rehearsal`: command passed, reported `blocked_external`.

Note: `platform:smoke` failed once immediately after the full test suite because `RefreshDatabase` left the DB in test fixture state. Reran Docker `migrate:fresh --seed`, then smoke passed.

## Known risks/questions

- Remaining 38 OpenAPI routes should not be implemented ad hoc; they require Coordinator/Orchestrator decisions or external credentials/policies.
- Domain verification endpoint is intentionally local-safe and evidence-based; it does not call DNS, Cloudflare, or certificate services.
- Domain delete performs actual row removal to match the OpenAPI "removed" behavior and avoid unique-host conflicts on future recreate.
- Customer topup cancel follows the existing customer-write pattern and does not add admin audit logs.
- Full production release is still blocked by external readiness gates; backend safe scope is ready for QA.

## Next Agent

QA Tester for backend safe-scope validation. Coordinator/Orchestrator must own decisions for the remaining blockers before any Gate 5 release trigger.
