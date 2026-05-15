# large-async-stock-generation-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
large-async-stock-generation
```

QA must verify async generation with Docker-only commands and must follow DB isolation. Destructive DB commands must use `newpaotang_test`; runtime DB `newpaotang` must not be wiped.

## QA Start Gate

Do not start QA until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md
```

If either handoff is missing, uncommitted, or does not include a commit hash, stop and report the blocker to Coordinator/Orchestrator.

## Objective

Run focused QA for large async stock generation, including backend async chunk completion, duplicate `full_number` preservation, idempotency, image dispatch separation, BO progress polling, and runtime restore/login smoke.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md
ai-agents/tasks/20260516-large-async-stock-generation-backend.md
ai-agents/tasks/20260516-large-async-stock-generation-bo.md
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md
docs/backend-console-commands.md
```

## Scope

Validate:

```text
1,000 sync path still works
12,000 async path returns queued/processing and does not insert all rows in request
running chunk jobs completes to 12,000 rows
quota coverage is correct after async completion
full_number duplicates remain allowed and are not deduped
stock row generation does not use insertOrIgnore
completed chunk retry does not insert duplicate rows
failed chunk transaction has no partial rows if test coverage exists
idempotency replay returns same batch
idempotency conflict rejects changed payload
image jobs are not dispatched during large request
image jobs/dispatcher start only after stock batch completion
batch list/detail endpoints expose progress
BO accepts large totals and shows progress polling
BO prevents duplicate submit while same batch is queued/processing
BO displays failed state and failure_reason
BO current game default and no ALL behavior remains intact
linked quota inputs remain intact
stock summary widgets refresh/continue to work
OpenAPI parses
artifact/credential scan passes
runtime restore/login smoke passes before clean PASS
```

## Out Of Scope

```text
fixing implementation defects unless Coordinator explicitly assigns QA a fix
production queue/load testing beyond focused local async proof
destructive commands against runtime DB newpaotang
production UAT without supplied credentials/session
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260516-large-async-stock-generation-qa-report.md
ai-agents/reports/artifacts/20260516-large-async-stock-generation-qa/**
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
4. Run focused backend tests for sync/async generation, chunk jobs, idempotency, duplicate `full_number`, image dispatch separation, and batch APIs.
5. Run BO lint/test/build and structural checks.
6. Validate authenticated BO large submit/progress polling workflow where practical.
7. Parse OpenAPI.
8. Run source scan/evidence that stock generation does not use `insertOrIgnore`.
9. Run artifact/credential scan for created QA artifacts.
10. Restore/check runtime DB non-destructively and verify login smoke before final report.

## Acceptance Criteria

```text
Backend tests pass using APP_ENV=testing and DB_DATABASE=newpaotang_test
no destructive command runs against runtime DB newpaotang
12,000 async completion is proven
duplicate full_number values are preserved
insertOrIgnore is not used for stock row generation
idempotency replay/conflict behavior is proven
image dispatch is separated from large request and starts after stock completion
BO progress polling and large total behavior are proven
linked quota/current game/no ALL regressions pass
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
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=LotteryImage --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Use additional Docker-compatible API/job/OpenAPI/browser checks as needed. Record exact commands.

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
ai-agents/reports/20260516-large-async-stock-generation-qa-report.md
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
sync path evidence
12,000 async completion evidence
duplicate full_number evidence
no insertOrIgnore evidence
idempotency evidence
image dispatch separation evidence
batch API progress evidence
BO progress polling evidence
linked quota/current game/no ALL regression evidence
OpenAPI parse result
credential/artifact scan result
Runtime Restore / Login Smoke
defects with owner recommendation
unrelated dirty files left untouched
next agent
```

## Next Agent

QA Tester
