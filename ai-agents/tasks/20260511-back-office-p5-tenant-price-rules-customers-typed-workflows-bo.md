# back-office-p5-tenant-price-rules-customers-typed-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted focused QA for `back-office-p5-central-games-typed-workflow` as PASS and promoted `central:games` to complete.

Official BO completion is now:

```text
43 / 56 complete = 76.8%
11 partial
2 api_gap
```

Coordinator opened the next BO implementation slice:

```text
back-office-p5-tenant-price-rules-customers-typed-workflows
```

Expected first owner:

```text
BO Develop
```

Scope:

```text
tenant:price_rules
tenant:customers
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: 885d93feaccb0f2e5c06d41d842ab350124baa82
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, clean, or overwrite them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from the current shared workspace:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential used to generate evidence.

## Objective

Implement or surface typed BO workflows for:

```text
tenant:price_rules
tenant:customers
```

Both rows remain partial because BO currently relies on generic JSON payload/detail workflows or incomplete surfaced actions. This task should make both rows ready for focused real-menu QA. Do not mark either row complete; Coordinator will decide after QA.

Customer-related CRUD verification must use BO/API evidence first. Do not enter or modify the Customer frontend.

## Required BO Direction

Implement BO only.

Required behavior for both rows:

```text
preserve existing list/detail API connections
preserve tenant X-Tenant-Id behavior
preserve tenant scope headers
preserve idempotency behavior from the existing admin API flow
replace or supplement generic JSON payload/detail workflows with typed controls
use safe local fixtures and avoid destructive production-like assumptions
do not change backend or OpenAPI contract
do not use Customer frontend
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Other `apps/back-office/**` files may be edited only if the typed workflows require existing shared form/action behavior to support the contracts cleanly.

## tenant:price_rules Requirements

Current row status:

```text
generic operations page
list/detail/create/update connected
create uses JSON payload
detail uses JSON editor
delete API exists but no BO delete action is surfaced
write workflow has not passed real QA
```

Required typed workflow:

```text
typed create for POST /admin/tenant/price-rules
typed update for PATCH /admin/tenant/price-rules/{price_rule_id}
typed archive/delete action for DELETE /admin/tenant/price-rules/{price_rule_id}
delete/archive must use reason/context confirmation because it is destructive
list/detail/filter/cursor behavior must remain intact
```

Suggested typed fields based on current backend behavior:

```text
code
name
game_id
rule_type
price_amount
currency
conditions
status
```

Contract details from backend reference:

```text
status accepts active or archived
currency defaults to THB
price_amount is stored as minor units
conditions must be an object/array
code/name are required on create
code must remain unique per tenant
DELETE archives by setting status=archived
```

If `conditions` cannot reasonably be represented as granular controls, a focused JSON/object field for `conditions` is acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## tenant:customers Requirements

Current row status:

```text
generic operations page with customers route override
catalog calls /admin/tenant/members APIs
list/detail/create/update/status connected
create uses JSON payload
detail uses JSON editor
status action exists but uses a fixed suspended payload
detail/status were not real-menu QA exercised
typed forms are missing
```

Required typed workflow:

```text
typed member create for POST /admin/tenant/members
typed member update for PATCH /admin/tenant/members/{member_id}
typed member status action for POST /admin/tenant/members/{member_id}/status
status action must show customer/member context and require reason
list/detail/search/status/date filters must remain intact
```

Create fields from OpenAPI/backend:

```text
name
phone
email
password
status
send_invitation
```

Create required fields:

```text
name
phone
```

Update fields from OpenAPI/backend:

```text
name
phone
email
admin_note
```

Status action fields:

```text
status: active, pending_verification, suspended, disabled
reason
notify_member
```

Important customer guardrail:

```text
Do not use the Customer frontend.
Do not copy real customer data or credentials into artifacts.
Do not expose password_hash or secrets in UI/handoff.
Use safe local fixture members only.
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
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

Backend/OpenAPI files are read-only references for this task.

## Allowed Files

Allowed implementation scope:

```text
apps/back-office/**
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
```

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Do not use Customer frontend for this task.

Do not route directly to QA. BO must hand back to Orchestrator.

If BO proves the current OpenAPI/backend contract is insufficient, do not patch backend or OpenAPI. Document the blocker and route back to Orchestrator/Coordinator.

## Required Validation

Application commands must be Docker-only.

Run focused checks appropriate for BO typed workflow changes:

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

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

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

## Evidence To Prepare For QA

After BO implementation, QA will retest `tenant:price_rules` and `tenant:customers`. Prepare BO handoff notes that make this easy.

Include:

```text
implementation commit hash
changed files
typed price rule create fields
typed price rule update fields
price rule archive/delete action and reason/context behavior
typed customer/member create fields
typed customer/member update fields
member status action fields and reason/context behavior
confirmation list/detail behavior was preserved
confirmation tenant scope and X-Tenant-Id behavior was preserved
Docker validation commands and results
confirmation no backend, OpenAPI, customer frontend, docs, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed
known unrelated dirty files left untouched
any field/contract limitations QA must respect
```

## Acceptance Criteria

- Real BO tenant price rules page has typed create/update workflow and a reason-confirmed archive/delete action.
- Real BO tenant customers page has typed create/update workflow and a reason-confirmed status action with selectable statuses.
- Existing list/detail/filter/cursor behavior remains intact for both rows.
- Tenant-scoped API calls continue to carry `x-admin-scope: tenant` and `x-tenant-id` where applicable.
- Customer frontend is not used.
- Backend/OpenAPI/Customer/frontend docs/Board/decision/task/report files are not changed.
- BO writes a handoff and commits/pushes scoped changes so Orchestrator can dispatch focused QA.

## Handoff Requirement

Write:

```text
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
```

Then commit and push scoped BO changes so other agents can see them.

Next agent:

```text
Orchestrator
```
