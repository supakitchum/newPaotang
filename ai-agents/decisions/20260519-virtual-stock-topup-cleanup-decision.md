# 20260519 Virtual Stock Topup Cleanup Decision

## Context

Latest hotfix commit is clean and pushed:

```text
0bfc447 hotfix: enforce stock coverage supply limits
```

Coordinator is opening the next work item from the user request:

```text
- add virtual stock top-up
- remove seed input and let the system manage it
- add Stock Generation row actions showing which agent/partner owns each ticket or no agent
- add actions to view each ticket image
- remove physical stock generation
```

## Decision

The stock generation direction is now virtual-only.

`POST /admin/central/stock/generate` must no longer expose or accept physical/quota generation as a user-facing flow. The restored physical quota/top-up code from prior hotfix was only a recovery step; this new task retires it intentionally.

Virtual generation must become additive:

```text
first virtual generate for a game creates the active virtual stock profile
later virtual generate/top-up for the same game adds virtual supply
top-up must not archive/replace the existing profile
top-up must not bulk insert stock_items/local_stock_items
reserved/sold counters must keep applying to the combined generated virtual supply
```

Seed is internal implementation detail only:

```text
BO must not show a seed input
API callers should not need to send seed
backend generates and stores deterministic internal seed/layer seed per generate/top-up batch
idempotency replay must return the same batch/profile/layer without changing supply twice
```

Stock Generation rows must be operationally inspectable:

```text
row action can open detail for generated virtual full_number / ticket capacity
detail shows generated capacity, used/reserved/sold counters, effective central/partner limits
detail shows partner/agent ownership or "unassigned/no agent" for virtual copies
detail shows real image records only for materialized tickets/local stock items
unmaterialized virtual capacity must not fake image rows
```

## Architecture Guidance

Backend should introduce a durable way to represent additive virtual supply. Recommended shape:

```text
stock_supply_profiles remains the active profile/container per game
new virtual supply layer/batch records represent each initial generate or top-up
each layer has its own internal seed, base_count, generated capacity, set_distribution snapshot, and batch_id
capacity for a full_number is the sum of capacity from active layers
partner copy ownership is computed per layer/copy so two top-ups do not collide
```

If Backend Develop finds a simpler safe schema, document it in handoff before BO starts.

## Removed / Retired Contract

Retire these from BO, OpenAPI, and normal backend flow:

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

Import stock and already-materialized reservation rows are separate existing concepts and must not be broken unless explicitly scoped.

## Agent Flow

```text
Coordinator -> Orchestrator -> Backend Develop -> Orchestrator -> BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Backend must go first because data model, generate semantics, full-number detail, ownership, and image-detail contracts must be source-of-truth before BO wires UI.

## Acceptance Summary

```text
hotfix base commit is clean and pushed before work starts
physical stock generation is removed from UI/API/docs/tests
virtual top-up adds supply instead of replacing active profile
seed is auto-generated and not displayed in BO
Stock Generation row/detail actions expose ownership and image visibility honestly
coverage limits remain bounded by generated virtual supply
customer availability uses combined virtual supply after top-up
OpenAPI/docs/tests are updated
QA uses isolated test DB for destructive commands
```

## Next Agent

Orchestrator
