# back-office-p4-tenant-menu-maintenance-ticket-validation-closure - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed focused P4 remediation QA and accepted the result as a partial pass.

Open follow-up task:

```text
back-office-p4-tenant-menu-maintenance-ticket-validation-closure
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
docs/back-office-crud-coverage.md
```

Coordinator promoted:

```text
central:menu_management
```

Official BO completion is now:

```text
27 / 56 complete = 48.2% verified complete
```

Held rows:

```text
tenant:menu_management
tenant:maintenance
```

This task is Backend-only and covers only the narrow tenant maintenance validation exception approved by Coordinator.

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: 045c1d05b7bdbf2018e39379b9f0ff410d0a69e1
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, clean, or include them as part of this task:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential.

If new or overlapping dirty files appear in backend-owned files before you edit, stop and report them to Orchestrator.

## Objective

Implement the narrow backend exception:

```text
POST /admin/tenant/maintenance/bypasses must reject missing or blank ticket_id.
```

Preserve:

```text
successful ticketed bypass create
bypass list/revoke
tenant scope and X-Tenant-Id behavior
reason requirement
idempotency-key behavior
existing BO UI guard behavior
```

No other backend scope is reopened.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
ai-agents/tasks/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/backend-request-validation.md
docs/backend-maintenance-support.md
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php
apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php
apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php
apps/platform-api/tests/Feature/MaintenanceTest.php
```

## Focused Scope

Affected endpoint:

```text
POST /api/v1/admin/tenant/maintenance/bypasses
```

Primary likely implementation area:

```text
apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php
```

Test area:

```text
apps/platform-api/tests/Feature/MaintenanceTest.php
```

You may touch the controller/service only if the validator alone cannot satisfy the approved behavior, and you must explain why in the handoff.

## Required Backend Behavior

Validation:

```text
missing ticket_id returns 422 validation_failed
blank ticket_id returns 422 validation_failed
ticket_id exceeding the existing max length still returns 422 validation_failed
ticketed bypass create still returns 201
validation failure creates no bypass row
validation failure creates no audit write and no idempotency stored response for the failed mutation
```

Preserve:

```text
actor_type, actor_id, and reason remain required
actor validation remains tenant-scoped
ticketed create still stores and returns ticket_id
ticketed create idempotency replay remains compatible
ticketed create with same Idempotency-Key but changed request meaning still conflicts according to existing idempotency rules
list/revoke behavior remains unchanged
tenant isolation remains unchanged
response envelope/error conventions remain unchanged
```

Expected error shape should follow existing validation responses, for example:

```text
HTTP 422
error.code = validation_failed
errors.ticket_id includes a required-field message
```

Do not update OpenAPI unless Coordinator explicitly opens contract editing.

## Out Of Scope

Do not:

```text
edit apps/back-office/**
edit apps/customer/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/reports/**
change tenant menu-management
change BO UI
change maintenance mode semantics
change support access
change unrelated validation contracts
change permission/security semantics outside ticket_id validation
claim staging, production, client delivery, Gate 5, or final release approval
run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, or build commands on the host machine
```

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php
apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php
apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php
apps/platform-api/tests/Feature/MaintenanceTest.php
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

If another backend file is absolutely required, keep the change narrowly scoped and document the reason in the handoff.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review the QA residual backend evidence:

```text
ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/api/focused-api-evidence.json
```

5. Add required validation for missing and blank `ticket_id` on maintenance bypass create.
6. Add or update focused backend tests in `MaintenanceTest.php` proving:

```text
missing ticket_id is rejected with 422 validation_failed
blank ticket_id is rejected with 422 validation_failed
ticketed create/list/revoke still passes
tenant isolation remains intact
reason/idempotency behavior remains intact
```

7. Confirm no BO/customer/OpenAPI files were edited.
8. Run Docker-only validation commands.
9. Write Backend handoff.
10. Commit and push your implementation and handoff.

## Required Validation

Use Docker commands only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

If a test filter has no matching tests, record the exact command/output and continue.

Local static reads/checks are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

Do not run host local PHP/Composer/Artisan, Node/npm/Nuxt/Vite, tests, builds, migrations, queues, or scheduler commands.

## Required Backend Handoff

Write:

```text
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

The handoff must include:

```text
implementation summary
files changed
endpoint changed
validation behavior for missing/blank ticket_id
ticketed create/list/revoke preservation
tenant scope and X-Tenant-Id preservation
idempotency behavior notes
validation commands and results
commit hash
unrelated dirty files observed
risks or Coordinator questions
next agent: Orchestrator
```

## Next Agent

Orchestrator
