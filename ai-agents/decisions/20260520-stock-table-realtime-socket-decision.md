# Stock Table Realtime Socket Decision

## Date

2026-05-20

## Status

Approved for Orchestrator dispatch.

## Decision

Add realtime websocket updates for the central Stock data table so operators can see `available_count`, `allocated_count`, `sold_count`, `recalled_count`, and `total_count` change without manual refresh.

This is a normal Coordinator-flow task. Coordinator must not implement this directly. User must send the dispatch prompt to Orchestrator.

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
- BO tests or component-level evidence proving realtime payloads update/reload the central stock table.
- BO lint/test/build through Docker.
- QA must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing` for destructive commands.
- QA must not wipe runtime DB `newpaotang`.

## Dispatch

Next Agent: Orchestrator

User must send the Coordinator board/task instruction to Orchestrator chat.
