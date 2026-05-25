# Customer Exact Six Duplicate Results Dev Customer Task

## Owner Agent

```text
Dev Customer
```

## Source Decision

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
```

## Execution Mode

```text
AUTO
Fallback: MANUAL if background runner is unavailable
```

## Objective

Fix the customer buy/search flow so an exact six numeric digit search preserves and renders every returned item/copy with the same `full_number`, while keeping each item selectable/reservable by its unique server identifier.

## Scope

- `apps/customer/**` only.
- Customer adapter/composable mapping for search input to `GET /api/v1/public/stock/search`.
- Customer `/buy/search` result normalization/rendering for exact six digit searches, including store-filtered search on that route.
- List keys, de-duplication, and remove/reserve identity handling for duplicate rows.
- Focused customer automated coverage for exact six digit duplicate result preservation.

## Out Of Scope

- Route redesign.
- Checkout/cart rewrite.
- Backend, OpenAPI, database, migration, schema, seed, or local runtime DB updates.
- Back-office work.
- Changing browse/random de-duplication behavior unless needed to avoid a direct regression from this task.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/file-ownership.md
```

## Agent Memory

```text
Read ai-sub-agents/memory/dev-customer/memory.md before starting.
Use memory as a hint only; source of truth remains task, docs, tests, and current code.
Update memory after completion if reusable knowledge was learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
Agent writes requested trigger final status in handoff/report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md requested DONE by AUTO runner
can_run_parallel: Yes, with ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
blocking_outputs:
- ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
- docs/openapi.yaml
- docs/customer-api-integration-map.md
- docs/buy-flow-adapter-contract.md
- docs/frontend-routes.md
unblocks:
- Orchestrator completion check after Dev Customer and Dev Backend handoffs exist
- QA task/trigger creation after Orchestrator verifies all dev outputs
```

Parallel note: Dev Backend is fixing existing API behavior under the current OpenAPI response shape. Customer code must continue to treat `meta.next_cursor` as opaque and does not need a new backend contract.

## Worktree Start Gate

```text
Read ai-sub-agents/workflow/worktree-start-gate.md.
Run the required commands before editing/testing.
Record dirty files before and after work.
Stop and send blocker if start gate fails.
```

## Ownership

Allowed:

```text
apps/customer/**
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-customer-trigger.md read-only in AUTO Mode
ai-sub-agents/memory/dev-customer/memory.md
```

Forbidden:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
database migrations
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Current Boundary Findings From Orchestrator

- `docs/openapi.yaml` defines `GET /api/v1/public/stock/search` returning `LocalStockSearchResponse.data[]` of `LocalStockItem`.
- `LocalStockItem` requires `id`, `game_id`, `full_number`, and `status`; current backend virtual resources also include `token`, `local_stock_item_id`, `stock_ref`, and `virtual_copy_index`.
- `apps/customer/composables/usePlatformApi.ts` currently maps stock items to legacy ticket shape and preserves `id` as `token` / `local_stock_item_id`.
- `apps/customer/composables/usePlatformApi.ts` currently sends `digits` as positional `d1..d6`; for all six digits filled, the adapter must send `number=<six_digits>` for the exact six digit requirement and avoid replacing it with only front/back/positional matching behavior.
- `apps/customer/pages/buy/search.vue` currently de-dupes search results through number-only identity. Exact six digit results must not collapse rows that share `full_number`.
- Verify current code before editing. These findings are routing hints, not permission to skip reading source.

## Acceptance Criteria

- When all six search digit boxes are filled with numeric digits, the outgoing public stock search includes `number=<six_digits>` as the exact six digit value.
- Partial searches with fewer than six digits continue to use the existing partial/positional behavior.
- If the API returns multiple items with the same `full_number`, exact six digit search renders every item/copy.
- Exact six digit rendering does not use `full_number` as the sole Vue list key, array key, de-dupe key, or remove/reserve identity.
- Each duplicate row keeps its own `token`, `id`, `local_stock_item_id`, or `stock_ref` for reserve actions.
- Store-filtered exact six digit search on the customer search route preserves duplicate rows and still sends `store_id` when present.
- Existing browse/random, non-exact search, loading, empty, API error, and maintenance behavior do not regress.
- No route redesign, checkout/cart rewrite, backend edit, migration, schema, seed, or local runtime DB update.

## Automated Test Requirement

```text
Dev Customer must add or update focused automated coverage for:
- exact six digit input maps to `number=<six_digits>` instead of only positional params
- duplicate results with the same `full_number` but distinct ids remain distinct
- partial search behavior remains unchanged
```

If the existing customer project has no component test harness, add or extend a lightweight script-level test under `apps/customer/scripts/**` and wire it so `npm test` exercises the new duplicate-search check. If a better existing customer test pattern is present at implementation time, use it.

## Test Env / DB Requirement

```text
Customer task should not run DB commands.
All application commands must run through Docker.
Do not wipe/reset local runtime DB newpaotang.
If any backend/data validation becomes necessary, stop and route through Orchestrator instead of running it from Dev Customer.
```

## Visible Google Chrome QA Requirement

```text
QA is required after dev handoffs.
QA must open real Google Chrome visibly to the user and prove the browser flow uses test env/test DB before clean PASS.
```

## QA Browser Environment

```text
browser URL: QA to provide, expected customer /buy/search or current equivalent
frontend service: customer
API base URL: platform-api test API
APP_ENV: testing
DB_DATABASE: newpaotang_test
tenant/domain: QA to use a seeded test tenant with duplicate exact-six stock
account/role: customer or guest, according to current buy/search behavior
test data fixture: same 6-digit full_number with at least two available visible copies; include over-limit fixture if backend handoff provides it
evidence path: ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: No
DB update required after Coordinator approval: No
```

## Suggested Validation Commands

```sh
docker compose -p newpaotang exec -T customer npm test
docker compose -p newpaotang exec -T customer npm run build
```

Run the focused command(s) appropriate to the implementation. Do not run Nuxt/npm directly on the host.

## Expected Handoff

```text
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
```

Handoff must include:

```text
worktree evidence
trigger evidence
files changed
automated tests added/updated
validation commands and results
test env / DB safety
shared lock status
memory update evidence
requested final trigger status: DONE or BLOCKED
Next Agent: Orchestrator
```

## Next Agent

```text
Orchestrator
```
