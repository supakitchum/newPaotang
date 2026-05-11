# back-office-p4-administration-security-settings-workflows-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed P4 administration/security/settings QA and accepted the result as FAIL.

Open focused remediation:

```text
back-office-p4-administration-security-settings-workflows-remediation
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
docs/back-office-crud-coverage.md
```

Official BO completion remains:

```text
26 / 56 complete = 46.4% verified complete
```

No P4 rows were promoted. Do not mark P4 rows complete in this remediation; leave completion decisions to focused QA and Coordinator review.

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: 260a8ab52c7cc19514923287b3b5d5299c025783
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

If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

## Objective

Fix only the two P2 issues found by QA:

```text
1. Tenant maintenance bypass create must require Ticket ID before submission.
2. Central and tenant menu-management saves must show confirmation with scope and changed-item context before submitting the menu tree.
```

Preserve all prior P4 implementation behavior outside these defects.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/package.json
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/tenant/maintenance.vue
```

Backend/OpenAPI files are read-only contract references unless Coordinator explicitly authorizes backend work:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Maintenance*
apps/platform-api/tests/Feature/*Menu*
```

## Focused Scope

Affected rows:

```text
central:menu_management
tenant:menu_management
tenant:maintenance
```

Affected routes:

```text
/admin/central/menu-management
/admin/tenant/menu-management
/admin/tenant/maintenance
```

## Required Remediation Behavior

### tenant:maintenance

Fix:

```text
Require Ticket ID before tenant maintenance bypass create submission.
Preserve existing reason guard.
Preserve operator context.
Preserve tenant scope and X-Tenant-Id behavior.
Preserve maintenance state save, events list, bypass list, and bypass revoke behavior.
```

Expected UI behavior:

```text
Create bypass submit button is disabled or blocked until ticket ID and reason are both present.
Validation state/message makes the missing ticket ID clear.
The outgoing bypass create request includes the typed ticket ID.
No password, token, credential, or private value is exposed.
```

Do not add backend validation in this task. If you believe API-level validation is required, document it in the BO handoff and route to Coordinator under the frozen-backend rule.

### central:menu_management and tenant:menu_management

Fix:

```text
Add confirmation before saving the menu tree for both central and tenant scopes.
Confirmation must show scope and changed-item context.
Preserve the required reason guard.
Preserve reset workflow.
Preserve editable label, route, permission, status, sort order, and role ID fields.
Preserve central/tenant scope behavior.
```

Expected UI behavior:

```text
Typing a reason alone does not immediately submit the menu tree.
Clicking save opens a confirmation step/modal.
Confirmation includes whether the save is central or tenant scoped.
Confirmation summarizes changed item context, such as changed labels/routes/permissions/status/sort order/role IDs and item identifiers where available.
Confirming the modal submits the existing menu tree save payload with reason.
Canceling the modal does not submit.
Reset still restores the loaded state and clears pending save context as appropriate.
```

If no changed item can be computed because the loaded data lacks stable identifiers, show the best available context and document the limitation in the handoff.

## Out Of Scope

Do not:

```text
edit backend code
edit customer frontend
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/reports/**
change permission/security semantics
change API contracts
change unrelated P4 rows
mark P4 rows complete
claim staging, production, Gate 5, or final release readiness
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, or scheduler commands on the host machine
```

You may update `docs/back-office-crud-coverage.md` only to reflect remediation-ready/focused-QA-pending status for the affected rows. Do not promote rows to complete.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

## Required Validation

Run Docker-only validation:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
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

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, migrations, queues, or scheduler commands.

## Browser / Manual Smoke Expected

After Docker validation, perform a focused browser smoke if practical:

```text
/admin/central/menu-management shows confirmation before save
/admin/tenant/menu-management shows confirmation before save
/admin/tenant/maintenance bypass create requires ticket ID and reason
```

If local browser tooling is blocked by the known stale-session/browser runtime issue, record the blocker and keep the Docker validation/API/static evidence.

## Required BO Handoff

Write:

```text
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

The handoff must include:

```text
implementation summary
files changed
affected rows/routes
confirmation behavior for central and tenant menu-management
ticket ID guard behavior for tenant maintenance bypass create
validation commands and results
browser/manual smoke results or blockers
commit hash
unrelated dirty files observed
risks or Coordinator questions
next agent: Orchestrator
```

Commit your implementation and handoff when validation is complete. Push `develop` so Orchestrator and QA can see the work.

## Next Agent

Orchestrator
