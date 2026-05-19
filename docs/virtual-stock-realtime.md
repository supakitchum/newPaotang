# Virtual Stock + Realtime Availability

## Current Contract

Virtual stock is enabled per game through `POST /admin/central/stock/generate` with a virtual-only generation mode.

The first generation for a game creates the active virtual stock profile/container. Later generation requests for the same game are top-ups: they add virtual supply to the existing active profile instead of replacing it.

When a game has an active virtual profile:

- customer search uses combined virtual capacity instead of prebuilt `stock_items`
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

Partner distribution and sale limits are configured outside the generate form. If partner distribution is empty, the engine falls back to existing partner quota weights or the current safe default behavior.

Back-office entry point:

- Central -> Stock Generation -> Generate stock
- Set distribution defines set capacity percentages, for example 10% of base numbers get 2-ticket capacity and 15% get 3-ticket capacity
- Re-running Generate stock for the same game is a virtual top-up and must increase generated virtual supply without replacing existing counters/reservations
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
- Stock Generation/detail must expose owner/agent assignment where available and show `no agent`/unassigned where not allocated
- image actions must show real materialized `stock_items` / `local_stock_items` image fields only
- unmaterialized virtual capacity must be shown as capacity, not as fake ticket image rows
- Stock Pattern Coverage must update generated/reserved/sold/remaining/limit values through websocket without manual refresh

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
