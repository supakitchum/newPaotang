# Customer Exact Six Duplicate Results Dev Backend Task

## Owner Agent

```text
Dev Backend
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

Ensure `GET /api/v1/public/stock/search?number=<six_digits>` can return every available virtual copy for the same exact `full_number`, including copy-aware pagination when the duplicate copy count exceeds `limit`, while preserving stable unique reservation identifiers.

## Why Backend Is In Scope

Orchestrator found that the current backend virtual stock search already returns row-level virtual copy resources with stable `id`, `token`, `local_stock_item_id`, `stock_ref`, and `virtual_copy_index`. However, the exact six digit branch appears to paginate by candidate full number only, not by duplicate copy index. When one exact `full_number` has more available copies than `limit`, `meta.next_cursor` may not advance through the remaining copies correctly. The Coordinator acceptance criteria require pagination/cursor behavior to continue working when exact six digit duplicate copies exceed the page limit.

## Scope

- `apps/platform-api/**` only.
- Public tenant stock search behavior under the existing OpenAPI contract.
- Exact six numeric digit `number` query for virtual stock copies.
- Cursor/pagination behavior for duplicate copies of one full number.
- Focused backend feature tests.

## Out Of Scope

- New endpoint or route changes.
- OpenAPI/docs changes unless implementation proves the existing contract is insufficient. If a contract change is required, stop and report BLOCKED to Orchestrator/Coordinator.
- Migration/schema/seed changes.
- Local runtime DB update.
- Customer frontend or back-office code.
- Reintroducing physical stock search behavior.

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
Read ai-sub-agents/memory/dev-backend/memory.md before starting.
Use memory as a hint only; source of truth remains task, docs, tests, and current code.
Update memory after completion if reusable knowledge was learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
Agent writes requested trigger final status in handoff/report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md requested DONE by AUTO runner
can_run_parallel: Yes, with ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
blocking_outputs:
- ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/virtual-stock-realtime.md
unblocks:
- Orchestrator completion check after Dev Backend and Dev Customer handoffs exist
- QA task/trigger creation after Orchestrator verifies all dev outputs
```

Parallel note: Keep the API response shape stable. Dev Customer consumes `meta.next_cursor` opaquely and does not need a new contract if this remains an existing-behavior fix.

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
apps/platform-api/**
ai-sub-agents/handoffs/**
ai-sub-agents/triggers/*dev-backend-trigger.md read-only in AUTO Mode
ai-sub-agents/memory/dev-backend/memory.md
```

Forbidden:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml unless a blocker proves contract work is required and Coordinator approves
database migrations unless Coordinator issues a new decision
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Current Boundary Findings From Orchestrator

- `docs/openapi.yaml` defines `/public/stock/search` with `number`, `cursor`, and `limit`, returning `LocalStockSearchResponse`.
- `LocalStockItem` requires `id`, `game_id`, `full_number`, and `status`.
- `docs/virtual-stock-realtime.md` says stable virtual stock refs use a monotonically expanding full-number copy index.
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php` currently builds virtual rows per copy and includes `virtual_copy_index`.
- The exact six digit candidate branch yields the one full number, then `searchLocalStock` iterates copy indexes. Verify whether pagination resumes by copy index when `count(copyIndexes) > limit`. If not, fix within the existing opaque cursor contract.
- Verify current code before editing. These findings are routing hints, not permission to skip reading source.

## Acceptance Criteria

- Exact six numeric `number=<six_digits>` search returns multiple available copies with the same `full_number` when virtual availability has multiple copies.
- Each returned duplicate has a stable unique identity suitable for reservation: `id` plus current compatibility fields such as `token`, `local_stock_item_id`, `stock_ref`, and `virtual_copy_index`.
- If duplicate copies for one exact `full_number` exceed `limit`, pagination progresses through distinct remaining copies and eventually ends with `has_more=false`.
- No duplicate `id` values are repeated across exact-six pages for the same query unless stock state changed between requests.
- Existing partial searches, positional searches, browse/random, store-filtered search, maintenance response behavior, and physical-stock retirement behavior do not regress.
- No migration, schema, seed, local runtime DB update, customer frontend edit, or back-office edit.

## Automated Test Requirement

```text
Dev Backend must add/update focused tests under apps/platform-api/tests, preferably PublicStockSearchTest.
```

Minimum cases:

```text
- exact six digit virtual search returns at least two rows with the same full_number and distinct ids
- exact six digit virtual search with limit below available copy count returns page 1 and page 2 with distinct ids and a terminating cursor
- regression guard that short/partial search and random/browse behavior covered by existing tests still pass
```

## Test Env / DB Requirement

```text
All backend tests must run with APP_ENV=testing and DB_DATABASE=newpaotang_test.
Do not run destructive commands against local runtime DB newpaotang.
Do not run migrate:fresh/refresh/reset/db:wipe unless explicitly using APP_ENV=testing and DB_DATABASE=newpaotang_test.
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
test data fixture: same 6-digit full_number with more available copies than the search page limit when possible
evidence path: ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: No expected. Existing API behavior under current contract only.
DB update required after Coordinator approval: No
```

If implementation proves a schema, seed, migration, or OpenAPI contract change is required, stop and report BLOCKED in the handoff instead of expanding scope.

## Suggested Validation Commands

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=PublicStockSearchTest --env=testing
```

Add broader backend tests only if the implementation touches shared service behavior beyond public stock search. Do not run PHP/Artisan directly on the host.

## Expected Handoff

```text
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
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
