# M5 Checkout, Wallet, Sold Sync QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-qa.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-task-orchestrator-handoff.md
ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
```

QA result:

```text
FAIL
```

Docker validation passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=CustomerAuth: PASS, 1 test, 19 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout: PASS, 1 test, 30 assertions
docker compose run --rm platform-api php artisan test --filter=WalletLedger: PASS, 1 test, 18 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerTopup: PASS, 1 test, 21 assertions
docker compose run --rm platform-api php artisan test --filter=TenantOrder: PASS, 1 test, 26 assertions
docker compose run --rm platform-api php artisan test --filter=TenantWallet: PASS, 1 test, 20 assertions
docker compose run --rm platform-api php artisan test --filter=TenantTopup: PASS, 1 test, 30 assertions
docker compose run --rm platform-api php artisan test --filter=PaymentWebhook: PASS, 2 tests, 39 assertions
docker compose run --rm platform-api php artisan test --filter=SoldSync: PASS, 1 test, 16 assertions
docker compose run --rm platform-api php artisan test --filter=IdempotencyService: PASS, 1 test, 3 assertions
docker compose run --rm platform-api php artisan test: PASS, 79 tests, 1119 assertions
```

QA found one acceptance-blocking defect:

```text
D1/P1 - Customer auth/profile endpoints ignore the tenant host for existing bearer sessions
```

Evidence from QA and Coordinator spot-check:

```text
docs/openapi.yaml requires TenantHostHeader for customer auth/profile logout/me/profile/update endpoints.
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md requires customer auth endpoints to resolve active tenant/domain through host conventions.
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php resolves bearer token without request host comparison.
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php resolves customer_auth_sessions by token only, then customer tenant, but not request host.
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php logout/me/profile/updateProfile use customer_session directly without resolving host and comparing tenant.
apps/platform-api/tests/Feature/CustomerAuthTest.php covers same-host happy path but not cross-tenant host mismatch.
```

## Decision

Revise before approval.

Do not approve M5 Checkout, Wallet, Payment Contract, Sold Sync yet.

## Required Revision

Orchestrator must create a focused Backend Develop revision task to close D1/P1.

Backend Develop must ensure every authenticated customer endpoint validates that the bearer session tenant matches the active tenant resolved from the request host before returning or mutating customer/session data.

At minimum, the fix must cover:

```text
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
GET /api/v1/customer/profile
PATCH /api/v1/customer/profile
```

The fix may be implemented centrally in customer auth middleware/session resolution or in a shared customer tenant guard. Prefer a centralized guard so all current and future bearer customer endpoints inherit host/session tenant matching.

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

Backend Develop must add focused automated coverage proving:

```text
a tenant A bearer token cannot access GET /customer/auth/me through tenant B host
a tenant A bearer token cannot access GET /customer/profile through tenant B host
a tenant A bearer token cannot PATCH /customer/profile through tenant B host
a tenant A bearer token cannot POST /customer/auth/logout through tenant B host
the failed cross-tenant logout attempt does not revoke the tenant A session
same-host me/profile/profile update/logout still work
existing CustomerAuth, CustomerCheckout, CustomerTopup, and full platform-api tests still pass
```

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Approved scope:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

Related helper edits are allowed only if needed to centralize customer host/session tenant validation.

Out of scope:

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not alter docs/openapi.yaml or source-of-truth docs.
Do not change checkout, wallet ledger, orders, tickets, topups, webhooks, sold sync, tenant admin commerce behavior, or schema except where a test fixture needs a second tenant/customer/session.
Do not implement LINE login, realtime auth, reward, affiliate, reports, settlement, real payment SDKs, or UI.
Do not broaden the revision into general auth redesign beyond host/session tenant enforcement.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=CustomerAuth
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout
docker compose run --rm platform-api php artisan test --filter=CustomerTopup
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Reason

Customer auth/profile endpoints are tenant-host scoped in the OpenAPI contract and M5 decision. Allowing a token issued for tenant A to succeed on tenant B host is a cross-tenant isolation defect and can expose or mutate customer data through the wrong tenant context.

The defect is narrow, but high priority because tenant isolation is a core platform invariant.

## Impact

M5 Checkout, Wallet, Payment Contract, Sold Sync remains unapproved until the revision and focused QA pass.

No frontend, customer app, back-office app, reward, affiliate, reports, settlement, real payment SDK, or later module work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```
