# M1 Admin User Management Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m1-admin-user-management-decision.md
ai-agents/tasks/20260506-m1-admin-user-management-backend.md
ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-user-management-qa.md
ai-agents/handoffs/20260506-m1-admin-user-management-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m1-admin-user-management-qa-report.md
```

QA result:

```text
PASS
```

Docker validation evidence from QA:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminUser: PASS, 8 tests, 87 assertions
docker compose run --rm platform-api php artisan test: PASS, 46 tests, 298 assertions
```

QA reported no defects.

## Decision

Approve Milestone 1 Admin User Management Foundation slice.

The approved endpoint scope includes:

```text
GET /api/v1/admin/central/admin-users
POST /api/v1/admin/central/admin-users
GET /api/v1/admin/central/admin-users/{admin_user_id}
PATCH /api/v1/admin/central/admin-users/{admin_user_id}
DELETE /api/v1/admin/central/admin-users/{admin_user_id}
GET /api/v1/admin/tenant/admin-users
POST /api/v1/admin/tenant/admin-users
GET /api/v1/admin/tenant/admin-users/{admin_user_id}
PATCH /api/v1/admin/tenant/admin-users/{admin_user_id}
DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}
```

The approved behavior includes:

```text
admin bearer authentication for all admin-user endpoints
central X-Admin-Scope enforcement with admin_user.manage
tenant X-Admin-Scope and X-Tenant-Id enforcement with tenant access and admin_user.manage
tenant admin-user query/write isolation through admin_scopes and admin_user_roles
central admin-user scope separation
role_ids validation against matching central or tenant scope
required Idempotency-Key header validation on writes
safe scoped disable without hard-deleting shared identity records
target admin permission cache invalidation when role assignments change
admin_user.changed audit logging with sensitive data redaction
credential-safe responses that omit password/hash/token/invitation material
focused AdminUser tests
```

## Approval Conditions

This approval is limited to admin user management endpoints and supporting backend behavior.

Still out of scope:

```text
password forgot/reset/change flows
2FA setup/enable/verify/recovery flows
real invitation email delivery or invitation tracking
production default admin accounts
menu-management update endpoints
partner provisioning
apps/customer changes
apps/back-office changes
stock, booking, checkout, wallet, payment, reward, support impersonation, notification, and other business flows
general idempotency persistence/replay/conflict semantics
source-of-truth doc changes
```

For the Backend/QA question about duplicate email behavior:

```text
For Milestone 1, duplicate-email create remains conflict-only.
Attaching an existing admin identity to another central/tenant scope requires a separate Coordinator decision and task.
```

## Reason

The admin user management slice satisfies the approved auth, permission, tenant isolation, role validation, idempotency-header, audit/redaction, credential-safety, permission-cache, and Docker validation criteria.

QA confirmed the focused and full `platform-api` suites pass through Docker and found no defects.

## Impact

Milestone 1 now has approved:

```text
platform core foundation
RBAC/menu default seeders
admin auth/menu read foundation
admin role management foundation
admin user management foundation
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Coordinator
```
