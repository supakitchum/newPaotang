# stock-table-realtime-socket-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator / Orchestrator Context

Coordinator rejected the previous QA result for `stock-table-realtime-socket` after user review.

User opened BO and reported that the expected stock table realtime/summary panel is not visible. This is a user-visible acceptance failure, so this remediation must prove the panel renders in the actual BO UI, not only through source/static checks.

Normal chain:

```text
Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator
```

Do not treat this as a new product feature. This is remediation for the existing active task.

## Canonical Worktree Start Gate

Use only the canonical worktree:

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

Stop and report a blocker to Orchestrator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
HEAD does not equal origin/develop after sync
you are in .codex/worktrees/*, newPaotang-bo-*, newPaotang-qa-*, newPaotang-orch-*, or detached HEAD
there are uncommitted changes that overlap apps/back-office/**
```

Known dirty file before this remediation dispatch:

```text
apps/platform-api/.phpunit.result.cache
```

This is PHPUnit runtime noise from prior QA. Do not stage it. If it is still present, record it in your handoff as unrelated dirty state left unstaged.

## Source Of Truth

Read before editing:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-orchestrator.md
ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
ai-agents/reports/20260520-stock-table-realtime-socket-qa-report.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
```

## Observed Defect

The previous BO implementation added a websocket subscription, but the user cannot see the expected realtime/summary panel in BO after QA.

Coordinator review notes:

```text
QA report originally claimed PASS but did not provide authenticated browser evidence that the panel is visible.
QA report stated live browser websocket event mutation was not manually triggered end-to-end.
Source/static checks are not enough for this defect class.
The remediation must be verified in the actual BO UI, not only through token checks.
```

## Ownership

You may edit:

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockSummaryWidgets.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/check-stock-summary-widgets.mjs
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md
```

Do not edit backend or customer files. If the panel cannot render because the backend contract/API data is missing or broken, stop and write a blocker handoff to Orchestrator.

## Required Remediation

Investigate and fix the missing BO panel.

Minimum user-visible acceptance:

```text
On the central grouped Stock table route with a selected game, a visible stock table realtime/summary panel must render above the table.
Routes that resolve to the grouped Stock table must not silently lose the panel.
If no game is selected, show a visible state/prompt explaining that a game must be selected instead of making the panel disappear without explanation.
The panel must make the realtime table workflow observable to an operator, for example with stock table realtime status and/or generated/available/allocated/sold summary widgets.
The panel must continue to refresh when stock.table.updated events cause row merge/reload behavior.
Do not remove or regress Stock Generation progress realtime.
Do not remove or regress Stock Pattern Coverage realtime.
Keep the UI consistent with docs/admin-dashboard-template-guidelines.md and the existing Meno admin panel/card/badge style.
```

Routes to verify at minimum:

```text
/admin/central/stock
/admin/central/master-stock
/admin/central/stock-generation
/admin/central/stock-recall
```

These aliases currently resolve through `useAdminOperationsCatalog.ts` to the grouped Central Stock resource. Confirm actual behavior from the code before changing anything.

Implementation guidance:

```text
Existing source already calls useAdminRealtimeSubscription for stock.table.updated.
Keep and expose the returned or derived realtime state if needed so operators can see the table realtime status.
Existing AdminStockSummaryWidgets is gated by showStockSummaryWidgets. Verify this condition on actual BO routes.
For no-game state, prefer a compact visible admin alert/panel near the table/summary area.
Do not add decorative marketing UI.
Avoid changing API contracts unless Coordinator reassigns backend work.
```

## Required Validation

All app commands must run through Docker only:

```sh
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Also run a static diff check:

```sh
git diff --check
```

If Docker Desktop or the Docker API fails, do not claim clean PASS. Record the failure and exact last visible output in the handoff.

## Commit / Push Requirement

When the remediation and validation are complete:

```text
stage only files in your ownership/scope
do not stage apps/platform-api/.phpunit.result.cache
commit with a message starting with: stock-table-realtime-remediation:
push develop so QA can see the work
```

## BO Handoff Requirements

Write:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md
```

The handoff must include:

```text
worktree path
branch
HEAD and origin/develop at start
HEAD and origin/develop at end
commit hash
exact BO route(s) where the panel was verified
files changed
validation commands/results
unrelated dirty files left unstaged
known risks
Next Agent: Orchestrator
```

## Next Agent

Orchestrator
