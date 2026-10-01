# back-office-p5-tenant-agent-quota-typed-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted focused QA for `back-office-p5-tenant-price-rules-customers-typed-workflows` as PASS and promoted these rows to complete:

```text
tenant:price_rules
tenant:customers
```

Official BO completion is now:

```text
45 / 56 complete = 80.4%
9 partial
2 api_gap
```

Coordinator opened the next BO implementation slice:

```text
back-office-p5-tenant-agent-quota-typed-workflows
```

Expected first owner:

```text
BO Develop
```

Scope:

```text
tenant:agents
tenant:agent_quotas
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: 8b98a7604027eaa528c8a52d391dba4885e1601e
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
tenant:agents
tenant:agent_quotas
```

Both rows remain partial because BO currently has list/detail/quota action coverage but does not yet expose complete typed create/update/quota workflows with real tenant BO menu QA. This task should make both rows ready for focused real-menu QA. Do not mark either row complete; Coordinator will decide after QA.

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

## tenant:agents Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/agents
list/detail/quota action connected
create/update APIs exist but are not surfaced as typed workflows
quota action is surfaced generically and still needs real typed workflow QA
workflow remains partial
```

Required typed workflow:

```text
typed create for POST /admin/tenant/agents
typed update for PATCH /admin/tenant/agents/{agent_id}
typed quota action for PATCH /admin/tenant/agents/{agent_id}/quotas
list/detail/filter/cursor behavior must remain intact
```

Typed create/update fields from backend behavior:

```text
code
name
phone
email
store_id
status
metadata
```

Contract notes:

```text
name is required on create
code defaults from name when omitted but should be surfaced as an editable field
code must remain unique per tenant
status defaults to active
metadata is stored as metadata_json
```

If `metadata` cannot reasonably be represented as granular controls, a focused JSON/object field for `metadata` is acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## tenant:agent_quotas Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/agent-quotas
dedicated route override uses the same /admin/tenant/agents list/detail APIs
quota action exists but lacks typed quota fields and real quota workflow QA
workflow remains partial
```

Required typed workflow:

```text
dedicated agent quota route must keep list/detail behavior against /admin/tenant/agents
typed quota action for PATCH /admin/tenant/agents/{agent_id}/quotas
quota action must show selected agent context and require reason/context confirmation
quota action must be usable from the dedicated agent quota route
real quota workflow must be ready for QA evidence
```

Typed quota fields from backend behavior:

```text
game_id
quota_count
used_count
status
payload
```

Contract notes:

```text
game_id may be nullable
quota_count is coerced to a non-negative integer
used_count is coerced to a non-negative integer
status defaults to active
payload is stored as payload_json
the response includes quotas on detail resources
```

If `payload` cannot reasonably be represented as granular controls, a focused JSON/object field for `payload` is acceptable. Do not use a whole-payload JSON editor as the primary quota workflow.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md
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

## Backend Contract References

Existing backend routes:

```text
GET /admin/tenant/agents
POST /admin/tenant/agents
GET /admin/tenant/agents/{agent_id}
PATCH /admin/tenant/agents/{agent_id}
PATCH /admin/tenant/agents/{agent_id}/quotas
```

Existing permissions:

```text
agent.view
agent.create
agent.update
agent.quota.manage
```

All write APIs require:

```text
X-Admin-Scope: tenant
X-Tenant-Id
Idempotency-Key
```

## Allowed Files

BO Develop may edit:

```text
apps/back-office/**
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo-handoff.md
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

Backend remains frozen unless BO proves the current OpenAPI/backend contract is insufficient and Coordinator approves a backend exception first.

## Required Validation

Use Docker-only application validation. Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations directly on the host.

Run:

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

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Handoff Required

When complete, create:

```text
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo-handoff.md
```

The handoff must include:

```text
implementation commit hash
files changed
exact typed fields/actions surfaced for tenant:agents
exact typed fields/actions surfaced for tenant:agent_quotas
tenant scope and X-Tenant-Id behavior preserved
idempotency behavior preserved for all write actions
validation commands and results
any skipped command with blocker reason
confirmation that no forbidden files were edited
confirmation that known unrelated dirty files were left untouched
```

Commit and push scoped BO changes before returning the handoff, following the project commit rule.

## Evidence Needed For QA

Make QA able to verify:

```text
real tenant BO menu route /admin/tenant/growth/agents
real tenant BO menu route /admin/tenant/growth/agent-quotas
tenant:agents list/detail API calls include tenant scope and X-Tenant-Id
tenant:agents typed create submits POST /admin/tenant/agents with Idempotency-Key
tenant:agents typed update submits PATCH /admin/tenant/agents/{agent_id} with Idempotency-Key
tenant:agents quota action submits PATCH /admin/tenant/agents/{agent_id}/quotas with Idempotency-Key
tenant:agent_quotas typed quota action submits PATCH /admin/tenant/agents/{agent_id}/quotas with Idempotency-Key
quota detail response shows updated quotas
filters/cursor behavior remains coherent
```

Do not write seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets into artifacts or handoffs.

## Next Agent

After BO Develop completes and pushes:

```text
Orchestrator
```

Orchestrator will create the focused QA Tester task for these rows.
