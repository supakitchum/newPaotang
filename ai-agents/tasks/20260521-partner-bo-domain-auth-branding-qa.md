# partner-bo-domain-auth-branding-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate completed Backend and BO delivery for:

```text
partner-bo-domain-auth-branding
```

Do not start until these handoffs exist and include pushed commits:

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-bo-handoff.md
```

## QA Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before testing:

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

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or overlapping dirty files exist.

## Objective

Prove partner Back Office domains work end-to-end:

```text
partner-a.test storefront domain remains tenant-resolved
bo.partner-a.test Back Office login is tenant-only and branded
bo.partner-a.test API calls infer and guard partner tenant correctly
Central BO behavior remains unchanged
```

## Source Of Truth

Read before QA:

```text
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-backend.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-bo.md
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-bo-handoff.md
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
```

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive DB setup must target test DB:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests must run with:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Do not run destructive DB commands against runtime `newpaotang`.

## Required Validation

Backend/API:

```text
GET /api/v1/public/admin-site-config with Host bo.partner-a.test returns partner mode, brand, tenant, storefront_host, bo_host
POST /api/v1/auth/admin/login with Host bo.partner-a.test works for partner tenant admin without tenant_id
same login rejects scope=central
same login rejects an admin assigned only to another partner tenant
GET /api/v1/auth/admin/me on bo.partner-a.test returns only the resolved tenant scope
central admin route on bo.partner-a.test is rejected
tenant admin route on bo.partner-a.test requires matching tenant scope/header
Central host login behavior still works
1 Partner = 1 Tenant provisioning/constraint tests pass
```

Back Office browser:

```text
bo.partner-a.test/login shows partner display name and logo from tenant theme
bo.partner-a.test/login does not show scope selector
bo.partner-a.test/login does not show Tenant ID or Partner ID field
successful partner login lands on /admin/tenant/dashboard
partner BO blocks /admin/central/* redirect/deep link
central BO login still shows scope selector and tenant input
central BO login can still use existing central workflow
```

Local proxy evidence:

```text
partner-a.test -> customer
bo.partner-a.test -> back-office
bo.partner-a.test/api/v1/* -> platform-api with Host header preserved as bo.partner-a.test
```

If proxy is not available, use Host-header API evidence plus BO static/runtime evidence and record the limitation clearly.

## Required Commands

Run implementation validations from handoffs plus, at minimum:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter='AdminAuthTest|AdminMenuTest|BootstrapSeederTest' --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
git diff --check
```

## Report

Write:

```text
ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md
```

Include:

```text
worktree path
HEAD and origin/develop
backend and BO commits under test
commands and results
API host-header evidence
browser/login evidence or limitation
test DB isolation evidence
PASS/FAIL recommendation
```
