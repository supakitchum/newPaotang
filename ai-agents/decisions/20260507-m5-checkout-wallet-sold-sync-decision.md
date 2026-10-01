# M5 Checkout, Wallet, Payment Contract, Sold Sync Decision

## Context

Approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
```

The platform now has approved tenant/domain/RBAC/admin/audit, partner provisioning, central stock/allocation, partner-local stock sync/search, customer reservation, reservation expiration, and local booking lock foundations.

The main execution plan now moves to:

```text
Milestone 5: Checkout, Wallet, Payment Contract, Sold Sync
```

M5 depends on M4 reservations and local stock. Gate D requires checkout, wallet ledger, and sold sync to be idempotent.

## Decision

Start the next backend slice: M5 Checkout, Wallet, Payment Contract, Sold Sync.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep this as one implementation task unless a real schema or contract blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Objective

Implement the customer account baseline, cart/checkout, wallet ledger, payment/topup contract, order/ticket records, tenant admin order/wallet/topup/ticket APIs, and asynchronous sold sync foundation so a reserved local stock item can become a paid order and sold ticket idempotently.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/events.md
docs/erd.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
```

## Scope

Approved endpoint scope:

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

Approved implementation scope:

```text
apps/platform-api/**
```

Approved schema scope:

```text
customers customer account/auth fields extending the M4 minimal customer foundation
customer_auth_sessions refresh-token/session support or equivalent existing session extension
orders
order_items
tickets
wallets
wallet_ledger
payments
topup_requests
idempotency_keys or IdempotencyService-backed equivalent
payment/topup webhook callback storage or sync_inbox-backed equivalent
sync_outbox and sync_inbox rows needed for order.paid.v1, stock.sold.v1, wallet.updated.v1, and sold sync processing
```

Implementation requirements:

```text
customer auth endpoints resolve active tenant/domain through TenantHostHeader or existing tenant-host conventions
customer register requires Idempotency-Key, hashes passwords, creates an active customer, creates primary wallet if missing, and returns CustomerAuthResponse
customer login validates phone/username and password inside tenant scope and returns CustomerAuthResponse
customer refresh rotates or renews access token safely using refresh_token
customer logout requires bearer auth and Idempotency-Key and revokes only the current customer session
customer auth/me and customer/profile read only the authenticated tenant customer
customer profile patch requires Idempotency-Key, stays tenant-scoped, audits or records profile changes if existing customer audit helper exists, and does not expose password/hash/session material
GET /customer/cart returns server-side active reservation/cart state from M4 reservations and local stock
POST /customer/checkout requires authenticated customer, tenant context, and Idempotency-Key
checkout validates active reservation ownership, tenant/game consistency, reservation not expired, and local stock still reserved for the customer
checkout must use a DB transaction and row locks for reservation, reservation items/local stock, order idempotency state, and wallet rows when wallet payment is used
wallet checkout debits through wallet_ledger only; do not update wallet balances without a posted ledger entry
wallet checkout creates paid order, order_items, tickets, marks reservation converted, marks local stock sold, emits order.paid.v1, stock.sold.v1, stock.unavailable.v1, and wallet.updated.v1 as applicable
external_payment checkout creates pending order/payment contract and redirect_url or provider payload placeholder; it must not mark local stock sold until payment succeeds
payment webhook contract accepts provider callbacks, dedupes callback ids/references, and finalizes pending payments idempotently when success is represented by the provider payload
topup endpoints create/list/read customer topups and payment placeholders under tenant/customer scope
topup approval must credit wallet through wallet_ledger only and emit wallet.updated.v1
topup reject/cancel must be idempotent and must not credit wallet
sold sync must process stock.sold.v1 asynchronously through an explicit command/service/job or inbox consumer and mark central stock_items sold without duplicate central mutations on retry
checkout/customer APIs must not write Central Stock Module tables directly; only the sold sync worker/service may update central sold state
IdempotencyService must prevent duplicate order, ledger, ticket, payment, topup, and sold-sync rows for same actor/route/key/payload
same-key replay must return the original resource/accepted response where applicable before mutable balance/reservation/payment state can reject the retry
all tenant admin endpoints require authenticated admin bearer token, X-Admin-Scope: tenant, X-Tenant-Id, active tenant access, and default-deny permission checks
admin order list/view require order.view
admin order patch requires order.update and Idempotency-Key
admin order cancel requires order.cancel and Idempotency-Key
admin order refund requires order.refund and Idempotency-Key; wallet refunds must use wallet_ledger reversal/credit entries, not balance overwrite
admin ticket list/view require ticket.view
admin wallet list/view/ledger require wallet.view
admin wallet adjust requires wallet.adjust and Idempotency-Key; adjustments must be audited and ledger-based
admin topup list/view require topup.view
admin topup approve/reject/cancel require topup.approve/topup.reject/topup.cancel and Idempotency-Key
tenant admin write actions must use centralized audit logging and sensitive redaction
response shapes should match CustomerAuthResponse, CustomerProfile, Cart, Order, WalletListResponse, TicketListResponse, TicketDetail, Topup, TopupOverview, AdminOrderListResponse, AdminOrderDetail, AdminResource, AdminTopupListResponse, AdminTopupDetail, and WebhookCallbackAccepted as closely as current helpers allow
status values must follow docs/status-enums.md for stored domain states; if OpenAPI response enums differ for topup presentation, Backend Develop must document the mapping in the handoff and cover it in tests
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement customer UI, back-office UI, composables, adapters, pages, SEO, sitemap, or realtime frontend.
Do not implement LINE login/callback or realtime channel authorization in this slice.
Do not implement reward result engine, reward status, reward claims, winning ticket processing, or reward payouts.
Do not implement affiliate, agent, commission, settlement, or reports.
Do not implement tenant payment-settings/payment-channels admin CRUD unless strictly required as static placeholder data for payment/topup contract tests.
Do not implement real external payment provider SDK integrations; provider callbacks may be contract/stub based with persistent dedupe.
Do not implement real file/slip upload storage beyond safe placeholder metadata if needed for topup requests.
Do not implement real async queue workers beyond persistent outbox/inbox rows and explicit Docker-testable commands/services.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not rewrite M3 allocation or M4 reservation/local-stock search behavior except where needed to consume M4 reservations in checkout.
```

## Acceptance Criteria

```text
Customer register/login/refresh/logout/me/profile endpoints work under tenant context.
Customer auth/session responses never leak password hashes, access token hashes, refresh token hashes, or secret material.
Customer cart returns active reservation/cart state for the authenticated tenant customer.
Customer wallet returns ledger-backed wallet balances.
Wallet checkout locks reservation and wallet rows and succeeds once.
Wallet checkout is idempotent; same-key retry does not duplicate order, order_items, tickets, wallet_ledger, payment, outbox, or local stock mutations.
Wallet debit is ledger-based with posted balance and wallet.updated.v1 event.
Paid order marks reservation converted, local stock sold, creates sold tickets, and emits order.paid.v1 and stock.sold.v1.
External payment checkout creates pending payment/order contract and payment webhook can finalize success idempotently.
Sold sync command/service consumes stock.sold.v1 and marks central stock sold without duplicate central state on retry.
Customer order/ticket/topup read endpoints only return authenticated customer's tenant data.
Customer topup create/credit/list/detail works with idempotency and tenant/customer isolation.
Admin order/ticket/wallet/topup endpoints enforce mapped tenant permissions and default deny.
Admin wallet adjustment and topup approval use wallet_ledger, write audit logs, and redact sensitive payloads.
Admin order refund uses ledger reversal/credit behavior and is idempotent.
Webhook callbacks dedupe duplicate provider event ids/references.
All write endpoints in scope reject missing/invalid Idempotency-Key where OpenAPI requires it.
Focused customer auth, checkout, wallet ledger, topup, admin order/ticket/wallet/topup, payment webhook, sold sync, and IdempotencyService tests pass.
Full platform-api tests pass.
No customer/back-office/source-of-truth doc changes are made.
Backend Develop writes a handoff to ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

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

## Reason

M5 is the next dependency in the main plan. Checkout, ledger-based wallet movement, order/ticket creation, and sold sync are required before customer app integration, reward result processing, reports, commission, settlement, and production load testing become meaningful.

This slice is intentionally large to keep velocity high while preserving a single coherent backend boundary: money movement and paid ticket issuance.

## Impact

Orchestrator should create one Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend, customer app, back-office app, reward, affiliate, reports, settlement, real payment SDK, or real async queue worker work is approved by this decision.

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
