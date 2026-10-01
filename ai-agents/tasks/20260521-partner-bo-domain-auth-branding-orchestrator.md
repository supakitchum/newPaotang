# Task: Partner BO Domain Auth Branding

## Role

Orchestrator

## Coordinator Instruction

รับงาน `partner-bo-domain-auth-branding` จาก Coordinator board.

อ่านก่อนแตกงาน:

- `ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/handoff-protocol.md`
- `ai-agents/workflow/file-ownership.md`
- `docs/docker-runtime-policy.md`

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

ทำให้แต่ละ Partner มี Back Office domain ของตัวเอง:

```text
Storefront/customer: partner-a.test
Back Office + same-origin API entrypoint: bo.partner-a.test
```

Partner BO ต้อง login เป็น tenant-only จาก host, แสดง partner name/logo, ไม่ให้ login ข้าม partner, และไม่ให้เข้า Central scope ผ่าน partner domain.

## Orchestrator Plan

แตกงานเป็น:

1. Backend Develop
   - Add `bo.*` admin host resolver.
   - Add public admin site config endpoint.
   - Update admin auth/session/scope guard for partner-host tenant-only behavior.
   - Enforce `1 Partner = 1 Tenant` through migration/provisioning guard.
   - Add backend tests and OpenAPI/docs updates where needed.
2. BO Develop
   - Add partner BO host mode detection.
   - Use same-origin `/api/v1` API base in partner BO mode.
   - Load admin site config and brand login page from tenant theme.
   - Hide scope and Partner/Tenant ID fields in partner BO mode.
   - Keep Central BO login unchanged.
   - Add BO lint/test/build guardrails.
3. QA Tester
   - Validate backend and BO together with local proxy/Host header.
   - Prove central scope and cross-partner login are blocked on partner host.
   - Prove Central BO behavior remains unchanged.

## Constraints

- Do not use `api.*` for this workflow.
- Do not create separate stored BO domain records in v1; derive `bo.{storefront_host}`.
- Do not perform runtime DB cleanup.
- Do not silently merge/delete duplicate partner tenants. If duplicates block the unique constraint, report blocker.
- Destructive DB test setup must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- Every implementation agent must commit and push scoped changes after validation.

## Acceptance Criteria

- `bo.partner-a.test` resolves partner/tenant from `partner-a.test`.
- Partner BO login succeeds without `tenant_id` for an admin assigned to that partner tenant.
- Partner BO login rejects central scope and cross-partner tenant admins.
- Partner BO authenticated API access cannot expose central scope or another tenant.
- Partner BO login page shows tenant theme name/logo and hides scope/ID inputs.
- Central BO login remains unchanged.
- `partner_tenants.partner_id` uniqueness/provisioning guard enforces `1 Partner = 1 Tenant`.
- QA report is created and returns to Coordinator.

## Next Agent

Orchestrator
