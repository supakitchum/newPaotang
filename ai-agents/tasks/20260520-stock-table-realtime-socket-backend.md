# stock-table-realtime-socket-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
stock-table-realtime-socket
```

Backend Develop is the first implementation agent for this workflow. BO Develop must wait for the backend handoff before subscribing the main Stock table.

## Canonical Worktree Start Gate

Backend Develop must start from the canonical worktree only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

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

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
HEAD does not equal origin/develop after sync
there are uncommitted changes that Backend Develop did not create and they overlap this task
```

The backend handoff must include the worktree path and HEAD used.

## Objective

Add realtime websocket support for the main central grouped Stock table so BO can see these row counts update without manual refresh:

```text
available_count
allocated_count
sold_count
recalled_count
total_count
```

Append the frozen virtual top-up ownership requirement to this same backend pass:

```text
existing allocations stay fixed to the supply layers that existed at allocation time
new top-up supply remains unassigned/no_agent until a later allocation explicitly assigns it
top-up layer capacity uses a fresh independent layer_seed
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
```

Relevant current files:

```text
apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php
apps/platform-api/app/Modules/CentralStock/Events/StockCoverageUpdated.php
apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
apps/platform-api/tests/Feature/AdminOperationsTest.php
apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
apps/platform-api/database/migrations/**
```

## Scope

Backend Develop owns:

```text
stock table realtime event class/channel/payload
central realtime auth for stock table channel requiring stock.view
payload row shape matching grouped GET /admin/central/stock rows
refresh_required events for broad/uncertain changes
row events for safe single full_number changes
emits from generation/top-up/import/allocation/cancel/recall/redistribute/customer reservation/release/sold paths where applicable
backend tests
backend handoff
virtual top-up ownership snapshot support
partner availability/count logic that respects allocation layer snapshots
```

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO websocket subscription/merge UI
replacing Stock Pattern Coverage realtime
replacing Stock Generation progress realtime
physical stock generation
Partner Quotas workflow
requested_count allocation flow
destructive runtime DB commands against newpaotang
```

## Required Backend Behavior

Channel and event:

```text
channel: private-admin.central.stock.table.game.{game_id}
event: stock.table.updated
auth: central admin with stock.view permission
tenant admin or central admin without stock.view must be denied
```

Payload must support refresh-required broad changes:

```json
{
  "game_id": "gam_x",
  "refresh_required": true,
  "reason": "generation_completed"
}
```

Payload must support safe single-row updates:

```json
{
  "game_id": "gam_x",
  "refresh_required": false,
  "row": {
    "game_id": "gam_x",
    "full_number": "123456",
    "front3": "123",
    "back3": "456",
    "back2": "56",
    "available_count": 10,
    "allocated_count": 1,
    "sold_count": 2,
    "recalled_count": 0,
    "total_count": 13,
    "status": "available"
  }
}
```

The row payload should match the grouped `/admin/central/stock?grouped=1&game_id=...` row contract as closely as possible. If the backend cannot safely compute a complete row for the event context, emit `refresh_required: true`.

Broadcast coverage must include events that affect grouped stock table counts:

```text
virtual stock generation/top-up/import broad changes
allocation create
allocation cancel
allocation recall-all or single recall
allocation redistribute
customer reservation
customer reservation release/expiration
sold sync or checkout sale completion
virtual_stock_counters changes that alter available/allocated/sold counts
```

Do not break existing realtime:

```text
stock.generation.progress.updated
stock.coverage.updated
stock.availability.updated
```

## Required Frozen Top-Up Ownership Behavior

Use the existing virtual model:

```text
one active stock_supply_profiles row per game
multiple active virtual_stock_supply_layers rows per game/profile
```

Do not split each top-up into a separate profile.

Add allocation-time supply snapshot support:

```text
partner_stock_allocations must store the supply layers that were active when the allocation was created or redistributed
suggested column: supply_layer_ids_json
snapshot content: ordered list of virtual_stock_supply_layers.id values
```

Ownership and availability rules:

```text
allocation created after initial generate can assign only the layers in its snapshot
top-up layers created later must be unassigned/no_agent for that existing allocation
existing allocation allocated_count must not increase after later top-up
central generated supply and remaining/unassigned supply may increase after top-up
new allocation after top-up may assign only still-unassigned supply from layers that are not already in active allocation snapshots
virtual copy detail must show old allocated copies with partner owner and new top-up copies as unassigned/no_agent
partner/customer search must not expose unassigned top-up copies to a partner until allocated
```

Partner assignment must not normalize active partner percentages to 100%. Use `10000` basis points as the denominator so any unallocated percent remains unassigned.

Top-up randomness:

```text
each new generation/top-up batch must keep using a new independent system-managed layer_seed
do not expose seed input in BO/API
do not force capacity to differ from previous layers for the same full_number
idempotency replay must return the original layer and must not create a duplicate layer
```

Generated pattern counts:

```text
central generated pattern counts include all active layers
partner generated pattern counts include only layers assigned to that partner through allocation snapshots
unassigned top-up layers must not be counted as partner generated supply
```

## Implementation Notes

Prefer a dedicated event class such as:

```text
App\Modules\CentralStock\Events\StockTableUpdated
```

Prefer reusing or extending a realtime service rather than scattering event payload construction across unrelated code.

Suggested helper responsibilities:

```text
emitStockTableRefresh(game_id, reason)
emitStockTableRow(game_id, full_number, reason/context)
build grouped row using the same source logic as GET /admin/central/stock grouped rows
avoid event emission when game_id is empty
```

For broad changes such as generation/import, `refresh_required` is acceptable.

For reservation/release/sold or single full_number counter changes, emit row payload where possible so BO can merge in-place.

## Required Steps

1. Inspect current grouped `/admin/central/stock` row builder and realtime services.
2. Add stock table event/channel/payload.
3. Add central realtime auth pattern for `private-admin.central.stock.table.game.{game_id}` and require `stock.view`.
4. Add payload helper/service for refresh and row events.
5. Wire refresh/row emits into generation/import/allocation/cancel/recall/redistribute/customer reservation/release/sold paths.
6. Add a migration for allocation supply layer snapshots, with backwards-compatible handling for allocations that predate the column.
7. Update allocation create/redistribute to store active layer snapshots and keep `allocated_count` fixed after top-up.
8. Update partner availability, owner detail, and generated pattern count logic to use allocation snapshots and unassigned top-up supply.
9. Ensure existing coverage/generation/customer realtime still dispatches as before.
10. Add tests for channel auth allowed/denied.
11. Add tests proving allocation changes dispatch stock table update or refresh event.
12. Add tests proving customer reservation/release/sold counter changes dispatch stock table row or refresh event.
13. Add tests proving frozen allocation/top-up ownership behavior.
14. Update docs/OpenAPI only if useful for realtime contract documentation.
15. Run Docker-only validation with test DB isolation.
16. Commit scoped backend changes and write backend handoff.

## Acceptance Criteria

```text
private-admin.central.stock.table.game.{game_id} channel exists
stock.view is required for channel auth
stock.table.updated broadcasts on the game-scoped channel
payload supports refresh_required and row shapes
row payload count fields match grouped stock table contract
generation/import broad changes emit refresh_required
allocation state changes emit row or refresh event
customer reservation/release/sold changes emit row or refresh event
percent allocations snapshot supply layers at allocation time
existing allocation allocated_count does not increase after later top-up
top-up copies are unassigned/no_agent until explicitly allocated
partner generated pattern counts exclude unassigned top-up layers
new top-up layer_seed differs across distinct generation batches
existing stock coverage/generation/customer realtime tests still pass
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
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AdminOperationsTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
```

Add or run focused tests for checkout/sold sync and customer reservation/release event coverage if not covered by the required filters. Validate OpenAPI/docs syntax through Docker if edited.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
channel name and auth requirement
event name and payload shapes
row payload source/contract
refresh_required behavior
generation/import emit behavior
allocation/cancel/recall/redistribute emit behavior
customer reservation/release/sold emit behavior
allocation layer snapshot migration/column
frozen allocation/top-up ownership behavior
unassigned top-up owner behavior
partner generated pattern count behavior
existing realtime compatibility notes
validation commands/results
test DB isolation evidence
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

Backend Develop
