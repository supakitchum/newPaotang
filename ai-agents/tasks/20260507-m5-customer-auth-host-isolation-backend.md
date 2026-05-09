# m5-customer-auth-host-isolation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed the M5 Checkout, Wallet, Sold Sync QA report and requested a focused revision before approval.

QA result:

```text
FAIL
```

Acceptance-blocking defect:

```text
D1/P1 - Customer auth/profile endpoints ignore the tenant host for existing bearer sessions
```

This task is authorized by:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-review-coordinator-handoff.md
ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
```

## Objective

Ensure every authenticated customer auth/profile endpoint validates that the bearer session tenant matches the active tenant resolved from the request host before returning, mutating, or revoking customer/session data.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
- ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
- ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
- ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-qa.md
- ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md
- ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-review-coordinator-handoff.md

## Scope

Fix only customer bearer-session host/tenant isolation for authenticated customer auth/profile endpoints.

At minimum, the fix must cover:

```text
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
GET /api/v1/customer/profile
PATCH /api/v1/customer/profile
```

Required behavior:

```text
resolve tenant from Host/TenantHostHeader using existing tenant-host conventions
reject unknown/inactive/suspended/maintenance-blocked tenant hosts consistently with other customer endpoints
compare resolved tenant_id to CustomerSessionContext::tenantId() before reading, updating, or revoking a session
return AuthenticationRequired or PermissionDenied consistently with existing customer tenant mismatch conventions
do not leak profile data from the token tenant when the request host belongs to another tenant
do not revoke a tenant A session when the logout request is sent through tenant B host
keep same-host valid auth/profile/logout behavior unchanged
```

Preferred implementation:

```text
centralize the check in customer auth middleware/session resolution or a shared customer tenant guard so current and future bearer customer endpoints inherit host/session tenant matching
```

Approved implementation files:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

Related helper edits are allowed only if needed to centralize customer host/session tenant validation.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not change checkout, wallet ledger, orders, tickets, topups, webhooks, sold sync, tenant admin commerce behavior, or schema except where a test fixture needs a second tenant/customer/session.
- Do not implement LINE login, realtime auth, reward, affiliate, reports, settlement, real payment SDKs, or UI.
- Do not broaden the revision into general auth redesign beyond host/session tenant enforcement.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

Can edit only if strictly required to centralize customer host/session tenant validation:

```text
apps/platform-api/app/Shared/Auth/**
apps/platform-api/app/Shared/Tenancy/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Backend Develop may write only its required handoff under `ai-agents/handoffs/**`.

If the fix requires schema, API contract, customer app, frontend, or broader auth redesign changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect `docs/openapi.yaml` for `TenantHostHeader` on customer auth/profile endpoints.
3. Inspect the M5 decision, QA report, and Coordinator QA review evidence for D1/P1.
4. Inspect current customer bearer middleware/session resolver/controller flow.
5. Identify the existing tenant-host resolver/conventions used by customer commerce endpoints and reuse them.
6. Implement a centralized or shared guard that resolves request tenant host and compares it to `CustomerSessionContext::tenantId()` before any protected customer auth/profile endpoint reads, updates, or revokes session/customer data.
7. Ensure unknown/inactive/suspended/maintenance-blocked tenant hosts are rejected consistently with existing customer endpoint behavior.
8. Ensure cross-tenant host mismatch returns the existing appropriate `AuthenticationRequired` or `PermissionDenied` style response.
9. Ensure cross-tenant host mismatch does not leak tenant A profile data through tenant B host.
10. Ensure cross-tenant logout does not revoke tenant A session.
11. Keep same-host `me`, `profile`, `profile update`, and `logout` behavior unchanged.
12. Add focused regression coverage for tenant A token used through tenant B host on `me`, `profile`, `profile update`, and `logout`.
13. Add coverage proving failed cross-tenant logout does not revoke the tenant A session.
14. Run validation commands through Docker only.
15. Write the required Backend Develop handoff.

## Acceptance Criteria

- Tenant A bearer token cannot access `GET /api/v1/customer/auth/me` through tenant B host.
- Tenant A bearer token cannot access `GET /api/v1/customer/profile` through tenant B host.
- Tenant A bearer token cannot `PATCH /api/v1/customer/profile` through tenant B host.
- Tenant A bearer token cannot `POST /api/v1/customer/auth/logout` through tenant B host.
- Failed cross-tenant logout attempt does not revoke the tenant A session.
- Same-host `me`, `profile`, `profile update`, and `logout` still work.
- Current and future bearer customer endpoints inherit host/session tenant validation through a centralized guard or clearly documented shared path where feasible.
- Existing `CustomerAuth`, `CustomerCheckout`, `CustomerTopup`, and full `platform-api` tests still pass.
- No out-of-scope files are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=CustomerAuth
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout
docker compose run --rm platform-api php artisan test --filter=CustomerTopup
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Orchestrator must create a focused QA task after Backend Develop produces a revision handoff.
