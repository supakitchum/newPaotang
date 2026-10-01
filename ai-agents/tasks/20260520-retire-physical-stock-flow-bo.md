# retire-physical-stock-flow-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
retire-physical-stock-flow
```

Backend Develop has completed and pushed the API/backend contract. BO Develop is now the next implementation agent.

## Backend Dependency

Read this handoff before implementation:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
```

Backend implementation commits:

```text
9876c9226410becc13136dfc7308bb3b721b1137
c2774dc186f262b94ddac8130c458cc7b7a6101b
```

Use the backend handoff and `docs/openapi.yaml` as the final source for retired route behavior, payloads, validation errors, and response fields.

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

The BO handoff must include the worktree path and HEAD used.

## Objective

Retire active physical stock and partner quota UI surfaces from BO while keeping virtual stock allocation workflows:

```text
remove or disable Partner Quotas menu/route/operation from active BO
remove physical allocation fields and legacy quota create/update actions from active UI
ensure allocation create/preview uses allocation_percent and virtual partner distribution only
ensure remaining/stock views route to virtual distribution-backed stock views
surface backend retired_flow responses clearly if legacy routes are reached
update BO checks/snapshots/build coverage for the retired active UI
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
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
```

Relevant sections:

```text
docs/coordinator-agent-handoff.md#2026-05-20-retire-physical-stock-flow
docs/virtual-stock-realtime.md#retire-physical-stock-flow
```

## Scope

BO Develop owns:

```text
apps/back-office active menu/navigation route overrides
apps/back-office operation catalog entries/actions
Partner Quotas active UI retirement
allocation create/preview form safeguards against requested_count
stock generation/remaining route behavior for virtual allocation views
BO scripts/checks/openapi snapshots for active UI expectations
BO handoff
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
dropping legacy tables
runtime DB cleanup
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md if BO coverage wording changes
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real credential files or local environment secrets
```

## Backend Contract To Consume

Active backend behavior:

```text
POST /api/v1/admin/central/allocations rejects requested_count with 422 validation_failed
POST /api/v1/admin/central/allocations accepts allocation_percent
POST /api/v1/admin/central/stock/generate accepts virtual_profile only
GET /api/v1/admin/central/partner-quotas remains legacy read-only
POST /api/v1/admin/central/partner-quotas returns 410 retired_flow
PATCH /api/v1/admin/central/partner-quotas/{quotaId} returns 410 retired_flow
GET /api/v1/partner-sync/allocations returns virtual allocation/distribution metadata
```

BO must not present retired write flows as active workflows.

## Required BO Behavior

Partner Quotas:

```text
remove or disable Central Partner Quotas menu/route/operation from active navigation
remove Create quota and Update quota actions from active operation surfaces
do not encourage users to use partner_quotas for stock allocation or visibility
if a stale deep link reaches /admin/central/partner-quotas, show read-only/retired copy or redirect to active partner stock percent/allocation workflow
surface 410 retired_flow as a clear retired workflow message, not a generic crash
```

Allocation:

```text
allocation create form must not include requested_count
allocation create/preview must use allocation_percent and backend option metadata
allocation list/actions must continue to use virtual partner distribution-backed routes
remaining-stock route should stay scoped by game_id, partner_id, tenant_id, allocation_id, and status where available
do not add physical allocation controls or partner_stock_allocation_items controls
```

Stock Generation:

```text
Generate stock UI must remain virtual_profile only
do not show quota_random, quota, physical generation modes
do not show retired physical fields:
  total_count
  back2_count_per_number
  back3_count_per_number
  front3_count_per_number
  start_number
  count
  number_digits
seed remains hidden/internal
```

Checks / snapshots:

```text
update BO structural checks so central:partner_quotas is not required as an active route
update openapi-admin path snapshot expectations if active BO route coverage should no longer include partner quota write paths
add/adjust checks to assert Partner Quotas active UI is retired and allocation percent workflow remains present
```

## Required Steps

1. Read Backend handoff and OpenAPI retired route descriptions.
2. Inspect current BO navigation, operation catalog, route overrides, and structural scripts.
3. Remove/disable active Central Partner Quotas route/menu/operation.
4. Remove Partner Quota create/update actions from active UI, or make any remaining stale/deep-link view explicitly read-only/retired.
5. Ensure 410 `retired_flow` errors display clear retired-workflow copy.
6. Verify allocation create still uses `allocation_percent` and no `requested_count`.
7. Verify Stock Generation normalizer/form still forces `generation_mode: virtual_profile` and strips retired fields.
8. Verify remaining-stock and stock-coverage allocation actions route to virtual distribution-backed views.
9. Update BO structural scripts/snapshots/checks for the new active route set.
10. Run Docker-only BO validation.
11. Commit scoped BO changes and write BO handoff.

## Acceptance Criteria

```text
Central Partner Quotas is removed or disabled from active BO navigation
Partner Quota create/update actions are not presented as active workflows
stale partner quota deep links do not present retired writes as active success paths
retired_flow responses are surfaced clearly
allocation create form has no requested_count
allocation create payload uses allocation_percent
Stock Generation UI remains virtual_profile only
retired physical generation fields/modes are not visible
remaining stock/coverage actions stay scoped to virtual distribution workflows
BO checks/lint/test/build pass through Docker
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

Run any focused BO structural scripts/checks that cover navigation/catalog/OpenAPI snapshots and record results.

If using browser/manual validation, start the app through Docker and record route/login evidence. Do not run destructive database commands against runtime `newpaotang`.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
backend routes/contracts consumed
Partner Quotas retirement behavior
stale/deep-link behavior if applicable
retired_flow display behavior
allocation requested_count removal/guard evidence
allocation_percent create evidence
Stock Generation virtual-only evidence
remaining stock/coverage route behavior
BO structural check/snapshot changes
validation commands/results
manual/browser evidence if available
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

BO Develop
