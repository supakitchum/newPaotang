# back-office-p4-tenant-menu-maintenance-ticket-validation-closure - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted the focused P4 remediation QA result as a partial pass, promoted `central:menu_management`, and opened a narrow backend exception plus closure QA for the held tenant rows.

Follow-up task:

```text
back-office-p4-tenant-menu-maintenance-ticket-validation-closure
```

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
docs/back-office-crud-coverage.md
```

Orchestrator dispatched Backend Develop:

```text
ai-agents/tasks/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend.md
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-planning-orchestrator-handoff.md
```

Backend Develop completed the narrow validation change and routed back to Orchestrator:

```text
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

## Objective

Perform focused closure QA for the held P4 tenant rows:

```text
tenant:menu_management
tenant:maintenance
```

The retest must prove:

```text
tenant:menu_management has real authenticated tenant browser modal/cancel/confirm/restore evidence
tenant:maintenance rejects missing or blank ticket_id at API level
tenant:maintenance UI missing-ticket guard remains present
tenant:maintenance ticketed create/list/revoke cleanup still passes
tenant scope and X-Tenant-Id remain correct
```

Do not retest full P4 unless needed to diagnose a focused closure failure. Do not mark rows complete directly; report evidence to Coordinator for completion decisions.

## Backend Implementation Under Test

Implementation commit:

```text
0da69e0e7a35427fe093fe2144be750c0762d162
```

Backend handoff commit:

```text
d7f362637c8d7c197e28d9b4322f919aec19cdc8
```

Files Backend reports changed:

```text
apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php
apps/platform-api/tests/Feature/MaintenanceTest.php
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

Backend reports no BO, customer frontend, OpenAPI, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Relevant Prior BO Remediation Under Test

BO remediation implementation:

```text
c38aa7cd6811f2c555eedbf166eeced368afd059
```

BO remediation handoff:

```text
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

This BO remediation added the tenant menu confirmation path and tenant maintenance UI Ticket ID guard. QA still needs real tenant browser evidence for those paths.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
ai-agents/tasks/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend.md
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/backend-request-validation.md
docs/backend-maintenance-support.md
apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php
apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php
apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php
apps/platform-api/tests/Feature/MaintenanceTest.php
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
```

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential. Leave it untouched.

If these files are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Focused QA Scope

Test only:

```text
tenant:menu_management
tenant:maintenance
```

Routes:

```text
/admin/tenant/menu-management
/admin/tenant/maintenance
POST /api/v1/admin/tenant/maintenance/bypasses
GET /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
```

## Required Workflow Checks

### tenant:menu_management

Use the real authenticated tenant BO menu, not only source review or direct API calls.

Required browser checks:

```text
tenant menu-management route opens from the real tenant menu
menu tree loads from real API with tenant scope preserved
editable label, route, permission, status, sort order, and role ID fields still render
typing reason alone does not submit the menu tree
clicking Save menu opens confirmation before any PUT write
confirmation shows Tenant scope
confirmation shows reason
confirmation shows menu item count and changed item count
confirmation shows changed item identifier/label and changed field context
Cancel closes confirmation and does not submit
Confirm save submits only after confirmation
safe reversible save persists expected state and survives reload
restore returns the changed item to its original value
X-Tenant-Id remains correct for list and save calls
```

Use a safe local fixture/menu item or reversible edit. Capture browser screenshots/text snapshots for modal-before-submit, cancel-no-submit, confirm-save, restore, and tenant scope. Capture API/network evidence for no PUT before confirm and correct `X-Tenant-Id` where practical.

If browser runtime is blocked again, exhaust reasonable supported options and record exact blocker details. A source-only review is not enough for promotion because Coordinator specifically held this row for real tenant browser evidence.

### tenant:maintenance

Use API evidence and the real authenticated tenant BO maintenance page.

Required API checks:

```text
POST /admin/tenant/maintenance/bypasses without ticket_id returns 422 validation_failed
POST /admin/tenant/maintenance/bypasses with blank ticket_id returns 422 validation_failed
missing/blank ticket_id creates no bypass row
missing/blank ticket_id creates no audit write for bypass creation
missing/blank ticket_id creates no stored idempotency response for the failed mutation
ticketed bypass create returns 201 and includes ticket_id
ticketed bypass list includes the created bypass
ticketed bypass revoke returns 204
revoked list or follow-up list confirms cleanup
tenant scope and X-Tenant-Id remain correct
ticketed create idempotency replay/conflict behavior remains compatible with Backend handoff
```

Required browser/UI checks:

```text
tenant maintenance route opens from the real tenant menu
maintenance state loads from real API
events and bypasses lists still load from real API
create bypass button is disabled or blocked when reason is missing
create bypass button is disabled or blocked when Ticket ID is missing
visible validation/helper text makes missing Ticket ID clear
form submit or Enter-key path cannot create a bypass without Ticket ID
with Ticket ID and reason present, safe create bypass submits and includes ticket_id
created bypass appears in UI or API evidence
safe revoke/cleanup still works and preserves reason/context
X-Tenant-Id remains correct
```

Capture API/browser evidence for missing-ticket rejection, blank-ticket rejection, UI missing-ticket guard, successful ticketed create, list, revoke, and cleanup.

## Cross-Cutting QA Requirements

Verify:

```text
no Customer frontend is used
no implementation files are edited
no API contract/OpenAPI changes are made
no secrets, bearer tokens, local credentials, private keys, seeded passwords, or unredacted one-time tokens are written to artifacts
known carry-forward Node DEP0180, Meno media-33.jpg, or git gc warnings are recorded only if observed and not treated as new blockers unless behavior regresses
```

## Out Of Scope

Do not:

```text
edit implementation code
edit apps/back-office/**
edit apps/platform-api/**
edit apps/customer/**
edit docs/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/handoffs/**
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, or scheduler commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, local credentials, private keys, or unredacted one-time tokens into artifacts
use Customer frontend
change backend validation, tenant isolation, maintenance, menu, permission, or security semantics
mark rows complete
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/**
```

Must not edit:

```text
apps/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ops/**
scripts/**
load-tests/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review Backend implementation diff from `0da69e0e7a35427fe093fe2144be750c0762d162`.
5. Review BO remediation behavior from `c38aa7cd6811f2c555eedbf166eeced368afd059`.
6. Run Docker-only validation commands.
7. Seed local backend data before API/browser QA.
8. Create only safe local Docker QA fixture data needed for reversible writes.
9. Capture API evidence before browser workflow submission.
10. Test real authenticated BO tenant menu-management and tenant maintenance routes.
11. Capture screenshots/snapshots/text artifacts for tenant menu confirmation, cancel-no-submit, confirm-save, restore, missing-ticket UI guard, API rejection, ticketed create/list/revoke cleanup, and scope evidence.
12. Redact secrets/tokens/local credentials from artifacts before committing.
13. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

If a test filter has no matching tests, record the exact command/output in the QA report and continue with the remaining validation and browser/API evidence.

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

## Expected QA Output

Write:

```text
ai-agents/reports/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/**
```

Report must include:

```text
HEAD under test
Backend implementation commit under test
Backend handoff commit under test
BO remediation commit under test
Docker validation command results
API evidence summary
browser evidence summary
per-row PASS/FAIL/HOLD status for tenant:menu_management and tenant:maintenance
tenant menu-management real browser modal/cancel/confirm/restore result
tenant maintenance API missing/blank ticket_id rejection result
tenant maintenance UI missing-ticket guard result
ticketed create/list/revoke cleanup result
tenant scope and X-Tenant-Id results
secret/token redaction statement
defects with severity, owner recommendation, and evidence path
whether closure is ready for Coordinator review
unrelated dirty workspace files observed
```

Artifacts should include:

```text
validation command logs
API before/after evidence for maintenance missing/blank ticket rejection and ticketed create/revoke
browser screenshots and text snapshots for real tenant menu navigation
tenant menu confirmation modal evidence
tenant menu cancel-no-submit evidence
tenant menu confirm-save/restore evidence
tenant maintenance missing-ticket guard evidence
scope/header evidence where practical
```

## Routing After QA

Route back to:

```text
Coordinator
```

If QA passes, Coordinator can decide whether to promote held P4 rows. If QA finds defects, report severity and likely owner. If QA finds frozen contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing implementation.
