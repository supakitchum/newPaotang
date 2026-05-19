# allocation-partner-percent-workflow-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
allocation-partner-percent-workflow
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

Known unrelated local artifact:

```text
apps/platform-api/.phpunit.result.cache may be dirty from Backend PHPUnit validation.
Do not include it in QA report commits unless QA intentionally updates it and Coordinator explicitly approves.
```

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

## Objective

Validate the full allocation partner percent workflow through real backend and BO behavior:

```text
allocation filters use partner/tenant/game selects with display names
partner -> tenant dependent behavior works
single active tenant auto-fills tenant
multi-tenant partner requires explicit tenant
no-active-tenant partner is blocked with clear validation
create allocation uses allocation_percent and does not send requested_count
allocation list/detail displays partner/tenant/game names and percent/counts
partner stock percent edit enforces total active partner percent <= 100
usage-protection validation appears when lowering percent below reserved/sold usage
recall-all and redistribute workflows work and update state
stock coverage and remaining-stock row actions route to scoped pages
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
docs/openapi.yaml
docs/virtual-stock-realtime.md
docs/coordinator-agent-handoff.md
ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md
ai-agents/tasks/20260519-allocation-partner-percent-workflow-bo.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

Relevant sections:

```text
docs/virtual-stock-realtime.md#allocation-and-partner-percent-rework
docs/coordinator-agent-handoff.md#allocation-partner-percent-workflow
```

## Commits Under Test

Backend:

```text
6d4061e19a0b3df1c351ededeeb0cfc382f09d6e
bf3ec0c895b99d910e1375e463ef2ea14e41039f
```

BO:

```text
975d245848cadcec56bb95bfeb405d998cf54bdd
5ec009c97272d8cf84c8d82cf78bbd6845e9d019
```

## Scope

Validate:

```text
backend allocation option APIs for partners, tenants, and games
BO allocation filters using option-backed selects instead of raw id text inputs
dependent partner -> tenant filtering in filters and create action
single active tenant auto-fill/lock behavior
multi-tenant explicit tenant selection requirement
no-active-tenant validation behavior
create allocation payload uses allocation_percent and no requested_count
idempotency replay or conflict behavior for allocation create where feasible
allocation list/detail display metadata and percent/count fields
partner stock percent edit UI and backend validation
active partner percent total <= 100 validation through API/UI
usage-protection rejection for lowering percent below reserved/sold stock where feasible
stock coverage row action route query params
remaining stock row action route query params
recall-all action request/state/result
redistribute disabled state before recall and success after recalled state
BO lint/test/build and backend focused tests
runtime restore/login smoke
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

Do not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`.

## Required Evidence

QA report must include:

```text
worktree path
current HEAD and origin/develop
Backend and BO commit hashes under test
test DB isolation evidence with DB_DATABASE=newpaotang_test
API evidence for allocation option endpoints
BO evidence that allocation filters use partner/tenant/game selects
BO/API evidence for partner -> tenant filtering
BO/API evidence for single-tenant auto-fill
BO/API evidence for multi-tenant explicit tenant requirement
BO/API evidence for no-active-tenant validation
API request evidence that create allocation uses allocation_percent and omits requested_count
allocation list/detail evidence for display metadata and percent/count fields
partner stock percent UI/API validation evidence for <= 100 total
usage-protection validation evidence or clear reason it could not be exercised
recall-all request/result/state evidence
redistribute disabled-state and success-after-recall evidence
stock coverage scoped route evidence
remaining stock scoped route evidence
BO lint/test/build evidence
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
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Manual/API workflow evidence may use Docker-hosted runtime and HTTP/browser checks. Prefer authenticated BO workflow evidence where feasible.

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
ai-agents/reports/20260519-allocation-partner-percent-workflow-qa-report.md
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
