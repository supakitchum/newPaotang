# 20260519 Virtual Stock Topup Cleanup - Coordinator Handoff

## Agent

Coordinator

## Task

Open work for `virtual-stock-topup-cleanup`.

## What Was Done

Confirmed the hotfix base is already clean and pushed:

```text
develop...origin/develop
0bfc447 hotfix: enforce stock coverage supply limits
```

Created the Coordinator decision for the next scope:

```text
ai-agents/decisions/20260519-virtual-stock-topup-cleanup-decision.md
```

Updated the shared virtual stock contract:

```text
docs/virtual-stock-realtime.md
```

Updated the agent board to route this new work through Orchestrator first.

## Coordinator Instruction For Orchestrator

Split this work into Backend Develop, BO Develop, and QA Tester tasks.

Routing:

```text
Backend Develop -> Orchestrator -> BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Backend goes first.

## Required Scope

Implement the following as one coordinated feature/hotfix cleanup:

```text
1. Add virtual stock top-up.
2. Remove seed input from BO and make backend manage seed/layer seed automatically.
3. Add Stock Generation row actions to see which agent/partner owns each virtual ticket/copy or whether it has no agent.
4. Add Stock Generation row/detail action to view real generated images for materialized tickets.
5. Remove physical stock generation from BO/API/OpenAPI/tests.
6. Make Stock Pattern Coverage realtime through websocket.
```

## Backend Develop Scope

Backend owns:

```text
virtual top-up schema/model/service changes
generate endpoint virtual-only contract
automatic internal seed generation
idempotent top-up replay/conflict behavior
combined virtual capacity calculation across initial generate + top-up layers
customer search/reservation availability using combined virtual supply
Stock Generation full-number/ticket detail contract with agent/partner ownership
real image fields for materialized stock_items/local_stock_items
Stock Pattern Coverage realtime broadcast events for generate/top-up, limit changes, overrides, reservation/release, and sold conversion
removal/rejection of physical quota generation payloads
OpenAPI updates
backend tests
backend handoff
```

Backend must not bulk insert `stock_items` for virtual top-up. Materialized rows should still be created lazily during reservation/sale flow.

Suggested data-model direction:

```text
keep stock_supply_profiles as active game container
add virtual supply layers/batches for additive top-up
sum layer capacity per full_number for generated supply
use layer id + full_number + copy index for stable virtual stock refs
preserve counters and existing reservations when top-up is added
```

If Backend chooses another design, it must document why and how it preserves additive supply and idempotency.

## BO Develop Scope

BO owns after backend handoff:

```text
remove seed input from Stock Generation
remove quota_random/physical generation mode and physical quota fields
make Generate Stock submit virtual generate/top-up only
show initial generate vs top-up status/copy in Stock Generation
add row action to full-number/detail view
show agent/partner ownership or unassigned/no agent for each available virtual copy where backend exposes it
show real image_url/image_thumb_url/generation status only for materialized tickets
subscribe Stock Pattern Coverage to websocket updates for the selected game/scope/dimension
update visible coverage rows/widgets/tabs from socket deltas and fallback to HTTP reload on reconnect
do not fake image rows for unmaterialized virtual capacity
surface backend validation errors for retired physical payloads and supply limit errors
build validation
BO handoff
```

## QA Tester Scope

QA owns after Backend and BO handoffs:

```text
validate initial virtual generate creates profile/supply
validate second virtual generate/top-up increases generated supply without replacing profile/counters
validate seed is not visible/required in BO
validate physical generation options and payloads are gone/rejected
validate customer search availability increases after top-up where limits allow
validate reservation still materializes real tickets lazily
validate Stock Generation detail shows owner/no-agent and real image data only when present
validate limits cannot exceed generated combined virtual supply
validate Stock Pattern Coverage updates through socket without manual refresh after reserve/sold/top-up/limit changes
validate two-browser realtime still works after top-up
```

QA destructive commands must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing` only. Runtime smoke must be non-destructive.

## Files Changed

```text
ai-agents/decisions/20260519-virtual-stock-topup-cleanup-decision.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-coordinator-handoff.md
docs/virtual-stock-realtime.md
ai-agents/BOARD.md
```

## Validation

Coordinator documentation/dispatch only.

Completed:

```sh
git status --short --branch
# develop...origin/develop before staging; only coordinator docs/board changes dirty

git diff --check
# passed
```

## Known Risks

```text
Virtual top-up changes core stock capacity math; backend must own the source-of-truth contract before BO.
Existing virtual_stock_ref shape may need versioning/layer identifiers to avoid collisions across top-ups.
Removing physical generation must not break import stock or already materialized reservation/ticket image flows.
Coverage limit validation from the latest hotfix must continue to use generated combined virtual supply.
Stock Pattern Coverage realtime can get noisy; backend should emit focused row/dimension deltas and BO should reload on reconnect instead of polling aggressively.
```

## Questions For Coordinator

None. The current decision is sufficient for Orchestrator to split tasks.

## Next Agent

Orchestrator
