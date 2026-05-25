# Customer Exact Six Duplicate Results Dev Customer Handoff

## Agent

```text
Dev Customer
```

## Task

```text
Implement customer exact six digit search mapping/rendering so duplicate rows with the same full_number are preserved with distinct item identity.
```

## Worktree Evidence

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
git top-level: /Users/supakit/WorkSpace/www/newPaotang
branch: develop...origin/develop
HEAD: d962763677594a14876b7d32173442f2843e181b
origin/develop: d962763677594a14876b7d32173442f2843e181b
```

Worktree start gate commands run:

```text
git fetch origin -> success
git status --short --branch -> success, dirty files recorded
git merge --ff-only origin/develop -> success, Already up to date.
git status --short -> success, dirty files recorded
git rev-parse HEAD -> d962763677594a14876b7d32173442f2843e181b
git rev-parse origin/develop -> d962763677594a14876b7d32173442f2843e181b
git rev-parse --show-toplevel -> /Users/supakit/WorkSpace/www/newPaotang
```

Dirty files before Dev Customer work:

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

Classification:

```text
No apps/customer/** files were dirty before Dev Customer work.
Pre-existing dirty files were Coordinator/Orchestrator/runner/task/trigger control-plane files.
Dev Backend may work in parallel under apps/platform-api/**; any backend dirt after this point is unrelated and was not touched by Dev Customer.
```

## Trigger Evidence

```text
trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
trigger status before work: RUNNING
trigger status after work: RUNNING, unchanged by Dev Customer
trigger status owner: AUTO Mode runner
requested final status: DONE
runner claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.claim.md
claim runner_id: codex-native-runner-coordinator-20260525T221358+0700
claim status at claim time: PENDING
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.heartbeat.md
heartbeat last_heartbeat_at observed: 2026-05-25T22:23:25+0700
runner log dependency check: PASS
```

## Source Of Truth Read

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/roles/dev-customer.md
ai-sub-agents/memory/dev-customer/memory.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
```

Relevant source-of-truth evidence:

```text
docs/openapi.yaml defines GET /public/stock/search query params including number, store_id, cursor, limit and returns LocalStockSearchResponse.data[] of LocalStockItem.
LocalStockItem requires id, game_id, full_number, and status.
docs/customer-api-integration-map.md maps LocalStockItem.id -> existing ticket.token and LocalStockItem.full_number -> ticket.number/full_number.
docs/buy-flow-adapter-contract.md allows adapter-derived filters while preserving existing flow.
docs/frontend-routes.md requires search cache not decide availability and reserve actions confirm with server.
```

## Implementation Summary

```text
Added apps/customer/utils/stockSearchIdentity.js with shared exact-six search param and result identity helpers.
Updated apps/customer/composables/usePlatformApi.ts so six filled digit boxes send number=<six_digits> and store_id when present.
Kept partial digit searches on existing positional d1..d6 behavior.
Updated apps/customer/pages/buy/search.vue so exact-six results preserve duplicate full_number rows when identities differ.
Changed exact-six result merge, list key, and booking-unavailable removal to prefer unique server item identity: token, local_stock_item_id, stock_ref, id.
Kept non-exact search de-duplication by number to avoid browse/partial behavior churn.
```

## Files Changed

Customer implementation/test files:

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/pages/buy/search.vue
apps/customer/utils/stockSearchIdentity.js
apps/customer/scripts/check-exact-six-search-identity.mjs
apps/customer/package.json
```

Agent communication/memory files:

```text
ai-sub-agents/memory/dev-customer/memory.md
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
```

Files intentionally not touched:

```text
apps/platform-api/**
apps/back-office/**
docs/**
database migrations
trigger status fields
```

## Automated Tests Added Or Updated

```text
Added apps/customer/scripts/check-exact-six-search-identity.mjs.
Updated apps/customer/package.json so npm test runs the existing tenant-domain integration check and the new exact-six duplicate identity check.
```

Focused coverage:

```text
exact six digit input maps to number=<six_digits> and does not send d1..d6
store-filtered exact-six mapping preserves store_id
partial digit search remains positional d1/d3/d5 without number
duplicate rows sharing full_number remain distinct when item identities differ
non-exact merge still collapses same-number rows
```

## Validation Evidence

Docker-only customer validation:

```text
docker compose -p newpaotang exec -T customer npm test -> PASS
docker compose -p newpaotang exec -T customer npm run build -> PASS
```

Observed focused test output:

```text
PASS exact six stock search params and duplicate row identity checks
```

Build evidence:

```text
Nuxt 3.11.2 / Nitro 2.9.6 production build completed successfully.
Client built successfully.
Server built successfully.
Nitro server built successfully.
```

Browser QA:

```text
Not performed by Dev Customer.
Per task, visible Google Chrome QA remains for QA Tester after Orchestrator completion check.
```

## Test Env / DB Safety

```text
Customer task ran no DB commands.
No migrations, seeders, wipes, refreshes, resets, or runtime DB updates were run.
Local runtime DB newpaotang was not touched.
Validation used Docker customer service only.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Status: No shared lock used or required by task.
```

## Memory Update Evidence

```text
Updated ai-sub-agents/memory/dev-customer/memory.md lines 36-37 with reusable exact-six search helper/test pattern.
Memory remains short and cache-only.
```

## Dirty Files After Work

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

## Risks / Notes For Orchestrator

```text
Dev Customer changes depend on server responses preserving stable row identity per duplicate item/copy.
apps/platform-api/** dirty files appeared after Dev Customer start gate and are treated as parallel Dev Backend work, not Dev Customer work.
```

## Requested Final Trigger Status

```text
DONE
```

## Next Agent

```text
Orchestrator
```
