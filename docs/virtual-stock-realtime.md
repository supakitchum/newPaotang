# Virtual Stock + Realtime Availability

## Retire Physical Stock Flow

Decision file:

```text
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
```

Virtual stock is the only active stock generation and allocation model for new work.

Retired from active API/UI behavior:

- physical stock generation modes
- Partner Quotas BO workflow
- `requested_count` allocation create payload
- physical allocation branch that bulk assigns `stock_items`
- `partner_stock_allocation_items` as source of truth for new partner allocation
- partner quota weights/sale windows as the source of virtual stock visibility

Still required:

- `stock_items` and `local_stock_items` for lazy materialization after customer reservation/sale/image work
- `partner_stock_allocations` as allocation snapshot
- `stock_partner_distributions` as partner stock percent source of truth

Do not drop legacy tables in the retirement task. Schema cleanup is a later phase after QA confirms no active endpoint/client depends on the old physical path.

## Current Contract

Virtual stock is enabled per game through `POST /admin/central/stock/generate` with a virtual-only generation mode.

The first generation for a game creates the active virtual stock profile/container. Later generation requests for the same game are top-ups: they add virtual supply to the existing active profile instead of replacing it.

Virtual stock generation requires seeded `base_lottery_numbers`. `DatabaseSeeder` runs `BaseLotteryNumberSeeder`, which loads the approved `number.json` from `BASE_LOTTERY_NUMBERS_PATH` or `storage/app/public/number.json` when present. If that file is missing, the seed step warns and generation remains blocked with `Base lottery numbers must be seeded before generating virtual stock.`

When a game has an active virtual profile:

- customer search uses combined virtual capacity instead of prebuilt `stock_items`
- partner/customer visibility requires active `stock_partner_distributions` rows for partner ownership; `partner_quotas` are legacy and not used as the new visibility source
- reservation creates `stock_items` and `local_stock_items` lazily only for selected tickets
- reserved and sold tickets are counted in `virtual_stock_counters`
- availability is broadcast after reserve, release, expiration, and sold conversion

Backend storage keeps `stock_supply_profiles` as the active game container and stores every initial generate/top-up as an active `virtual_stock_supply_layers` row. Each layer stores an internal layer seed, base-number count snapshot, set-distribution snapshot, batch id, and layer capacity. Full-number capacity is the sum of every active layer.

Games without an active virtual profile have no generated virtual availability. The old physical quota/range generation flow is retired and the generate endpoint rejects it.

## Generation Payload

Example:

```json
{
  "game_id": "gam_current",
  "generation_mode": "virtual_profile",
  "set_distribution": [
    { "set_size": 2, "percent": 10 },
    { "set_size": 3, "percent": 15 }
  ]
}
```

The set distribution controls added capacity per full number for the initial generation or top-up. Tickets are still sold one by one.

`seed` is internal and system-managed. BO must not show a seed input and API callers should not send one. Backend stores profile/layer seed metadata internally to make generated capacity deterministic and idempotent.

Partner distribution and sale limits are configured outside the generate form. Active partner visibility is sourced from `stock_partner_distributions`; if a virtual game has no active partner distribution rows, partner/customer virtual availability is empty until allocation percent is configured.

Partner sync allocation pulls:

- `GET /partner-sync/allocations` returns virtual allocation/distribution metadata from `stock_partner_distributions` and the matching `partner_stock_allocations` snapshot when present
- new active partner sync no longer uses `partner_stock_allocation_items` as the stock source of truth
- legacy materialized `stock_items` and `local_stock_items` still exist for reservation/sale/image materialization after a customer action

Back-office entry point:

- Central -> Stock Generation -> Generate stock
- Set distribution defines set capacity percentages, for example 10% of base numbers get 2-ticket capacity and 15% get 3-ticket capacity
- Re-running Generate stock for the same game is a virtual top-up and must increase generated virtual supply without replacing existing counters/reservations
- Allocation ownership is frozen to the supply layers that existed when the allocation was created or redistributed. A later top-up increases central generated/unassigned supply, but it must not increase an existing partner allocation or owner assignment.
- Partner distribution, central sale limits, and partner sale limits belong in Stock Settings / Stock Pattern Coverage, not in the generate modal
- Legacy physical fields such as `total_count`, `back2_count_per_number`, `start_number`, and `count` are not available in BO and are rejected by API

Physical/quota generation modes are retired from the normal contract:

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
```

## Limits And Counters

Limits live in `stock_sale_limit_settings`.

- central scope: `scope_type=central`, `scope_id=central`
- partner scope: `scope_type=partner`, `scope_id={partner_id}`
- fields: `back2_limit`, `back3_limit`, `front3_limit`

Counters live in `virtual_stock_counters`.

- reserved and sold both reduce remaining availability
- release/expire decrements reserved
- checkout conversion moves reserved to sold

The visible remaining count is the minimum of full-number partner capacity, central pattern limits, and partner pattern limits.

Coverage limits must be bounded by generated virtual supply. If a user wants to raise a central/partner limit above current supply, they must top up stock first.

## Realtime

Customer stock updates are broadcast as:

- channel: `private-customer.tenant.{tenant_id}.stock.game.{game_id}`
- event: `stock.availability.updated`

Payload:

```json
{
  "tenant_id": "ten_x",
  "partner_id": "par_x",
  "game_id": "gam_x",
  "full_number": "123456",
  "front3": "123",
  "back3": "456",
  "back2": "56",
  "remaining_count": 0,
  "status": "sold_out",
  "stock_mode": "virtual"
}
```

Customer UI must treat HTTP reservation as the source of truth. Websocket only updates visible state; if websocket disconnects, the UI falls back to polling the active search page.

Stock Pattern Coverage must also update through websocket.

Recommended admin channel:

- channel: `private-admin.central.stock.coverage.game.{game_id}`
- event: `stock.coverage.updated`

Payload should be a focused delta, not a full table dump:

```json
{
  "game_id": "gam_x",
  "scope_type": "central",
  "scope_id": "central",
  "dimension": "back2",
  "number": "56",
  "generated_count": 1200,
  "reserved_count": 10,
  "sold_count": 50,
  "default_limit": 500,
  "override_limit": null,
  "limit": 500,
  "remaining_limit": 440,
  "sellable_remaining_count": 440,
  "status": "available"
}
```

Backend should emit coverage updates after:

- virtual generate/top-up changes generated supply
- central/partner limit settings change
- per-pattern overrides change
- reservation/release/expiration changes reserved counters
- checkout conversion changes sold counters

BO Stock Pattern Coverage must subscribe for the selected game/scope and update visible rows/widgets without manual refresh. HTTP remains the source-of-truth fallback on reconnect, missed events, or when a delta does not cover the current filtered page.

## Agent Notes

- Do not bulk-generate `stock_items` for virtual games.
- Do not use `insertOrIgnore` for virtual reservation materialization in a way that hides sold/reserved conflicts.
- Do not expose seed as a BO input.
- Do not reintroduce physical stock generation.
- Top-up must add virtual supply and must not archive/replace the existing active profile.
- Stable virtual stock refs use a monotonically expanding full-number copy index; layer records make the capacity additive while keeping already issued refs stable.
- Stock Pattern Coverage must use websocket updates for realtime rows/widgets and fallback to HTTP reload only when needed.
- QA must test with two browsers: browser A sees a number, browser B reserves/sells until limit is full, browser A must see the number disabled by realtime.
- QA destructive DB commands must use testing DB only.

## Virtual Top-Up Follow-Up

Coordinator task `virtual-stock-topup-cleanup` supersedes the earlier replace-profile behavior.

Expected behavior:

- first generate creates active virtual profile/container for the game
- later generate/top-up adds an additional virtual supply layer/batch
- generated capacity for a full number is the sum of all active virtual supply layers
- counters remain stable across top-ups
- idempotency replay must not add supply twice
- changing set distribution for a top-up affects only that top-up layer
- allocation creates/redistributes snapshot the currently active supply layers; top-up layers created later remain unassigned/no_agent until a later allocation explicitly assigns them
- partner allocation/availability and partner generated pattern counts must use allocation snapshots instead of dynamically inheriting every later top-up layer
- partner percent assignment must use `10000` basis points as the fixed denominator so any unallocated percent remains unassigned instead of being normalized to active partners
- Stock Generation/detail must expose owner/agent assignment where available and show `no agent`/unassigned where not allocated
- image actions must show real materialized `stock_items` / `local_stock_items` image fields only
- unmaterialized virtual capacity must be shown as capacity, not as fake ticket image rows
- Stock Pattern Coverage must update generated/reserved/sold/remaining/limit values through websocket without manual refresh

## Central Stock Table Realtime

Central grouped stock table subscribers use:

- channel: `private-admin.central.stock.table.game.{game_id}`
- event: `stock.table.updated`
- auth: central admin scope with `stock.view`

Broad generation/top-up, allocation, recall, cancel, redistribute, and limit changes may emit `refresh_required: true`. Single full-number counter changes from customer reservation, release, expiration, or sold conversion should emit a grouped row payload when the backend can safely compute one.

## Stock Generation And Coverage Follow-Up

Coordinator task `stock-generation-coverage-usability` extends the virtual stock contract with BO usability and limit-default requirements.

Stock Generation list:

- Filters for `game_id`, number search, `front3`, `back3`, `back2`, and `status` must work through backend API.
- `Tickets` sort must sort by generated supply/capacity for the full number. It must not silently fall back to full-number lexical order.
- Row actions should include a full-number detail view.

Full-number detail:

- Show generated supply/capacity, availability, counters, and effective limits for the selected `game_id + full_number`.
- Show materialized `stock_items` and `local_stock_items` for that number.
- Show real image fields for materialized tickets, including `image_url`, `image_thumb_url`, generation status, and errors where available.
- Virtual capacity that has not been materialized yet must be shown as capacity without per-ticket image rows.

Stock Settings coverage defaults:

- Store default base Stock Pattern Coverage for central and partner scopes.
- Recommended key: `platform_system_settings.stock_pattern_coverage_default`.
- Expected shape:

```json
{
  "central": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner": { "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
}
```

These defaults are form/initial values for Stock Pattern Coverage. They must not rewrite existing saved game/scope limits unless the user saves the form.

Partner coverage limit rule:

- Partner limits may be lower than central.
- Partner limits must never exceed the central effective limit.
- Backend must enforce `partner effective limit <= central effective limit` for total/default settings and per-number overrides.
- BO should show the central ceiling, but backend validation is the source of truth.

## Allocation And Partner Percent Rework

Coordinator task `allocation-partner-percent-workflow` replaces the old allocation UX/API assumptions with the virtual stock partner percent model.

Terminology:

- "Agent" in business wording maps to the current `partners` table unless a later Coordinator decision introduces a separate agent entity.
- Partner tenant selection must be derived from the selected partner whenever possible.

Retirement follow-up status:

- Backend allocation create rejects `requested_count`; BO create must use `allocation_percent`.
- Backend allocation list/detail exposes partner, tenant, game, percent, remaining, and recalled metadata.
- Backend option endpoints, recall-all, redistribute, and partner percent update endpoints are implemented.
- BO still owns final UI retirement for physical allocation/Partner Quotas surfaces.

Expected backend contract:

- Allocation list/detail must include display metadata:
  - `partner_id`, `partner_code`, `partner_name`
  - `tenant_id`, `tenant_code`, `tenant_name`
  - `game_id`, `game_code`, `game_name`
  - `allocation_percent`
  - `allocated_count`, `remaining_count`, `recalled_count`, `status`
- Allocation filters using ids must support BO option sources:
  - partner selector by partner name/code
  - tenant selector constrained by selected partner
  - game selector by game name/code/current status
- If a selected partner has exactly one active tenant, BO should auto-fill `tenant_id`.
- If a selected partner has multiple active tenants, BO must show a tenant select filtered by partner and require one explicit tenant.
- If a selected partner has no active tenant, create allocation must be blocked with a clear validation error.
- `requested_count` must be retired from the BO create allocation workflow. New allocation creation should accept an allocation percent:
  - proposed request field: `allocation_percent`
  - valid range: greater than `0` and up to `100`
  - backend calculates target allocation count from available generated supply for the selected game and partner/agent percent contract
  - idempotency replay must return the same allocation and must not allocate twice
- Partner/agent stock percent must be centrally configurable:
  - store per partner per game if the game-specific model is required by existing `stock_partner_distributions`
  - expose default/global partner percent only if backend can clearly define how it applies to future games
  - all active partner percents for a game must sum to at most `100%`
  - backend validation is source of truth; BO validation is only a convenience layer
- Percent changes must not corrupt already sold/reserved stock. If a percent update would put a partner below already allocated/reserved/sold usage, backend must reject or require a separate recall/rebalance workflow.

Expected BO changes:

- Allocations filters:
  - replace `Partner ID`, `Tenant ID`, and `Game ID` text inputs with selects
  - show partner/game/tenant display names, not raw ids
  - tenant select auto-populates or filters after partner selection
- Create allocation modal:
  - use partner select, tenant select/auto-fill, game select
  - remove `Requested count`
  - add `Allocation percent`
  - show calculated preview: estimated supply, percent, estimated allocation count, existing allocated/remaining
- Allocation table:
  - show partner/agent display name
  - show tenant name where relevant
  - show game name
  - show allocation percent
  - show allocated/remaining/recalled counts
- Allocation row actions:
  1. Edit stock coverage for that partner/agent. Route should open Stock Pattern Coverage with `game_id`, `scope_type=partner`, and `partner_id`.
  2. View remaining stock like Stock Generation full-number table. Open a new page/tab scoped by `game_id` and `partner_id`.
  3. Recall all stock for that allocation/partner/game in one action with reason + idempotency key.
  4. Re-distribute stock after full recall. This should be disabled unless the prior recall-all state is complete.
- Partners table:
  - add stock percent column for each partner/agent
  - add central-only edit action/form for stock percent
  - validate sum of active partner percents does not exceed `100%`

Expected API additions/changes:

- Option endpoints or catalog option sources for partners, tenants-by-partner, and current/open games.
- `GET /admin/central/allocations` should support sortable/filterable partner/game/tenant metadata.
- `POST /admin/central/allocations` should accept percent-based payload and stop requiring `requested_count` from BO.
- Add recall-all endpoint, proposed:
  - `POST /admin/central/allocations/{allocation_id}/recall-all`
- Add re-distribute endpoint, proposed:
  - `POST /admin/central/allocations/{allocation_id}/redistribute`
- Add partner stock percent update endpoint or extend existing partner/stock settings endpoint.

Backend implementation contract:

- Partner/agent stock percent is stored per game in `stock_partner_distributions`.
- `partner_stock_allocations.allocation_percent_basis_points` records the percent snapshot used for the allocation.
- `partner_stock_allocations.requested_count` remains as the stored calculated target count for compatibility; BO must send `allocation_percent`, not `requested_count`.
- `partner_stock_allocations.recalled_count` records full recall progress for percent allocations.
- `partner_stock_allocations.payload_hash` is used with `created_by_admin_id + idempotency_key` so same-key replay returns the same allocation and changed payload returns `idempotency_conflict`.
- Option source endpoints:
  - `GET /admin/central/allocation-options/partners`
  - `GET /admin/central/allocation-options/tenants`
  - `GET /admin/central/allocation-options/games`
- Partner stock percent endpoint:
  - `PUT /admin/central/allocations/partner-percent`
- Recall/redistribute endpoints:
  - `POST /admin/central/allocations/{allocation_id}/recall-all`
  - `POST /admin/central/allocations/{allocation_id}/redistribute`
- Percent allocation target count is calculated from eligible unassigned virtual supply layers at allocation/redistribute time and then stored as a fixed snapshot for that allocation.
- Active partner percentages for the same game must sum to `<= 100%`.
- Percent updates below already reserved/sold partner usage are rejected.
- Recall-all sets the partner distribution to `status=recalled` and `percent_basis_points=0`; redistribute reactivates the saved allocation percent only after full recall.

Agent flow:

1. Backend Develop:
   - update allocation resource/list/filter contracts
   - implement percent-based allocation validation/calculation
   - implement partner percent validation sum <= 100
   - implement recall-all and redistribute endpoints
   - update OpenAPI, permissions/docs where needed
2. BO Develop:
   - replace id text fields with selects
   - implement dependent partner -> tenant behavior
   - update create modal to percent workflow
   - add allocation table columns/actions
   - add Partners stock percent UI
3. QA Tester:
   - test central allocation list filters with display names
   - test create allocation by percent with single-tenant auto-fill and multi-tenant manual select
   - test partner percent sum validation API/UI
   - test recall-all then redistribute flow
   - verify runtime smoke/login after tests
4. Coordinator:
   - review QA evidence
   - update BO percentage/completion status only from working API/UI evidence

Acceptance:

- Raw id entry is removed from allocation filters and create modal.
- Partner selection auto-fills tenant when there is exactly one active tenant.
- Create allocation no longer asks for `requested_count`; percent drives allocation.
- Allocation table shows partner/tenant/game display names and allocation percent.
- Allocation row actions cover stock coverage, remaining stock view, recall-all, and redistribute-after-recall.
- Partners table shows and edits partner/agent stock percent.
- Backend and BO both enforce total active partner stock percent <= 100%.
- QA confirms no destructive DB commands ran against runtime DB.
