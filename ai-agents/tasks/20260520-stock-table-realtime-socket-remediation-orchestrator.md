# stock-table-realtime-socket-remediation - Orchestrator

## Target Agent

Orchestrator

## Coordinator Instruction

The active task `stock-table-realtime-socket` is not accepted.

User opened BO after QA and reported that the expected panel is not visible. Coordinator rejects the QA PASS and routes remediation through the normal chain:

```text
Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator
```

Do not open a new product feature task. Treat this as remediation for the existing active task.

## Canonical Worktree Start Gate

Orchestrator and every downstream agent must start from:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
HEAD does not equal origin/develop after sync
there are uncommitted changes that overlap the remediation
```

Current known dirty files before this remediation dispatch:

```text
apps/platform-api/.phpunit.result.cache
```

This file is QA runtime noise and must not be staged unless Coordinator explicitly says so.

## Source Of Truth

Read:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
ai-agents/reports/20260520-stock-table-realtime-socket-qa-report.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
```

## Observed Failure

User-visible defect:

```text
QA inspected the task, but the user opened BO and cannot see the expected panel.
```

Coordinator review notes:

- QA report originally claimed PASS but did not provide authenticated browser evidence that the panel is visible.
- QA report stated live browser websocket event mutation was not manually triggered end-to-end.
- Source/static checks are not enough for this defect class.
- The remediation must be verified in the actual BO UI, not only through token checks.

## Orchestrator Scope

Dispatch BO Develop remediation first.

If BO Develop finds the issue is caused by backend contract/API data, stop and send a blocker to Coordinator instead of editing backend directly from the BO task.

After BO Develop commits/pushes, dispatch QA Tester to rerun focused QA with browser evidence.

## BO Develop Remediation Requirements

BO Develop owns:

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockSummaryWidgets.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/check-stock-summary-widgets.mjs
BO handoff for this remediation
```

BO Develop must investigate and fix the missing panel in BO.

Minimum user-visible acceptance:

- On the central grouped Stock table route with a selected game, a visible stock table realtime/summary panel must render above the table.
- Routes that resolve to the grouped Stock table, including aliases such as Central Stock, Master Stock, and Stock Generation if applicable, must not silently lose the panel.
- If no game is selected, the page must show a visible state/prompt explaining that a game must be selected instead of making the panel disappear without explanation.
- The panel must make the realtime table workflow observable to an operator, for example by showing table realtime status and/or the summary widgets tied to generated/available/allocated/sold counts.
- The panel must continue to refresh when `stock.table.updated` events cause row merge/reload behavior.
- Do not remove existing Stock Generation progress realtime or Stock Pattern Coverage realtime behavior.
- Keep the UI consistent with `docs/admin-dashboard-template-guidelines.md`.

Implementation guidance:

- Existing source already calls `useAdminRealtimeSubscription` for `stock.table.updated`; BO may need to keep the returned realtime state and render a compact visible status area.
- Existing `AdminStockSummaryWidgets` is gated by `showStockSummaryWidgets`. Verify this condition on the actual BO routes the user uses.
- Avoid adding a decorative marketing-style card. Use the existing admin panel/card/badge style.
- Keep backend files out of scope unless Coordinator reassigns.

Required BO validation:

```sh
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

BO handoff must include:

```text
worktree path
HEAD and origin/develop at start/end
commit hash
exact BO route(s) where the panel was verified
files changed
validation commands/results
unrelated dirty files left unstaged
Next Agent: Orchestrator
```

## QA Remediation Requirements

QA Tester must not report PASS unless it has authenticated browser or equivalent DOM evidence that the panel is visible in BO.

QA must verify:

- BO login works.
- Open central grouped Stock table route.
- Select or confirm a current game filter.
- The expected panel is visible above the table.
- The panel remains visible after stock table realtime refresh/reload behavior.
- The table still shows `available_count`, `allocated_count`, `sold_count`, `recalled_count`, and `total_count`.
- No selected game state is visible and understandable if that path is tested.
- Runtime restore/login smoke passes after QA.

Destructive database commands remain limited to:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime DB `newpaotang` must not be wiped.

## Expected Output

Orchestrator must write/update task prompts and handoffs for the remediation, then route:

```text
BO Develop -> QA Tester -> Coordinator
```

Next Agent: Orchestrator
