# M5 Checkout, Wallet, Sold Sync Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-qa.md
ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-qa-review-decision.md
ai-agents/tasks/20260507-m5-customer-auth-host-isolation-backend.md
ai-agents/handoffs/20260507-m5-customer-auth-host-isolation-backend-handoff.md
ai-agents/tasks/20260507-m5-customer-auth-host-isolation-qa.md
ai-agents/reports/20260507-m5-customer-auth-host-isolation-qa-report.md
```

Initial QA result:

```text
FAIL
```

Coordinator requested a focused revision for:

```text
D1/P1 - Customer auth/profile endpoints ignore the tenant host for existing bearer sessions
```

Focused QA follow-up result:

```text
PASS
```

Initial Docker validation evidence:

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

Focused Docker validation evidence:

```text
docker compose run --rm platform-api php artisan test --filter=CustomerAuth: PASS, 2 tests, 40 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerCheckout: PASS, 1 test, 30 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerTopup: PASS, 1 test, 21 assertions
docker compose run --rm platform-api php artisan test: PASS, 80 tests, 1140 assertions
```

## Decision

Approve M5 Checkout, Wallet, Payment Contract, Sold Sync slice.

The focused revision closed D1/P1. Authenticated customer auth/profile routes now resolve the request tenant from `Host`, compare it against the bearer session tenant before controller execution, and reject cross-tenant host/token mismatch without leaking profile data or revoking the source tenant session.

## Approved Endpoint Scope

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

## Approved Behavior

```text
customer account/auth expansion over the M4 customer/session foundation
customer register/login/refresh/logout/me/profile under tenant host context
customer bearer middleware host/session tenant isolation after focused revision
customer auth/profile responses without password hashes, token hashes, refresh hashes, or secret material
server-side customer cart from active M4 reservation/local-stock state
customer wallet read with ledger-backed balances
wallet checkout with reservation/local-stock/wallet row locks
wallet checkout idempotency without duplicate order, order_items, tickets, ledger, payment, outbox, or stock mutation
ledger-based wallet debit and wallet.updated.v1 event persistence
paid order creation with order_items, tickets, reservation conversion, local stock sold state, order.paid.v1, stock.sold.v1, and stock.unavailable.v1
external payment pending order/payment contract and idempotent payment webhook finalization
customer order/ticket/topup reads scoped to authenticated tenant customer
customer topup create/credit/list/detail foundation with idempotency and tenant/customer isolation
tenant admin order/ticket/wallet/topup APIs with mapped permissions and default deny
tenant admin write idempotency, centralized audit logging, and sensitive redaction
ledger-based admin wallet adjustment, topup approval credit, and order refund/reversal behavior
payment/topup webhook callback persistence and dedupe
stock:sold:sync explicit command/service consuming stock.sold.v1 through sync_inbox dedupe and marking central stock sold idempotently
IdempotencyService-backed duplicate prevention for approved M5 writes
topup stored-status to OpenAPI presentation mapping documented in Backend handoff
focused CustomerAuth, CustomerCheckout, WalletLedger, CustomerTopup, TenantOrder, TenantWallet, TenantTopup, PaymentWebhook, SoldSync, and IdempotencyService tests
```

## Approval Conditions

This approval is limited to M5 Checkout, Wallet, Payment Contract, Sold Sync and the focused customer auth host-isolation revision.

Accepted M5 risks:

```text
Payment provider behavior is contract/stub based only; no real provider SDK, signature verification, or provider-specific normalization is approved yet.
Webhook routes accept unsigned callbacks because OpenAPI marks X-Signature optional in the current contract.
Sold sync is Docker-testable through an explicit stock:sold:sync command/service; no real queue worker daemon is approved yet.
Checkout uses a fixed placeholder unit price of 10000 minor units until price-rule/payment pricing source is modeled.
Topup stored status follows docs/status-enums.md and is mapped to OpenAPI presentation enums as documented in Backend handoff.
Maintenance blocking is centralized in customer auth middleware for auth/profile/logout paths while other protected customer endpoints keep existing controller-level maintenance behavior.
```

Still out of scope:

```text
apps/customer changes
apps/back-office changes
source-of-truth doc changes
LINE login/callback
customer realtime auth
customer UI and back-office UI
customer app adapter/composables/pages
reward result engine, reward claims, winning ticket processing, and reward payouts
affiliate, agent, commission, settlement, and reports
real payment SDK/provider integration
real async queue worker daemon
real file/slip storage pipeline
```

## Reason

M5 is the required money and issuance foundation after M4 reservations. The approved work enables a reserved local stock item to become a paid order and sold ticket through ledger-based wallet movement and idempotent checkout/sold sync.

The only QA blocker was customer auth/profile host/session tenant isolation. The focused revision centralized the host/session comparison in customer auth middleware, added regression coverage, and QA found no remaining defects.

## Impact

Milestone 5 now has approved:

```text
customer account/session backend baseline
cart and checkout backend foundation
wallet ledger foundation
payment/topup contract foundation
order and ticket record foundation
tenant admin order/ticket/wallet/topup backend APIs
payment/topup webhook dedupe foundation
IdempotencyService foundation for M5 writes
sold sync foundation from partner-local sold stock to Central Stock
Gate D checkout/wallet/sold-sync idempotency coverage
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Coordinator
```
