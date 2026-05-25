# Customer Exact Six Duplicate Results QA Tester Task

## Owner Agent

```text
QA Tester
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

Validate that exact six digit customer stock search displays every duplicate/copy with the same `full_number`, preserves a unique reservation identity per row, and that backend public stock search paginates duplicate virtual copies without repeating ids.

## Scope

- Customer `/buy/search` or the current equivalent customer search route.
- Exact six digit stock search behavior, including duplicate display for the same `full_number`.
- Store-filtered exact six digit search when the current route supports store context.
- Backend `GET /api/v1/public/stock/search?number=<six_digits>` duplicate-copy behavior and cursor pagination.
- Test env/test DB proof before any clean PASS.
- Visible Google Chrome browser acceptance evidence.

## Out Of Scope

- Fixing implementation defects.
- Editing implementation code or tests.
- Updating local runtime DB `newpaotang`.
- Git staging, commit, or push.
- Back-office UI QA except for awareness of the unrelated VirtualStockRealtimeTest risk note below.

## Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/roles/qa-tester.md
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
```

Required handoffs to read:

```text
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-ready-for-qa-handoff.md
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
```

## Agent Memory

```text
Read ai-sub-agents/memory/qa-tester/memory.md before starting.
Use memory as a hint only; source of truth remains task, docs, handoffs, tests, and current behavior.
Update memory after completion if reusable QA data, Chrome evidence pattern, or test DB wiring notes were learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
QA Tester writes requested trigger final status in QA report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md status DONE
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md status DONE
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-ready-for-qa-handoff.md
can_run_parallel: No
blocking_outputs:
- this QA task
- QA trigger
- both dev handoffs
- Orchestrator ready-for-QA handoff
- source-of-truth docs listed above
unblocks:
- Coordinator QA review after QA report exists
```

## Worktree Start Gate

```text
Read ai-sub-agents/workflow/worktree-start-gate.md.
Run the required start gate before QA work.
Record dirty files before and after QA.
Stop and report BLOCKED if the start gate fails.
```

## Ownership

Allowed:

```text
ai-sub-agents/reports/**
ai-sub-agents/handoffs/*qa*.md
ai-sub-agents/memory/qa-tester/memory.md
```

Forbidden:

```text
apps/**
docs/openapi.yaml
database migrations
ai-sub-agents/triggers/*qa-tester-trigger.md status edits in AUTO Mode
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
Release evidence: Not applicable. Dev handoffs and Orchestrator completion check declare no shared locks required.
```

## Acceptance Criteria

- Exact six digit customer search sends/uses the full six digit number as an exact `number=<six_digits>` query behavior, not only positional/partial matching.
- If multiple API results share the same `full_number`, the customer UI displays every returned item/copy.
- Duplicate rows do not collapse because of `full_number` only list keys, grouping, maps, or normalization.
- Each displayed duplicate preserves a unique reservation identity such as `id`, `token`, `local_stock_item_id`, or `stock_ref`.
- Backend exact six API results return duplicate virtual copies with distinct ids for the same `full_number`.
- Backend exact six cursor pagination with `limit` below available duplicate count advances to remaining copies without repeating ids and eventually returns `has_more=false`.
- Existing partial search, browse/random, loading, empty, API error, and `maintenance_active` behavior do not show obvious regressions in the tested path.
- QA report proves browser testing was connected to test env/test DB before clean PASS.
- QA report includes visible Google Chrome evidence.

## Required QA Scenarios

1. Test env/test DB proof:
   - Record `APP_ENV=testing`.
   - Record `DB_DATABASE=newpaotang_test`.
   - Record API base URL and frontend customer URL.
   - Prove the browser flow talks to the intended test API/test DB using config, network request evidence, or test data unique to `newpaotang_test`.

2. Backend API duplicate search:
   - Use a test fixture where one exact six digit `full_number` has at least two available visible copies.
   - Call `GET /api/v1/public/stock/search?game_id=<test_game>&number=<six_digits>&limit=<small>` against the test API.
   - Verify response `data[]` includes duplicate rows with the same `full_number` and distinct `id` values.
   - Verify `meta.next_cursor`/`has_more` behavior by fetching the next cursor when duplicate count exceeds `limit`.
   - Verify ids are not repeated across pages unless test stock state changed during the test.

3. Customer visible Chrome behavior:
   - Open real Google Chrome visibly to the user.
   - Navigate to customer `/buy/search` or current equivalent route in the test environment.
   - Search the same exact six digit fixture.
   - Confirm every duplicate/copy visible from the API result appears in the UI.
   - Confirm row selection/reserve affordance targets unique item identity, not `full_number` alone.
   - Capture screenshot or screen recording under the evidence path.

4. Regression spot checks:
   - Partial search with fewer than six digits still behaves as partial/positional search.
   - Browse/random search route still renders a usable list.
   - Empty, loading, API error, or maintenance state is not obviously broken if fixture/supporting controls exist.

## Validation Evidence From Dev Handoffs

Dev Customer:

```text
docker compose -p newpaotang exec -T customer npm test -> PASS
docker compose -p newpaotang exec -T customer npm run build -> PASS
Focused output: PASS exact six stock search params and duplicate row identity checks
```

Dev Backend:

```text
git diff --check -- apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php apps/platform-api/tests/Feature/PublicStockSearchTest.php ai-sub-agents/memory/dev-backend/memory.md -> PASS
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=PublicStockSearchTest --env=testing -> PASS, 13 passed, 158 assertions
```

## Risk Notes For QA Awareness

Adjacent backend regression slice from Dev Backend handoff:

```text
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter='VirtualStockRealtimeTest|CustomerReservationTest|TenantStockTest' --env=testing
Result: CustomerReservationTest PASS, TenantStockTest PASS, VirtualStockRealtimeTest 6 passed / 1 failed.
Failure: Tests\Feature\VirtualStockRealtimeTest::test_central_stock_virtual_grouped_total_count_sort_and_full_number_detail
Expected: https://cdn.example.test/central/123456.png
Actual:   http://cdn.example.test/central/123456.png
Location: apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php:730
Standalone rerun reproduced the same https/http image URL assertion.
Dev Backend assessment: outside the touched public stock search path and recorded as an unrelated risk.
```

QA should carry this risk into the QA report. Do not treat it as cleanly resolved by the exact-six validation. If QA observes image URL or central stock detail behavior connected to the customer exact-six flow, report `FAIL` or `PASS WITH RISK` with evidence.

## Test Env / DB Requirement

```text
All QA validation must run on test env/test DB first.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for backend/data commands.
Do not wipe/reset local runtime DB newpaotang.
Do not update local runtime DB.
Destructive test DB commands are allowed only if explicitly targeted to APP_ENV=testing and DB_DATABASE=newpaotang_test and recorded in the QA report.
```

## Visible Google Chrome QA Requirement

```text
Google Chrome app must be visible to the user.
Headless browser evidence is not sufficient for browser acceptance.
QA must record Chrome visible: Yes, URL, account/role, tenant/domain, test data fixture, API base URL, APP_ENV, DB_DATABASE, and evidence path.
If visible Chrome cannot be used, report BLOCKED.
If test env/test DB wiring cannot be proven, report BLOCKED or PASS WITH RISK; never clean PASS.
```

## QA Browser Environment

```text
browser URL: QA to record; expected customer /buy/search or current equivalent in test environment
frontend service: customer
API base URL: QA to record; platform-api test API
APP_ENV: testing
DB_DATABASE: newpaotang_test
tenant/domain: QA to record; must be a tenant/domain wired to test data
account/role: customer or guest according to current buy/search behavior
test data fixture: exact six digit full_number with multiple visible available copies; over-limit duplicate fixture preferred for cursor proof
expected evidence path: ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: No.
DB update required after Coordinator approval: No expected.
Reason: Dev handoffs declare no migration/schema/seed/OpenAPI contract change.
```

## Suggested Validation Commands

Use Docker only. Adjust filters or URLs to the actual test fixture.

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=PublicStockSearchTest --env=testing
docker compose -p newpaotang exec -T customer npm test
```

For backend API manual checks, use the test API base URL and record the exact request/response evidence in the QA report. Do not run PHP, Artisan, Node, npm, Nuxt, or Vite directly on the host.

## Expected QA Report

```text
ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md
```

Report must include:

```text
worktree evidence
trigger evidence
test env/test DB evidence
commands run and results
backend API duplicate pagination evidence
visible Google Chrome evidence
scenario-by-scenario result
VirtualStockRealtimeTest https/http risk note disposition
runtime DB safety
memory update evidence
recommendation: PASS, FAIL, PASS WITH RISK, or BLOCKED
Next Agent: Coordinator
```

## Next Agent

```text
Coordinator
```
