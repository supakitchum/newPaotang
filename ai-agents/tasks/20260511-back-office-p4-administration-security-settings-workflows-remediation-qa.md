# back-office-p4-administration-security-settings-workflows-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator reviewed P4 administration/security/settings QA and accepted the result as FAIL with two P2 findings.

Coordinator opened focused remediation:

```text
back-office-p4-administration-security-settings-workflows-remediation
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
docs/back-office-crud-coverage.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-planning-orchestrator-handoff.md
```

BO Develop completed remediation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

## Objective

Perform focused QA retest for the P4 remediation only.

The retest must prove that:

```text
tenant maintenance bypass create requires Ticket ID and reason before submission
central menu-management save shows confirmation with scope and changed-item context before submitting
tenant menu-management save shows confirmation with scope and changed-item context before submitting
```

Do not retest the full P4 suite unless needed to diagnose a focused failure. Do not mark rows complete directly; report evidence to Coordinator for completion decisions.

## BO Remediation Under Test

Implementation commit:

```text
c38aa7cd6811f2c555eedbf166eeced368afd059
```

BO handoff commit:

```text
f9d79d5b4afc327516cf1a17f4d23c567a298437
```

Files BO reports changed:

```text
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/pages/admin/tenant/maintenance.vue
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

BO reports no backend, customer frontend, OpenAPI, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
ai-agents/tasks/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Maintenance*
apps/platform-api/tests/Feature/*Menu*
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
central:menu_management
tenant:menu_management
tenant:maintenance
```

Routes:

```text
/admin/central/menu-management
/admin/tenant/menu-management
/admin/tenant/maintenance
```

## Required Workflow Checks

### central:menu_management

Use the real authenticated central BO menu and test:

```text
menu tree loads from real API
editable label, route, permission, status, sort order, and role ID fields still render
typing reason alone does not immediately submit the menu tree
clicking Save menu opens confirmation before any PUT write
confirmation shows Central scope
confirmation shows reason
confirmation shows menu item count and changed item count
confirmation shows changed item identifier/label and changed field context
Cancel closes confirmation and does not submit
Confirm save submits the existing menu tree save payload only after confirmation
safe reversible save persists expected state and survives reload
reset restores the loaded state and clears pending confirmation context
```

Use a safe local fixture/menu item or reversible edit. Capture before/after API evidence and browser evidence for modal-before-submit, cancel-no-submit, confirm-save, and restore.

### tenant:menu_management

Use the real authenticated tenant BO menu and test:

```text
menu tree loads from real API with tenant scope preserved
editable label, route, permission, status, sort order, and role ID fields still render
typing reason alone does not immediately submit the menu tree
clicking Save menu opens confirmation before any PUT write
confirmation shows Tenant scope
confirmation shows reason
confirmation shows menu item count and changed item count
confirmation shows changed item identifier/label and changed field context
Cancel closes confirmation and does not submit
Confirm save submits the existing menu tree save payload only after confirmation
safe reversible save persists expected state and survives reload
reset restores the loaded state and clears pending confirmation context
X-Tenant-Id remains correct
```

Use a safe local fixture/menu item or reversible edit. Capture before/after API evidence and browser evidence for modal-before-submit, cancel-no-submit, confirm-save, restore, and tenant scope.

### tenant:maintenance

Use the real authenticated tenant BO menu and test:

```text
maintenance state loads from real API
events and bypasses lists still load from real API
create bypass button is disabled or blocked when reason is missing
create bypass button is disabled or blocked when Ticket ID is missing
visible validation/helper text makes missing Ticket ID clear
form submit or Enter-key path cannot create a bypass without Ticket ID
with Ticket ID and reason present, safe create bypass submits and includes ticket_id
created bypass appears in the list or API evidence
safe revoke/cleanup still works and preserves reason/context
X-Tenant-Id remains correct
```

Important residual backend note:

```text
Coordinator asked BO to fix UI only because backend is frozen.
If direct API still accepts ticket_id: null, record it as known residual backend behavior, not a failure of this UI remediation unless Coordinator changes the scope.
```

Capture API/browser evidence for missing-ticket blocked UI, successful ticketed create, and cleanup/revoke.

## Cross-Cutting QA Requirements

Verify:

```text
no Customer frontend is used
no backend code is edited
no API contract/OpenAPI changes are needed for this focused retest
no secrets, bearer tokens, local credentials, private keys, seeded passwords, or unredacted one-time support tokens are written to artifacts
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
change backend validation, tenant isolation, support-access, maintenance, menu, permission, or security semantics
mark P4 rows complete
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO remediation diff from `c38aa7cd6811f2c555eedbf166eeced368afd059`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create only safe local Docker QA fixture data needed for reversible writes.
8. Capture API evidence before browser workflow submission.
9. Test the real authenticated BO central and tenant menus for the three focused rows.
10. Capture screenshots/snapshots/text artifacts for confirmation modals, reason guards, ticket guard, submitted write results, scope evidence, and cleanup.
11. Redact secrets/tokens/local credentials from artifacts before committing.
12. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

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
ai-agents/reports/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
BO handoff commit under test
Docker validation command results
API evidence summary
browser evidence summary
per-row PASS/FAIL/HOLD status for central:menu_management, tenant:menu_management, tenant:maintenance
central menu confirmation result
tenant menu confirmation result
maintenance Ticket ID guard result
reason guard and cancel-no-submit results
central/tenant scope and X-Tenant-Id results
secret/token redaction statement
defects with severity, owner recommendation, and evidence path
whether focused remediation is ready for Coordinator review
unrelated dirty workspace files observed
```

Artifacts should include:

```text
validation command logs
API before/after evidence for reversible menu saves and maintenance bypass create/revoke
browser screenshots and text snapshots for real-menu navigation
confirmation modal evidence
cancel-no-submit evidence
missing-ticket guard evidence
scope/header evidence where practical
```

## Routing After QA

Route back to:

```text
Coordinator
```

If QA passes, Coordinator can decide whether to promote affected P4 rows. If QA finds defects, report severity and likely owner. If QA finds frozen backend contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing backend or permissions.
