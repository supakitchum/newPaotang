# M1 Admin Auth Menu Read Approval Decision

## Context

Coordinator reviewed the Admin Auth/Menu Read Foundation flow:

```text
ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md
ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-auth-menu-read-qa.md
ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-qa-review-decision.md
ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-backend.md
ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-qa.md
ai-agents/reports/20260506-m1-admin-auth-logout-idempotency-qa-report.md
```

Initial QA result:

```text
FAIL
```

Coordinator requested a focused revision for:

```text
D1 - Admin logout does not enforce required Idempotency-Key
```

Focused QA follow-up result:

```text
PASS
```

Docker validation evidence from follow-up QA:

```text
docker compose run --rm platform-api php artisan test --filter=AdminAuth: PASS, 9 tests, 78 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenu: PASS, 5 tests, 19 assertions
docker compose run --rm platform-api php artisan test: PASS, 29 tests, 141 assertions
```

## Decision

Approve Milestone 1 Admin Auth/Menu Read Foundation slice.

The approved endpoint scope includes:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
```

The approved behavior includes:

```text
DB-backed opaque admin token/session foundation
server-side access/refresh token hash persistence and revocation
refresh token rotation
active admin password login validation
central and tenant admin scope checks
tenant menu X-Tenant-Id boundary enforcement
permission-driven menu reads through RBAC/MenuService
safe auth/validation errors
login/logout audit logging
required Idempotency-Key validation on admin logout
focused auth/menu tests
```

## Approval Conditions

This approval is limited to the six approved endpoints and their foundation behavior.

Still out of scope:

```text
password forgot/reset/change flows
2FA setup/enable/verify/recovery flows
admin user CRUD
role CRUD
menu-management update endpoints
role assignment to users
production default admin accounts
partner provisioning
apps/customer changes
apps/back-office changes
central stock, booking, checkout, wallet, payment, reward, support impersonation, notification, and other business flows
general idempotency persistence/replay/conflict semantics
```

## Reason

The only QA defect was a logout OpenAPI header contract mismatch. The focused revision now rejects missing/invalid `Idempotency-Key` headers and preserves successful logout/revocation behavior for valid headers.

The full platform API test suite passes through Docker after the revision. No customer or back-office changes were reported.

## Impact

Milestone 1 now has approved:

```text
platform core foundation
RBAC/menu default seeders
admin auth/menu read foundation
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
