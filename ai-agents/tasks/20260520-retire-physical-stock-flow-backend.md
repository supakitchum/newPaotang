# retire-physical-stock-flow-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
retire-physical-stock-flow
```

Backend Develop is the first implementation agent for this workflow. BO Develop must wait for the backend handoff before final UI retirement.

## Canonical Worktree Start Gate

Backend Develop must start from the canonical worktree only:

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
there are uncommitted changes that Backend Develop did not create and they overlap this task
```

The backend handoff must include the worktree path and HEAD used.

## Objective

Retire the old physical stock flow from active backend/API use while keeping virtual materialization tables:

```text
POST /admin/central/stock/generate accepts only generation_mode=virtual_profile
POST /admin/central/allocations rejects requested_count
allocation does not bulk assign physical stock_items or partner_stock_allocation_items
partner_stock_allocations remains the allocation snapshot
stock_partner_distributions is the partner percent/source-of-truth
partner/customer stock visibility reads virtual distribution and generated counts
partner-sync/allocations returns virtual allocation data
OpenAPI/docs/tests reflect the active virtual-only stock flow
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
ai-agents/decisions/20260520-coordinator-role-rules-decision.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
docs/permissions.md
docs/erd.md
docs/status-enums.md
```

Relevant sections:

```text
docs/coordinator-agent-handoff.md#2026-05-20-retire-physical-stock-flow
docs/virtual-stock-realtime.md#retire-physical-stock-flow
```

## Scope

Backend Develop owns:

```text
active stock generation API behavior
central allocation create behavior
physical allocation branch deactivation/removal from active flow
virtual allocation snapshot and partner distribution behavior
partner/customer stock visibility for virtual allocation
partner-sync allocation output for virtual allocation data
OpenAPI updates
backend docs/permissions/status docs where needed
backend tests
backend handoff
```

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
dropping legacy tables
deleting stock_items or local_stock_items
deleting virtual_stock_ref columns
runtime DB cleanup
destructive runtime DB commands against newpaotang
```

## Keep These Tables / Concepts

Do not remove these because virtual stock still needs them:

```text
stock_items
local_stock_items
virtual_stock_ref columns
partner_stock_allocations as allocation snapshot
stock_partner_distributions as partner stock percent source of truth
```

Do not drop these legacy tables in this task:

```text
partner_quotas
partner_stock_allocation_items
```

They may be left as legacy tables, but new active generation/allocation/sync paths must not depend on them as the source of truth.

## Required Backend Behavior

Stock generation:

```text
POST /admin/central/stock/generate accepts generation_mode=virtual_profile only
quota_random, quota, physical, missing/legacy generation modes are rejected
legacy physical fields remain rejected:
  total_count
  back2_count_per_number
  back3_count_per_number
  front3_count_per_number
  start_number
  count
  number_digits
seed/layer seed remains internal
base lottery numbers must use apps/platform-api/storage/app/public/number.json via the approved seeder/source path
do not revert to generated 000000-999999 base source
```

Allocation:

```text
POST /admin/central/allocations rejects requested_count in the request payload
allocation_percent remains the active BO/API input
allocation target count is derived from virtual generated supply and partner distribution/percent contract
allocation writes/updates partner_stock_allocations and stock_partner_distributions
allocation must not bulk-insert or bulk-update stock_items for physical assignment
allocation must not create partner_stock_allocation_items for new active allocation flow
existing lazy materialization after customer reservation/sale/image flows must continue to use stock_items/local_stock_items
```

Partner/customer visibility:

```text
partner stock views must read virtual partner distribution and generated counts
customer search/reservation visibility must reflect virtual partner distribution and generated counts
games without active virtual profile have no generated virtual availability
reservation may still lazily materialize stock_items/local_stock_items for selected tickets
```

Partner sync:

```text
GET /partner-sync/allocations must support virtual allocation data
do not return only physical partner_stock_allocation_items data
include enough allocation/distribution/count metadata for partner clients to understand virtual allocated stock
preserve auth/tenant/partner scoping
```

Partner quota legacy API:

```text
Audit active /admin/central/partner-quotas backend exposure.
Do not use partner_quotas as the source of truth for new stock visibility/allocation.
If write endpoints remain reachable for compatibility, document them as legacy/deprecated or return a clear retired-flow response according to existing API conventions.
Do not drop the partner_quotas table.
```

## Required Steps

1. Inspect current central stock generation, allocation, partner sync, partner store/customer visibility, OpenAPI, and tests.
2. Confirm stock generation validation rejects all non-virtual modes and legacy physical fields.
3. Remove/deactivate any active backend branch that bulk allocates physical `stock_items`.
4. Remove/deactivate new-flow writes to `partner_stock_allocation_items`.
5. Make `requested_count` a rejected create-allocation request field.
6. Ensure active allocation flow uses `allocation_percent`, `partner_stock_allocations`, and `stock_partner_distributions`.
7. Ensure partner/customer stock visibility reads virtual generated counts and partner distributions.
8. Update `partner-sync/allocations` to expose virtual allocation data, not only physical allocation item rows.
9. Audit central partner quota endpoints/docs and mark/disable legacy active use without dropping tables.
10. Update OpenAPI and backend docs to remove active physical allocation/generation behavior.
11. Add or update backend tests for rejected physical generate payloads, rejected `requested_count`, virtual allocation snapshot/distribution writes, no physical bulk allocation rows, partner/customer visibility, and partner sync virtual allocation output.
12. Run Docker-only validation with test DB isolation.
13. Commit scoped backend changes and write backend handoff.

## Acceptance Criteria

```text
physical/quota generation payloads are rejected by API and tests
requested_count allocation payload is rejected by API and tests
virtual allocation creates/updates partner_stock_allocations and stock_partner_distributions
new allocation flow does not bulk create/update physical stock_items
new allocation flow does not create partner_stock_allocation_items as source-of-truth rows
stock_items/local_stock_items lazy materialization still works for customer reservation/sale/image flows
partner/customer stock visibility reflects virtual distribution and generated counts
partner-sync/allocations returns virtual allocation data
OpenAPI/docs do not advertise active physical generation/allocation workflows
backend tests pass through Docker with newpaotang_test isolation
handoff includes commit hash
```

## Validation Commands

Use Docker commands only. Destructive database commands must use `newpaotang_test`.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest
```

Add or run focused partner sync/partner store tests for virtual allocation visibility. Validate OpenAPI syntax through Docker and record the command.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
stock generation retirement behavior
requested_count rejection behavior
allocation storage/write behavior
evidence that new allocation does not bulk write physical stock_items or partner_stock_allocation_items
partner/customer visibility behavior
partner-sync virtual allocation contract
partner quota legacy API decision/behavior
OpenAPI/docs changes
test DB isolation evidence
validation commands/results
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

Backend Develop
