# stock-generate-linked-quota-inputs-hotfix-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed BO hotfix for:

```text
stock-generate-linked-quota-inputs-hotfix
```

QA must verify real authenticated BO behavior, not only lint/build.

## QA Start Gate

Do not start QA until the BO implementation handoff exists, includes a commit hash, and is pushed:

```text
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-bo-handoff.md
```

If the BO handoff reports that no reliable current-game marker exists, stop and route to Orchestrator/Coordinator for Backend assignment instead of running a partial QA pass.

## Objective

Run focused QA for the Stock Generate linked quota inputs and current-game selection hotfix, then report PASS/FAIL with evidence.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-decision.md
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-coordinator-handoff.md
ai-agents/tasks/20260515-stock-generate-linked-quota-inputs-hotfix-bo.md
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-bo-handoff.md
docs/openapi.yaml
docs/back-office-crud-coverage.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockSummaryWidgets.vue
```

## Scope

Validate:

```text
authenticated central BO can open the Stock Generate page/form
typing 2-tail value immediately displays required 3-tail and 3-front values
typing 3-tail value immediately displays required 2-tail and 3-front values
typing 3-front value immediately displays required 2-tail and 3-tail values
invalid 2-tail value not divisible by 10 shows inline validation before submit
dependency conflicts block submit or clearly mark the modal invalid before submit
Stock Generate game defaults to current draw/current game
ALL is not available in the Stock Generate game selector
generate cannot be submitted with all-game/empty-game selection
valid submit payload remains accepted or reaches backend validation success path in a controlled test
previous stock summary widgets still render
summary widgets stay aligned with selected current game
legacy start_number/count/range/number_digits fields do not return
BO validation commands pass
runtime restore/login smoke passes before clean PASS
```

## Out Of Scope

```text
fixing implementation defects unless Coordinator explicitly assigns QA a fix
changing quota algorithm
changing backend validation
changing stock summary endpoint behavior
destructive commands against runtime DB newpaotang
production UAT without supplied credentials/session
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260515-stock-generate-linked-quota-inputs-hotfix-qa-report.md
ai-agents/reports/artifacts/20260515-stock-generate-linked-quota-inputs-hotfix-qa/**
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

QA report must record the DB name and command evidence for any destructive DB command. Do not use `migrate:fresh --seed` against runtime DB `newpaotang`.

## Required Steps

1. Verify BO implementation commit is present locally and on `origin/develop`.
2. Use a clean QA worktree if the shared worktree is dirty.
3. Run BO lint/test/build and any structural checks from the BO handoff.
4. Start Docker runtime for authenticated BO browser validation.
5. Open central Stock page/form in authenticated BO.
6. Exercise linked quota input behavior for 2-tail, 3-tail, and 3-front.
7. Verify invalid/conflict behavior before submit.
8. Verify current game default, no ALL option, and no empty/all-game submit payload.
9. Verify summary widgets remain visible/aligned and legacy fields do not return.
10. Run artifact/credential scan for created QA artifacts.
11. Perform runtime restore/login smoke before final report.

## Acceptance Criteria

```text
real authenticated BO workflow confirms linked quota values update while typing
invalid dependency is shown inline before submit
conflicting/empty/all-game submit is blocked or clearly invalidated
current game is selected by default
ALL is absent from Stock Generate game selector
valid payload remains accepted in controlled path
summary widgets still render and align with current game
legacy range/count fields are absent
BO Docker validation passes
artifact/credential scan passes
Runtime Restore / Login Smoke section is present and passing
QA report clearly states PASS, FAIL, or PASS WITH RISK and next agent
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang up -d platform-api back-office
```

Run any repo-available BO structural checks related to stock generation and record exact commands.

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
ai-agents/reports/20260515-stock-generate-linked-quota-inputs-hotfix-qa-report.md
```

Must include:

```text
result: PASS, FAIL, or PASS WITH RISK
worktree path
current HEAD and origin/develop
BO commit hash under test
files/artifacts created
validation commands and results
authenticated BO workflow evidence
linked quota input evidence
invalid/conflict evidence
current game default evidence
ALL removal / empty-game prevention evidence
summary widget regression evidence
legacy field absence evidence
credential/artifact scan result
Runtime Restore / Login Smoke
defects with owner recommendation
unrelated dirty files left untouched
next agent
```

## Next Agent

QA Tester
