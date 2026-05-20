# 20260520 QA Agent New Chat Handoff

## Purpose

Use this file as the continuity note when opening a new chat for the QA Tester Agent.

## Agent Identity / Role

You are the QA Tester Agent for NewPaotang.

Primary responsibilities:

- Build a practical test plan from the Orchestrator QA task and implementation handoffs.
- Validate acceptance criteria, regressions, permissions, tenant isolation, API behavior, BO/customer flows, and runtime readiness.
- Write the QA result report for Coordinator.
- Report defects to Coordinator for routing. Do not send work directly to Backend/BO unless Coordinator explicitly instructs it.

## Hard Rules

- Use canonical worktree only: `/Users/supakit/WorkSpace/www/newPaotang`.
- Before testing, sync and verify the canonical worktree:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

- Stop and report blocker to Coordinator if:
  - Worktree is not `/Users/supakit/WorkSpace/www/newPaotang`.
  - Worktree is under `.codex/worktrees/*`, `newPaotang-qa-*`, `newPaotang-orch-*`, `newPaotang-bo-*`, or detached HEAD.
  - `git merge --ff-only origin/develop` fails.
  - There are uncommitted changes QA did not create and they overlap the task.
- QA must not edit implementation code unless Coordinator explicitly assigns QA fixture/test-code work.
- QA may write reports/artifacts under `ai-agents/reports/**`.
- Do not stage, commit, or push.
- Use Docker for app/test/build/migration commands.
- Runtime DB `newpaotang` must not be wiped.
- Destructive DB commands must target test DB only:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

- Backend tests must run with:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

- Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`.
- Do not mark PASS unless tests/evidence were actually run, or limitations are clearly reported.

## Current Worktree Snapshot

Observed before writing this handoff:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 2f55196abff7314df1580da5253c4ca5a521da2d
status: clean against tracked files at observation time
```

The new QA chat must still rerun the start gate above before work.

## Must-Read Files For New QA Chat

Read these first:

```text
ai-agents/prompts/open-chat-qa-tester.md
ai-agents/README.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/roles/qa-tester.md
ai-agents/BOARD.md
docs/coordinator-agent-handoff.md
docs/openapi.yaml
docs/permissions.md
```

For the active task, read:

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
ai-agents/decisions/20260520-coordinator-role-rules-decision.md
docs/virtual-stock-realtime.md
ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md
ai-agents/tasks/20260520-retire-physical-stock-flow-bo.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-qa-dispatch-handoff.md
```

## Active Task

Board currently shows:

```text
active task: retire-physical-stock-flow
QA task: retire-physical-stock-flow-qa
QA status: pending
Next Agent after QA: Coordinator
```

Task file:

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md
```

Expected report:

```text
ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md
```

Suggested artifacts root:

```text
ai-agents/reports/artifacts/20260520-retire-physical-stock-flow-qa/
```

## Commits Under Test From QA Task

Backend:

```text
9876c9226410becc13136dfc7308bb3b721b1137
c2774dc186f262b94ddac8130c458cc7b7a6101b
```

BO:

```text
3d46de9e5f656dcc8e480dc338302219315ea783
40e03dc1edfedb2cb81db4b00b20f8489c67cba7
```

## Active Task Objective

Validate that active physical stock flow is retired while virtual stock generation/allocation/materialization still works.

QA scope includes:

- `POST /admin/central/stock/generate` rejects `quota_random`, `quota`, `physical`, and legacy physical fields.
- `POST /admin/central/allocations` rejects `requested_count`.
- `POST /admin/central/allocations` accepts `allocation_percent`.
- Virtual allocation writes `partner_stock_allocations` and `stock_partner_distributions`.
- Virtual allocation does not bulk assign `stock_items`.
- Virtual allocation does not create `partner_stock_allocation_items` as source-of-truth rows.
- Customer search/reservation visibility reflects `stock_partner_distributions`.
- Reservation still lazily materializes `stock_items` / `local_stock_items`.
- `GET /partner-sync/allocations` returns virtual allocation/distribution metadata.
- `GET /admin/central/partner-quotas` is legacy read-only.
- `POST/PATCH /admin/central/partner-quotas` returns `410 retired_flow`.
- BO active navigation no longer shows Central Partner Quotas.
- BO operation catalog does not show Partner Quotas create/update write actions.
- Stale `/admin/central/partner-quotas` deep link shows retired guidance or cannot present retired writes as active success paths.
- BO retired_flow/410 errors show retired workflow copy.
- BO allocation create has no `requested_count` and still uses `allocation_percent`.
- BO Stock Generation remains `virtual_profile` only and retired physical fields are not visible.
- BO stock coverage/remaining stock actions stay scoped to virtual distribution-backed views.

## Required Commands From QA Task

Use Docker only:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerSyncAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerQuotaTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=LocalStockSyncTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Manual/API workflow evidence may use Docker-hosted runtime and HTTP/browser checks. Prefer authenticated BO workflow evidence for navigation/deep-link checks.

## Runtime Restore / Login Smoke Rule

Before final QA report after browser/runtime/DB work, restore runtime and verify smoke:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

If BO build/browser QA was run, recreate/restart back-office and verify:

- customer `/login` returns `200`
- back-office `/login` returns `200`
- back-office `/admin/login` redirects to `/login` and follow returns `200`
- central admin API login returns `200`

## Most Recent Completed QA Context

Previous completed QA task:

```text
allocation-partner-percent-workflow-authenticated-bo-qa
```

Result:

```text
PASS
```

Report:

```text
ai-agents/reports/20260519-allocation-partner-percent-workflow-authenticated-bo-qa-report.md
```

Important note from that QA:

- Runtime DB was not wiped.
- A pending runtime migration was applied during QA because runtime `newpaotang` lacked the allocation percent workflow column.
- Runtime restore/login smoke passed after QA.

This previous task is closed; do not continue it unless Coordinator asks.

## New Chat First Instruction

When opening the new QA chat, tell the agent:

```text
อ่าน ai-agents/handoffs/20260520-qa-agent-new-chat-handoff.md แล้วเริ่มงาน QA ตาม ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md โดยทำ start gate ก่อน
```

## Next Agent

QA Tester continues this task, then reports to Coordinator.
