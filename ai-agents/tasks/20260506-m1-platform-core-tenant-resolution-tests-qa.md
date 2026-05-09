# m1-platform-core-tenant-resolution-tests - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused revision for QA defect D1. Rerun focused Docker validation and write a follow-up QA report for Coordinator review.

This QA task follows:

```text
ai-agents/decisions/20260506-m1-platform-core-qa-review-decision.md
ai-agents/tasks/20260506-m1-platform-core-tenant-resolution-tests-backend.md
ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md
```

## Objective

Verify that inactive tenant and inactive partner host resolution are now covered by automated tests, that the relevant tests pass through Docker, and that no out-of-scope changes were made.

## Source Of Truth

- ai-agents/decisions/20260506-m1-platform-core-qa-review-decision.md
- ai-agents/tasks/20260506-m1-platform-core-tenant-resolution-tests-backend.md
- ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md
- ai-agents/reports/20260506-m1-platform-core-qa-report.md
- ai-agents/tasks/20260506-m1-platform-core-backend.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- docs/openapi.yaml
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Review the Backend revision task and Backend handoff.
- Inspect `apps/platform-api/tests/Feature/TenantResolutionTest.php`.
- Confirm automated coverage exists for inactive `partner_tenants.status` returning `tenant_inactive`.
- Confirm automated coverage exists for inactive `partners.status` returning `tenant_inactive`.
- Confirm Backend did not change implementation logic unless required by a real failing test.
- Confirm no customer or back-office implementation files were changed.
- Run focused tenant resolution test validation through Docker only.
- Run full platform API test suite through Docker only.
- Write a follow-up QA report for Coordinator.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not add permission/menu seeders.
- Do not change `admin_menus.parent_id` schema.
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
3. Compare the Backend revision handoff against the Backend revision task acceptance criteria.
4. Inspect `apps/platform-api/tests/Feature/TenantResolutionTest.php` to confirm the two new inactive-state tests exist.
5. Inspect `git status --short` for changed files and report whether changes are within approved scope.
6. Run the required Docker validation commands.
7. Record pass/fail, defects, risks, and not-tested items.
8. Write the follow-up QA report to the required report path.

## Acceptance Criteria

- QA confirms inactive tenant status test exists and asserts `tenant_inactive`.
- QA confirms inactive partner status test exists and asserts `tenant_inactive`.
- QA confirms focused `TenantResolutionTest` passes through Docker.
- QA confirms full `platform-api` test suite passes through Docker.
- QA confirms no business logic changes were made unless justified by a real behavior bug.
- QA confirms no out-of-scope customer/back-office/source-of-truth document changes were made for this revision.
- QA writes follow-up report to `ai-agents/reports/20260506-m1-platform-core-tenant-resolution-tests-qa-report.md`.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
sed -n '1,260p' apps/platform-api/tests/Feature/TenantResolutionTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-platform-core-tenant-resolution-tests-qa-report.md
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
