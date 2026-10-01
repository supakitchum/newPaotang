# m5-checkout-wallet-sold-sync Handoff

## Agent

Backend Develop

## Task

Implement Milestone 5 checkout, wallet, payment/topup contract, order/ticket records, tenant admin order/wallet/topup/ticket APIs, idempotency, and sold sync foundation in `apps/platform-api`.

## What Was Done

- Added M5 schema for customer account/auth expansion, `idempotency_keys`, `wallets`, `wallet_ledger`, `orders`, `order_items`, `tickets`, `payments`, `topup_requests`, and `webhook_callbacks`.
- Implemented customer auth register/login/refresh/logout/me/profile with tenant host resolution, password hashing, refresh token rotation, session revocation, idempotent register/profile writes, and secret-safe responses.
- Implemented customer cart, wallet, checkout, order, ticket, and topup APIs.
- Implemented wallet checkout with reservation/local-stock row locks, wallet row locking, ledger debit, paid order/tickets, reservation conversion, local stock sold state, and outbox events.
- Implemented external payment checkout and payment webhook finalization with callback dedupe.
- Implemented customer topup create/credit/list/detail and topup webhook credit finalization.
- Implemented tenant admin order, ticket, wallet, wallet ledger, wallet adjust, topup list/view/approve/reject/cancel APIs.
- Implemented ledger-based admin wallet adjustment, topup approval credit, and order refund reversal/credit behavior with audit logging.
- Implemented `stock:sold:sync` command to consume `stock.sold.v1` outbox events into Central Stock through `sync_inbox` dedupe.
- Added focused feature tests for all M5 validation filters.

## Files Changed

Backend files changed:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantCommerceController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/WebhookController.php
apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/Commerce/CommerceService.php
apps/platform-api/app/Shared/Idempotency/IdempotencyService.php
apps/platform-api/database/migrations/2026_05_07_000001_create_checkout_wallet_sold_sync_tables.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/tests/Feature/CustomerAuthTest.php
apps/platform-api/tests/Feature/CustomerCheckoutTest.php
apps/platform-api/tests/Feature/CustomerTopupTest.php
apps/platform-api/tests/Feature/IdempotencyServiceTest.php
apps/platform-api/tests/Feature/PaymentWebhookTest.php
apps/platform-api/tests/Feature/SoldSyncTest.php
apps/platform-api/tests/Feature/TenantOrderTest.php
apps/platform-api/tests/Feature/TenantTopupTest.php
apps/platform-api/tests/Feature/TenantWalletTest.php
apps/platform-api/tests/Feature/WalletLedgerTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

Handoff file changed:

```text
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
```

## API Endpoints Implemented

```text
POST /api/v1/customer/auth/register
POST /api/v1/customer/auth/login
POST /api/v1/customer/auth/refresh
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
GET /api/v1/customer/profile
PATCH /api/v1/customer/profile
GET /api/v1/customer/cart
POST /api/v1/customer/checkout
GET /api/v1/customer/wallet
GET /api/v1/customer/orders/{order_id}
GET /api/v1/customer/tickets
GET /api/v1/customer/tickets/history
GET /api/v1/customer/tickets/{ticket_id}
GET /api/v1/customer/topups
POST /api/v1/customer/topups
POST /api/v1/customer/topups/credit
GET /api/v1/customer/topups/{topup_id}
GET /api/v1/admin/tenant/orders
GET /api/v1/admin/tenant/orders/{order_id}
PATCH /api/v1/admin/tenant/orders/{order_id}
POST /api/v1/admin/tenant/orders/{order_id}/cancel
POST /api/v1/admin/tenant/orders/{order_id}/refund
GET /api/v1/admin/tenant/tickets
GET /api/v1/admin/tenant/tickets/{ticket_id}
GET /api/v1/admin/tenant/wallets
GET /api/v1/admin/tenant/wallets/{wallet_id}
GET /api/v1/admin/tenant/wallets/{wallet_id}/ledger
PATCH /api/v1/admin/tenant/wallets/{wallet_id}/adjust
GET /api/v1/admin/tenant/topups
GET /api/v1/admin/tenant/topups/{topup_id}
POST /api/v1/admin/tenant/topups/{topup_id}/approve
POST /api/v1/admin/tenant/topups/{topup_id}/reject
POST /api/v1/admin/tenant/topups/{topup_id}/cancel
POST /api/v1/webhooks/payments/{provider}
POST /api/v1/webhooks/topups/{provider}
```

## Permissions/Tenant Checks Enforced

- Customer APIs resolve tenant from Host and compare it to authenticated customer `tenant_id`.
- Customer read APIs query by `tenant_id` + `customer_id`.
- Customer checkout validates reservation ownership, tenant, game, active status, expiry, and reserved local stock.
- Customer checkout does not update Central Stock tables directly.
- Tenant admin APIs require `admin.auth`, `X-Admin-Scope: tenant`, `X-Tenant-Id`, active tenant session scope, and permission checks:
  - `order.view`, `order.update`, `order.cancel`, `order.refund`
  - `ticket.view`
  - `wallet.view`, `wallet.adjust`
  - `topup.view`, `topup.approve`, `topup.reject`, `topup.cancel`
- Tenant admin queries and writes are scoped by selected `tenant_id`.
- Admin write actions require `Idempotency-Key` and write audit logs for order, wallet, and topup mutations.

## Validation

Commands/tests run through Docker:

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

## Known Risks

- Payment provider behavior is contract/stub based only. No real provider SDK, signature verification, or provider-specific payload normalization is implemented in this slice.
- Sold sync is Docker-testable through explicit command `stock:sold:sync`; no real async queue worker daemon was added.
- Checkout uses a fixed placeholder unit price of 10000 minor units because price-rule/payment pricing source is not yet modeled in the approved schema.
- Topup stored status follows `docs/status-enums.md` (`pending`, `processing`, `succeeded`, `failed`, `cancelled`, `expired`, `reversed`) and API presentation maps to OpenAPI enums:
  - `pending` + `bank_transfer` -> `pending_review`
  - `pending`/`processing` for QR or credit -> `pending_payment`
  - `succeeded` -> `approved`
  - `failed`/`reversed` -> `rejected`
- Webhook routes currently accept unsigned callbacks as allowed by the optional OpenAPI `X-Signature` placeholder.

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator
