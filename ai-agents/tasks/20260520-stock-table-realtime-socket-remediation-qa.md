# stock-table-realtime-socket-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

This is focused QA for the remediation of `stock-table-realtime-socket`.

Coordinator rejected the previous QA result after user review because the user opened BO and could not see the expected stock table realtime/summary panel. BO Develop has now completed and pushed a remediation.

Normal chain:

```text
Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator
```

Do not treat this as a new product feature. Validate the remediation and report back to Coordinator.

## Canonical Worktree Start Gate

Use only the canonical worktree:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or testing anything, run:

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
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
HEAD does not equal origin/develop after sync
there are uncommitted changes that QA did not create and they overlap this task
```

Known dirty file before this QA dispatch:

```text
apps/platform-api/.phpunit.result.cache
```

This is prior PHPUnit runtime noise. Do not stage it unless QA changes it during validation and explicitly records why. It must not block QA unless it overlaps the task.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-orchestrator.md
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md
ai-agents/reports/20260520-stock-table-realtime-socket-qa-report.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
```

## Commits Under Test

Original backend and BO delivery:

```text
backend implementation: 42af0f5b04b73bca2f22458f6a4526c262df43ad
backend handoff: af9186dcb465ddd724dd4fe99a537bac8eb5a50a
original BO implementation: e6ae549895accd8979830531c35cf2babe7dabdf
original BO handoff: 6ee3ebfbc9a1381789a0c651679a74f23514981b
```

Remediation under test:

```text
orchestrator dispatch: 034367b2a8c66e758363a986e964a01deffeb7b7
BO remediation implementation: 6d730b18418d789ab05774bb26abc4330d72b761
BO remediation handoff: cd2f6f1
```

QA must test the latest pushed `origin/develop` at or after:

```text
cd2f6f1
```

## Defect To Validate

Previous failure:

```text
User opened BO after QA and reported that the expected panel is not visible.
```

QA must not report PASS unless it has authenticated BO browser or equivalent DOM evidence that the panel is visible in BO.

Source/static checks alone are insufficient for this remediation.

## Required Browser / DOM Evidence

QA must log in to BO and verify the actual rendered UI.

At minimum, verify these routes:

```text
/admin/central/stock
/admin/central/stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/master-stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/stock-generation?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/stock-recall?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
```

If the seeded current game id differs, record the actual game id and use it consistently.

Evidence must include:

```text
BO login works
central grouped Stock table route opens after authentication
no-game route shows a visible prompt/state explaining that a game must be selected
selected-game routes show a visible stock table realtime/summary panel above the table
panel title or DOM marker is visible, for example .np-stock-realtime-panel / "Stock table realtime"
panel shows realtime status or equivalent operator-visible state
summary widgets are visible for selected game
table columns remain visible: Available, Allocated, Sold, Recalled, Tickets
no page-level browser errors that prevent rendering
```

Screenshots, DOM snapshots, browser text snapshots, or equivalent artifact paths are acceptable. The report must name the artifact paths.

## Functional Regression Scope

Validate that the remediation did not break the existing realtime work:

```text
AdminOperationsPage still subscribes only on central grouped Stock list with selected game_id and authenticated session
stock.table.updated safe row payload still merges visible row counts when compatible
stock.table.updated refresh_required still reloads the table and Stock Summary widgets
uncertain filter/sort/cursor/page states still reload instead of unsafe mutation
reconnect still reloads table and Stock Summary widgets
Stock Generation progress realtime remains wired
Stock Pattern Coverage realtime remains wired
frozen top-up ownership remains correct
```

Use focused automated tests and source/DOM evidence where appropriate.

## Required Validation Commands

All app commands must run through Docker only:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AdminOperationsTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

QA may rerun `SoldSyncTest` and `PublicStockSearchTest` from the original QA task if it needs extra confidence, but the focused remediation PASS hinges on browser evidence that the panel is visible.

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive database commands must explicitly target test DB `newpaotang_test`:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`.

## Runtime Restore / Login Smoke

Before clean PASS, QA must restore/check the local Docker runtime without wiping runtime DB:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

The QA report must include the required `Runtime Restore / Login Smoke` section from `ai-agents/workflow/handoff-protocol.md`.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260520-stock-table-realtime-socket-remediation-qa-report.md
```

Result must be one of:

```text
PASS
FAIL
PASS WITH RISK
BLOCKED
```

The report must include:

```text
worktree path
branch
HEAD and origin/develop under test
commit hashes under test
test DB isolation evidence
validation command results
authenticated browser/DOM evidence and artifact paths
defects with owner recommendation
runtime restore/login smoke
unrelated dirty files left unstaged
Next Agent: Coordinator
```

## Next Agent

Coordinator
