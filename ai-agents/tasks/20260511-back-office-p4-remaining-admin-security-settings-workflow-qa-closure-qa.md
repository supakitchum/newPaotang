# back-office-p4-remaining-admin-security-settings-workflow-qa-closure - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted the focused tenant menu/maintenance closure QA as PASS, promoted `tenant:menu_management` and `tenant:maintenance`, and closed the narrow backend exception for tenant maintenance bypass `ticket_id` validation.

Open next P4 closure task:

```text
back-office-p4-remaining-admin-security-settings-workflow-qa-closure
```

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-report.md
docs/back-office-crud-coverage.md
```

Official BO completion before this QA task:

```text
29 / 56 complete = 51.8% verified complete
```

Backend is frozen again except for recorded API-gap decisions:

```text
central:master_stock
tenant:commission_transactions
```

Customer frontend remains frozen.

## Objective

Perform focused real-menu QA closure for the remaining P4 administration, security, and settings rows that are implementation-ready but still need workflow evidence.

QA must use real authenticated BO central and tenant menu workflows, not route/catalog presence alone. Verify create/update/disable/archive/save/domain/support actions with safe local fixtures and cleanup. Capture before/after API evidence where writes occur. Prove central/tenant scope headers are correct. Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.

Do not mark rows complete directly; report evidence to Coordinator for completion decisions.

## Implementation Under Test

Primary BO P4 implementation commit:

```text
52e0f728594bdeda4ae0c6262c22c3cae8698a40
```

Relevant P4 remediation commits already accepted for other rows:

```text
c38aa7cd6811f2c555eedbf166eeced368afd059
0da69e0e7a35427fe093fe2144be750c0762d162
```

Latest Coordinator review head:

```text
90a13d82c135697208efa2fc090a7e42fdf9f585
```

Relevant prior handoffs:

```text
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa-report.md
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-qa.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/tenant/support-access/index.vue
apps/back-office/pages/admin/tenant/support-access/[id].vue
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Role*
apps/platform-api/tests/Feature/*Setting*
apps/platform-api/tests/Feature/*Support*
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

Test these rows:

```text
central:admin_users
central:roles_permissions
central:system_settings
tenant:admin_users
tenant:roles_permissions
tenant:support_access_logs
tenant:settings
```

Browser routes:

```text
/admin/central/admin-users
/admin/central/roles
/admin/central/system-settings
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/support-access
/admin/tenant/support-access/{support_access_id}
/admin/tenant/settings
```

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

### central:admin_users

Use safe local QA fixture data and test from the real central menu:

```text
list renders from real API
detail opens for an admin user row
typed create form renders identity/status/password/role ID fields
typed update form renders prefilled identity/status/role ID fields
disable confirmation shows admin identity, scope, and target context
disable requires operator reason before submission
password or secret values are not displayed after save
safe create/update/disable submission persists expected state
before/after API evidence proves the created fixture and disabled state
```

Do not disable the active QA account or seeded owner account. Create a safe local admin fixture if needed and clean up or leave it disabled with explicit QA label.

### central:roles_permissions

Use safe local QA fixture data and test from the real central menu:

```text
list renders from real API
typed create role form renders name/key/status/permission-code controls
typed update role form preserves and edits permission codes
archive confirmation shows role name/key/scope context
archive requires operator reason before submission
safe create/update/archive submission persists expected state
permission codes are handled as explicit operator fields, not arbitrary raw JSON
before/after API evidence proves create/update/archive
```

### central:system_settings

Use the real central system settings menu:

```text
settings load from real API
known typed fields render for platform/API/release/backend-gap values
save payload includes only intended known fields
save action shows context and reason behavior implemented by BO
safe settings save persists expected state and survives reload
restore original values after the write
generic arbitrary JSON is not the only operator-facing workflow
```

Capture before/after API evidence for save and restore.

### tenant:admin_users

Use safe local QA fixture data and test from the real tenant menu:

```text
list renders with tenant scope preserved
detail opens for a tenant admin user row
typed create form renders identity/status/password/tenant role ID fields
typed update form renders prefilled identity/status/tenant role ID fields
disable confirmation shows admin identity, tenant, scope, and target context
disable requires operator reason before submission
password or secret values are not displayed after save
safe create/update/disable submission persists expected state
X-Tenant-Id remains correct on list/detail/create/update/disable requests
before/after API evidence proves the created fixture and disabled state
```

Do not disable the active QA tenant owner account. Create a safe local tenant admin fixture if needed and clean up or leave it disabled with explicit QA label.

### tenant:roles_permissions

Use safe local QA fixture data and test from the real tenant menu:

```text
list renders with tenant scope preserved
typed create role form renders name/key/status/permission-code controls
typed update role form preserves and edits permission codes
archive confirmation shows role name/key/tenant context
archive requires operator reason before submission
safe create/update/archive submission persists expected state
permission codes are handled as explicit operator fields, not arbitrary raw JSON
X-Tenant-Id remains correct on list/create/update/archive requests
before/after API evidence proves create/update/archive
```

### tenant:support_access_logs

Use safe local QA fixture data and test from real tenant support access menus:

```text
list renders from real API with tenant scope preserved
create modal uses backend contract support scopes and allowed status values
safe create submission persists expected request state
detail opens for the created support access row
approve, revoke, impersonate, elevated-actions, and end-session actions show strong request/user/tenant/context
each security-sensitive action is disabled or blocked until reason is present
safe action submissions persist expected state where fixture permits
one-time tokens, secrets, bearer tokens, and passwords are not exposed in screenshots, snapshots, logs, or committed artifacts
support access remains tenant-scoped and does not cross tenants
X-Tenant-Id remains correct on list/create/detail/action requests
```

If an action returns a one-time token, record only that a redacted token was returned and verify it is not displayed again. Capture before/after API evidence for submitted actions.

### tenant:settings

Use the real tenant settings menu:

```text
settings load from real API with tenant scope preserved
theme/branding panel loads and saves through /admin/tenant/theme
domain list loads from real API
domain detail opens for a domain row
typed settings fields render for site/SEO/maintenance/API values
typed theme fields render for brand/color/logo-like values surfaced by BO
typed domain create/update forms render expected domain/status/primary fields
verify domain action shows domain context and required reason where implemented
delete domain confirmation shows domain context and required reason
safe settings/theme/domain create/update/verify/delete submissions persist expected state
restore original settings/theme values after writes
X-Tenant-Id remains correct on settings/theme/domain requests
```

Capture before/after API evidence for settings save/restore, theme save/restore, and domain create/detail/update/verify/delete cleanup.

## Cross-Cutting QA Requirements

Verify:

```text
central and tenant navigation links open the correct routes
hard refresh/direct open after real-menu navigation does not render login for an authenticated session
loading, empty, error, disabled, success, and validation states are coherent for the tested forms/actions
reason guards cannot be bypassed from the UI for security-sensitive actions
confirmation modals show enough record context to prevent wrong-target actions
idempotency behavior is used where the UI/API exposes or supports it
write submissions do not leak secrets or local credentials into artifacts
mobile sanity at 390x844 for at least one dense central workflow and one dense tenant workflow
known carry-forward Vue hydration warnings, Node DEP0180, Meno media-33.jpg, or git gc warnings are recorded only if observed and not treated as new blockers unless behavior regresses
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
copy real secrets, tokens, bearer tokens, customer data, local credentials, private keys, seeded passwords, or unredacted one-time support tokens into artifacts
use Customer frontend
change backend validation, tenant isolation, support-access, settings, role, admin-user, permission, or security semantics
mark rows complete
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review the P4 BO implementation diff from `52e0f728594bdeda4ae0c6262c22c3cae8698a40`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create only safe local Docker QA fixture data needed for reversible writes.
8. Capture API evidence before browser workflow submission.
9. Test real authenticated BO central and tenant menus for all scoped rows.
10. Capture screenshots/snapshots/text artifacts for forms, confirmations, reason guards, submitted write results, scope evidence, mobile sanity, and cleanup.
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
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=Support
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
ai-agents/reports/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/**
```

Report must include:

```text
HEAD under test
implementation commits under test
Docker validation command results
API evidence summary
browser evidence summary
per-row PASS/FAIL/HOLD status for all scoped rows
central/tenant admin user workflow results
central/tenant role workflow results
central system settings save/restore result
tenant support access workflow results
tenant settings/theme/domain workflow results
reason guard and confirmation context results
central/tenant scope and X-Tenant-Id results
mobile sanity results
secret/token redaction statement
defects with severity, owner recommendation, and evidence path
whether closure is ready for Coordinator review
unrelated dirty workspace files observed
```

Artifacts should include:

```text
validation command logs
API before/after evidence for submitted writes/actions
browser screenshots and text snapshots for real-menu navigation
form and confirmation modal evidence
reason-guard evidence
scope/header evidence where practical
mobile screenshots for selected dense central and tenant workflows
```

## Routing After QA

Route back to:

```text
Coordinator
```

If QA passes, Coordinator can decide whether to promote remaining P4 rows. If QA finds defects, report severity and likely owner. If QA finds frozen contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing implementation.
