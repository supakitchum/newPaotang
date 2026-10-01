# virtual-stock-topup-cleanup-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
virtual-stock-topup-cleanup
```

Backend must go first because virtual top-up changes stock capacity source-of-truth, generate semantics, idempotency, ownership/detail contracts, and Stock Pattern Coverage realtime events.

## Objective

Make stock generation virtual-only and additive:

```text
first virtual generate creates the active game profile/container
later virtual generate/top-up adds supply without replacing the active profile
seed/layer seed is generated and managed internally
idempotency replay does not add supply twice
combined capacity sums all active virtual supply layers
customer availability and reservation use combined virtual supply
Stock Generation detail exposes owner/no-agent and real image fields honestly
Stock Pattern Coverage broadcasts realtime row/dimension deltas
physical/quota generation is retired from normal API/OpenAPI/tests
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
ai-agents/decisions/20260519-virtual-stock-topup-cleanup-decision.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-coordinator-handoff.md
```

## Scope

Backend Develop owns:

```text
virtual top-up schema/model/service changes
generate endpoint virtual-only contract
automatic internal seed/layer seed generation
idempotent top-up replay/conflict behavior
combined virtual capacity calculation across initial generate + top-up layers
customer search/reservation availability using combined virtual supply
Stock Generation full-number/ticket detail contract with agent/partner ownership
real image fields for materialized stock_items/local_stock_items
Stock Pattern Coverage realtime broadcast events for generate/top-up, limit changes, overrides, reservation/release, expiration, and sold conversion
removal/rejection of physical quota generation payloads
OpenAPI updates
backend tests
backend handoff
```

Recommended data-model direction:

```text
keep stock_supply_profiles as the active game container
add virtual supply layer/batch records for each initial generate/top-up
each layer stores internal seed/layer seed, capacity snapshot, set_distribution snapshot, and batch id
capacity for a full_number is the sum of capacity from active layers
stable virtual stock refs use layer id + full_number + copy index or an equivalent collision-safe scheme
existing counters/reservations keep applying after top-up
```

If another design is safer, document why and prove it preserves additive supply and idempotency.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO seed input removal
BO websocket subscription UI
bulk inserting stock_items/local_stock_items for virtual top-up
reintroducing physical/quota generation
destructive runtime DB commands against newpaotang
```

Import stock and already materialized reservation/image rows are separate existing concepts and must not be broken unless explicitly needed for this backend scope.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/virtual-stock-realtime.md if backend contract clarification is required
backend-owned docs when needed
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
real credential files or local environment secrets
```

## Required Steps

1. Inspect current virtual stock profile/counter/detail/generate/reservation implementation.
2. Introduce durable additive virtual supply layer/batch storage or an equivalent safe design.
3. Make `POST /admin/central/stock/generate` virtual-only for normal API flow.
4. Remove/retire these user-facing payloads from API/OpenAPI/tests:

```text
generation_mode=quota_random
generation_mode=quota
generation_mode=physical
total_count
back2_count_per_number
back3_count_per_number
front3_count_per_number
start_number
count
number_digits
async physical generation chunks
physical stock generation image dispatch from generate request
```

5. Make seed internal. API callers should not need to send `seed`; BO must not depend on it.
6. Implement idempotency replay/conflict behavior so replay returns the same batch/profile/layer and does not add supply twice.
7. Update generated capacity calculations to sum all active virtual supply layers.
8. Ensure reserved/sold counters continue to reduce combined supply correctly after top-up.
9. Ensure customer search/reservation availability uses combined virtual supply after top-up.
10. Extend Stock Generation full-number/ticket detail contract with ownership:

```text
partner/agent owner when available
unassigned/no agent when not allocated
real image_url/image_thumb_url/image_generation_status/image_generation_error only from materialized rows
unmaterialized capacity shown without fake ticket/image rows
```

11. Add Stock Pattern Coverage realtime events.
12. Recommended admin realtime contract:

```text
channel: private-admin.central.stock.coverage.game.{game_id}
event: stock.coverage.updated
```

13. Emit focused deltas after virtual generate/top-up, limit setting changes, per-pattern override changes, reservation/release/expiration changes, and sold conversion.
14. Keep HTTP APIs as source-of-truth fallback for reconnect or incomplete event payloads.
15. Update `docs/openapi.yaml` and backend docs.
16. Add/update backend tests for top-up, idempotency, combined capacity, retired physical payload rejection, customer availability, detail ownership/images, and coverage broadcast events.
17. Commit scoped backend changes and write the backend handoff.

## Acceptance Criteria

```text
first virtual generate creates supply/profile
second virtual generate/top-up adds supply without replacing profile/counters
idempotency replay cannot add supply twice
seed is generated internally and not required from caller
physical/quota payloads are rejected or absent from normal contract
combined virtual capacity is used by admin list/detail and customer availability
reservation still lazily materializes real ticket rows
detail exposes owner/no-agent and real image fields honestly
coverage limits remain bounded by combined generated supply
Stock Pattern Coverage websocket events are emitted for scoped changes
OpenAPI/docs/tests match implementation
backend validation passes through Docker
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
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Add or run focused tests for new virtual top-up, idempotency, retired physical payload rejection, and coverage broadcast behavior. Validate OpenAPI syntax through Docker and record the command.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
```

Must include:

```text
commit hash
files changed
schema/model/service design
generate/top-up contract
internal seed/layer seed behavior
idempotency replay/conflict behavior
combined capacity calculation
customer availability/reservation impact
detail ownership/image contract
coverage realtime channel/event/payload and emit points
physical/quota retirement details
OpenAPI/docs changes
test DB isolation evidence
validation commands/results
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

Backend Develop
