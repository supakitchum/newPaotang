# allocation-partner-percent-workflow-bo Handoff

## Agent

BO Develop

## Task

`allocation-partner-percent-workflow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
start HEAD: 22b752c5f6176de23da22cd6e5b4ea35fedd3730
implementation commit: 975d245848cadcec56bb95bfeb405d998cf54bdd
```

## What Was Done

- Reworked the central Allocations catalog to use backend allocation option sources instead of raw Partner ID, Tenant ID, and Game ID inputs.
- Added allocation partner, tenant, and game option-source loading from:
  - `GET /admin/central/allocation-options/partners`
  - `GET /admin/central/allocation-options/tenants`
  - `GET /admin/central/allocation-options/games`
- Added dependent partner -> tenant behavior in generic BO filters and action forms.
- Added single active tenant auto-fill and locked tenant select behavior in action forms.
- Added multi-tenant validation requiring explicit tenant selection.
- Added no-active-tenant client-side blocking message; backend validation still remains source of truth.
- Removed `requested_count` from the create allocation form and replaced it with `allocation_percent`.
- Added allocation percent preview using game generated supply metadata and selected percent.
- Updated allocation list columns to show partner, tenant, and game display names with allocation percent, active partner percent, allocated count, remaining count, recalled count, and status.
- Added allocation row actions:
  - Stock coverage route to `/admin/central/stock-pattern-coverage?game_id={game_id}&scope_type=partner&scope_id={partner_id}`
  - Remaining stock route to `/admin/central/stock-generation?game_id={game_id}&partner_id={partner_id}&tenant_id={tenant_id}&allocation_id={id}&status=allocated`
  - Recall all via `POST /admin/central/allocations/{allocation_id}/recall-all`
  - Redistribute via `POST /admin/central/allocations/{allocation_id}/redistribute`, disabled until `status=recalled`
  - Existing cancel action retained
- Added Partners table stock percent column fallback and central-only edit action using `PUT /admin/central/allocations/partner-percent`.
- Added client convenience validation for allocation percent > 0 and <= 100 while surfacing backend errors for active partner total > 100 and usage-protection rejection.
- Updated Stock Pattern Coverage to seed game/scope filters from query params used by allocation actions.
- Updated BO structural snapshot/check evidence for allocation percent workflow endpoints and UI wiring.

## Files Changed

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockPatternCoverage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

## Backend Routes / Contracts Consumed

```text
GET /admin/central/allocation-options/partners
GET /admin/central/allocation-options/tenants
GET /admin/central/allocation-options/games
GET /admin/central/allocations
POST /admin/central/allocations
GET /admin/central/allocations/{allocation_id}
POST /admin/central/allocations/{allocation_id}/recall-all
POST /admin/central/allocations/{allocation_id}/redistribute
POST /admin/central/allocations/{allocation_id}/cancel
PUT /admin/central/allocations/partner-percent
```

Create allocation now submits:

```json
{
  "partner_id": "par_x",
  "tenant_id": "ten_x",
  "game_id": "gam_x",
  "allocation_percent": 25,
  "reason": "operator reason"
}
```

`requested_count` is no longer present in the BO create allocation form fields.

## UI Behavior Evidence

- Allocation filters use option-backed selects for partner, tenant, and game.
- Tenant options are filtered by selected partner in both filters and action forms.
- Single-tenant partners auto-fill `tenant_id` and lock the tenant select.
- Multi-tenant partners keep tenant editable and block submit until a tenant is selected.
- No-active-tenant partners block submit with `The selected partner has no active tenant.`
- Allocation percent preview shows estimated generated supply, selected percent, estimated allocation count, existing partner percent when option metadata exposes it, and existing remaining count when record context exposes it.
- Allocation row detail/context uses partner/tenant/game display fields and percent/count fields.
- Stock coverage action opens the partner/game-scoped Stock Pattern Coverage view through query params.
- Remaining stock action opens the Stock Generation alias with game, partner, tenant, allocation, and allocated status query params.
- Recall-all and redistribute use existing idempotency-key action flow and reason modal.
- Redistribute button is disabled unless backend row status is `recalled`.
- Partners workflow exposes Edit stock percent action and sends partner/game/tenant/percent to backend.
- Backend validation messages for `allocation_percent` are surfaced through existing `AdminApiState`.

## Validation

All application commands were run through Docker service `back-office`.

```sh
git diff --check
```

Result: passed.

```sh
docker compose -p newpaotang build back-office
```

Result: passed.

```sh
docker compose -p newpaotang run --rm back-office npm run lint
```

Result: passed.

```sh
docker compose -p newpaotang run --rm back-office npm run test
```

Result: passed.

```sh
docker compose -p newpaotang run --rm back-office npm run build
```

Result: passed. Nuxt emitted a non-blocking Node deprecation warning for `fs.Stats constructor`.

Non-mutating HTTP smoke after `docker compose -p newpaotang up -d back-office`:

```text
GET http://localhost:3100/login -> 200 OK
GET http://localhost:3100/admin/central/allocations -> 302 /login?redirect=/admin/central/allocations
GET http://localhost:3100/admin/central/stock-pattern-coverage?game_id=gam_percent&scope_type=partner&scope_id=par_percent_a -> 302 /login?redirect=...
```

Browser automation tool was not exposed in this session after tool discovery, so manual visual browser validation was not performed.

## Unrelated Dirty Files Left Untouched

```text
apps/platform-api/.phpunit.result.cache
```

This was the known backend validation artifact from the task prompt and was not staged or committed.

## Known Risks

- The Partners list API does not currently return stock percent fields for every partner. BO shows the Stock % column when backend data exists and always exposes the edit action to load/update percent context.
- Remaining stock action reuses the existing Stock Generation/Master Stock route with partner, tenant, allocation, game, and allocated status query params. It depends on backend stock listing support for those filters where data is materialized.
- Browser-level authenticated workflow QA remains for QA Tester.

## Questions For Coordinator

None.

## Next Agent

Orchestrator
