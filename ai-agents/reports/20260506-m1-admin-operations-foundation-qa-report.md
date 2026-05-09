# QA Report

## Task

`20260506-m1-admin-operations-foundation-qa`

QA validated the Admin Operations Foundation after Backend Develop completed:

- `ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md`

## Scope Tested

- Reviewed Coordinator decision, Backend task, Backend handoff, Orchestrator QA task handoff, QA task, prior approval decisions, QA role, global rules, stage gates, handoff protocol, and file ownership rules.
- Reviewed source-of-truth docs: `docs/openapi.yaml`, `docs/api-conventions.md`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, `docs/workspace-app-structure.md`, `document/07_SECURITY_ADMIN_PERMISSION.md`, `document/09_AI_WORK_INSTRUCTIONS.md`, and `document/15_EXECUTION_PLAN.md`.
- Validated only the ten approved endpoints:
  - `GET /api/v1/admin/central/dashboard/summary`
  - `POST /api/v1/admin/central/realtime/auth`
  - `GET /api/v1/admin/central/menu-management`
  - `PUT /api/v1/admin/central/menu-management`
  - `GET /api/v1/admin/central/audit-logs`
  - `GET /api/v1/admin/tenant/dashboard/summary`
  - `POST /api/v1/admin/tenant/realtime/auth`
  - `GET /api/v1/admin/tenant/menu-management`
  - `PUT /api/v1/admin/tenant/menu-management`
  - `GET /api/v1/admin/tenant/audit-logs`
- Inspected routes, controller, admin scope middleware, admin session resolver, `AdminOperationsService`, `MenuManagementService`, `PermissionService`, `AuditLogger`, realtime config, dashboard response builders, menu update validation, audit-log listing/redaction, OpenAPI schemas, and focused tests.
- Checked auth/scope middleware use, `dashboard.view`, `menu.manage`, `audit.view`, permissionless realtime channel auth beyond authenticated scope, tenant isolation, channel allow/deny behavior, menu-management idempotency validation, menu tree/scope/role/order validation, `menu.changed` audit logging, permission cache invalidation, audit-log filters/cursor/limit behavior, and Docker-only validation.

## Commands Run

```sh
sed -n '1,260p' ai-agents/prompts/open-chat-qa-tester.md
find ai-agents/tasks ai-agents/handoffs ai-agents/decisions ai-agents/reports -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,300p' ai-agents/BOARD.md
sed -n '1,320p' ai-agents/tasks/20260506-m1-admin-operations-foundation-qa.md
sed -n '1,300p' ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
sed -n '1,260p' ai-agents/handoffs/20260506-m1-admin-operations-foundation-qa-task-orchestrator-handoff.md
sed -n '1,260p' ai-agents/decisions/20260506-m1-admin-operations-foundation-decision.md
sed -n '1,380p' ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
sed -n '1,260p' ai-agents/roles/qa-tester.md
sed -n '1,260p' ai-agents/rules/global-rules.md
sed -n '1,260p' ai-agents/workflow/stage-gates.md
sed -n '1,260p' ai-agents/workflow/handoff-protocol.md
sed -n '1,260p' ai-agents/workflow/file-ownership.md
sed -n '1,240p' docs/docker-runtime-policy.md
sed -n '1,220p' ai-agents/README.md
rg -n "dashboard/summary|realtime/auth|menu-management|audit-logs|DashboardSummary|RealtimeAuth|MenuTree|UpdateMenuTree|AuditLog|AdminResourceListResponse|Idempotency-Key" docs/openapi.yaml
sed -n '1188,1305p' docs/openapi.yaml
sed -n '3200,3435p' docs/openapi.yaml
sed -n '6290,6335p' docs/openapi.yaml
sed -n '7045,7295p' docs/openapi.yaml
sed -n '7380,7425p' docs/openapi.yaml
sed -n '8520,8575p' docs/openapi.yaml
sed -n '1,380p' docs/api-conventions.md
sed -n '1,820p' docs/permissions.md
sed -n '1,280p' docs/status-enums.md
sed -n '1,360p' apps/platform-api/routes/api.php
sed -n '1,620p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminOperationsController.php
sed -n '1,760p' apps/platform-api/app/Shared/Admin/AdminOperationsService.php
sed -n '1,780p' apps/platform-api/app/Shared/Rbac/MenuManagementService.php
sed -n '1,260p' apps/platform-api/app/Shared/Audit/AuditLogger.php
sed -n '1,360p' apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
sed -n '1,340p' apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
sed -n '1,760p' apps/platform-api/tests/Feature/AdminOperationsTest.php
sed -n '1,220p' apps/platform-api/config/platform.php
rg -n "admin_menus|audit_logs|role_menus|admin_permission_cache_versions|admin_scopes|permissions|roles" apps/platform-api/database/migrations/2026_05_06_000001_create_platform_core_tables.php apps/platform-api/database/migrations -S
sed -n '1,380p' apps/platform-api/database/migrations/2026_05_06_000001_create_platform_core_tables.php
sed -n '1,360p' apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
sed -n '1,280p' apps/platform-api/tests/Support/AdminAuthFixtures.php
git status --short apps/customer apps/back-office docs document apps/platform-api/config/platform.php apps/platform-api/routes/api.php apps/platform-api/app/Modules/Platform/Http/Controllers/AdminOperationsController.php apps/platform-api/app/Shared/Admin/AdminOperationsService.php apps/platform-api/app/Shared/Rbac/MenuManagementService.php apps/platform-api/tests/Feature/AdminOperationsTest.php apps/platform-api/.phpunit.result.cache
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminOperations
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test --filter=AdminDashboard
docker compose run --rm platform-api php artisan test --filter=AdminRealtime
docker compose run --rm platform-api php artisan test --filter=AuditLog
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan tinker --execute='var_export(app(App\\Shared\\Audit\\AuditLogger::class)->redactPayload([...]))'
nl -ba apps/platform-api/config/platform.php | sed -n '1,80p'
nl -ba apps/platform-api/app/Shared/Audit/AuditLogger.php | sed -n '35,95p'
find apps/platform-api -maxdepth 1 -name '.phpunit.result.cache' -print
rm -f apps/platform-api/.phpunit.result.cache
```

Docker validation results:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminOperations: PASS, 7 tests, 87 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenu: PASS, 7 tests, 41 assertions
docker compose run --rm platform-api php artisan test --filter=AdminDashboard: PASS, 2 tests, 25 assertions
docker compose run --rm platform-api php artisan test --filter=AdminRealtime: PASS, 1 test, 17 assertions
docker compose run --rm platform-api php artisan test --filter=AuditLog: PASS, 3 tests, 27 assertions
docker compose run --rm platform-api php artisan test: PASS, 53 tests, 385 assertions
```

Notes:

- I briefly ran `AdminMenu` and `AdminDashboard` filters concurrently. Those attempts failed with testing database migration/drop-table races because both Docker test processes shared the same PostgreSQL database. I reset the database and reran the required validations sequentially; the sequential validation results above are the authoritative results.
- The optional `php artisan tinker` evidence command was attempted through Docker, but this Laravel install does not define `tinker`. Source inspection was used for the redaction defect evidence.

## Test Results

`FAIL`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| Central dashboard summary works with `dashboard.view` | PASS | Routes use `admin.auth` + `admin.scope:central`; controller checks `dashboard.view`; focused tests verify central summary shape. |
| Tenant dashboard summary works with selected-tenant `dashboard.view` | PASS | Tenant routes use `admin.auth` + `admin.scope:tenant`; middleware enforces `X-Tenant-Id`; focused tests verify tenant summary shape. |
| Dashboard summary default deny without `dashboard.view` | PASS | `authorizedContext()` uses `PermissionService`; focused test verifies `403 permission_denied`. |
| Central realtime auth allows central channels and rejects tenant channels | PASS | Realtime path uses authenticated central scope and fixed central channel allow-list; focused tests verify allow/deny and OpenAPI-compatible payload. |
| Tenant realtime auth allows selected-tenant channels and rejects central/other-tenant channels | PASS | Tenant channel allow-list includes only active tenant id from session; focused tests verify selected-tenant allow and other-tenant deny. |
| Central menu-management read/update works with `menu.manage` | PASS | Controller checks `menu.manage`; focused tests verify read/update, role menu assignment, and response tree. |
| Tenant menu-management read/update works with selected-tenant `menu.manage` | PASS | Source inspection confirms tenant scope/tenant id are passed into menu tree and role filtering; Docker focused coverage exercises shared menu-management paths. |
| Menu-management writes reject missing/invalid `Idempotency-Key` | PASS | Controller calls shared `RequestHeaderValidator`; focused test verifies missing key returns validation error. |
| Menu-management writes validate tree/menu scope and reject cross-scope menu changes | PASS | `MenuManagementService` validates id/key scope, duplicate ids/keys, sibling order, parent position, permission scope, status, and role ids. Focused tests verify cross-scope menu id, invalid role id, and duplicate order rejection. |
| Menu-management writes write `menu.changed` audit logs with redaction | PASS | Service writes `menu.changed`; focused test verifies payload password is redacted and secret value is not persisted. |
| Menu-management writes invalidate/increment relevant cache foundation | PASS | Service increments or creates `admin_permission_cache_versions` for admins assigned in scope; focused test verifies increment. |
| Central audit-log list works with `audit.view` and redacts password/token/hash/raw secret style keys | PASS | Service filters central logs by `scope_type = central` and `tenant_id IS NULL`; focused tests verify permission and redaction for password/token-hash fields. |
| Tenant audit-log list works with `audit.view` and is tenant isolated | PASS | Service filters tenant logs by selected tenant id; focused tests verify one-tenant visibility and other-tenant header denial. |
| Audit-log listing redacts invitation material | FAIL | See D1. Redaction uses key substring matching against `platform.audit.sensitive_keys`, which lacks `invite`/`invitation`, so invitation-only keys are not guaranteed to be redacted. |
| Response shapes match OpenAPI as closely as current contracts allow | PASS | Dashboard, realtime, menu tree, and audit list responses match required top-level schema fields; menu items include additional management fields allowed by current schema openness. |
| Focused admin operations validations pass in Docker | PASS | All required filters passed sequentially through Docker. |
| Full platform-api suite passes in Docker | PASS | 53 tests, 385 assertions. |
| Docker runtime policy followed | PASS | All application validation commands were run through `docker compose run --rm platform-api ...`; no host PHP/Composer/Artisan/Node runtime command was run. |
| No customer/back-office/source-of-truth doc changes for this slice | PASS WITH RISK | `git status --short apps/customer apps/back-office` returned no output. Broader docs remain dirty from existing milestone flow, and `docs/docker-runtime-policy.md` is untracked from prior work, so diff-level isolation remains limited. |

## Defects

### D1 - Audit redaction does not cover invitation-only fields

Priority: P2

Evidence:

- `apps/platform-api/app/Shared/Audit/AuditLogger.php:53-57` loads only `platform.audit.sensitive_keys`.
- `apps/platform-api/app/Shared/Audit/AuditLogger.php:84-94` marks a field sensitive only when the field name contains one of those configured substrings.
- `apps/platform-api/config/platform.php:11-21` includes `password`, `token`, `secret`, `authorization`, `credentials`, and `api_key`, but does not include `invite` or `invitation`.

Impact:

The QA acceptance criteria require audit-log read responses to redact invitation material. Keys such as `invitation_url`, `invitation_code`, or `invite_link` do not contain any configured sensitive substring unless they also include `token` or `secret`, so those values can be stored and returned in audit-log responses. This leaves an explicit credential-safety acceptance item uncovered.

Expected:

Invitation-related audit payload keys should be redacted at write and read time, or invitation material should be otherwise normalized into existing sensitive key names before audit persistence.

## Risks / Not Tested

- Dashboard summary returns real counts only for current foundation tables. Downstream business module KPIs remain zero/default until those modules exist.
- Realtime auth is deterministic backend authorization/signing only; no production websocket infrastructure, broadcast driver, or dynamic channel registry was validated.
- Tenant menu configuration remains shared at `admin_menus.scope_type = tenant`; tenant-specific variation is limited to tenant role/menu assignments.
- `admin_menus.parent_id` still has no FK by current schema decision. Submitted tree consistency is service-validated.
- This slice validates required `Idempotency-Key` headers but intentionally does not implement idempotency persistence, replay, or conflict semantics.
- Audit-log cursor is an opaque base64 encoded `created_at`/`id` pair and is not signed.
- OpenAPI `UpdateMenuTreeRequest.reason` is described as required for audit log, but the schema does not mark it required and the implementation does not enforce it. QA did not mark this as a defect because the approved acceptance criteria focus on audit logging/redaction rather than mandatory reason validation.
- PHPUnit generated `.phpunit.result.cache`; QA removed it after validation.
- The worktree remains broadly dirty from prior milestone flow, and `apps/platform-api` is still untracked as a new tree, so diff-level isolation is limited. Scoped inspection showed no `apps/customer/**` or `apps/back-office/**` changes.

## Recommendation

Coordinator should send the slice back for Backend revision to close D1. The implementation otherwise satisfies the approved auth, scoped permission, tenant isolation, realtime channel, menu-management, cache invalidation, OpenAPI-shape, and Docker validation criteria.

## Next Agent

Coordinator
