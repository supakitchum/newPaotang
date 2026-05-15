# stock-generation-summary-widgets-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
stock-generation-summary-widgets
```

QA must validate API/UI behavior and must follow the QA database isolation policy. Destructive DB commands must use `newpaotang_test`; runtime DB `newpaotang` must not be wiped.

## QA Start Gate

Do not start QA until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md
```

If either handoff is missing, uncommitted, or does not include a commit hash, stop and report the blocker to Coordinator/Orchestrator.

## Objective

Run focused QA for stock generation summary widgets and report PASS/FAIL with evidence for backend aggregates, BO widget rendering, game filter refresh behavior, authorization, regression safety, OpenAPI/docs, test DB isolation, and runtime restore/login smoke.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260515-stock-generation-summary-widgets-decision.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-coordinator-handoff.md
ai-agents/tasks/20260515-stock-generation-summary-widgets-backend.md
ai-agents/tasks/20260515-stock-generation-summary-widgets-bo.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md
```

## Scope

Validate:

```text
GET /api/v1/admin/central/stock/summary exists and is documented
central-only enforcement
permission behavior for stock.view OR stock.generate, or documented blocker if impossible
correct total_count for quota-generated stock
correct status_counts
correct back2 coverage expected distinct 100
correct back3 coverage expected distinct 1000
correct front3 coverage expected distinct 1000
correct min/max/count per number for generated 1000 and 3000 row cases where feasible
game_id filter changes aggregate results
batch_id filter if implemented
empty/no-stock response is explicit and not misleading
BO widgets call summary endpoint and display backend values
BO widgets update when game_id filter changes
BO loading state does not render misleading zero values
BO summary error state is visible and non-blocking
existing Generate Stock flow still works
OpenAPI parses
credential/artifact scan passes
QA database isolation evidence is present
runtime restore/login smoke passes before clean PASS
```

## Out Of Scope

```text
fixing implementation defects unless Coordinator explicitly assigns QA a fix
changing stock generation algorithm
production UAT without supplied credentials/session
destructive commands against runtime DB newpaotang
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260515-stock-generation-summary-widgets-qa-report.md
ai-agents/reports/artifacts/20260515-stock-generation-summary-widgets-qa/**
tests/** only if a QA-owned helper/fixture is explicitly needed
apps/*/tests/** only if adding a QA-owned regression test is necessary and Coordinator permits it
```

Must not edit:

```text
apps/platform-api/app/**
apps/back-office/**
apps/customer/**
docs/openapi.yaml
ai-agents/decisions/**
real credential files or local environment secrets
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

QA report must record the DB name and command evidence for any destructive DB command.

## Required Steps

1. Verify Backend and BO commits are present locally and on `origin/develop`.
2. Use a clean QA worktree if the shared worktree is dirty.
3. Prepare `newpaotang_test` only for destructive test setup.
4. Run backend tests and focused API checks for summary aggregates.
5. Run BO lint/test/build and structural/browser checks for widgets.
6. Validate game filter refresh behavior and no misleading loading/empty values.
7. Validate existing Generate Stock flow still works.
8. Parse OpenAPI.
9. Run credential/artifact scan for created QA artifacts.
10. Restore/check runtime DB non-destructively and verify login smoke before final report.

## Acceptance Criteria

```text
Backend tests pass using APP_ENV=testing and DB_DATABASE=newpaotang_test
no destructive command runs against runtime DB newpaotang
summary API returns correct aggregate totals and coverage for quota-generated stock
summary API enforces central scope and expected permission behavior
BO widgets render API values and respond to game_id filter changes
BO widgets handle loading/error/empty states safely
Generate Stock flow still works
OpenAPI parses
artifact/credential scan passes
Runtime Restore / Login Smoke section is present and passing
QA report clearly states PASS, FAIL, or PASS WITH RISK and next agent
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Use additional Docker-compatible API, OpenAPI, structural, and browser checks as needed. Record exact commands.

Mandatory runtime restore/login smoke before final report:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

If runtime restore/login smoke fails, do not report clean PASS.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260515-stock-generation-summary-widgets-qa-report.md
```

Must include:

```text
result: PASS, FAIL, or PASS WITH RISK
worktree path
current HEAD and origin/develop
Backend and BO commit hashes under test
files/artifacts created
validation commands and results
test DB isolation evidence with DB_DATABASE=newpaotang_test
summary API aggregate evidence
BO widget evidence
game filter refresh evidence
Generate Stock regression evidence
OpenAPI parse result
credential/artifact scan result
Runtime Restore / Login Smoke
defects with owner recommendation
unrelated dirty files left untouched
next agent
```

## Next Agent

QA Tester
