# QA Report: M5 Checkout, Wallet, Sold Sync

## Task

`20260507-m5-checkout-wallet-sold-sync-qa`

## Summary

Result: FAIL

All required Docker validation commands pass, including the full `platform-api` suite, but QA found one blocking P1 tenant-isolation defect. Customer auth/profile endpoints that are documented as tenant-host scoped do not resolve or compare the request `Host` for existing bearer sessions, so a customer token from tenant A can be used against tenant B host for profile reads/profile update/logout.

## Scope Tested

Reviewed the approved M5 checkout/wallet/payment/topup/sold-sync surface:

- Customer auth/profile/cart/checkout/wallet/order/ticket/topup endpoints
- Tenant admin order/ticket/wallet/topup endpoints
- Payment and topup webhook endpoints
- Wallet ledger posting and idempotency
- Checkout reservation conversion, ticket/order creation, local stock sold state, and outbox events
- Sold sync command/service central stock mutation boundary
- Tenant/admin permissions, audit, idempotency, and response shape alignment

## Files Inspected

- `ai-agents/prompts/open-chat-qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `docs/docker-runtime-policy.md`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md`
- `ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-qa.md`
- `ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-qa-task-orchestrator-handoff.md`
- `ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md`
- `docs/openapi.yaml`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/permissions.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/database/migrations/2026_05_07_000001_create_checkout_wallet_sold_sync_tables.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantCommerceController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/WebhookController.php`
- `apps/platform-api/app/Shared/Auth/CustomerAuthService.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`
- `apps/platform-api/app/Shared/PartnerStore/CommerceService.php`
- `apps/platform-api/tests/Feature/CustomerAuthTest.php`
- `apps/platform-api/tests/Feature/CustomerCheckoutTest.php`
- `apps/platform-api/tests/Feature/WalletLedgerTest.php`
- `apps/platform-api/tests/Feature/CustomerTopupTest.php`
- `apps/platform-api/tests/Feature/TenantOrderTest.php`
- `apps/platform-api/tests/Feature/TenantWalletTest.php`
- `apps/platform-api/tests/Feature/TenantTopupTest.php`
- `apps/platform-api/tests/Feature/PaymentWebhookTest.php`
- `apps/platform-api/tests/Feature/SoldSyncTest.php`
- `apps/platform-api/tests/Feature/IdempotencyServiceTest.php`

## Commands Run

All application/runtime commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CustomerAuth
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout
docker compose run --rm platform-api php artisan test --filter=WalletLedger
docker compose run --rm platform-api php artisan test --filter=CustomerTopup
docker compose run --rm platform-api php artisan test --filter=TenantOrder
docker compose run --rm platform-api php artisan test --filter=TenantWallet
docker compose run --rm platform-api php artisan test --filter=TenantTopup
docker compose run --rm platform-api php artisan test --filter=PaymentWebhook
docker compose run --rm platform-api php artisan test --filter=SoldSync
docker compose run --rm platform-api php artisan test --filter=IdempotencyService
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands included `rg`, `sed`, `nl -ba`, and `ls`.

## Test Results

- `migrate:fresh --seed --env=testing`: PASS
- `CustomerAuth`: PASS, 1 test, 19 assertions
- `CustomerCheckout`: PASS, 1 test, 30 assertions
- `WalletLedger`: PASS, 1 test, 18 assertions
- `CustomerTopup`: PASS, 1 test, 21 assertions
- `TenantOrder`: PASS, 1 test, 26 assertions
- `TenantWallet`: PASS, 1 test, 20 assertions
- `TenantTopup`: PASS, 1 test, 30 assertions
- `PaymentWebhook`: PASS, 2 tests, 39 assertions
- `SoldSync`: PASS, 1 test, 16 assertions
- `IdempotencyService`: PASS, 1 test, 3 assertions
- Full platform-api suite: PASS, 79 tests, 1119 assertions

## Endpoint And Schema Findings

M5 routes are registered for customer auth/profile/cart/checkout/wallet/order/ticket/topup, tenant admin order/ticket/wallet/topup, and payment/topup webhook endpoints. The M5 migration adds customer auth/session extensions plus idempotency, wallet, ledger, order, ticket, payment, topup, and webhook callback tables.

The `stock:sold:sync` console command is wired and delegates to `CommerceService::processSoldSync()`. Source review confirms checkout/customer flows emit sold events while central `stock_items` sold mutation is handled by the sold sync worker/service path.

## Checkout / Wallet / Topup Findings

Customer commerce endpoints resolve the tenant by request host and compare it against the bearer customer session before returning or mutating cart, checkout, wallet, order, tickets, and topup resources. Checkout uses transactions, row locks, idempotency replay checks, ledger-based wallet debit, reservation conversion, local stock sold updates, order/ticket creation, and M5 outbox events. Topup approval/credit paths post wallet ledger entries rather than overwriting balances.

## Tenant Admin Findings

Tenant admin order/ticket/wallet/topup routes use `admin.auth` plus `admin.scope:tenant`, enforce permissions through `PermissionService`, require `Idempotency-Key` for writes, and call centralized audit logging for mutable actions. Focused tests cover default-deny and same-key replay for the main M5 admin mutations.

## Webhook / Sold Sync Findings

Payment and topup webhooks persist callback records, dedupe by provider callback key, reject same-key different-payload conflicts, and finalize success callbacks idempotently. Sold sync consumes pending `stock.sold.v1` events and uses `sync_inbox` to avoid duplicate central mutations on retry.

## Defects

### D1/P1: Customer auth/profile endpoints ignore the tenant host for existing bearer sessions

OpenAPI requires `TenantHostHeader` for `POST /customer/auth/logout`, `GET /customer/auth/me`, `GET /customer/profile`, and `PATCH /customer/profile`, and the M5 decision requires customer auth endpoints to resolve the active tenant/domain through host conventions. However, `CustomerAuthController::logout()`, `me()`, `profile()`, and `updateProfile()` only read the `customer_session` attribute and never resolve the request tenant or compare it to the session tenant. `AuthenticateCustomer`/`CustomerSessionResolver` also resolve the bearer token without considering the request host.

Impact: a valid token issued under tenant A can be sent to tenant B's host and still read tenant A profile data, patch tenant A profile data, or revoke tenant A's current session. This violates tenant-host scoping and can produce cross-tenant customer data exposure or cross-tenant session revocation behavior.

Evidence:

- `docs/openapi.yaml:559-610`
- `docs/openapi.yaml:7028-7033`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md:145-151`
- `apps/platform-api/routes/api.php:40-43`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php:74-127`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php:20-30`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php:15-29`
- `apps/platform-api/tests/Feature/CustomerAuthTest.php:69-88`

Recommended owner: Backend Develop.

Recommended fix: make all customer auth/profile endpoints resolve the active tenant from `Host` and reject mismatches against `CustomerSessionContext::tenantId()` before reading, updating, or revoking the session. Add regression coverage with two active tenant domains proving a tenant A bearer token cannot access `/customer/auth/me`, `/customer/profile`, profile PATCH, or logout through tenant B's host.

## Risks / Not Tested

- The current tests do not include cross-tenant customer-auth host mismatch coverage, which is why D1/P1 is not caught by the green suite.
- Webhook signature verification remains placeholder/optional per Backend handoff risk.
- Sold sync is an explicit command/service, not a running async worker in this validation.
- External payment provider integration is stubbed, and the unit price remains a placeholder as documented in the Backend handoff.
- QA did not edit implementation, customer app, back-office app, source-of-truth docs, decisions, tasks, handoffs, or Board files.

## Recommendation

Do not approve M5 until D1/P1 is fixed and covered by focused cross-tenant customer auth/profile regression tests. After the fix, rerun `CustomerAuth`, customer commerce/topup filters as needed, and the full `platform-api` suite.

## Next Agent

Coordinator
