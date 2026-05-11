# back-office-p5-tenant-price-rules-customers-typed-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened this P5 BO implementation slice after accepting `central:games` typed workflow QA as PASS.

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
```

## Objective

Perform focused QA for these rows only:

```text
tenant:price_rules
tenant:customers
```

The retest must prove that the real tenant BO workflows now support typed price-rule create/update/archive and typed customer/member create/update/status actions end to end, while preserving existing list/detail/filter/cursor behavior and tenant scoping.

If focused QA passes, Coordinator can decide whether to promote either or both rows to complete.

Customer-related CRUD QA must use BO/API evidence only. Do not enter the Customer frontend.

## BO Implementation Under Test

Implementation commit:

```text
10ce1bfb720d561e0fab6f886c45f04337a6e239
```

BO handoff commit:

```text
187e21a14968ef0983f60fb943c4173469921bcf
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/openapi-admin-paths.snapshot.json
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
```

BO reports no backend, OpenAPI contract, Customer frontend, docs, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
ai-agents/tasks/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/app/Modules/AdminOperations/Http/Controllers/BoMenuCompletionController.php
apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php
apps/platform-api/tests/Feature/BoMenuCompletionBackendGapTest.php
```

Backend/OpenAPI files are read-only references. Do not edit them.

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential. Leave it untouched.

If these files are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Focused QA Scope

Test only:

```text
tenant:price_rules
/admin/tenant/price-rules

tenant:customers
/admin/tenant/customers
```

Required shared checks:

```text
access both pages from the real authenticated BO tenant menu
verify list APIs load with x-admin-scope: tenant and x-tenant-id
verify detail opens from real rows
verify typed create/update action modals expose expected controls
verify write requests include tenant scope and idempotency key where applicable
verify filter/cursor/loading/empty/error behavior remains coherent
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

## tenant:price_rules QA Requirements

Required workflow:

```text
create a safe local price rule through the typed Create price rule modal
verify create fields: code, name, game_id, rule_type, price_amount, currency, conditions JSON, status
verify conditions accepts valid JSON object/array
verify create submits POST /api/v1/admin/tenant/price-rules with tenant scope and idempotency
verify created row appears in list and detail
update the same price rule through the typed Update price rule modal
verify update fields match the typed create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/price-rules/{price_rule_id} with tenant scope and idempotency
verify list/detail reflect updated values
open Archive action from the real row/detail
verify archive modal shows price-rule context and requires reason
execute archive on the safe local QA rule if practical
verify DELETE /api/v1/admin/tenant/price-rules/{price_rule_id} carries tenant scope and idempotency
verify archived status/detail or archived filter evidence after archive
```

Use safe local fixture data. Prefer a unique code such as:

```text
p5_price_rule_<short timestamp>
```

If a `game_id` is needed for the rule, create or reuse safe local backend fixture data through Docker/API evidence. Do not assume production-like game ids.

## tenant:customers QA Requirements

Required workflow:

```text
create a safe local customer/member through the typed Create member modal
verify create fields: name, phone, email, password, status, send_invitation
verify password value is never copied into artifacts or screenshots in readable form if entered
verify create submits POST /api/v1/admin/tenant/members with tenant scope and idempotency
verify response/UI does not expose password_hash
verify created member appears in list and detail
update the same member through typed Update member modal
verify update fields: name, phone, email, admin_note
verify update submits PATCH /api/v1/admin/tenant/members/{member_id} with tenant scope and idempotency
verify list/detail reflect updated visible profile fields
open Change status action from the real row/detail
verify status action fields: status, notify_member, reason
verify status modal shows customer/member context and requires reason
execute a safe status change, for example active -> suspended or suspended -> active
verify POST /api/v1/admin/tenant/members/{member_id}/status carries tenant scope and idempotency
verify status filter can find the updated safe member
```

Use safe local fixture data only. Prefer unique phone/email values for the run.

Customer data guardrails:

```text
do not enter Customer frontend
do not use real customer data
do not write seeded passwords, bearer tokens, local credentials, customer secrets, private keys, or support tokens to artifacts
do not capture password text in screenshots or logs
```

## Contract Notes To Respect

Price rules:

```text
status accepts active or archived
currency defaults to THB
price_amount is stored as minor units
conditions must be a valid JSON object or array
code/name are required on create
code must remain unique per tenant
DELETE archives the rule by setting status=archived
```

Customers/members:

```text
create requires name and phone
create accepts email, password, status, send_invitation
update accepts name, phone, email, admin_note
status action requires status and reason
member statuses: active, pending_verification, suspended, disabled
admin_note may be audit-only and may not echo on the member resource
```

Do not treat audit-only non-echo of `admin_note` as a defect unless BO claims it should visibly persist.

## Out Of Scope

Do not:

```text
edit implementation code
edit apps/back-office/**
edit apps/platform-api/**
edit apps/customer/**
edit docs/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/handoffs/**
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, real customer data, local credentials, or private keys into artifacts
use Customer frontend
change backend price rule/member logic
change API/OpenAPI contract
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/**
```

Must not edit:

```text
apps/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ops/**
scripts/**
load-tests/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `10ce1bfb720d561e0fab6f886c45f04337a6e239`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create or identify safe local fixtures for price rule and member workflows.
8. Capture API evidence for tenant price rule create/update/archive and member create/update/status.
9. Test the real authenticated BO tenant menus and typed modals.
10. Capture screenshots/snapshots/text artifacts for typed fields, request payload keys, tenant scope, idempotency, detail routes, archive/status confirmations, filters, and final states.
11. Redact artifacts and verify no secrets/passwords/tokens are included.
12. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, migrations, queues, or scheduler commands.

## Expected QA Output

Write:

```text
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
API evidence summary
browser evidence summary
typed price rule create/update/archive field and result evidence
typed member create/update/status field and result evidence
tenant scope and X-Tenant-Id results
idempotency result for write calls
confirmation no Customer frontend was used
whether tenant:price_rules is a completion candidate after implementation
whether tenant:customers is a completion candidate after implementation
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
redaction summary
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether `tenant:price_rules` and/or `tenant:customers` count toward BO completion. If QA finds defects, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
