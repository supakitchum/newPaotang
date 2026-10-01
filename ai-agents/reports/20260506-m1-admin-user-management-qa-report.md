# QA Report

## Task

`20260506-m1-admin-user-management-qa`

QA validated the Admin User Management Foundation after Backend Develop completed:

- `ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md`

## Scope Tested

- Reviewed Coordinator decision, Backend task, Backend handoff, Orchestrator QA task handoff, QA task, prior approval decisions, QA role, global rules, stage gates, and file ownership rules.
- Reviewed source-of-truth docs: `docs/openapi.yaml`, `docs/api-conventions.md`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, `docs/workspace-app-structure.md`, `document/07_SECURITY_ADMIN_PERMISSION.md`, `document/09_AI_WORK_INSTRUCTIONS.md`, and `document/15_EXECUTION_PLAN.md`.
- Validated only the ten approved endpoints:
  - `GET /api/v1/admin/central/admin-users`
  - `POST /api/v1/admin/central/admin-users`
  - `GET /api/v1/admin/central/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/central/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/central/admin-users/{admin_user_id}`
  - `GET /api/v1/admin/tenant/admin-users`
  - `POST /api/v1/admin/tenant/admin-users`
  - `GET /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}`
- Inspected routes, controller, admin scope middleware, admin session resolver, shared header validator, admin user management service, permission service, audit logger, relevant schema, OpenAPI admin-user schemas, and focused tests.
- Checked admin auth/scope middleware use, `admin_user.manage` enforcement, tenant boundary constraints, central-vs-tenant endpoint separation, role assignment validation, idempotency header validation, scoped disable behavior, permission cache invalidation, audit logging/redaction, and credential-safe responses.
- Ran required Docker-only validation commands.

## Commands Run

```sh
find ai-agents/tasks ai-agents/handoffs ai-agents/reports ai-agents/decisions -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,280p' ai-agents/BOARD.md
rg -n "QA Tester|Next Agent|Target Agent|ready|handoff_sent|approve|revise|Active Task|Latest Decision|task-breakdown" ai-agents/tasks ai-agents/handoffs ai-agents/decisions ai-agents/reports -S
sed -n '1,280p' ai-agents/tasks/20260506-m1-admin-user-management-qa.md
sed -n '1,260p' ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md
sed -n '1,260p' ai-agents/tasks/20260506-m1-admin-user-management-backend.md
sed -n '1,220p' ai-agents/decisions/20260506-m1-admin-user-management-decision.md
sed -n '1,180p' ai-agents/handoffs/20260506-m1-admin-user-management-qa-task-orchestrator-handoff.md
sed -n '1,180p' ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
sed -n '1,160p' ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
sed -n '1,140p' ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
sed -n '1,180p' ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
sed -n '1,260p' ai-agents/roles/qa-tester.md
sed -n '1,260p' ai-agents/rules/global-rules.md
sed -n '1,260p' ai-agents/workflow/stage-gates.md
sed -n '1,260p' ai-agents/workflow/file-ownership.md
rg -n "admin/(central|tenant)/admin-users|AdminUser|CreateTenantAdminUserRequest|UpdateTenantAdminUserRequest|Idempotency-Key" docs/openapi.yaml
sed -n '1478,1618p' docs/openapi.yaml
sed -n '4328,4470p' docs/openapi.yaml
sed -n '7275,7355p' docs/openapi.yaml
sed -n '8810,8915p' docs/openapi.yaml
sed -n '7049,7095p' docs/openapi.yaml
sed -n '1,360p' docs/api-conventions.md
sed -n '1,760p' docs/permissions.md
sed -n '1,260p' docs/status-enums.md
sed -n '1,220p' docs/docker-runtime-policy.md
sed -n '1,220p' docs/workspace-app-structure.md
sed -n '1,320p' document/07_SECURITY_ADMIN_PERMISSION.md
sed -n '1,240p' document/09_AI_WORK_INSTRUCTIONS.md
sed -n '1,360p' document/15_EXECUTION_PLAN.md
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,520p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminUserController.php
sed -n '1,760p' apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
sed -n '1,220p' apps/platform-api/app/Shared/Http/RequestHeaderValidator.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
sed -n '1,300p' apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
sed -n '1,260p' apps/platform-api/app/Shared/Rbac/PermissionService.php
sed -n '1,260p' apps/platform-api/app/Shared/Audit/AuditLogger.php
sed -n '1,220p' apps/platform-api/config/audit.php
sed -n '1,520p' apps/platform-api/tests/Feature/AdminUserTest.php
git status --short apps/customer apps/back-office docs document apps/platform-api/.phpunit.result.cache apps/platform-api/routes/api.php apps/platform-api/app/Modules/Platform/Http/Controllers/AdminUserController.php apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php apps/platform-api/tests/Feature/AdminUserTest.php
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminUser
docker compose run --rm platform-api php artisan test
find apps/platform-api -maxdepth 1 -name '.phpunit.result.cache' -print
rm -f apps/platform-api/.phpunit.result.cache
```

Docker validation results:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminUser: PASS, 8 tests, 87 assertions
docker compose run --rm platform-api php artisan test: PASS, 46 tests, 298 assertions
```

## Test Results

`PASS`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| Central admin-user list/create/view/update/disable works with `admin_user.manage` | PASS | Routes exist with `admin.auth` + `admin.scope:central`; focused test covers central create/list/view/update/delete. |
| Tenant admin-user list/create/view/update/disable works with tenant `admin_user.manage` | PASS | Routes exist with `admin.auth` + `admin.scope:tenant`; focused test covers tenant create/list/view/update/delete under `X-Tenant-Id`. |
| Write endpoints reject missing/invalid `Idempotency-Key` | PASS | `AdminUserController` calls shared `RequestHeaderValidator` for store/update/destroy; focused test covers missing and too-short keys. |
| Permission checks default deny without `admin_user.manage` | PASS | `AdminUserController::authorizedContext()` uses `PermissionService`; focused test verifies `403 permission_denied`. |
| Tenant admin cannot access or mutate another tenant admin user | PASS | Middleware and service queries constrain tenant scope; focused test verifies other-tenant show/update is not found and other-tenant list is forbidden. |
| Central admin cannot use tenant admin-user endpoints without tenant access | PASS | Tenant scope middleware blocks central-only sessions; focused test verifies `403 permission_denied`. |
| Central endpoints do not create tenant-scoped access | PASS | Central service context uses `tenant_id = null` and central role validation; source inspection confirms central create syncs only central scope assignments. |
| `role_ids` reject outside requested scope or tenant | PASS | `AdminUserManagementService::invalidRoleIds()` filters by active roles matching selected scope/tenant; focused test rejects tenant role on central create and other-tenant role on tenant create. |
| Role assignment changes invalidate target admin permission cache | PASS | Create/update/disable call permission-cache invalidation; focused test verifies cache version increments on role update. |
| Create/update/disable actions write audit logs with sensitive redaction | PASS | Service writes `admin_user.changed` audit logs; focused central test verifies three audit entries. `AuditLogger` recursively redacts configured sensitive keys, and unit coverage verifies recursive redaction. |
| No password/hash/token/invitation material returned | PASS | Resource builder excludes password hash and credential/invitation fields; focused tests assert admin-user responses do not contain sensitive keys. |
| Response shapes match OpenAPI as closely as current contract allows | PASS | Tenant responses include `AdminUser` fields; central responses use generic `AdminResource`/`AdminResourceListResponse` with additional properties. |
| Focused AdminUser tests pass in Docker | PASS | 8 tests, 87 assertions. |
| Full platform-api tests pass in Docker | PASS | 46 tests, 298 assertions. |
| Docker runtime policy followed | PASS | All migration/test commands used `docker compose run --rm platform-api ...`; no host PHP/Composer/Artisan/Node runtime command was run. |
| No customer/back-office/source-of-truth doc changes for this slice | PASS WITH RISK | `git status --short apps/customer apps/back-office` returned no output. Broader docs remain dirty from existing milestone flow, but Backend handoff did not list source-of-truth doc changes for this slice. |

## Defects

None.

## Risks / Not Tested

- Existing schema does not track invitation delivery, invitation tokens, or `last_login_at`; Backend returns `last_login_at: null` and does not expose invitation material.
- Existing schema does not model per-scope admin-user status. Disable/delete removes the selected scoped role assignments, and only sets the shared admin identity to `disabled` when no role assignments remain.
- Duplicate email currently returns `resource_conflict` instead of attaching an existing admin identity to another scope; Coordinator should decide whether conflict-only remains the intended behavior.
- This slice validates required `Idempotency-Key` headers but intentionally does not implement idempotency persistence, replay, or conflict semantics.
- Source inspection confirmed audit redaction for submitted `password` keys, but focused AdminUser tests assert audit count rather than the exact redacted audit payload.
- Existing sessions for a shared admin identity are not explicitly revoked when one scoped assignment is removed while the identity still has other assignments. Authorization remains permission/scope constrained, but session revocation semantics are not part of this slice.
- PHPUnit generated `.phpunit.result.cache`; QA removed it after validation.
- The worktree remains broadly dirty from prior milestone flow, and `apps/platform-api` is still untracked as a new tree, so diff-level isolation is limited. Scoped path inspection showed the Backend-reported implementation files are within approved `apps/platform-api/**` ownership.

## Recommendation

Coordinator can approve the `m1-admin-user-management` slice. Admin user management endpoints satisfy the approved auth, permission, tenant isolation, role validation, idempotency-header, audit/redaction, credential-safety, permission-cache, and Docker validation criteria.

## Next Agent

Coordinator
