# m5-checkout-wallet-sold-sync - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the Milestone 5 backend slice after M4 Local Stock, Search, Booking approval: Checkout, Wallet, Payment Contract, Sold Sync.

This task is authorized by:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-coordinator-handoff.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
```

Keep this as one Backend Develop implementation task unless a real schema or contract blocker is found and documented for Coordinator review.

## Objective

Implement the customer account baseline, cart/checkout, wallet ledger, payment/topup contract, order/ticket records, tenant admin order/wallet/topup/ticket APIs, and asynchronous sold sync foundation so a reserved local stock item can become a paid order and sold ticket idempotently.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/events.md
- docs/erd.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
- ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
- ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md

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

- Customer auth endpoints resolve active tenant/domain through `TenantHostHeader` or existing tenant-host conventions.
- Customer register requires `Idempotency-Key`, hashes passwords, creates an active customer, creates primary wallet if missing, and returns `CustomerAuthResponse`.
- Customer login validates phone/username and password inside tenant scope and returns `CustomerAuthResponse`.
- Customer refresh rotates or renews access token safely using `refresh_token`.
- Customer logout requires bearer auth and `Idempotency-Key` and revokes only the current customer session.
- Customer `auth/me` and customer/profile read only the authenticated tenant customer.
- Customer profile patch requires `Idempotency-Key`, stays tenant-scoped, records or audits profile changes if an existing customer audit helper exists, and does not expose password/hash/session material.
- `GET /api/v1/customer/cart` returns server-side active reservation/cart state from M4 reservations and local stock.
- `POST /api/v1/customer/checkout` requires authenticated customer, tenant context, and `Idempotency-Key`.
- Checkout validates active reservation ownership, tenant/game consistency, reservation not expired, and local stock still reserved for the customer.
- Checkout must use a DB transaction and row locks for reservation, reservation items/local stock, order idempotency state, and wallet rows when wallet payment is used.
- Wallet checkout debits through `wallet_ledger` only; do not update wallet balances without a posted ledger entry.
- Wallet checkout creates paid order, order_items, tickets, marks reservation converted, marks local stock sold, emits `order.paid.v1`, `stock.sold.v1`, `stock.unavailable.v1`, and `wallet.updated.v1` as applicable.
- External payment checkout creates pending order/payment contract and `redirect_url` or provider payload placeholder; it must not mark local stock sold until payment succeeds.
- Payment webhook contract accepts provider callbacks, dedupes callback ids/references, and finalizes pending payments idempotently when success is represented by the provider payload.
- Topup endpoints create/list/read customer topups and payment placeholders under tenant/customer scope.
- Topup approval must credit wallet through `wallet_ledger` only and emit `wallet.updated.v1`.
- Topup reject/cancel must be idempotent and must not credit wallet.
- Sold sync must process `stock.sold.v1` asynchronously through an explicit command/service/job or inbox consumer and mark central `stock_items` sold without duplicate central mutations on retry.
- Checkout/customer APIs must not write Central Stock Module tables directly; only the sold sync worker/service may update central sold state.
- `IdempotencyService` must prevent duplicate order, ledger, ticket, payment, topup, and sold-sync rows for same actor/route/key/payload.
- Same-key replay must return the original resource/accepted response where applicable before mutable balance/reservation/payment state can reject the retry.
- All tenant admin endpoints require authenticated admin bearer token, `X-Admin-Scope: tenant`, `X-Tenant-Id`, active tenant access, and default-deny permission checks.
- Admin order list/view require `order.view`.
- Admin order patch requires `order.update` and `Idempotency-Key`.
- Admin order cancel requires `order.cancel` and `Idempotency-Key`.
- Admin order refund requires `order.refund` and `Idempotency-Key`; wallet refunds must use wallet_ledger reversal/credit entries, not balance overwrite.
- Admin ticket list/view require `ticket.view`.
- Admin wallet list/view/ledger require `wallet.view`.
- Admin wallet adjust requires `wallet.adjust` and `Idempotency-Key`; adjustments must be audited and ledger-based.
- Admin topup list/view require `topup.view`.
- Admin topup approve/reject/cancel require `topup.approve`/`topup.reject`/`topup.cancel` and `Idempotency-Key`.
- Tenant admin write actions must use centralized audit logging and sensitive redaction.
- Response shapes should match `CustomerAuthResponse`, `CustomerProfile`, `Cart`, `Order`, `WalletListResponse`, `TicketListResponse`, `TicketDetail`, `Topup`, `TopupOverview`, `AdminOrderListResponse`, `AdminOrderDetail`, `AdminResource`, `AdminTopupListResponse`, `AdminTopupDetail`, and `WebhookCallbackAccepted` as closely as current helpers allow.
- Status values must follow `docs/status-enums.md` for stored domain states.
- If OpenAPI response enums differ for topup presentation, document the mapping in the handoff and cover it in tests.
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement customer UI, back-office UI, composables, adapters, pages, SEO, sitemap, or realtime frontend.
- Do not implement LINE login/callback or realtime channel authorization in this slice.
- Do not implement reward result engine, reward status, reward claims, winning ticket processing, or reward payouts.
- Do not implement affiliate, agent, commission, settlement, or reports.
- Do not implement tenant payment-settings/payment-channels admin CRUD unless strictly required as static placeholder data for payment/topup contract tests.
- Do not implement real external payment provider SDK integrations; provider callbacks may be contract/stub based with persistent dedupe.
- Do not implement real file/slip upload storage beyond safe placeholder metadata if needed for topup requests.
- Do not implement real async queue workers beyond persistent outbox/inbox rows and explicit Docker-testable commands/services.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not rewrite M3 allocation or M4 reservation/local-stock search behavior except where needed to consume M4 reservations in checkout.

## File Ownership

Can edit:

```text
apps/platform-api/**
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

If implementation requires API contract, source-of-truth doc, frontend, back-office, customer app, reward, affiliate, reports, settlement, real payment SDK, or real async worker changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect existing tenant resolution, customer auth/session foundation from M4, customer reservation/local stock schema and services, M3 central allocation/stock/outbox implementation, admin auth/session, tenant scope middleware, `PermissionService`, `AuditLogger`, and idempotency helpers.
3. Inspect `docs/openapi.yaml` for all approved customer, admin tenant, and webhook endpoints in this task.
4. Inspect `docs/permissions.md` for mapped tenant permissions.
5. Inspect `docs/events.md` for `order.paid.v1`, `stock.sold.v1`, `wallet.updated.v1`, and related payment/topup/sold sync conventions.
6. Inspect `docs/erd.md` and `docs/status-enums.md` for customer, order, ticket, wallet, payment, topup, checkout, and sold sync schemas/statuses.
7. Add migrations for approved M5 schema scope.
8. Expand the M4 minimal customer/session foundation into the M5 customer account/auth baseline.
9. Implement customer auth register/login/refresh/logout/me/profile endpoints with tenant isolation, password hashing, session/token safety, idempotency on writes, and no secret leakage.
10. Implement customer cart from active M4 reservations/local stock.
11. Implement checkout for wallet and external payment contract paths with transaction locks, idempotency, reservation ownership validation, order/payment/ticket creation, local stock mutation, and outbox event persistence.
12. Implement wallet ledger service so all wallet debits/credits/adjustments/refunds/topup approvals are ledger-based.
13. Implement customer wallet, order, ticket, topup list/create/credit/detail endpoints with tenant/customer isolation and idempotency where required.
14. Implement payment and topup webhook callback contracts with provider callback dedupe and idempotent finalization.
15. Implement sold sync command/service/job or inbox consumer that processes `stock.sold.v1` and marks central stock sold without duplicate central mutations on retry.
16. Implement tenant admin order list/view/update/cancel/refund endpoints with mapped permissions, idempotency on writes, audit, and redaction.
17. Implement tenant admin ticket list/view endpoints with mapped permissions.
18. Implement tenant admin wallet list/view/ledger/adjust endpoints with mapped permissions, ledger-based adjustment, idempotency on writes, audit, and redaction.
19. Implement tenant admin topup list/view/approve/reject/cancel endpoints with mapped permissions, idempotency on writes, ledger-based credit on approval, audit, and redaction.
20. Ensure default deny remains authorization baseline.
21. Ensure checkout/customer APIs do not write Central Stock Module tables directly; sold sync is the only approved central sold-state writer.
22. Add focused automated tests for customer auth, checkout, wallet ledger, customer topups, tenant order/ticket/wallet/topup APIs, payment webhooks, topup webhooks, sold sync, and `IdempotencyService`.
23. Run validation commands through Docker only.
24. Write the required Backend Develop handoff.

## Acceptance Criteria

- Customer register/login/refresh/logout/me/profile endpoints work under tenant context.
- Customer auth/session responses never leak password hashes, access token hashes, refresh token hashes, or secret material.
- Customer cart returns active reservation/cart state for the authenticated tenant customer.
- Customer wallet returns ledger-backed wallet balances.
- Wallet checkout locks reservation and wallet rows and succeeds once.
- Wallet checkout is idempotent; same-key retry does not duplicate order, order_items, tickets, wallet_ledger, payment, outbox, or local stock mutations.
- Wallet debit is ledger-based with posted balance and `wallet.updated.v1` event.
- Paid order marks reservation converted, local stock sold, creates sold tickets, and emits `order.paid.v1` and `stock.sold.v1`.
- External payment checkout creates pending payment/order contract and payment webhook can finalize success idempotently.
- Sold sync command/service consumes `stock.sold.v1` and marks central stock sold without duplicate central state on retry.
- Customer order/ticket/topup read endpoints only return authenticated customer's tenant data.
- Customer topup create/credit/list/detail works with idempotency and tenant/customer isolation.
- Admin order/ticket/wallet/topup endpoints enforce mapped tenant permissions and default deny.
- Admin wallet adjustment and topup approval use `wallet_ledger`, write audit logs, and redact sensitive payloads.
- Admin order refund uses ledger reversal/credit behavior and is idempotent.
- Webhook callbacks dedupe duplicate provider event ids/references.
- All write endpoints in scope reject missing/invalid `Idempotency-Key` where OpenAPI requires it.
- Focused customer auth, checkout, wallet ledger, topup, admin order/ticket/wallet/topup, payment webhook, sold sync, and `IdempotencyService` tests pass.
- Full `platform-api` tests pass.
- No customer/back-office/source-of-truth doc changes are made.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
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

Reason: QA should receive a task only after Backend Develop produces a handoff.
