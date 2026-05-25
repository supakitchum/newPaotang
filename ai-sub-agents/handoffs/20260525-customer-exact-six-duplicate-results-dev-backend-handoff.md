# Customer Exact Six Duplicate Results Dev Backend Handoff

## Agent

```text
Dev Backend
```

## Task

```text
Implement backend exact six digit public virtual stock search duplicate-copy behavior with copy-aware pagination under the existing API contract.
```

## Worktree Evidence

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop...origin/develop
HEAD: d962763677594a14876b7d32173442f2843e181b
origin/develop: d962763677594a14876b7d32173442f2843e181b
completed_at: 2026-05-25T22:25:58+0700
```

Worktree start gate commands run before editing/testing:

```text
pwd -> /Users/supakit/WorkSpace/www/newPaotang
git fetch origin -> success
git status --short --branch -> success, dirty files recorded
git merge --ff-only origin/develop -> success, Already up to date.
git status --short -> success, dirty files recorded
git rev-parse HEAD -> d962763677594a14876b7d32173442f2843e181b
git rev-parse origin/develop -> d962763677594a14876b7d32173442f2843e181b
```

Dirty files before Dev Backend work:

```text
 M ai-sub-agents/flow-ai-agent.md
 M ai-sub-agents/memory/coordinator/memory.md
 M ai-sub-agents/memory/orchestrator/memory.md
 M ai-sub-agents/roles/coordinator.md
 M ai-sub-agents/runner/README.md
 M ai-sub-agents/templates/trigger-template.md
 M ai-sub-agents/workflow/background-runner.md
 M ai-sub-agents/workflow/execution-mode.md
?? ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
?? ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.claim.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.claim.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-dev-backend-runner-log.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-dev-customer-runner-log.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-orchestrator-runner-log.md
?? ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md
?? ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
?? ai-sub-agents/templates/codex-spawn-prompt-template.md
?? ai-sub-agents/templates/coordinator-runner-prompt.md
?? ai-sub-agents/templates/runner-log-template.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md
?? ai-sub-agents/workflow/codex-native-runner.md
```

Start-gate classification:

```text
No dirty files existed under apps/platform-api/** before Dev Backend edits.
Pre-existing dirty files were Coordinator/Orchestrator/runner control-plane files and task/trigger inputs.
Dev Backend did not revert or edit unrelated pre-existing dirty files.
```

Dirty files after Dev Backend work:

```text
 M ai-sub-agents/flow-ai-agent.md
 M ai-sub-agents/memory/coordinator/memory.md
 M ai-sub-agents/memory/dev-backend/memory.md
 M ai-sub-agents/memory/dev-customer/memory.md
 M ai-sub-agents/memory/orchestrator/memory.md
 M ai-sub-agents/roles/coordinator.md
 M ai-sub-agents/runner/README.md
 M ai-sub-agents/templates/trigger-template.md
 M ai-sub-agents/workflow/background-runner.md
 M ai-sub-agents/workflow/execution-mode.md
 M apps/customer/composables/usePlatformApi.ts
 M apps/customer/package.json
 M apps/customer/pages/buy/search.vue
 M apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
 M apps/platform-api/tests/Feature/PublicStockSearchTest.php
?? ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
?? ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
?? ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
?? ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.claim.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.claim.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.heartbeat.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-dev-backend-runner-log.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-dev-customer-runner-log.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-orchestrator-runner-log.md
?? ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md
?? ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
?? ai-sub-agents/templates/codex-spawn-prompt-template.md
?? ai-sub-agents/templates/coordinator-runner-prompt.md
?? ai-sub-agents/templates/runner-log-template.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md
?? ai-sub-agents/workflow/codex-native-runner.md
?? apps/customer/scripts/check-exact-six-search-identity.mjs
?? apps/customer/utils/stockSearchIdentity.js
```

After-work classification:

```text
Dev Backend changed only:
- apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
- apps/platform-api/tests/Feature/PublicStockSearchTest.php
- ai-sub-agents/memory/dev-backend/memory.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md

apps/customer/** and ai-sub-agents/memory/dev-customer/memory.md appeared/changed from the parallel Dev Customer task and were not touched by Dev Backend.
apps/platform-api/.phpunit.result.cache was generated by the test run and restored to avoid cache churn.
```

## Trigger Evidence

```text
trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
trigger status read before work: RUNNING
trigger status owner: AUTO Mode runner
trigger status edited by Dev Backend: No
runner claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.claim.md
claim runner_id: codex-native-runner-coordinator-20260525T221358+0700
claim status at claim time: PENDING
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.heartbeat.md
heartbeat last_heartbeat_at read: 2026-05-25T22:23:25+0700
requested final trigger status: DONE
```

## Implementation Summary

- Updated `VirtualStockService::searchLocalStock` so non-random public virtual stock search uses the existing opaque copy-aware cursor shape `{number_offset, copy_offset}`.
- Exact six digit `number=<six_digits>` now pages through duplicate virtual copies of the same `full_number` instead of repeating the first copies when `limit` is below available copy count.
- Random mode remains on its existing random/interleaving path to avoid changing random browse ordering.
- Exact full-number candidate generation now treats positive number offsets as past the one exact candidate, preventing stale numeric exact cursors from repeating the same number.
- No OpenAPI/schema/migration/seed changes were made.

## Files Changed By Dev Backend

```text
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
ai-sub-agents/memory/dev-backend/memory.md
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
```

## Automated Tests Added Or Updated

Updated:

```text
apps/platform-api/tests/Feature/PublicStockSearchTest.php
```

Added focused cases:

```text
test_PublicStockSearch_exact_six_virtual_search_returns_duplicate_copies_with_unique_reservation_ids
test_PublicStockSearch_exact_six_virtual_search_paginates_duplicate_copies_by_copy_index
```

Coverage:

```text
- exact six virtual search returns three rows with the same full_number
- duplicate rows keep distinct stable ids/tokens/local_stock_item_ids/stock_refs
- virtual_copy_index is stable per copy
- limit below duplicate count returns page 1, page 2, no repeated ids, and terminating has_more=false
- existing PublicStockSearchTest partial/random/positional/maintenance/retired-physical cases still pass
```

## Validation Evidence

Formatting/diff check:

```sh
git diff --check -- apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php apps/platform-api/tests/Feature/PublicStockSearchTest.php ai-sub-agents/memory/dev-backend/memory.md
```

Result:

```text
PASS, no whitespace errors.
```

Focused backend validation:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=PublicStockSearchTest --env=testing
```

Result:

```text
PASS Tests\Feature\PublicStockSearchTest
13 passed, 158 assertions, duration 2.92s
```

Adjacent backend regression slice:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter='VirtualStockRealtimeTest|CustomerReservationTest|TenantStockTest' --env=testing
```

Result:

```text
CustomerReservationTest: PASS, 2 tests
TenantStockTest: PASS, 3 tests
VirtualStockRealtimeTest: 6 passed, 1 failed
Overall: 1 failed, 11 passed, 336 assertions
```

Failure detail:

```text
Tests\Feature\VirtualStockRealtimeTest::test_central_stock_virtual_grouped_total_count_sort_and_full_number_detail
Expected: https://cdn.example.test/central/123456.png
Actual:   http://cdn.example.test/central/123456.png
Location: apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php:730
```

Standalone confirmation of adjacent failure:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=test_central_stock_virtual_grouped_total_count_sort_and_full_number_detail --env=testing
```

Result:

```text
FAIL with the same https/http image URL assertion.
```

Assessment:

```text
The failing adjacent VirtualStockRealtimeTest assertion is in central stock image URL normalization, outside the touched public stock search code path. It reproduces standalone and is recorded for Orchestrator/QA awareness. The required focused PublicStockSearchTest validation for this task passes.
```

## Test Env / DB Safety Evidence

```text
All app validation commands used Docker.
All backend tests were run with APP_ENV=testing and DB_DATABASE=newpaotang_test.
No migrate:fresh, migrate:refresh, migrate:reset, db:wipe, seed, or destructive DB command was run.
No migration/schema/seed/OpenAPI contract change was made.
Local runtime DB newpaotang was not wiped/reset/refreshed.
DB update required after Coordinator approval: No.
```

Docker service evidence:

```text
docker compose -p newpaotang ps platform-api -> platform-api service Up, mapped to 0.0.0.0:8000
```

## Shared File Locks

```text
Lock required: No
Lock file: None
Shared files edited: None
```

## Memory Update Evidence

```text
memory file: ai-sub-agents/memory/dev-backend/memory.md
updated: Yes
line count after update: 39
added reusable notes:
- VirtualStockService copy-aware cursor shape `{number_offset, copy_offset}`.
- Exact-six public virtual stock search must paginate duplicate copies by copy_offset.
```

## Requested Final Trigger Status

```text
DONE
```

## Next Agent

```text
Orchestrator
```
