# stock-table-realtime-socket-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
stock-table-realtime-socket
```

Backend Develop has completed and pushed the realtime backend contract. BO Develop is now the next implementation agent.

## Backend Dependency

Read this handoff before implementation:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
```

Backend implementation commits:

```text
42af0f5b04b73bca2f22458f6a4526c262df43ad
af9186dcb465ddd724dd4fe99a537bac8eb5a50a
```

Use the backend handoff as the final source for channel name, event name, auth permission, and payload shapes.

## Canonical Worktree Start Gate

BO Develop must start from the canonical worktree only:

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
there are uncommitted changes that BO Develop did not create and they overlap this task
```

The BO handoff must include the worktree path and HEAD used.

## Objective

Subscribe the main central grouped Stock table to backend realtime updates so operators can see count changes without manual refresh:

```text
available_count
allocated_count
sold_count
recalled_count
total_count
status / updated fields where provided
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
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
```

Relevant BO files:

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminRealtime.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminStockSummaryWidgets.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/check-stock-summary-widgets.mjs
```

## Scope

BO Develop owns:

```text
AdminOperationsPage stock table realtime subscription
row payload merge/reload behavior
stock summary widget refresh on realtime changes
small realtime/fallback state if it matches existing UI patterns
BO structural checks/tests for stock table realtime wiring
BO handoff
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
backend event/channel changes
replacing Stock Pattern Coverage realtime
replacing Stock Generation progress realtime
physical stock generation
Partner Quotas workflow
requested_count allocation flow
destructive runtime DB commands against newpaotang
```

## Backend Contract To Consume

Channel:

```text
private-admin.central.stock.table.game.{game_id}
```

Event:

```text
stock.table.updated
```

Auth:

```text
central admin with stock.view permission
```

Broad payload:

```json
{
  "game_id": "gam_x",
  "refresh_required": true,
  "reason": "generation_completed",
  "updated_at": "2026-05-20T00:00:00Z"
}
```

Row payload:

```json
{
  "game_id": "gam_x",
  "refresh_required": false,
  "reason": "reservation_created",
  "updated_at": "2026-05-20T00:00:00Z",
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

## Required BO Behavior

Subscribe only when all are true:

```text
scope is central
current resource is the grouped Stock table / central stock operation
mode is list
game_id filter is present
admin session is authenticated
```

Do not subscribe when:

```text
tenant pages are active
Stock Pattern Coverage page is active
Stock Generation progress component already handles its own subscription
no game_id is selected
session is not authenticated
```

On `refresh_required: true`:

```text
reload the current Stock table page through HTTP
refresh Stock Summary widgets
avoid resetting user filters unless the existing load behavior requires it
```

On row payload:

```text
validate payload game_id matches the selected game_id
validate row.full_number exists
if row is already visible on current page and current filters/sort are compatible, merge count/status/update fields in-place
refresh Stock Summary widgets after a successful merge
reload table + summary if current filters/sort/page compatibility is uncertain
reload table + summary if row is missing required fields
do not insert unseen rows into the current page unless filters/sort/page compatibility is proven safe
```

Compatibility rules:

```text
number/front3/back3/back2/status/partner/tenant/allocation filters can make row membership uncertain
API sort by count/status/updated fields can make row order uncertain
cursor pagination can make unseen row placement uncertain
when uncertain, prefer reload over clever local mutation
```

Realtime state:

```text
reuse useAdminRealtimeSubscription
use existing realtime badge/state style if lightweight
on reconnect, reload the table and summary widgets
when realtime is unavailable, HTTP table reload remains source of truth
```

Keep existing realtime behavior intact:

```text
AdminStockGenerationBatches stock.generation.progress.updated must keep working
AdminStockPatternCoverage stock.coverage.updated must keep working
customer-facing stock.availability.updated is out of BO scope
```

Frozen top-up ownership note for BO:

```text
Backend now keeps old allocations fixed after top-up and marks later top-up copies as unassigned/no_agent until allocated.
BO should not fake owner assignment for unassigned top-up rows/copies.
If existing detail views receive owner/no_agent fields from backend, display backend values as-is.
```

## Required Steps

1. Read Backend handoff and confirm channel/event/payload.
2. Inspect `AdminOperationsPage.vue` list loading, stock summary refresh key, filters, sort state, pagination state, and existing realtime composable use.
3. Add computed stock table realtime channel for selected `game_id`.
4. Add `useAdminRealtimeSubscription` in `AdminOperationsPage.vue` for the central grouped Stock table only.
5. Implement event handler for `refresh_required` and row payloads.
6. Merge visible matching rows only when safe; otherwise reload.
7. Refresh stock summary widgets on merge, reload, and reconnect.
8. Add or update structural BO checks to assert stock table realtime wiring, channel, event, reload, and summary refresh behavior.
9. Ensure Stock Pattern Coverage and Stock Generation progress subscriptions are untouched.
10. Run Docker-only BO validation.
11. Commit scoped BO changes and write BO handoff.

## Acceptance Criteria

```text
AdminOperationsPage subscribes to private-admin.central.stock.table.game.{game_id} only for central grouped Stock table with selected game_id
subscription uses stock.table.updated
no subscription happens without game_id or authentication
refresh_required reloads table and summary widgets
safe row payload updates visible matching row counts in-place
uncertain row/filter/sort/page compatibility reloads instead of unsafe mutation
reconnect reloads table and summary widgets
existing generation progress realtime remains wired
existing stock pattern coverage realtime remains wired
Stock Generation remains virtual_profile only
Partner Quotas/requested_count/physical stock flows are not reintroduced
BO lint/test/build pass through Docker
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
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Run any focused BO structural scripts/checks that cover `AdminOperationsPage.vue`, realtime, and stock table summary behavior. If browser/manual validation is available, record central Stock route evidence with selected game filter and realtime/fallback state. Do not run destructive database commands against runtime `newpaotang`.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
backend channel/event/payload consumed
subscription enable/disable conditions
refresh_required reload behavior
row merge behavior
uncertain compatibility reload behavior
summary widget refresh behavior
reconnect behavior
existing realtime compatibility notes
frozen top-up owner/no_agent display note if touched
validation commands/results
manual/browser evidence if available
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

BO Develop
