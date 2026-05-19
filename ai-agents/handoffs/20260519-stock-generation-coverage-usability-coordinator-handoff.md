# 20260519 Stock Generation Coverage Usability - Coordinator Handoff

Task key: `stock-generation-coverage-usability`
Agent: Coordinator
Next Agent: Orchestrator

## Coordinator Scope Decision

This is normal coordinator flow, not direct hotfix implementation. Coordinator must not edit implementation code for this task unless the user explicitly sends a future `Hotfix` command.

Route through:

```text
Coordinator -> Orchestrator -> Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

## User Requirements

Fix and complete the following Stock Generation / Stock Coverage work:

```text
1. Generation progress action view is clickable but shows nothing.
2. Stock Generation rows need an action to view full-number detail.
3. Full-number detail must include ticket/leaf detail and generated image status/URLs for each materialized ticket for that number.
4. Stock Generation filters do not work.
5. Stock Generation sort by Tickets shows incorrect results.
6. Stock Settings needs a form for default base Stock Pattern Coverage for central and partner.
7. Stock Pattern Coverage must load those defaults as the initial values.
8. Partner Stock Pattern Coverage can be lower than Central but must never exceed the Central effective limit.
```

## Contract Direction

### Stock Generation Progress View

BO must make the progress action/detail view actually render data when selected.

Backend must verify the existing batch detail endpoint returns enough fields for BO:

```text
batch id
game id
type
status
requested/generated counts
progress percentage
round/chunk fields if present
payload/config summary
timestamps
failure reason
```

If backend data is sufficient, BO owns the fix. If not, Backend Develop must extend the batch detail resource and update OpenAPI.

### Full Number Detail Action

Stock Generation table rows represent a `full_number` under a game. Add a row action such as `View number`.

The detail must show:

```text
game_id
full_number
front3/back3/back2
generated supply / total_count
available/reserved/sold counts
central effective limits that affect the number
partner effective limits if a partner scope is selected
materialized stock_items for this full_number
materialized local_stock_items for this full_number
image generation fields for each materialized central/partner ticket
```

Image fields to expose where available:

```text
image_url
image_thumb_url
image_generation_status
image_generation_error
local/partner image_url
local/partner image_thumb_url
```

Important: virtual stock does not materialize every ticket in advance. For unmaterialized capacity, the detail must clearly show that no per-ticket image exists yet instead of faking rows.

### Stock Generation Filter

Filters must work through API, not browser-only filtering.

Minimum filters:

```text
game_id
full_number/number search
front3
back3
back2
status
```

For virtual stock, filter source is `base_lottery_numbers` plus virtual counters/limits. Filtering must not fall back to a single profile row when base numbers exist but the filtered page is empty.

### Tickets Sort

`Tickets` sort must mean generated supply/capacity for that full number, not lexicographic full_number fallback.

Backend Develop must make `sort_by=total_count` correct for virtual stock.

Implementation options allowed:

```text
1. Add a lightweight materialized capacity/index table per stock supply profile for query/sort only.
2. Add a database-side deterministic capacity expression that exactly matches the virtual capacity algorithm.
3. Another backend-approved approach that keeps stock_items lazy and does not bulk-create sellable ticket rows.
```

Do not solve this only in BO. Backend API order is the source of truth for sortable data tables.

### Stock Settings Default Coverage

Add central settings for default base Stock Pattern Coverage:

```text
central default:
  back2_limit
  back3_limit
  front3_limit

partner default:
  back2_limit
  back3_limit
  front3_limit
```

Recommended storage:

```text
platform_system_settings.stock_pattern_coverage_default
```

Shape:

```json
{
  "central": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner": { "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
}
```

These are defaults for forms/initial Stock Pattern Coverage values. They must not silently rewrite existing saved game/scope limits unless the user explicitly saves the coverage form.

### Partner Limit Ceiling

Backend must enforce this rule:

```text
partner effective limit <= central effective limit
```

This must apply to:

```text
partner total/default limit settings
partner per-number overrides
any API endpoint that writes partner stock_sale_limit_settings or stock_sale_limit_overrides
```

If partner value exceeds central effective value, API must return `422 validation_failed` with field errors. BO must show the central ceiling beside the field and prevent obvious invalid input, but backend remains the authority.

Central limits still must not exceed generated supply/capacity.

## Backend Develop Ownership

Backend Develop owns:

```text
stock generation list/detail API contract
virtual stock filter/sort correctness
full-number detail API and image fields
stock settings default coverage validation/storage
partner <= central validation for total limits and overrides
OpenAPI updates
backend tests
handoff with commit hash
```

Suggested API additions/changes:

```text
GET /admin/central/stock?grouped=true&sort_by=total_count&sort_dir=desc
GET /admin/central/stock/{game_id}/numbers/{full_number}
GET /admin/central/stock/settings
PATCH /admin/central/stock/settings
PUT /admin/central/stock/limit-settings
PUT /admin/central/stock/limit-overrides
```

If an existing detail route is preferred over a new route, document the chosen route in the handoff and OpenAPI.

## BO Develop Ownership

BO Develop owns:

```text
Generation progress action/detail view rendering
Stock Generation row action for full-number detail
detail modal/page showing materialized tickets and image status/URLs
filter wiring and reset behavior
Tickets sortable header using backend API sort state
Stock Settings form for central/partner coverage defaults
Stock Pattern Coverage loading defaults into empty/new forms
Partner coverage UI ceiling display and client-side guard
build/lint validation
handoff with commit hash
```

BO must not hide backend validation errors. Partner exceeding central should show the backend field error clearly.

## QA Tester Scope

QA must test real BO workflows, not just build/lint.

Required coverage:

```text
Generation progress action view opens and shows real batch details.
Stock Generation row action opens full-number detail.
Full-number detail shows virtual unmaterialized capacity and materialized ticket/image rows when present.
Stock Generation filters work for game_id, number, front3, back3, back2, and status.
Tickets sort returns correct order for virtual generated supply/capacity.
Stock Settings saves default central/partner coverage values.
Stock Pattern Coverage loads saved defaults into empty/new scope forms.
Partner coverage lower than central saves.
Partner coverage greater than central returns validation error and does not save.
Partner per-number override greater than central effective value is rejected.
Runtime restore/login smoke passes.
```

QA must use the isolated test DB for destructive setup:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

QA must not wipe runtime DB `newpaotang`.

## Acceptance

This task can return to Coordinator only when:

```text
Backend handoff exists with commit hash.
BO handoff exists with commit hash.
OpenAPI/docs are updated for any changed contract.
QA report exists and is PASS or PASS WITH RISK with explicit accepted risk.
No implementation agent leaves uncommitted scoped changes.
```

## Risks / Notes For Orchestrator

`sort_by=total_count` is the highest-risk backend item because virtual capacity is computed from profile seed and set distribution. Orchestrator should make Backend Develop solve this before BO finalizes the table behavior.

Per-number image detail must not pretend images exist for unmaterialized virtual tickets. It should expose real image fields only from actual `stock_items` / `local_stock_items`.

## Files Coordinator Updated

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-coordinator-handoff.md
docs/virtual-stock-realtime.md
ai-agents/BOARD.md
```

## Validation

Coordinator only updated docs/handoff. No implementation validation was run.

## Next Agent

Orchestrator
