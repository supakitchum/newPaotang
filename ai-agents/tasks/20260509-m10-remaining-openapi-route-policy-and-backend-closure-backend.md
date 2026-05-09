# 20260509-m10-remaining-openapi-route-policy-and-backend-closure - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the prior backend-only safe-scope M10 closure as locally validated:

```text
ai-agents/decisions/20260509-m10-backend-completion-and-release-gate-closure-approval-decision.md
ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-approval-coordinator-handoff.md
```

The approved work reduced OpenAPI missing app routes from 53 to 38 and kept undocumented backend routes at 0.

Open the next backend-only task:

```text
20260509-m10-remaining-openapi-route-policy-and-backend-closure
```

Split the remaining 38 OpenAPI route gaps into implementable backend slices and blocker/policy slices. Implement safe internal backend routes first. Do not implement high-risk security/provider/external routes without an explicit documented policy decision. Keep BO frozen.

Do not trigger Gate 5. The project remains inside M10.

## Objective

Drive the remaining M10 backend OpenAPI route gap toward closure without fabricating external readiness or changing BO/customer UI.

The result must answer, route by route:

```text
which OpenAPI path/method is missing
whether it is implemented now, guarded local/dev only, blocked external, or requires Coordinator/security/provider policy
what persistence/security/external dependency applies
what backend code/docs/tests changed
what Docker validation proves the result
which routes remain blocked and who owns the next decision
```

## Source Of Truth

- `ai-agents/decisions/20260509-m10-backend-completion-and-release-gate-closure-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-approval-coordinator-handoff.md`
- `ai-agents/handoffs/20260509-m10-backend-completion-and-release-gate-closure-backend-handoff.md`
- `ai-agents/reports/20260509-m10-backend-completion-and-release-gate-closure-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/production-secret-boundary.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/**`
- `apps/platform-api/database/**`
- `apps/platform-api/tests/**`

## Scope

Backend-only route policy and closure for the remaining 38 OpenAPI app-route gaps.

Known remaining groups:

```text
Asset uploads and commit: 6 routes
Tenant payment settings/channels: 7 routes
Tenant SEO, redirects, public content: 13 routes
Admin 2FA and password lifecycle: 9 routes
LINE auth and customer realtime auth: 3 routes
```

Route groups to classify:

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
POST /customer/realtime/auth
```

## Route Classification Rules

Use this decision model for every route:

```text
implement now
implement guarded local/dev
block pending Coordinator/Ops
contract decision required
security/provider policy required
```

Guidance:

- Prefer implementing backend routes that can safely reuse existing tables, services, tenant settings, RBAC, idempotency, audit, and validation patterns.
- Guard local/dev implementations when the OpenAPI contract can be satisfied without calling real external providers and when the response clearly preserves production blockers.
- Do not invent production R2, LINE, mail, 2FA, recovery-code, or payment-provider behavior.
- Do not mark external gates ready without real evidence.
- Do not change OpenAPI paths, methods, response semantics, or business rules unless the issue is documented and Coordinator approval is required.

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not reopen BO menu completion, BO visual, BO hydration, BO npm audit, or Meno license/legal work.
- Do not implement customer UI flow changes.
- Do not claim staging, production, client delivery, external secret management, Cloudflare/R2 production readiness, LINE production readiness, mail delivery readiness, old-data migration success, cutover, rollback, Gate 5, or final M10 release approval.
- Do not fabricate provider credentials, object-storage evidence, mail-provider evidence, DNS evidence, or websocket production evidence.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, or build commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/m10-backend-completion-and-release-gate-closure.md
ops/m10/backend-release-gate-ledger.md
ops/m10/runtime-readiness.md
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/r2-ticket-image-strategy.md
ops/m10/production-secret-boundary.md
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml unless a non-breaking documentation correction is required and fully justified
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Recompute OpenAPI route parity before implementation and capture the exact 38 missing route rows.
5. Build a route-by-route closure table with:

```text
OpenAPI path/method
current route status
implementation owner
persistence/security/external dependency
decision: implement now, implement guarded local/dev, block pending Coordinator/Ops, contract decision required, or security/provider policy required
test evidence
```

6. Implement only routes classified as safe backend implementation or guarded local/dev implementation.
7. For asset upload/commit routes, do not pretend R2 is production-ready. If implemented, use explicit local/dev intent metadata and preserve R2/Cloudflare external blockers in docs/ledger.
8. For tenant payment settings/channels, require explicit tenant scoping, secret redaction, idempotent writes, audit logs, and a conservative persistence model. If persistence/security is unclear, do not implement; document the blocker.
9. For tenant SEO/redirect/public content, prefer existing tenant settings/store data if sufficient. If new content persistence is required, document the contract/persistence blocker instead of inventing a product model.
10. For admin password lifecycle and 2FA, do not implement weak placeholder security. If implemented, require hashed tokens/secrets, expiry, replay protection, audit, redaction, tests, and no real mail delivery claim. Otherwise mark security/provider policy required.
11. For LINE auth and customer realtime auth, do not fabricate provider or public websocket readiness. Guard local/dev behavior or block pending Coordinator/Ops with exact evidence.
12. Update the backend completion doc and release-gate ledger with route closure counts, remaining blockers, and next owners.
13. Ensure no `apps/back-office/**` or `apps/customer/**` files were edited.
14. Run Docker-only validation commands.
15. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- No BO or customer implementation files are edited.
- The exact 38-route gap is classified route by route.
- Safe backend routes are implemented with RBAC, tenant/customer scoping, validation, idempotency for writes, audit/redaction where applicable, and tests.
- High-risk provider/security/external routes are not implemented blindly.
- `docs/m10-backend-completion-and-release-gate-closure.md` and `ops/m10/backend-release-gate-ledger.md` reflect the new route counts, implemented routes, blocked routes, and next owners.
- Undocumented backend route count remains 0 or any exception is fully justified.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Handoff clearly says whether the result is ready for QA or requires Coordinator policy before QA.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose exec -T platform-api php artisan platform:smoke
```

Run focused tests for every changed backend feature. If the route groups touch existing focused suites, include relevant filters such as:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
```

If ops/readiness docs or services are touched, also run:

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
rg -n "blocked_external|blocked_coordinator|security/provider|LINE|R2|Cloudflare|mail|recovery|realtime|OpenAPI" docs/m10-backend-completion-and-release-gate-closure.md ops/m10/backend-release-gate-ledger.md
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md
```

Must include:

```text
what was done
files changed
route-by-route closure table for all 38 routes
routes implemented now
routes implemented guarded local/dev
routes blocked pending Coordinator/Ops
routes requiring contract/security/provider decision
backend/API parity count before and after
permission/event/ERD/status parity findings
Docker validation commands and results
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

If the result is ready for QA, say:

```text
Ready for QA
```

If Coordinator policy is required before QA, say:

```text
Coordinator policy decision required before QA
```
