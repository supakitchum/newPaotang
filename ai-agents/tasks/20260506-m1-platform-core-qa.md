# m1-platform-core - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

QA is authorized after Backend Develop completed `ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md`. Validate the Milestone 1 platform core backend foundation against the original Backend Develop task, Backend handoff, source-of-truth documents, Docker runtime policy, and acceptance criteria.

## Objective

Test and report whether the `apps/platform-api` Laravel 13 platform core foundation satisfies the Milestone 1 acceptance criteria for boot, migrations, health endpoints, tenant/domain resolution, RBAC default deny behavior, menu foundation, audit redaction, and Docker-only validation.

## Source Of Truth

- ai-agents/tasks/20260506-m1-platform-core-backend.md
- ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-decision.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/events.md
- docs/erd.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/01_SYSTEM_OVERVIEW.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md

## Scope

- Review Backend Develop task and handoff.
- Verify changed backend files under `apps/platform-api/**` are consistent with the task scope.
- Run backend validation through Docker only.
- Validate Laravel boot and migrations from an empty testing database.
- Validate health endpoints match `docs/openapi.yaml`.
- Validate tenant/domain schema and safe host resolution behavior for unknown, inactive domain, inactive tenant, and inactive partner cases where tests or implementation expose those paths.
- Validate RBAC foundation separates central and tenant scope.
- Validate permission checks default to deny.
- Validate menu service is permission/scope driven and is not treated as backend authorization.
- Validate admin audit logger redacts sensitive payload fields.
- Check that no customer or back-office implementation was changed for this task.
- Report pass/fail, defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit `apps/platform-api/**` unless Coordinator explicitly authorizes QA to change test fixtures or test code.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not create new product/business requirements.
- Do not approve or reject Coordinator-level architecture questions; report them to Coordinator.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
tests/**
apps/*/tests/** only if a test/fixture change is required and clearly reported
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/bootstrap/**
apps/platform-api/config/**
apps/platform-api/database/migrations/**
apps/platform-api/routes/**
apps/platform-api/public/**
apps/platform-api/composer.json
apps/platform-api/composer.lock
apps/back-office/**
apps/customer/**
docs/**
document/**
```

Prefer read-only validation. If test code or fixtures need edits, explain why in the QA report.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, and `ai-agents/workflow/file-ownership.md`.
3. Inspect Backend Develop handoff and compare it against `ai-agents/tasks/20260506-m1-platform-core-backend.md`.
4. Inspect `git status --short` and confirm whether changed files are inside the authorized backend scope or agent workflow files.
5. Inspect `apps/platform-api` structure enough to verify Laravel, module/shared convention, routes, migrations, services, and tests exist.
6. Run validation commands through Docker only.
7. If a validation command fails, capture the failure and continue with any safe remaining read-only checks.
8. Record defects as actionable items with file paths and reproduction/validation evidence.
9. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-platform-core-qa-report.md`.
- QA confirms whether `apps/platform-api` exists and boots through Docker.
- QA confirms whether migrations run from an empty PostgreSQL testing database.
- QA confirms whether `/api/v1/health`, `/api/v1/health/live`, and `/api/v1/health/ready` match `docs/openapi.yaml`.
- QA confirms whether tenant/domain schema exists.
- QA confirms whether host tenant resolution has safe behavior for unknown and inactive states.
- QA confirms whether RBAC foundation separates central and tenant scope.
- QA confirms whether permission checks default to deny.
- QA confirms whether menu service is driven by permission/scope data and is not authorization.
- QA confirms whether admin write audit logger exists and redacts sensitive payload fields.
- QA confirms automated tests cover boot, health, tenant resolution, default deny permission behavior, RBAC scope separation, permission-driven menus, and audit redaction.
- QA confirms Docker runtime policy was followed during validation.
- QA identifies any defects, not-tested items, known risks, and Coordinator questions.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose build platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --env=testing
docker compose run --rm platform-api php artisan test
```

If containers are already running and dependencies are already installed, the equivalent `exec` form is acceptable:

```sh
docker compose exec platform-api php artisan migrate:fresh --env=testing
docker compose exec platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api -maxdepth 4 -type f | sort
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-platform-core-qa-report.md
```

Must include:

```text
task
scope tested
commands run
test results
defects
risks / not tested
recommendation
next agent
```

Next Agent should be:

```text
Coordinator
```
