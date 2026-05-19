# Virtual Stock + Realtime Availability

## Current Contract

Virtual stock is enabled per game by creating a `stock_supply_profiles` row through `POST /admin/central/stock/generate` with `generation_mode=virtual_profile`.

When a game has an active virtual profile:

- customer search uses virtual capacity instead of prebuilt `stock_items`
- reservation creates `stock_items` and `local_stock_items` lazily only for selected tickets
- reserved and sold tickets are counted in `virtual_stock_counters`
- availability is broadcast after reserve, release, expiration, and sold conversion

Games without an active virtual profile have no generated virtual availability. The old physical quota/range generation flow is retired and the generate endpoint rejects it.

## Generation Payload

Example:

```json
{
  "game_id": "gam_current",
  "generation_mode": "virtual_profile",
  "seed": "draw-2026-05-16",
  "set_distribution": [
    { "set_size": 2, "percent": 10 },
    { "set_size": 3, "percent": 15 }
  ],
  "partner_distribution": [
    { "partner_id": "par_x", "percent": 50 },
    { "partner_id": "par_y", "percent": 50 }
  ],
  "central_limits": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner_limits": [
    { "partner_id": "par_x", "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
  ]
}
```

The set distribution controls capacity per full number. Tickets are still sold one by one.
Partner distribution and sale limits are optional. If partner distribution is empty, the engine falls back to existing partner quota weights.

Back-office entry point:

- Central -> Stock Generation -> Generate stock
- Set distribution defines set capacity percentages, for example 10% of base numbers get 2-ticket capacity and 15% get 3-ticket capacity
- Partner distribution, central sale limits, and partner sale limits are optional config blocks saved when the profile is generated
- Legacy physical fields such as `total_count`, `back2_count_per_number`, `start_number`, and `count` are not available in BO and are rejected by API

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

## Agent Notes

- Do not bulk-generate `stock_items` for virtual games.
- Do not use `insertOrIgnore` for virtual reservation materialization in a way that hides sold/reserved conflicts.
- QA must test with two browsers: browser A sees a number, browser B reserves/sells until limit is full, browser A must see the number disabled by realtime.
- QA destructive DB commands must use testing DB only.

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
