# back-office-p5-tenant-agent-quota-typed-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened this P5 BO implementation slice after accepting `tenant:price_rules` and `tenant:customers` typed workflow QA as PASS.

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo-handoff.md
```

## Objective

Perform focused QA for these rows only:

```text
tenant:agents
tenant:agent_quotas
```

The retest must prove that the real tenant BO workflows now support typed agent create/update/quota actions and typed dedicated agent quota updates end to end, while preserving existing list/detail/filter/cursor behavior and tenant scoping.

If focused QA passes, Coordinator can decide whether to promote either or both rows to complete.

## BO Implementation Under Test

Implementation commit:

```text
4be4957083de80b9ef63395d1479b8a78be83f55
```

BO handoff commit:

```text
260e095772dadccb9ee34cf0a8a16978a72a7c53
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo-handoff.md
```

BO reports no backend, OpenAPI contract, Customer frontend, docs, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/tasks/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/app/Modules/Growth/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/tests/Feature/AgentTest.php
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
tenant:agents
/admin/tenant/growth/agents

tenant:agent_quotas
/admin/tenant/growth/agent-quotas
```

Required shared checks:

```text
access both pages from the real authenticated BO tenant menu
verify list APIs load with x-admin-scope: tenant and x-tenant-id
verify detail opens from real rows
verify typed create/update/quota action modals expose expected controls
verify write requests include tenant scope and idempotency key where applicable
verify filter/cursor/loading/empty/error behavior remains coherent
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

## tenant:agents QA Requirements

Required workflow:

```text
create a safe local agent through the typed Create agent modal
verify create fields: code, name, phone, email, store_id, status, metadata JSON
verify metadata accepts valid JSON object/array
verify create submits POST /api/v1/admin/tenant/agents with tenant scope and idempotency
verify created row appears in list and detail
update the same agent through the typed Update agent modal
verify update fields match the typed create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/agents/{agent_id} with tenant scope and idempotency
verify list/detail reflect updated values
open Update quotas action from the real row/detail
verify quota fields: game_id, quota_count, used_count, status, payload JSON, reason
verify quota modal shows agent context and requires reason
verify payload accepts valid JSON object/array
execute a safe quota update
verify PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas carries tenant scope and idempotency
verify detail response shows updated quotas
```

Use safe local fixture data. Prefer a unique code such as:

```text
p5_agent_<short timestamp>
```

If a `game_id` is not needed for the focused check, a blank tenant-wide quota is acceptable because the backend permits nullable `game_id`. If using a `game_id`, create or reuse safe local backend fixture data through Docker/API evidence. Do not assume production-like game ids.

## tenant:agent_quotas QA Requirements

Required workflow:

```text
open the dedicated /admin/tenant/growth/agent-quotas route from the real tenant menu
verify the route uses GET /api/v1/admin/tenant/agents for list data
verify detail opens through GET /api/v1/admin/tenant/agents/{agent_id}
open Update quotas action from a real agent row/detail
verify quota fields: game_id, quota_count, used_count, status, payload JSON, reason
verify quota modal shows agent/quota context and requires reason
execute a safe quota update from the dedicated quota route
verify PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas carries tenant scope and idempotency
verify detail response shows updated quotas after the dedicated route update
verify list/detail/filter/cursor behavior remains coherent on the dedicated quota route
```

The dedicated quota route intentionally uses the same agents list/detail API. Do not treat shared backing APIs as a defect if the route, modal fields, request evidence, context, and detail quota response are correct.

## Contract Notes To Respect

Agents:

```text
name is required on create
code defaults from name when omitted but BO surfaces it as editable
code must remain unique per tenant
status defaults to active
metadata is stored as metadata_json
allowed BO status options: active, inactive, suspended
```

Agent quotas:

```text
game_id may be nullable
quota_count is coerced to a non-negative integer
used_count is coerced to a non-negative integer
status defaults to active
payload is stored as payload_json
detail response includes quotas
```

Do not treat `quotas.0.*` being blank on list rows as a defect unless detail fetch also fails to expose quota state after an update. BO handoff notes list rows may open with defaults because list responses do not include quota detail.

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
change backend agent/quota logic
change API/OpenAPI contract
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `4be4957083de80b9ef63395d1479b8a78be83f55`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create or identify safe local fixtures for agent and quota workflows.
8. Capture API evidence for tenant agent create/update/quota and dedicated agent quota update.
9. Test the real authenticated BO tenant menus and typed modals.
10. Capture screenshots/snapshots/text artifacts for typed fields, request payload keys, tenant scope, idempotency, detail routes, quota confirmations, filters, and final states.
11. Redact artifacts and verify no secrets/passwords/tokens are included.
12. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AgentTest
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
ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
API evidence summary
browser evidence summary
typed agent create/update/quota field and result evidence
typed dedicated agent quota field and result evidence
tenant scope and X-Tenant-Id results
idempotency result for write calls
confirmation no Customer frontend was used
whether tenant:agents is a completion candidate after implementation
whether tenant:agent_quotas is a completion candidate after implementation
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
redaction summary
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether `tenant:agents` and/or `tenant:agent_quotas` count toward BO completion. If QA finds defects, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
