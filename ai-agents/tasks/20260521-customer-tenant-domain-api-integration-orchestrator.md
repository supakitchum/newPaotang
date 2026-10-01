# Task: Customer Tenant Domain API Integration

## Role

Orchestrator

## Coordinator Instruction

รับงาน `customer-tenant-domain-api-integration` จาก Coordinator board.

อ่านก่อนแตกงาน:

- `ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md`
- `ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md`
- `ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md`
- `ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md`
- `docs/customer-api-integration-map.md`
- `docs/site-config-contract.md`
- `docs/api-conventions.md`
- `docs/docker-runtime-policy.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/handoff-protocol.md`

## Required Start Gate

ทุก agent ต้องเริ่มจาก canonical worktree:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

ถ้า command ใด fail, worktree dirty แบบไม่เกี่ยวข้องกับ scope, หรือ HEAD ไม่ตรง `origin/develop` ให้หยุดและส่ง blocker กลับ Coordinator.

Known unrelated dirty artifact may exist:

```text
apps/platform-api/.phpunit.result.cache
```

Do not stage it.

## Goal

ทำให้ `apps/customer` ใช้งานตาม tenant domain/API ใหม่:

```text
partner-a.test -> customer storefront
partner-a.test/api/v1/* -> platform-api /api/v1/* with Host preserved as partner-a.test
bo.partner-a.test -> Back Office (already handled by previous task)
```

Customer ต้อง resolve tenant จาก storefront host, load site-config/brand/SEO/maintenance จาก tenant นั้น, และเรียก public/customer APIs ของ tenant นั้นโดยไม่ใช้ Tenant ID input หรือ hard-coded tenant config.

## Orchestrator Plan

แตกงานเป็น:

1. Customer Develop
   - Audit current `apps/customer` API base, SSR fetch behavior, auth storage, and site-config bootstrap.
   - Implement host-aware customer API base using same-origin `/api/v1` for tenant storefront domains.
   - Ensure SSR/server calls preserve original storefront `Host` when calling platform-api.
   - Fix local Docker/Nuxt/Vite allowed host/proxy behavior so seeded hosts such as `alpha.newpaotang.test` can open the customer app locally.
   - Load and apply `GET /api/v1/public/site-config` for tenant name/logo/theme/SEO/maintenance without hard-coded tenant IDs.
   - Scope customer session/token storage by host or tenant so cross-tenant browser sessions do not leak.
   - Keep existing customer routes/UI flow and adapter/composable boundaries.
   - Preserve idempotency keys for customer writes.
   - Document backend contract gaps instead of editing backend.
2. QA Tester
   - Validate local storefront hosts and same-origin `/api/v1` tenant resolution.
   - Validate at least alpha and beta tenant separation.
   - Validate public stock/search/store tenant behavior.
   - Validate authenticated customer session isolation or document blocker if seeded customer login data is unavailable.

## Constraints

- Do not edit `apps/platform-api/**` or `apps/back-office/**`.
- Do not add `api.*` host support.
- Do not redesign customer screens, rename routes, or rewrite product flow.
- Do not run destructive DB commands against runtime DB `newpaotang`.
- Destructive test setup must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- Use Docker commands for Customer validation.
- Every implementation agent must commit and push scoped changes after validation.

## Acceptance Criteria

- `alpha.newpaotang.test` can open the local customer app without Vite/Nuxt host blocking.
- Same-origin `GET /api/v1/public/site-config` from `alpha.newpaotang.test` resolves `ten_demo_alpha`.
- A second seeded domain resolves a different tenant and does not share customer auth/session state with alpha.
- Customer API adapter/composables use `/api/v1` or preserve storefront Host for SSR calls.
- Customer app applies tenant site name/logo/theme/SEO/maintenance from site-config where current UI supports it.
- Public browse/search/store calls resolve tenant by host.
- Customer writes keep `Idempotency-Key`.
- No backend/BO code is changed.
- QA report is created and returns to Coordinator.

## Next Agent

Orchestrator
