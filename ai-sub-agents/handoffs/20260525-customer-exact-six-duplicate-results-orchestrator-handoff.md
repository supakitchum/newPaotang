# Customer Exact Six Duplicate Results Orchestrator Handoff

## Agent

```text
Orchestrator
```

## Task

```text
Break down Coordinator decision for customer exact six-digit duplicate search results.
Create downstream dev task prompt(s) and trigger(s).
Requested output: ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
```

## Worktree / HEAD

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

Dirty files before Orchestrator work:

```text
 M ai-sub-agents/flow-ai-agent.md
 M ai-sub-agents/memory/coordinator/memory.md
 M ai-sub-agents/roles/coordinator.md
 M ai-sub-agents/runner/README.md
 M ai-sub-agents/templates/trigger-template.md
 M ai-sub-agents/workflow/background-runner.md
 M ai-sub-agents/workflow/execution-mode.md
?? ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
?? ai-sub-agents/runner/logs/20260525-customer-exact-six-duplicate-results-orchestrator-runner-log.md
?? ai-sub-agents/templates/codex-spawn-prompt-template.md
?? ai-sub-agents/templates/coordinator-runner-prompt.md
?? ai-sub-agents/templates/runner-log-template.md
?? ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md
?? ai-sub-agents/workflow/codex-native-runner.md
```

Classification:

```text
Pre-existing dirty files were runner/control-plane, Coordinator, decision, and trigger inputs.
Orchestrator read required dirty inputs but did not revert or edit unrelated dirty files.
Orchestrator edited only ai-sub-agents/tasks/**, ai-sub-agents/triggers/*dev-*-trigger.md, ai-sub-agents/handoffs/**, and ai-sub-agents/memory/orchestrator/memory.md.
No apps/** implementation files were edited.
```

Dirty files after Orchestrator work:

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
?? ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
?? ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
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

## Trigger Status

Orchestrator trigger:

```text
trigger file: ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.md
trigger status before work: RUNNING
trigger status after work: RUNNING, unchanged by Orchestrator
trigger status owner: AUTO Mode runner
requested final status: DONE
runner claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
```

Downstream triggers created:

```text
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
status: PENDING
target agent: Dev Customer
can_run_parallel: Yes, with Dev Backend
expected handoff: ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md

ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
status: PENDING
target agent: Dev Backend
can_run_parallel: Yes, with Dev Customer
expected handoff: ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
```

## What Was Done

- Read required Orchestrator control docs in the requested order, including the Coordinator decision twice.
- Ran the worktree start gate before task breakdown work; start gate passed.
- Read source-of-truth docs named by the decision and trigger:
  - `docs/openapi.yaml`
  - `docs/api-conventions.md`
  - `docs/customer-api-integration-map.md`
  - `docs/buy-flow-adapter-contract.md`
  - `docs/frontend-routes.md`
  - `docs/virtual-stock-realtime.md`
- Investigated current ownership boundaries without editing implementation files.
- Determined Dev Customer is required for adapter/rendering de-duplication and exact-six request mapping.
- Determined Dev Backend is also required because exact-six virtual duplicate copy pagination appears to need copy-aware cursor behavior under the existing API contract.
- Created downstream Dev Customer and Dev Backend task prompts.
- Created downstream Dev Customer and Dev Backend AUTO triggers with dependency graph fields.
- Declared no shared file lock requirement because the tasks edit disjoint ownership areas: `apps/customer/**` and `apps/platform-api/**`.
- Did not create QA task/trigger yet. Per Gate 3, QA is created only after all assigned dev-agent triggers are DONE, handoffs exist, and locks are released or not required.

## Files Changed

Created:

```text
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md
ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
```

Updated:

```text
ai-sub-agents/memory/orchestrator/memory.md
```

No implementation files were edited:

```text
apps/customer/** not edited by Orchestrator
apps/platform-api/** not edited by Orchestrator
apps/back-office/** not edited by Orchestrator
docs/openapi.yaml not edited by Orchestrator
```

## Automated Tests Added Or Updated

```text
None by Orchestrator. Orchestrator does not edit implementation tests.
```

Automated test expectations assigned downstream:

```text
Dev Customer:
- Add/update focused customer automated coverage for exact six input mapping to `number=<six_digits>`.
- Cover duplicate result preservation for same `full_number` with distinct ids.
- Cover partial search behavior remains unchanged.
- Suggested Docker commands include `docker compose -p newpaotang exec -T customer npm test` and build if appropriate.

Dev Backend:
- Add/update focused backend feature tests, preferably in PublicStockSearchTest.
- Cover exact six duplicate virtual rows with distinct ids.
- Cover exact six duplicate copy pagination when available copies exceed limit.
- Suggested Docker command uses APP_ENV=testing and DB_DATABASE=newpaotang_test.
```

## Validation

Protocol validation performed:

```text
Confirmed task files exist:
- ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-customer.md
- ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-dev-backend.md

Confirmed trigger files exist:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md

Confirmed both tasks/triggers include:
- depends_on
- can_run_parallel
- blocking_outputs
- unblocks
- DB change declaration
- shared lock declaration
- expected handoff path
- requested final status instruction for dev handoff
- Next Agent

Confirmed Orchestrator memory remains small: 42 lines.
Confirmed Orchestrator memory diff contains one reusable pattern only.
```

Application validation:

```text
Not run by Orchestrator.
Reason: Orchestrator must not run build/test/migration/seed/reset for this task; validation commands are assigned to downstream dev agents.
```

Boundary evidence:

```text
OpenAPI evidence:
- /public/stock/search returns LocalStockSearchResponse.
- LocalStockItem requires id, game_id, full_number, and status.

Customer evidence:
- apps/customer/composables/usePlatformApi.ts maps LocalStockItem id to token/local_stock_item_id.
- apps/customer/composables/usePlatformApi.ts currently maps filled digit boxes to d1..d6 params; exact six must send number=<six_digits>.
- apps/customer/pages/buy/search.vue currently de-dupes by full_number/number identity; exact six must preserve duplicate rows.

Backend evidence:
- apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php creates virtual rows per copy with stock_ref/id/token/local_stock_item_id/virtual_copy_index.
- The exact six candidate path yields a single full_number and current pagination appears number-offset based, so duplicate copies over limit need Dev Backend verification/fix.
```

## Test Env / DB Safety

```text
Orchestrator ran no app tests, migrations, seeders, resets, or DB commands.
No destructive DB command was run.
Local runtime DB newpaotang was not touched or reset.
Downstream backend task explicitly requires APP_ENV=testing and DB_DATABASE=newpaotang_test.
Downstream QA requirement explicitly requires proving test env/test DB wiring before clean PASS.
```

## Shared File Locks

```text
Lock required: No
Reason: Dev Customer owns apps/customer/** and Dev Backend owns apps/platform-api/**; no shared back-office or cross-agent shared file risk was identified.
Lock files created: None
Release evidence required before QA: Not applicable
```

## Dependency Graph

Dev Customer:

```text
depends_on:
- Orchestrator trigger DONE
can_run_parallel: Yes, with Dev Backend
blocking_outputs:
- Dev Customer task
- Orchestrator handoff
- required customer/API source-of-truth docs
unblocks:
- Orchestrator completion check
- QA creation after all dev handoffs
```

Dev Backend:

```text
depends_on:
- Orchestrator trigger DONE
can_run_parallel: Yes, with Dev Customer
blocking_outputs:
- Dev Backend task
- Orchestrator handoff
- required backend/API source-of-truth docs
unblocks:
- Orchestrator completion check
- QA creation after all dev handoffs
```

Future QA gate:

```text
QA task/trigger should depend on:
- Dev Customer trigger DONE
- Dev Backend trigger DONE
- Dev Customer handoff exists
- Dev Backend handoff exists
- shared locks released or not required
- Orchestrator ready-for-QA handoff
```

## Memory Updates

```text
memory file read: ai-sub-agents/memory/orchestrator/memory.md
memory file updated: Yes
summary: Added reusable routing pattern that frontend/backend tasks can run in parallel when backend work fixes behavior under an already stable opaque-cursor API contract, with QA depending on both handoffs.
memory line count after update: 42
```

## Known Risks

```text
Dev Backend opened because exact-six duplicate copy pagination over limit appears risky in current VirtualStockService behavior.
Dev Customer must avoid changing browse/random de-duplication behavior while fixing exact-six search.
QA must use a test fixture where one full_number has multiple visible available copies; over-limit fixture is preferred to prove backend pagination.
```

## Questions For Coordinator

```text
None.
```

## Requested Final Trigger Status

```text
DONE
```

## Next Agent

```text
Dev Customer
```

Parallel next agent also explicit:

```text
Dev Backend
```
