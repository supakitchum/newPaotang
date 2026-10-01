# allocation-partner-percent-workflow-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
allocation-partner-percent-workflow
```

Backend Develop has completed and pushed the API/backend contract. BO Develop is now the next implementation agent.

## Backend Dependency

Read this handoff before implementation:

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

Backend implementation commits:

```text
6d4061e19a0b3df1c351ededeeb0cfc382f09d6e
bf3ec0c895b99d910e1375e463ef2ea14e41039f
```

Use the backend handoff and `docs/openapi.yaml` as the final source for route names, payloads, validation errors, and response fields.

## Canonical Worktree Start Gate

BO Develop must start from the canonical worktree only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
there are uncommitted changes that BO Develop did not create and they overlap this task
```

Known unrelated local artifact from Backend validation:

```text
apps/platform-api/.phpunit.result.cache may be dirty in the shared local worktree.
Do not stage or commit it from BO work. Report it if it blocks the start gate.
```

The BO handoff must include the worktree path and HEAD used.

## Objective

Rework Back Office allocation and partner percent workflows to consume the backend percent allocation contract:

```text
replace raw Partner ID, Tenant ID, and Game ID allocation fields with selects
implement dependent partner -> tenant selection and single-tenant auto-fill
remove Requested count from the create allocation workflow
add Allocation percent and calculated preview to create allocation
show partner/tenant/game display names and allocation percent in allocation list/detail
add allocation row actions for stock coverage, remaining stock, recall-all, and redistribute
add Partners table stock percent display/edit workflow
surface backend validation for partner percent sum <= 100 and usage protection
update BO checks/tests/build and write BO handoff
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
docs/coordinator-agent-handoff.md
ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

Relevant sections:

```text
docs/virtual-stock-realtime.md#allocation-and-partner-percent-rework
docs/coordinator-agent-handoff.md#allocation-partner-percent-workflow
```

## Scope

BO Develop owns:

```text
apps/back-office allocation catalog/page wiring
allocation filters and create modal field definitions
allocation option loading from backend partner/tenant/game option endpoints
dependent tenant select behavior after partner selection
allocation_percent input and preview behavior
allocation table/detail display fields
allocation row actions for stock coverage, remaining stock, recall-all, redistribute
partner stock percent display/edit UI in central Partners workflow
BO structural scripts/snapshots where needed
BO tests/build/handoff
```

Terminology:

```text
"Agent" in business wording maps to the existing partners entity for this scope.
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing backend route names or contracts without Orchestrator/Coordinator routing
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md if BO coverage wording changes
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real credential files or local environment secrets
apps/platform-api/.phpunit.result.cache
```

## Backend Routes To Consume

Option source endpoints:

```text
GET /admin/central/allocation-options/partners
GET /admin/central/allocation-options/tenants
GET /admin/central/allocation-options/games
```

Allocation endpoints:

```text
GET /admin/central/allocations
POST /admin/central/allocations
GET /admin/central/allocations/{allocation_id}
POST /admin/central/allocations/{allocation_id}/recall-all
POST /admin/central/allocations/{allocation_id}/redistribute
POST /admin/central/allocations/{allocation_id}/cancel
```

Partner percent endpoint:

```text
PUT /admin/central/allocations/partner-percent
```

BO-facing create allocation payload:

```json
{
  "partner_id": "par_x",
  "tenant_id": "ten_x",
  "game_id": "gam_x",
  "allocation_percent": 25
}
```

`tenant_id` may be omitted only when the selected active partner has exactly one active tenant and the backend can resolve it. BO should auto-fill when the partner option exposes single-tenant metadata.

Do not send `requested_count` from BO create allocation.

## Required BO Behavior

Allocation filters:

```text
replace Partner ID text input with partner select by name/code
replace Tenant ID text input with tenant select constrained by selected partner
replace Game ID text input with game select by name/code/current-open status
keep status filter
show display labels in selected values where existing components support it
```

Create allocation modal:

```text
partner select is required
tenant behavior depends on partner:
  exactly one active tenant: auto-fill/lock or show selected tenant clearly
  multiple active tenants: show filtered tenant select and require explicit tenant
  no active tenant: block submit and surface backend validation
game select is required
remove Requested count
add Allocation percent number input, > 0 and <= 100
show calculated preview from selected game/partner metadata where backend option/list data exposes enough values
preview should include estimated supply, percent, estimated allocation count, existing allocated/remaining when available
submit with idempotency key using existing BO conventions
surface backend validation and idempotency conflict messages clearly
```

Allocation table/detail:

```text
show partner_code/partner_name instead of raw partner_id where available
show tenant_code/tenant_name instead of raw tenant_id where available
show game_code/game_name instead of raw game_id where available
show allocation_percent
show allocated_count, remaining_count, recalled_count, status
keep legacy requested_count hidden from BO-facing table unless needed only as internal target detail
```

Allocation row actions:

```text
Edit stock coverage: route to Stock Pattern Coverage scoped by game_id, scope_type=partner, partner_id
View remaining stock: open Stock Generation/full-number style stock view scoped by game_id and partner_id
Recall all: POST /admin/central/allocations/{allocation_id}/recall-all with reason and idempotency key
Redistribute: POST /admin/central/allocations/{allocation_id}/redistribute with reason/idempotency key if backend requires it
Redistribute must be disabled unless allocation is fully recalled/recalled status according to backend response fields
Cancel action may remain if still valid in current catalog
```

Partners table stock percent:

```text
show partner/agent stock percent where backend data is available or expose an action that loads the percent context
add central-only edit action/form for stock percent by partner/game/tenant as required by PUT /admin/central/allocations/partner-percent
validate percent > 0 and <= 100 on the client as convenience only
surface backend active partner percent total <= 100 validation
surface backend rejection when lowering percent below already reserved/sold usage
do not fake success when backend rejects the update
```

## Required Steps

1. Read backend handoff and OpenAPI allocation schemas/paths.
2. Inspect current BO operation catalog and allocation/partner components.
3. Replace allocation raw id filters with option-backed select fields.
4. Add option source loading for partner, tenant-by-partner, and current/open game selects using backend endpoints.
5. Implement partner -> tenant dependent behavior and single-tenant auto-fill.
6. Replace create allocation `requested_count` with `allocation_percent`.
7. Add calculated preview using backend option/list metadata where available.
8. Update allocation list/detail columns to display partner/tenant/game names and percent/count fields.
9. Add recall-all and redistribute actions with reason/idempotency behavior matching BO conventions.
10. Add route/action for stock coverage scoped to partner/game.
11. Add remaining stock action/page route or reuse existing stock generation/coverage view with `game_id` and `partner_id` scope.
12. Add Partners stock percent display/edit workflow.
13. Update BO structural scripts/snapshots/checks for new admin endpoints if required.
14. Run Docker-only BO validation.
15. Commit scoped BO changes and write BO handoff.

## Acceptance Criteria

```text
allocation filters no longer use raw id text inputs for partner/tenant/game
partner select loads backend partner options by name/code
tenant select is constrained by selected partner
single active tenant partner auto-fills tenant in create allocation
multi-tenant partner requires explicit tenant selection
no-active-tenant partner cannot submit and shows a clear error
create allocation no longer asks for or sends requested_count
create allocation sends allocation_percent
allocation table/detail show partner/tenant/game display names, allocation_percent, allocated/remaining/recalled counts
stock coverage action opens partner/game scoped coverage workflow
remaining stock action opens partner/game scoped remaining stock view
recall-all action calls backend endpoint with safe confirmation/reason/idempotency
redistribute action is disabled until full recall/recalled state and then calls backend endpoint
Partners workflow shows/edits partner stock percent
UI surfaces backend <=100% partner percent validation
UI surfaces backend usage-protection validation when percent is too low
BO checks/tests/build pass through Docker
handoff includes commit hash
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Run any focused BO structural scripts that cover admin operation catalog/OpenAPI path snapshots/allocation/partner workflows and record results.

If using browser/manual validation, start the app through Docker and record route, login, and workflow evidence. Do not run destructive database commands against runtime `newpaotang`.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
backend routes/contracts consumed
allocation option source behavior
partner -> tenant dependent select behavior
single-tenant auto-fill behavior
multi-tenant explicit selection behavior
no-active-tenant validation behavior
allocation_percent create payload evidence
requested_count removal evidence
allocation table/detail display fields
stock coverage action route behavior
remaining stock action route behavior
recall-all action behavior
redistribute action/disabled-state behavior
Partners stock percent UI behavior
partner percent <= 100 validation display behavior
usage-protection validation display behavior
validation commands/results
manual/browser evidence if available
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

BO Develop
