# m1-rbac-menu-seeders - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md`. Validate the default RBAC permission and menu seeders against the Coordinator decision, Backend task, Backend handoff, `docs/permissions.md`, and Docker runtime policy.

## Objective

Test and report whether the `apps/platform-api` RBAC/menu seeders correctly seed default central/tenant permissions and menus, preserve scope separation, stay idempotent, and keep the existing platform API test suite passing.

## Source Of Truth

- ai-agents/decisions/20260506-m1-rbac-menu-seeders-decision.md
- ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md
- ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md

## Scope

- Review Backend Develop task and handoff.
- Verify changed backend files are within the approved scope:
  - `apps/platform-api/database/seeders/**`
  - `apps/platform-api/tests/**`
  - `apps/platform-api/app/Shared/Rbac/**` only if used for seeder/test support
- Inspect `DefaultRbacMenuSeeder`, `DatabaseSeeder`, and focused RBAC/menu seeder tests.
- Validate central permissions seed with `scope_type = central`.
- Validate tenant permissions seed with `scope_type = tenant`.
- Validate central menus seed with documented `required_permission_code` values from `docs/permissions.md`.
- Validate tenant menus seed with documented `required_permission_code` values from `docs/permissions.md`.
- Validate repeated seeding does not create duplicate permission/menu rows.
- Validate permission/menu scope separation is preserved.
- Confirm no admin auth endpoints, admin menu API endpoints, role assignments, default tenant/admin accounts, migrations, docs, customer app, or back-office app changes were made for this slice.
- Run required validation commands through Docker only.
- Write QA report for Coordinator review.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not add admin auth endpoints or admin menu API endpoints.
- Do not assign roles to users or create default admin accounts.
- Do not change `admin_menus.parent_id` schema/FK behavior.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
tests/** only if Coordinator explicitly allows test fixture updates
apps/*/tests/** only if Coordinator explicitly allows test fixture updates
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/bootstrap/**
apps/platform-api/config/**
apps/platform-api/database/**
apps/platform-api/routes/**
apps/platform-api/tests/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

This task should be read-only except for writing the QA report.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, and `ai-agents/workflow/file-ownership.md`.
3. Compare Backend handoff against `ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect the RBAC/menu seeder and focused tests enough to validate documented permission/menu coverage.
6. Run validation commands through Docker only.
7. If a validation command fails, capture the failure and continue any safe read-only checks.
8. Record defects as actionable items with evidence.
9. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-rbac-menu-seeders-qa-report.md`.
- QA confirms default central permissions seed with `scope_type = central`.
- QA confirms default tenant permissions seed with `scope_type = tenant`.
- QA confirms central menus seed with `required_permission_code` matching `docs/permissions.md`.
- QA confirms tenant menus seed with `required_permission_code` matching `docs/permissions.md`.
- QA confirms repeated seeding does not duplicate permission rows.
- QA confirms repeated seeding does not duplicate menu rows.
- QA confirms permission/menu scope separation is preserved.
- QA confirms focused RBAC/menu seeder tests pass through Docker.
- QA confirms full platform API test suite passes through Docker.
- QA confirms Docker runtime policy was followed during validation.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/database/seeders apps/platform-api/tests -maxdepth 4 -type f | sort
sed -n '1,260p' apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
sed -n '1,260p' apps/platform-api/tests/Feature/RbacMenuSeederTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-rbac-menu-seeders-qa-report.md
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
