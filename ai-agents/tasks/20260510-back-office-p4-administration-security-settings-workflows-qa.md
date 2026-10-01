# back-office-p4-administration-security-settings-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator approved focused P3 tenant sync-log remediation QA and opened the next BO priority:

```text
back-office-p4-administration-security-settings-workflows
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

## Objective

Perform real Back Office P4 administration, security, maintenance, and settings workflow QA.

QA must test authenticated central and tenant menus, not only direct URLs or build/lint/unit checks. Verify typed forms, security-sensitive confirmations, operator reason guards, central/tenant scope behavior, `X-Tenant-Id` behavior, idempotency where visible/supported, loading/error/empty states, responsive behavior, and that sensitive data is not exposed in screenshots or artifacts.

Do not mark any P4 row complete unless the workflow is verified from the real BO menu with evidence. These rows remain `partial` until Coordinator reviews the QA report and decides promotion.

## BO Implementation Under Test

Implementation commit:

```text
52e0f728594bdeda4ae0c6262c22c3cae8698a40
```

BO handoff commit:

```text
da664c6d59241165adc148765a5e1a218b5a6624
```

Files BO reports changed:

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/admin/tenant/support-access/[id].vue
apps/back-office/pages/admin/tenant/support-access/index.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

BO reports backend, customer frontend, OpenAPI, compose, GitHub workflow, Board, decision, task, and report files were not changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
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
apps/back-office/components/AdminMenuTreeEditor.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/admin/tenant/support-access/index.vue
apps/back-office/pages/admin/tenant/support-access/[id].vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Role*
apps/platform-api/tests/Feature/*Menu*
apps/platform-api/tests/Feature/*Setting*
apps/platform-api/tests/Feature/*Maintenance*
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

## QA Scope

Test these P4 rows:

```text
central:admin_users
central:roles_permissions
central:menu_management
central:system_settings
tenant:admin_users
tenant:roles_permissions
tenant:menu_management
tenant:maintenance
tenant:support_access_logs
tenant:settings
```

## Browser Routes To Test

Central:

```text
/admin/central/admin-users
/admin/central/roles
/admin/central/menu-management
/admin/central/system-settings
```

Tenant:

```text
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/maintenance
/admin/tenant/support-access
/admin/tenant/support-access/{support_access_id}
/admin/tenant/settings
```

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

### central:admin_users

Use safe local QA fixture data and test from the real central menu:

```text
list renders from the real API
detail opens for an admin user row
typed create form renders identity/status/password/role ID fields
typed update form renders prefilled identity/status/role ID fields
disable confirmation shows admin identity, scope, and target context
disable requires operator reason before submission
password or secret values are not displayed after save
safe create/update/disable submission persists expected state where fixture permits
```

Capture before/after API evidence for submitted writes. If disable would affect the active QA account or seeded owner account, create a safe local admin fixture first or record the exact reason the destructive action was not submitted.

### central:roles_permissions

Use safe local QA fixture data and test:

```text
list renders from the real API
typed create role form renders name/key/status/permission-code controls
typed update role form preserves existing permission codes
archive confirmation shows role name/key/scope context
archive requires operator reason before submission
safe create/update/archive submission persists expected state where fixture permits
permission codes are handled as explicit operator fields, not arbitrary raw JSON
```

Capture before/after API evidence for submitted writes.

### central:menu_management

Test the typed menu tree editor:

```text
menu tree loads from real API
operator can inspect item scope, route, permission, status, sort order, and role IDs
editing label/route/permission/status/sort order/role IDs updates the pending payload
reset restores the current loaded state
save confirmation shows central scope and changed item context
save requires operator reason before submission
safe save submission persists expected state and survives reload
```

Use a safe local fixture/menu item or reversible edit. Capture before/after API evidence and browser evidence before submit, after submit, and after reload.

### central:system_settings

Test known-key settings workflow:

```text
settings load from the real API
known typed fields render for platform/API/release/backend-gap values
save payload only includes intended known fields
save action shows context and required reason where implemented
safe settings save persists expected state and survives reload
generic arbitrary JSON is not the only operator-facing workflow for this row
```

Capture before/after API evidence for submitted saves.

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
safe create/update/disable submission persists expected state where fixture permits
```

Capture before/after API evidence and confirm `X-Tenant-Id` remains correct.

### tenant:roles_permissions

Use safe local QA fixture data and test:

```text
list renders with tenant scope preserved
typed create role form renders name/key/status/permission-code controls
typed update role form preserves existing permission codes
archive confirmation shows role name/key/tenant context
archive requires operator reason before submission
safe create/update/archive submission persists expected state where fixture permits
permission codes are handled as explicit operator fields, not arbitrary raw JSON
```

Capture before/after API evidence and confirm `X-Tenant-Id` remains correct.

### tenant:menu_management

Test the typed tenant menu tree editor:

```text
menu tree loads from real API with tenant scope preserved
operator can inspect item scope, route, permission, status, sort order, and role IDs
editing label/route/permission/status/sort order/role IDs updates the pending payload
reset restores the current loaded state
save confirmation shows tenant scope and changed item context
save requires operator reason before submission
safe save submission persists expected state and survives reload
```

Use a safe local fixture/menu item or reversible edit. Capture before/after API evidence and confirm `X-Tenant-Id` remains correct.

### tenant:maintenance

Test the dedicated maintenance page:

```text
maintenance state loads from real API
events and bypasses lists load from real API
save maintenance form requires reason and includes ticket fields where surfaced
create bypass form requires reason/ticket and useful target context
revoke bypass confirmation shows bypass/user/context and requires reason
safe save/create/revoke submissions persist expected state where fixture permits
tenant scope and `X-Tenant-Id` remain correct
maintenance changes do not mutate unrelated tenants
```

Capture before/after API evidence for maintenance save, bypass create, and bypass revoke where safe. If QA enables maintenance mode, restore the safe seeded state before finishing and record the restore.

### tenant:support_access_logs

Test support access list, create, detail, and actions:

```text
list renders from real API with tenant scope preserved
create modal uses backend contract support scopes and allowed status values
safe create submission persists expected request state where fixture permits
detail opens for a support access row
approve/revoke/impersonate/elevated-actions/end-session actions show strong request/user/tenant/context
each security-sensitive action is disabled or blocked until reason is present
safe action submissions persist expected state where fixture permits
one-time tokens, secrets, bearer tokens, and passwords are not exposed in screenshots, snapshots, logs, or committed artifacts
support access remains tenant-scoped and does not cross tenants
```

Capture before/after API evidence for submitted actions. Redact sensitive response fields before writing artifacts. If an action returns a one-time token, record only that a redacted token was returned and verify it is not displayed again.

### tenant:settings

Test tenant settings, theme, and domain workflows:

```text
settings load from real API with tenant scope preserved
theme/branding panel loads and saves through `/admin/tenant/theme`
domain list loads from real API
domain detail opens for a domain row
typed settings fields render for site/SEO/maintenance/API values
typed theme fields render for brand/color/logo-like values surfaced by BO
typed domain create/update forms render expected domain/status/primary fields
verify domain action shows domain context and required reason where implemented
delete domain confirmation shows domain context and required reason
safe settings/theme/domain create/update/verify/delete submissions persist expected state where fixture permits
```

Capture before/after API evidence and confirm `X-Tenant-Id` remains correct.

## Cross-Cutting QA Requirements

Verify:

```text
central and tenant navigation links open the correct P4 routes
hard refresh/direct open after real-menu navigation does not render login for an authenticated session
loading, empty, error, disabled, success, and validation states are coherent
reason guards cannot be bypassed from the UI for security-sensitive actions
confirmation modals show enough record context to prevent wrong-target actions
idempotency behavior is used where the UI/API exposes or supports it
write submissions do not leak secrets or local credentials into artifacts
mobile sanity at 390x844 for at least one dense central workflow and one dense tenant workflow
known carry-forward Vue hydration warning, Node `DEP0180`, or missing Meno image warning should be recorded only if observed and not treated as a new P4 blocker unless behavior regresses
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
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, local credentials, private keys, or unredacted one-time support tokens into artifacts
use Customer frontend
change backend security, permission, tenant, support-access, or maintenance semantics
change API contracts or OpenAPI
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `52e0f728594bdeda4ae0c6262c22c3cae8698a40`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create only safe local Docker QA fixture data needed for reversible writes.
8. Capture API evidence before browser workflow submission.
9. Test the real authenticated BO central and tenant menus for all P4 rows.
10. Capture screenshots/snapshots/text artifacts for forms, confirmations, reason guards, submitted write results, scope evidence, and mobile sanity.
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
docker compose run --rm platform-api php artisan test --filter=Maintenance
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
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
BO handoff commit under test
Docker validation command results
API evidence summary
browser evidence summary
per-row PASS/FAIL/HOLD status
security-sensitive reason guard results
central/tenant scope and X-Tenant-Id results
secret/token redaction statement
mobile sanity results
defects with severity, owner recommendation, and evidence path
rows recommended for Coordinator completion promotion, if any
rows that must remain partial, if any
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

If QA passes, Coordinator can decide whether to promote some or all P4 rows to complete. If QA finds implementation defects, report severity and likely owner. If QA finds frozen backend contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing backend or permissions.
