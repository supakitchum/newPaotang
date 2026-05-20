# Retire Physical Stock Flow Decision

## Date

2026-05-20

## Status

Approved for Orchestrator dispatch.

## Decision

Retire the old physical stock flow from active use while keeping virtual materialization tables.

Do not drop legacy tables in this task. This is a behavior/API/UI retirement pass, not a destructive schema cleanup.

## Product Direction

Virtual stock is now the only supported stock generation and allocation model for new work.

Physical/legacy flows must no longer be exposed or used by BO/API:

```text
physical generation
quota_random / quota / physical generation modes
Partner Quotas BO workflow
requested_count allocation create payload
physical allocation branch that bulk assigns stock_items
partner_stock_allocation_items as source of truth for new partner allocation
```

Keep these because virtual stock still needs them after customer action:

```text
stock_items
local_stock_items
virtual_stock_ref columns
partner_stock_allocations as allocation snapshot
stock_partner_distributions as partner percent source of truth
```

## Required Behavior

- `POST /admin/central/stock/generate` accepts only `generation_mode=virtual_profile` for active stock generation.
- `POST /admin/central/allocations` rejects `requested_count`; allocation percent comes from Partner default stock percent work or the current virtual partner percent contract if that work is not merged yet.
- Allocation must not bulk-insert or bulk-update physical `stock_items` or `partner_stock_allocation_items`.
- Allocation must write/update `partner_stock_allocations` and `stock_partner_distributions`.
- Partner/customer stock visibility must read virtual partner distribution and generated counts.
- `partner-sync/allocations` must support virtual allocation data instead of returning only physical allocation items.
- BO must remove or disable Partner Quotas and physical allocation UI.

## Out Of Scope

- Dropping tables such as `partner_quotas` or `partner_stock_allocation_items`.
- Deleting `stock_items` or `local_stock_items`.
- Runtime DB cleanup unless user explicitly asks in the same turn.

## Validation Expectations

- Backend tests prove physical generation payloads are rejected.
- Backend tests prove allocation with `requested_count` is rejected.
- Backend tests prove virtual allocation creates allocation snapshot + partner distribution without physical bulk allocation rows.
- Backend tests prove partner/customer search and partner sync can see virtual allocated stock.
- BO lint/build pass and Partner Quotas/physical allocation fields are not visible.
- QA uses only `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing` for destructive commands.

## Dispatch

Next Agent: Orchestrator

User must send the Coordinator board instruction to Orchestrator chat.
