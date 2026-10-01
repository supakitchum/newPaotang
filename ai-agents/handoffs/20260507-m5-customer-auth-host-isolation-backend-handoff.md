# m5-customer-auth-host-isolation Backend Handoff

## Agent

Backend Develop

## Task

Focused revision for D1/P1 from M5 Checkout, Wallet, Sold Sync QA:

```text
Customer auth/profile endpoints ignore the tenant host for existing bearer sessions
```

## What Was Done

- Updated customer auth middleware to resolve the request tenant from `Host` before authenticated customer routes proceed.
- Added bearer token tenant preflight so a tenant A customer token sent through tenant B host returns `permission_denied` before controller execution.
- Updated customer session resolver to support expected-tenant resolution so cross-tenant mismatches do not read customer profile data or touch `last_used_at`.
- Kept same-host customer auth/profile/logout behavior unchanged.
- Added regression coverage for tenant A bearer token used through tenant B host on:
  - `GET /api/v1/customer/auth/me`
  - `GET /api/v1/customer/profile`
  - `PATCH /api/v1/customer/profile`
  - `POST /api/v1/customer/auth/logout`
- Added coverage proving failed cross-tenant logout does not revoke the tenant A session and same-host logout still revokes it.

## Files Changed

```text
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
```

## Validation

All validation commands were run through Docker only.

```text
docker compose run --rm platform-api php artisan test --filter=CustomerAuth: PASS, 2 tests, 40 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout: PASS, 1 test, 30 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerTopup: PASS, 1 test, 21 assertions
docker compose run --rm platform-api php artisan test: PASS, 80 tests, 1140 assertions
```

## Permissions / Tenant Checks Enforced

```text
customer.auth middleware resolves tenant host through PartnerStoreService
unknown/inactive/non-active tenant hosts return existing tenant resolution errors
auth/profile/logout routes block maintenance hosts through existing maintenance response behavior
bearer token tenant_id must match resolved request tenant_id before controller execution
cross-tenant mismatch returns permission_denied and does not revoke the source session
same-host me/profile/profile update/logout behavior remains valid
```

Implementation note:

```text
Middleware centralizes host/session tenant matching for current and future customer bearer routes.
Maintenance blocking is applied in middleware for the auth/profile/logout endpoints in this revision while other customer bearer endpoints retain their existing controller-specific maintenance behavior.
```

## Known Risks

```text
none
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

Reason:

```text
Orchestrator must create a focused QA task after Backend Develop produces a revision handoff.
```
