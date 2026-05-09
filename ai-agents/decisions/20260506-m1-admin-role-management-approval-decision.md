# M1 Admin Role Management Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m1-admin-role-management-decision.md
ai-agents/tasks/20260506-m1-admin-role-management-backend.md
ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-role-management-qa.md
ai-agents/handoffs/20260506-m1-admin-role-management-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m1-admin-role-management-qa-report.md
```

QA result:

```text
PASS
```

Docker validation evidence from QA:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminRole: PASS, 9 tests, 70 assertions
docker compose run --rm platform-api php artisan test: PASS, 38 tests, 211 assertions
```

QA reported no defects.

## Decision

Approve Milestone 1 Admin Role Management Foundation slice.

The approved endpoint scope includes:

```text
GET /api/v1/admin/central/roles
POST /api/v1/admin/central/roles
PATCH /api/v1/admin/central/roles/{role_id}
DELETE /api/v1/admin/central/roles/{role_id}
GET /api/v1/admin/tenant/roles
POST /api/v1/admin/tenant/roles
PATCH /api/v1/admin/tenant/roles/{role_id}
DELETE /api/v1/admin/tenant/roles/{role_id}
```

The approved behavior includes:

```text
role.manage authorization for central and tenant scopes
tenant role query/write tenant_id isolation
central role scope separation
permission-code validation against seeded permissions by scope
required Idempotency-Key header validation on writes
role archive instead of hard delete
role version increment and permission cache invalidation foundation
role.changed audit logging
focused AdminRole tests
```

## Approval Conditions

This approval is limited to role management endpoints and supporting backend behavior.

Still out of scope:

```text
admin user CRUD
role assignment to users outside test fixtures
default admin accounts
menu-management update endpoints
password reset/change and 2FA
partner provisioning
apps/customer changes
apps/back-office changes
central stock, booking, checkout, wallet, payment, reward, support impersonation, notification, and other business flows
general idempotency persistence/replay/conflict semantics
admin_menus.parent_id schema/FK changes
```

## Reason

The role management slice validates the first approved admin write surface against backend authorization, tenant isolation, audit logging, version/cache invalidation, and Docker-only test requirements.

QA confirmed the focused and full `platform-api` suites pass through Docker and found no defects.

## Impact

Milestone 1 now has approved:

```text
platform core foundation
RBAC/menu default seeders
admin auth/menu read foundation
admin role management foundation
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
