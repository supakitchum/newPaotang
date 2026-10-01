# M1 Admin Operations Foundation Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m1-admin-operations-foundation-decision.md
ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-operations-foundation-qa.md
ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-qa-review-decision.md
ai-agents/tasks/20260506-m1-admin-operations-audit-redaction-backend.md
ai-agents/handoffs/20260506-m1-admin-operations-audit-redaction-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-operations-audit-redaction-qa.md
ai-agents/reports/20260506-m1-admin-operations-audit-redaction-qa-report.md
```

Initial QA result:

```text
FAIL
```

Coordinator requested a focused revision for:

```text
D1 - Audit redaction does not cover invitation-only fields
```

Focused QA follow-up result:

```text
PASS
```

Docker validation evidence from follow-up QA:

```text
docker compose run --rm platform-api php artisan test --filter=AuditLogger: PASS, 1 test, 11 assertions
docker compose run --rm platform-api php artisan test --filter=AdminOperations: PASS, 7 tests, 95 assertions
docker compose run --rm platform-api php artisan test --filter=AuditLog: PASS, 3 tests, 42 assertions
docker compose run --rm platform-api php artisan test: PASS, 53 tests, 400 assertions
```

## Decision

Approve Milestone 1 Admin Operations Foundation slice.

The approved endpoint scope includes:

```text
GET /api/v1/admin/central/dashboard/summary
POST /api/v1/admin/central/realtime/auth
GET /api/v1/admin/central/menu-management
PUT /api/v1/admin/central/menu-management
GET /api/v1/admin/central/audit-logs
GET /api/v1/admin/tenant/dashboard/summary
POST /api/v1/admin/tenant/realtime/auth
GET /api/v1/admin/tenant/menu-management
PUT /api/v1/admin/tenant/menu-management
GET /api/v1/admin/tenant/audit-logs
```

The approved behavior includes:

```text
dashboard.view authorization for central and tenant dashboard summaries
authenticated central and tenant realtime channel authorization with scope/channel boundary checks
menu.manage authorization for central and tenant menu-management read/update
menu-management Idempotency-Key header validation on writes
menu tree, menu scope, role scope, duplicate order, and parent consistency validation
menu.changed audit logging
permission/menu cache invalidation foundation after menu-management writes
audit.view authorization for central and tenant audit-log lists
tenant audit-log tenant_id isolation
central audit-log tenant_id null/platform scope isolation
centralized audit redaction for password, token, secret, hash, credential, api key, invite, and invitation fields
focused AdminOperations and AuditLogger tests
```

## Approval Conditions

This approval is limited to the Admin Operations Foundation endpoints and the focused audit-redaction revision.

Still out of scope:

```text
partner provisioning and Milestone 2 resources
customer realtime auth
webhook-log and sync-log endpoints
export jobs
stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance, support impersonation, and other business flows
production websocket infrastructure beyond deterministic backend authorization response behavior
tenant-specific admin menu row/configuration schema
admin_menus.parent_id FK/schema changes
general idempotency persistence/replay/conflict semantics
apps/customer changes
apps/back-office changes
source-of-truth doc changes
```

For the Backend question about tenant menu configuration:

```text
For Milestone 1, tenant menu configuration remains shared at scope_type = tenant.
Tenant-specific menu rows/configuration requires a separate Coordinator decision and explicit schema task.
```

## Reason

The original admin operations implementation satisfied the approved auth, scoped permission, tenant isolation, realtime channel, menu-management, cache invalidation, OpenAPI-shape, and Docker validation criteria except for invitation-material audit redaction.

The focused revision closed D1 by extending the centralized audit redaction path and proving write/read redaction through Docker-tested unit and feature coverage. Follow-up QA found no defects.

## Impact

Milestone 1 now has approved:

```text
platform core foundation
RBAC/menu default seeders
admin auth/menu read foundation
admin role management foundation
admin user management foundation
admin operations foundation
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
