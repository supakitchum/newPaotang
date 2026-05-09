# 20260509-m10-remaining-openapi-route-policy-and-backend-closure - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved the prior backend safe-scope M10 closure and instructed Orchestrator to continue backend-only closure for the remaining OpenAPI route gaps:

```text
ai-agents/decisions/20260509-m10-backend-completion-and-release-gate-closure-approval-decision.md
ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-approval-coordinator-handoff.md
```

Backend Develop completed:

```text
20260509-m10-remaining-openapi-route-policy-and-backend-closure
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

Run QA for the implemented/classified backend-only route closure slice.

This QA does not approve staging, production, client delivery, external secret management, Cloudflare/R2 production readiness, LINE production readiness, mail-provider readiness, admin 2FA/password lifecycle policy, old-data migration, cutover, rollback, Gate 5, or final M10 release.

## Objective

Verify that Backend Develop correctly classified all 38 remaining OpenAPI route gaps, safely implemented 27 backend routes, preserved 11 high-risk routes as policy/provider/security blockers, and maintained backend route parity rules.

QA must prove:

```text
route parity moved from 38 missing to 11 missing
undocumented backend routes remain 0
implemented routes are registered and protected by the expected auth/scope/permission boundaries
guarded local/dev routes do not claim production readiness
blocked admin security and LINE routes remain unregistered and documented as policy/provider/security blockers
Docker-only backend validation passes
BO and customer UI remain untouched
```

## Source Of Truth

- `ai-agents/tasks/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend.md`
- `ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md`
- `ai-agents/decisions/20260509-m10-backend-completion-and-release-gate-closure-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-approval-coordinator-handoff.md`
- `ai-agents/reports/20260509-m10-backend-completion-and-release-gate-closure-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/database/migrations/2026_05_09_000002_create_remaining_openapi_route_closure_tables.php`
- `apps/platform-api/app/Models/PlatformAsset.php`
- `apps/platform-api/app/Models/TenantPaymentSetting.php`
- `apps/platform-api/app/Models/TenantPaymentChannel.php`
- `apps/platform-api/app/Models/PartnerTenantSeoSetting.php`
- `apps/platform-api/app/Models/PartnerTenantSeoPage.php`
- `apps/platform-api/app/Models/PartnerTenantRedirect.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/AssetController.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantPaymentSettingsController.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantSeoController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AssetService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/TenantPaymentSettingsService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/TenantSeoService.php`
- `apps/platform-api/app/Modules/PublicSite/Http/Controllers/PublicContentController.php`
- `apps/platform-api/app/Modules/PublicSite/Services/PublicContentService.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerRealtimeController.php`
- `apps/platform-api/app/Modules/Auth/Services/CustomerRealtimeAuthService.php`
- `apps/platform-api/tests/Feature/M10RemainingOpenApiRouteClosureTest.php`

## Scope

Perform focused QA for the backend-only remaining OpenAPI route closure.

Verify implemented routes:

```text
POST /admin/central/assets/uploads
GET /admin/central/assets/{asset_id}
POST /admin/central/assets/{asset_id}/commit
POST /admin/tenant/assets/uploads
GET /admin/tenant/assets/{asset_id}
POST /admin/tenant/assets/{asset_id}/commit
GET /admin/tenant/payment-settings
PATCH /admin/tenant/payment-settings
GET /admin/tenant/payment-channels
POST /admin/tenant/payment-channels
GET /admin/tenant/payment-channels/{payment_channel_id}
PATCH /admin/tenant/payment-channels/{payment_channel_id}
DELETE /admin/tenant/payment-channels/{payment_channel_id}
GET /public/seo/page
GET /public/news
GET /public/stores
GET /admin/tenant/seo
PATCH /admin/tenant/seo
GET /admin/tenant/seo/pages
POST /admin/tenant/seo/pages
PATCH /admin/tenant/seo/pages/{page_id}
DELETE /admin/tenant/seo/pages/{page_id}
GET /admin/tenant/redirects
POST /admin/tenant/redirects
PATCH /admin/tenant/redirects/{redirect_id}
DELETE /admin/tenant/redirects/{redirect_id}
POST /customer/realtime/auth
```

Verify blocked routes remain not implemented and documented:

```text
POST /auth/admin/password/forgot
POST /auth/admin/password/reset
POST /auth/admin/password/change
GET /auth/admin/2fa
DELETE /auth/admin/2fa
POST /auth/admin/2fa/setup
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
POST /auth/admin/2fa/verify
POST /customer/auth/line/login
GET /customer/auth/line/callback
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, or Board.
- Do not approve production R2/Cloudflare presign, production payment-provider readiness, LINE provider readiness, mail-provider delivery, admin password lifecycle, 2FA policy, customer public websocket production readiness, staging, production, client delivery, external secret-management, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, build, or runtime commands on the host machine.
- Do not copy real tokens, secrets, private keys, bearer tokens, customer data, provider credentials, or production URLs into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa-report.md
ai-agents/reports/artifacts/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
apps/customer/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa-report.md and ai-agents/reports/artifacts/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa/**
```

If a defect requires implementation, docs, tests, middleware, auth/session, backend, provider, or policy changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime, migration, and test commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Recompute route parity against `docs/openapi.yaml` and `apps/platform-api/routes/api.php`.
5. Verify Backend handoff's route-by-route closure table covers all 38 routes.
6. Verify the 27 implemented routes are registered in `route:list`.
7. Verify the 11 blocked security/provider routes remain absent from the app route table.
8. Static-review the new controllers/services/models/migration/tests for:

```text
auth scope and tenant/customer isolation
documented permission checks
idempotency on write routes
audit/redaction for admin writes and sensitive payloads
guarded local/dev production flags for assets/public news/customer realtime
no fabricated R2, LINE, mail, payment-provider, or websocket production readiness
```

9. Run Docker-only validation commands.
10. Verify docs/ledger reflect:

```text
OpenAPI 279
app routes 268
missing 11
undocumented 0
27 implemented or guarded routes
11 blocked policy/provider/security routes
external production gates still blocked
Gate 5 not triggered
```

11. Confirm no BO/customer implementation files were edited for this slice.
12. Write QA report to:

```text
ai-agents/reports/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- QA writes only the allowed report/artifact paths.
- All 38 routes are accounted for in the QA report.
- All 27 implemented routes are registered and covered by focused or full backend tests.
- The 11 blocked routes are correctly classified and not silently implemented.
- Backend route parity is verified: `OpenAPI 279`, `app 268`, `missing 11`, `undocumented 0`, or any discrepancy is reported as a defect.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Guarded local/dev routes do not claim production readiness.
- BO/customer UI freeze is preserved.
- QA verdict routes to Coordinator after report.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test --filter=M10RemainingOpenApiRouteClosureTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

If ops/readiness docs or services appear changed beyond ledger/doc updates, also run:

```sh
docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json
docker compose exec -T platform-api php artisan platform:observability:report --format=json
docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json
docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "uploads|commit|payment-settings|payment-channels|seo|redirects|2fa|password|line|realtime" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app apps/platform-api/tests
rg -n "production_storage_ready|production_realtime_ready|blocked_external|blocked_coordinator|LINE|2FA|password lifecycle|OpenAPI|missing 11|undocumented 0" docs/m10-backend-completion-and-release-gate-closure.md ops/m10/backend-release-gate-ledger.md ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa-report.md
```

Also write artifacts under:

```text
ai-agents/reports/artifacts/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa/
```

Must include:

```text
verdict
scope checked
files/artifacts reviewed
route parity counts
implemented route checks
blocked route checks
permission/tenant/customer isolation findings
guarded local/dev readiness findings
Docker validation commands and results
defects, if any
risks/not approved
recommendation
next agent
```

Set next agent to:

```text
Coordinator
```
