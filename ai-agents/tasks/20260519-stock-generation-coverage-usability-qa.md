# stock-generation-coverage-usability-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
stock-generation-coverage-usability
```

## QA Start Gate

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-bo-handoff.md
```

## Objective

Test real BO workflows and backend source-of-truth behavior for Stock Generation coverage usability.

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
ai-agents/handoffs/20260519-stock-generation-coverage-usability-coordinator-handoff.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-backend.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-bo.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-bo-handoff.md
```

## Scope

Validate:

```text
Generation progress action view opens and shows real batch details
Stock Generation row action opens full-number detail
full-number detail shows virtual unmaterialized capacity
full-number detail shows materialized ticket/image rows when present
Stock Generation filters work for game_id, number/full_number, front3, back3, back2, and status
Tickets sort returns correct order for virtual generated supply/capacity
Stock Settings saves default central/partner coverage values
Stock Pattern Coverage loads saved defaults into empty/new scope forms
partner coverage lower/equal central saves
partner coverage greater than central returns validation error and does not save
partner per-number override greater than central effective value is rejected
runtime restore/login smoke passes
```

## Out Of Scope

```text
fixing implementation defects directly
editing apps/platform-api/** unless Coordinator explicitly assigns QA fixture/test-code work
editing apps/back-office/** unless Coordinator explicitly assigns QA fixture/test-code work
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
backend API evidence for filters and total_count sort
backend API evidence for partner <= central validation
BO/browser evidence for progress detail view
BO/browser evidence for full-number detail and image/materialized rows
BO/browser evidence for filters, reset, and Tickets sort
BO/browser evidence for Stock Settings defaults and Stock Pattern Coverage initial values
negative validation evidence for partner > central total/default and per-number override
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
ai-agents/reports/20260519-stock-generation-coverage-usability-qa-report.md
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
