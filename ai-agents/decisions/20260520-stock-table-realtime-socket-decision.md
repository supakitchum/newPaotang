# Stock Table Realtime Socket Decision

## Date

2026-05-20

## Status

Approved after remediation QA.

## Decision

Add realtime websocket updates for the central Stock data table so operators can see `available_count`, `allocated_count`, `sold_count`, `recalled_count`, and `total_count` change without manual refresh.

This is a normal Coordinator-flow task. Coordinator must not implement this directly. User must send the dispatch prompt to Orchestrator.

## Coordinator Amendment: Frozen Allocation Ownership For Top-Ups

Append this virtual top-up ownership rule to the same backend workflow before Backend Develop starts. Do not split it into a separate task because it touches the same stock generation, allocation, customer availability, grouped stock table row, and realtime refresh surfaces.

Required product rule:

- Keep one active `stock_supply_profiles` container per game with multiple `virtual_stock_supply_layers`.
- Each allocation must snapshot the active supply layers that existed at allocation time.
- Existing allocations must stay fixed after later top-ups; their `allocated_count` and partner ownership must not grow just because generated supply grew.
- Supply added by later top-ups must be unassigned (`no_agent` / unassigned owner) until a new allocation or redistribute flow explicitly allocates it.
- Top-up layers must keep using a new independent system-managed `layer_seed`; do not force per-number capacity to differ from previous layers because that would distort the configured distribution.
- Partner assignment must use a fixed denominator of `10000` basis points so unallocated percent remains unassigned instead of normalizing active partners to 100%.

## Current State

- `Generation progress` already subscribes to `stock.generation.progress.updated`.
- `Stock Pattern Coverage` already subscribes to `stock.coverage.updated`.
- The main Stock table on Central Stock / Stock Generation is still loaded through `/admin/central/stock` in `AdminOperationsPage.vue` and does not subscribe to a stock-table socket.
- Existing `StockCoverageUpdated` payloads are pattern/dimension oriented and are not the same shape as grouped stock table rows.

## Required Behavior

- Add a realtime channel for the grouped central Stock table, scoped by game.
- Suggested channel:

```text
private-admin.central.stock.table.game.{game_id}
```

- Suggested event:

```text
stock.table.updated
```

- Authorization must require central `stock.view` permission at minimum.
- Payload must support:
  - `refresh_required: true` for broad changes where exact row deltas are not safe or efficient.
  - `row` payload for a single `full_number`, shaped to match the grouped `/admin/central/stock` row contract.
- Frontend must subscribe only when:
  - central stock grouped table is visible,
  - `game_id` filter is present,
  - admin session is authenticated.
- If a row update matches the current filters and exists on the current page, merge it into the table in-place.
- If payload is incomplete, filter/sort compatibility is uncertain, or `refresh_required` is true, reload the table and refresh stock summary widgets.
- Stock table rows, number detail rows, partner availability, and realtime payloads must respect allocation layer snapshots:
  - central generated supply can increase after top-up,
  - existing partner allocation/assigned count must stay unchanged,
  - new top-up copies show as unassigned until explicitly allocated.

## Broadcast Coverage

Backend implementation must cover changes that affect grouped stock table counts:

- stock generation / top-up / import
- allocation create, cancel, recall, redistribute
- customer reservation and release
- sold sync / checkout sale completion
- virtual stock counter changes that alter available/allocated/sold counts

## Out Of Scope

- Replacing Stock Pattern Coverage realtime.
- Replacing Generation progress realtime.
- Reintroducing physical stock generation or Partner Quotas workflow.
- Destructive runtime DB operations.

## Validation Expectations

- Backend tests for realtime channel authorization, including rejection without `stock.view`.
- Backend tests proving stock table update or refresh events are dispatched for allocation and customer stock counter changes.
- Backend tests proving initial allocation stays fixed after top-up, top-up copies are unassigned, and a later allocation can assign newly unassigned supply.
- Backend tests proving partner generated pattern counts exclude unassigned top-up layers.
- BO tests or component-level evidence proving realtime payloads update/reload the central stock table.
- BO lint/test/build through Docker.
- QA must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing` for destructive commands.
- QA must not wipe runtime DB `newpaotang`.

## Dispatch

Next Agent: Orchestrator

User must send the Coordinator board/task instruction to Orchestrator chat.

## Coordinator Review: BO Panel Missing After QA

Date: 2026-05-20

Coordinator rejects the QA PASS for this task.

User opened BO after QA and reported that the expected panel is not visible. This is a user-visible acceptance failure for the stock table realtime workflow.

Review findings:

- QA report was left uncommitted/unpushed in the worktree when Coordinator inspected the task.
- QA report says `PASS`, but its own risks section says live browser websocket event mutation was not manually triggered end-to-end.
- BO evidence is mostly source/static guardrails plus build/lint/test. That is not enough when the reported defect is visual panel visibility in the actual BO.
- Existing BO handoff says no owner/allocation display logic changed and does not prove a visible stock table realtime/status panel is rendered for the operator.

Decision:

- Do not close `stock-table-realtime-socket`.
- Route a remediation through Orchestrator first, then BO Develop, then QA Tester.
- BO must ensure the stock table realtime/summary panel is visibly rendered in BO for the central grouped Stock table with a selected game.
- If no game is selected, BO must show a visible prompt/state instead of silently hiding the panel.
- QA must provide authenticated BO browser evidence that the panel is visible before it may report PASS.

Remediation task:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-orchestrator.md
```

## Coordinator Approval After Remediation QA

Date: 2026-05-20

Coordinator approves `stock-table-realtime-socket` after remediation QA.

Evidence reviewed:

- BO remediation implementation commit: `6d730b18418d789ab05774bb26abc4330d72b761`.
- QA dispatch/current HEAD under test: `6d1c536b4cf26a4544c941d823814a9e28130fe0`.
- QA report: `ai-agents/reports/20260520-stock-table-realtime-socket-remediation-qa-report.md`.
- Browser artifact directory: `ai-agents/reports/artifacts/20260520-stock-table-realtime-socket-remediation-qa/browser`.

Acceptance result:

- Authenticated BO login passed.
- `/admin/central/stock` shows visible `.np-stock-realtime-panel` and no-game prompt.
- Selected-game routes `/admin/central/stock`, `/admin/central/master-stock`, `/admin/central/stock-generation`, and `/admin/central/stock-recall` show the visible Stock table realtime panel, summary widgets, and grouped stock count columns.
- Backend focused tests, BO lint/test/check/build, runtime restore, and login smoke passed.
- Destructive DB command was limited to `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.

Residual risk:

- QA did not manually trigger a live browser stock mutation event. Backend event/auth tests and BO source/static checks still cover the `stock.table.updated` contract and merge/reload paths.

Decision:

```text
APPROVED
```
