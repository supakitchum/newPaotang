# back-office-p4-administration-security-settings-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved the focused `tenant:sync_logs` remediation QA and promoted that row to complete.

Open the next BO priority:

```text
back-office-p4-administration-security-settings-workflows
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Official BO completion before this task:

```text
26 / 56 complete = 46.4% verified complete
```

Do not count any P4 row as complete until BO implementation is done and QA verifies the real menu workflow.

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: 17cd2045b7fb20a4f6b2cdb3aa4ab611116e9244
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, or clean them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from Coordinator/QA context:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/*.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential used to generate evidence.

## Objective

Implement P4 Back Office administration, security, maintenance, and settings workflows against the frozen backend contract.

Move selected P4 rows from generic/partial coverage toward real operator workflows. Use typed/security-appropriate forms and confirmations where practical, avoid unsafe generic JSON-only handling for security-sensitive actions, preserve central/tenant authorization behavior, update the CRUD coverage matrix notes, and hand back to Orchestrator for QA dispatch.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-report.md
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
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminModal.vue
apps/back-office/components/AdminFormSection.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/admin/tenant/support-access.vue
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

## Scope

Implement these matrix rows:

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

Expected routes and known matrix contracts:

```text
/admin/central/admin-users
- GET /admin/central/admin-users
- GET /admin/central/admin-users/{admin_user_id}
- POST /admin/central/admin-users
- PATCH /admin/central/admin-users/{admin_user_id}
- DELETE /admin/central/admin-users/{admin_user_id}

/admin/central/roles
- GET /admin/central/roles
- POST /admin/central/roles
- PATCH /admin/central/roles/{role_id}
- DELETE /admin/central/roles/{role_id}

/admin/central/menu-management
- GET /admin/central/menu-management
- PUT /admin/central/menu-management

/admin/central/system-settings
- GET /admin/central/system-settings
- PATCH /admin/central/system-settings

/admin/tenant/admin-users
- GET /admin/tenant/admin-users
- GET /admin/tenant/admin-users/{admin_user_id}
- POST /admin/tenant/admin-users
- PATCH /admin/tenant/admin-users/{admin_user_id}
- DELETE /admin/tenant/admin-users/{admin_user_id}

/admin/tenant/roles
- GET /admin/tenant/roles
- POST /admin/tenant/roles
- PATCH /admin/tenant/roles/{role_id}
- DELETE /admin/tenant/roles/{role_id}

/admin/tenant/menu-management
- GET /admin/tenant/menu-management
- PUT /admin/tenant/menu-management

/admin/tenant/maintenance
- GET /admin/tenant/maintenance
- GET /admin/tenant/maintenance/events
- GET /admin/tenant/maintenance/bypasses
- PUT /admin/tenant/maintenance
- POST /admin/tenant/maintenance/bypasses
- DELETE /admin/tenant/maintenance/bypasses/{bypass_id}

/admin/tenant/support-access
- GET /admin/tenant/support-access
- GET /admin/tenant/support-access/{support_access_id}
- POST /admin/tenant/support-access
- POST /approve
- POST /revoke
- POST /impersonate
- POST /elevated-actions
- POST /end-session

/admin/tenant/settings
- GET /admin/tenant/settings
- GET /admin/tenant/theme
- GET /admin/tenant/domains
- GET /admin/tenant/domains/{domain_id}
- PATCH /admin/tenant/settings
- PATCH /admin/tenant/theme
- POST /admin/tenant/domains
- PATCH /admin/tenant/domains/{domain_id}
- DELETE /admin/tenant/domains/{domain_id}
- POST /admin/tenant/domains/{domain_id}/verify
```

If the actual frozen contract differs, follow `docs/openapi.yaml` and record the exact mismatch in the BO handoff.

## Required Implementation Behavior

Use existing Meno/admin patterns and current BO composables.

Required behavior:

```text
replace operator-facing raw JSON create/update/delete where the matrix identifies workflow gaps
keep generic JSON support for unrelated menus that still rely on it
show clear record context before delete, role changes, menu saves, setting saves, maintenance changes, support approvals/revocations, impersonation, elevated actions, and session-ending actions
require operator reason where the existing action pattern requires reason or where the workflow is security-sensitive
use idempotency keys for writes/actions where backend expects or supports them
preserve central scope, tenant scope, and X-Tenant-Id behavior
handle loading/error/empty/success/disabled/validation states
avoid silently falling back to unrelated dashboard/settings/report pages
use SweetAlert2/template alert behavior where existing BO action flows use it
```

P4 row-specific expectations:

```text
central:admin_users and tenant:admin_users
- list/detail
- typed create/update forms for identity/status/roles where contract supports them
- delete confirmation with admin identity, scope, and reason guard where supported
- avoid exposing or persisting real passwords in artifacts

central:roles_permissions and tenant:roles_permissions
- list
- typed create/update role forms where contract supports them
- permission selection/editing if contract shape is clear
- delete confirmation with role/scope context and reason guard where supported

central:menu_management and tenant:menu_management
- real menu edit/save workflow against GET/PUT contract
- avoid JSON-only completion unless the backend contract only supports a generic tree payload and QA/Coordinator can verify it as an expected operator workflow
- show scope/menu context before save

central:system_settings
- settings read/save workflow with meaningful typed fields where contract exposes known keys
- if only generic settings payload is available, preserve JSON editor but document why typed controls are not safe

tenant:maintenance
- save maintenance mode/workflow
- create bypass workflow
- revoke/delete bypass workflow
- events/bypasses lists remain useful

tenant:support_access_logs
- list/detail
- create support access request workflow if safe
- approve/revoke/impersonate/elevated-actions/end-session actions show security-sensitive context and reason guard
- do not expose real passwords or secrets
- if impersonation/elevated action submission is unsafe for QA fixtures, surface safe modal/context and document exact boundary

tenant:settings
- tenant settings save workflow
- theme save workflow where contract supports it
- domain list/detail/create/update/verify/delete workflows where contract supports them
- preserve tenant scope and domain context
```

Security-sensitive rows need focused QA evidence before completion. Do not mark them complete based on route/catalog presence or JSON editor existence alone.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

Do not change backend contracts, permission semantics, tenant/customer flows, production/Ops config, API schemas, or Customer frontend behavior.

Do not use Customer frontend for this task.

Do not mark BO percentage as complete yourself. Update `docs/back-office-crud-coverage.md` notes/status only to reflect implementation readiness or known blockers. Coordinator recalculates percentage after QA.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Do not stage or commit unrelated dirty QA/runtime files listed in the Branch And Sync Rules section.

## Required Steps

1. Read the source-of-truth files and current catalog/page patterns.
2. Map each P4 row to current BO route/catalog/page behavior and backend OpenAPI contract.
3. Implement typed/security-appropriate forms, settings/menu editors, and action confirmations where the contract supports them.
4. Preserve existing list/detail/action behavior for rows already wired.
5. If a row is blocked by missing contract, unsafe payload ambiguity, permission uncertainty, or security risk, stop that row and report the exact blocker instead of changing backend/security behavior.
6. Update `docs/back-office-crud-coverage.md` row notes to show BO implementation status and QA readiness, but leave completion as `partial` until QA passes.
7. Run required Docker validation.
8. Commit BO implementation changes with a task-prefixed commit message.
9. Write BO handoff and route back to Orchestrator, not directly to QA.

## Acceptance Criteria

- Central and tenant admin user workflows expose list/detail/create/update/delete where safely supported by contract.
- Central and tenant role workflows expose list/create/update/delete and permission editing where contract shape is clear.
- Central and tenant menu management workflows can save menu changes through real GET/PUT workflow or document exact contract/UI blocker.
- Central system settings can save meaningful settings or document why only generic payload editing is safe.
- Tenant maintenance save/create bypass/revoke bypass workflows are testable from real menu.
- Tenant support access workflows expose safe security-sensitive context and actions without leaking secrets.
- Tenant settings/theme/domain workflows are surfaced where contract supports them.
- Loading/error/empty/success/disabled/validation states remain coherent.
- BO implementation does not edit backend, customer, OpenAPI, production/Ops, or permission source files.
- `docs/back-office-crud-coverage.md` reflects implementation readiness without marking rows complete before QA.
- BO handoff lists changed files, endpoints consumed, validation, blockers/risks, commit hash, and next agent.

## Validation Commands

Application commands must be Docker-only.

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=Support
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

If a suggested backend test filter does not exist, record the exact command/result in the handoff and continue with the applicable Docker validation.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

Must include:

```text
what was done
files changed
template/admin patterns used
API endpoints consumed
coverage matrix status per row
validation commands and results
implementation commit hash
known risks/blockers
security-sensitive workflow notes
confirmation that unrelated dirty QA/runtime files were left untouched
next agent: Orchestrator
```
