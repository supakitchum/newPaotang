# Task: Allocation Partner Percent Workflow Authenticated BO QA

## Role

QA Tester

## Reason

Previous QA result for `allocation-partner-percent-workflow` was PASS WITH RISK because authenticated BO browser workflow automation was not available. Backend/API evidence, BO lint/test/build, source wiring, route smoke, and runtime restore/login smoke already passed.

This task closes the remaining BO visual/workflow risk only.

## Required Start Gate

```sh
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report if the worktree is dirty before QA starts, except for known local runtime artifacts that are explicitly documented.

## Scope

Test the authenticated Back-office allocation UI workflow as a real central admin user.

Must cover:

- Login to BO as central admin.
- Open the allocation/stock allocation menu from BO navigation.
- Allocation filters use selects, not raw id text inputs.
- Partner select displays partner names.
- Tenant select is filtered by partner.
- If selected partner has exactly one active tenant, tenant is auto-filled or the create request is accepted through backend single-tenant auto-fill behavior.
- Game select displays game names and generated supply metadata where available.
- Create allocation uses `allocation_percent`.
- Create allocation UI must not require or send `requested_count`.
- Allocation table displays partner name, tenant name, game name, allocation percent, allocated/generated count, remaining/recalled state where applicable.
- Row actions are visible and usable:
  - edit partner stock coverage
  - view remaining stock in scoped stock view/new page
  - recall all
  - redistribute after recall-all
- Redistribute is disabled or blocked before recall-all.
- Partners table displays each partner/agent stock percent.
- Editing partner stock percent validates total active partner percent per game is `<= 100%`.
- UI shows a clear validation error if percent would exceed 100%.

## Required Evidence

Save artifacts under:

```text
ai-agents/reports/artifacts/20260519-allocation-partner-percent-workflow-authenticated-bo-qa/
```

Required evidence:

- Browser screenshots for each main BO workflow step.
- Network/API evidence showing create allocation payload uses `allocation_percent` and omits `requested_count`.
- Evidence for partner/tenant/game option loading.
- Evidence for percent over-100 validation.
- Evidence for recall-all then redistribute.
- Evidence for scoped stock/coverage action navigation.
- BO console/network errors, if any.
- Final `git status --short --branch`.

## Required Validation

Use Docker only.

Backend destructive setup must use test DB only:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Do not run destructive commands against runtime DB `newpaotang`.

Run at minimum:

```sh
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

After QA, restore/smoke runtime without destructive migrations:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

## Report

Create:

```text
ai-agents/reports/20260519-allocation-partner-percent-workflow-authenticated-bo-qa-report.md
```

Report must include:

- Result: PASS / FAIL / PASS WITH RISK.
- Exact commit SHA tested.
- Browser/tool used.
- List of BO workflows tested.
- Screenshots/artifact paths.
- Defects with route/API/component references.
- Confirmation that destructive DB commands used `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- Runtime restore/login smoke result.

## Acceptance

- Authenticated BO workflow is tested from the real UI, not source inspection only.
- `requested_count` is absent from create allocation UI/API payload.
- Partner percent validation `<= 100%` is confirmed in UI and API behavior.
- Recall-all and redistribute are confirmed through the UI.
- Runtime login remains usable after QA.

## Next Agent

Coordinator
