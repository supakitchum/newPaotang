# stock-table-realtime-socket-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
stock-table-realtime-socket
```

Backend Develop and BO Develop have completed and pushed their implementation handoffs. QA Tester is now the next agent.

## QA Start Gate

QA Tester must start from the canonical worktree only:

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

The QA report must include the worktree path and HEAD used for testing.

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
```

## Objective

Validate stock table realtime behavior end to end:

```text
backend stock table channel auth requires stock.view
backend stock.table.updated row/refresh events dispatch for expected stock changes
BO subscribes only on central grouped Stock table with selected game_id and authenticated session
BO merges safe row payloads and reloads on refresh_required or uncertainty
BO refreshes stock summary widgets after realtime changes
fallback HTTP reload works when realtime is unavailable/reconnects
existing stock generation progress and stock pattern coverage realtime are not regressed
frozen top-up ownership remains correct
runtime restore/login smoke passes
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md
ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
docs/coordinator-agent-handoff.md
docs/virtual-stock-realtime.md
docs/openapi.yaml
```

## Commits Under Test

Backend:

```text
42af0f5b04b73bca2f22458f6a4526c262df43ad
af9186dcb465ddd724dd4fe99a537bac8eb5a50a
```

BO:

```text
e6ae549895accd8979830531c35cf2babe7dabdf
6ee3ebfbc9a1381789a0c651679a74f23514981b
```

## Known Pre-QA Risk

BO handoff reported:

```text
docker compose -p newpaotang run --rm back-office npm run build
BLOCKED by Docker Desktop instability after Nuxt client/server compilation output.
Docker wrapper exited 125 with "error waiting for container: unexpected EOF".
```

QA must rerun BO build. A clean PASS is not allowed unless BO build exits 0.

## Scope

Validate:

```text
POST /admin/central/realtime/auth allows private-admin.central.stock.table.game.{game_id} for central stock.view
POST /admin/central/realtime/auth denies central without stock.view
POST /admin/central/realtime/auth denies tenant scope for central stock table channel
stock.table.updated broadcasts on private-admin.central.stock.table.game.{game_id}
refresh_required payload is emitted for broad generation/top-up/import/allocation changes
row payload is emitted for safe customer reservation/release/sold counter changes
row payload count fields match grouped /admin/central/stock row contract
AdminOperationsPage subscribes only on central grouped Stock list with selected game_id and authenticated session
BO does not subscribe on tenant pages, Stock Pattern Coverage, missing game_id, or unauthenticated session
BO safe row payload merges visible row counts in place
BO refresh_required reloads table and Stock Summary widgets
BO uncertain filter/sort/cursor compatibility reloads instead of unsafe mutation
BO reconnect reloads table and Stock Summary widgets
Stock Generation progress realtime remains wired
Stock Pattern Coverage realtime remains wired
frozen top-up ownership: old allocation counts/owners fixed after top-up, later top-up copies unassigned/no_agent until allocated
```

## Out Of Scope

```text
fixing implementation defects directly
editing implementation code unless Coordinator explicitly assigns QA fixture/test-code work
wiping runtime DB newpaotang
reintroducing physical stock generation, Partner Quotas, or requested_count allocation flow
```

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive database commands must explicitly target test DB `newpaotang_test`:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests must run with:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`.

## Required Evidence

QA report must include:

```text
worktree path
current HEAD and origin/develop
Backend and BO commit hashes under test
test DB isolation evidence with DB_DATABASE=newpaotang_test
backend channel auth allow/deny evidence
backend stock.table.updated refresh payload evidence
backend stock.table.updated row payload evidence
grouped stock table row contract comparison evidence
BO subscription enable/disable source or browser evidence
BO row merge behavior evidence
BO refresh_required reload behavior evidence
BO summary widget refresh evidence
BO reconnect/fallback evidence or clear reason it could not be exercised
Stock Generation progress realtime no-regression evidence
Stock Pattern Coverage realtime no-regression evidence
frozen top-up ownership evidence
BO build rerun result
BO lint/test/check evidence
backend focused test evidence
runtime restore/login smoke evidence
defects with owner recommendation
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AdminOperationsTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=SoldSyncTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Manual/API workflow evidence may use Docker-hosted runtime and HTTP/browser checks. Prefer authenticated BO workflow evidence for the central Stock table with a selected game.

Mandatory runtime restore/login smoke before clean PASS:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260520-stock-table-realtime-socket-qa-report.md
```

Result must be one of:

```text
PASS
FAIL
PASS WITH RISK
BLOCKED
```

The report must include the required `Runtime Restore / Login Smoke` section from `ai-agents/workflow/handoff-protocol.md`.

Must include the next agent:

```text
Coordinator
```

## Next Agent

QA Tester
