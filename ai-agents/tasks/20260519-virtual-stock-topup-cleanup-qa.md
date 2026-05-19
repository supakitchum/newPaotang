# virtual-stock-topup-cleanup-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
virtual-stock-topup-cleanup
```

## QA Start Gate

QA Tester must start from the canonical worktree only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or testing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
there are uncommitted changes that QA did not create and they overlap this task
```

The QA report must include the worktree path and HEAD used for testing.

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md
```

## Objective

Validate virtual-only additive stock top-up, retired physical generation, owner/image details, and Stock Pattern Coverage realtime behavior through real backend/BO workflows.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
ai-agents/decisions/20260519-virtual-stock-topup-cleanup-decision.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-coordinator-handoff.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-backend.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-bo.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md
```

## Scope

Validate:

```text
initial virtual generate creates profile/supply
second virtual generate/top-up increases generated supply without replacing profile/counters
idempotency replay does not add supply twice
seed is not visible or required in BO
physical generation options and payloads are gone/rejected
customer search availability increases after top-up where limits allow
reservation still lazily materializes real tickets
Stock Generation detail shows owner/no-agent and real image data only when present
limits cannot exceed generated combined virtual supply
Stock Pattern Coverage updates through socket without manual refresh after reserve/sold/top-up/limit changes
two-browser realtime still works after top-up
runtime restore/login smoke passes
```

## Out Of Scope

```text
fixing implementation defects directly
editing implementation code unless Coordinator explicitly assigns QA fixture/test-code work
wiping runtime DB newpaotang
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

## Required Evidence

QA report must include:

```text
worktree path
current HEAD and origin/develop
Backend and BO commit hashes under test
API evidence for initial generate and top-up additive supply
API evidence for idempotency replay not adding supply twice
API/BO evidence that seed is not required or visible
API/BO evidence that physical/quota generation is gone/rejected
customer availability evidence before/after top-up
reservation lazy materialization evidence
Stock Generation detail owner/no-agent evidence
real materialized image field evidence and no fake image rows for unmaterialized capacity
limit validation evidence against combined generated supply
Stock Pattern Coverage websocket evidence after top-up/limit/reservation/sold changes
two-browser realtime evidence after top-up
test DB isolation evidence with DB_DATABASE=newpaotang_test
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
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

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
ai-agents/reports/20260519-virtual-stock-topup-cleanup-qa-report.md
```

Result must be one of:

```text
PASS
FAIL
PASS WITH RISK
BLOCKED
```

The report must include the required `Runtime Restore / Login Smoke` section from `ai-agents/workflow/handoff-protocol.md`.

## Next Agent

QA Tester
