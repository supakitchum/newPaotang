# m5-checkout-wallet-sold-sync - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Milestone 5 Checkout, Wallet, Payment Contract, Sold Sync backend handoff. Validate the implementation against the approved Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permission model, status/event contracts, ERD, M4 approval dependency, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-decision.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-coordinator-handoff.md
ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
```

## Objective

Validate the Milestone 5 backend slice and produce a QA report covering customer account/auth, cart, checkout, wallet ledger, payment/topup contracts, order/ticket records, tenant admin order/wallet/topup/ticket APIs, webhook callback dedupe, IdempotencyService behavior, and sold sync from local paid stock back to Central Stock.

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
- ai-agents/tasks/20260507-m5-checkout-wallet-sold-sync-backend.md
- ai-agents/handoffs/20260507-m5-checkout-wallet-sold-sync-backend-handoff.md

## Scope

Validate only the approved M5 endpoint scope:

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

Validate implementation and tests in:

```text
apps/platform-api/**
```

Validate these schema/workflow areas:

```text
customers
customer_auth_sessions
idempotency_keys or IdempotencyService-backed equivalent
wallets
wallet_ledger
orders
order_items
tickets
payments
topup_requests
webhook_callbacks or equivalent callback dedupe storage
sync_outbox and sync_inbox rows for order.paid.v1, stock.sold.v1, wallet.updated.v1, and sold sync processing
stock:sold:sync explicit command/service
```

Validate these behavior areas:

- Customer auth/register/login/refresh/logout/me/profile tenant isolation and secret-safe responses.
- Customer cart from active M4 reservation/local-stock state.
- Checkout reservation ownership, tenant/game consistency, non-expired reservation validation, local stock reserved state, transaction locks, idempotency, and no direct Central Stock writes.
- Wallet checkout ledger debit, paid order/order_items/tickets, reservation conversion, local stock sold state, and event persistence.
- External payment checkout pending order/payment contract and webhook success finalization.
- Customer wallet/order/ticket/topup reads scoped to authenticated tenant customer.
- Customer topup create/credit/list/detail idempotency and wallet ledger credit behavior.
- Tenant admin order/ticket/wallet/topup permissions, default deny, tenant access checks, idempotency on writes, audit, and redaction.
- Wallet adjustment, order refund, and topup approval must use `wallet_ledger`, not balance overwrites.
- Payment/topup webhook callback dedupe for duplicate provider event ids/references.
- Sold sync command/service consumes `stock.sold.v1` and updates central `stock_items` sold state idempotently.
- Topup stored status to OpenAPI presentation mapping is documented in Backend handoff and covered by tests.
- Backend known risks are correctly bounded: fixed placeholder unit price, contract/stub payment provider behavior, unsigned callbacks per optional signature placeholder, explicit command instead of real async worker.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not create or edit `apps/back-office/**`.
- Do not edit source-of-truth docs in `docs/**` or `document/**`.
- Do not implement customer UI, back-office UI, composables, adapters, pages, SEO, sitemap, or realtime frontend.
- Do not implement LINE login/callback or realtime channel authorization.
- Do not implement reward result engine, reward claims, winning-ticket processing, or reward payouts.
- Do not implement affiliate, agent, commission, settlement, or reports.
- Do not require real external payment provider SDK integrations.
- Do not require real file/slip upload storage beyond approved placeholder metadata.
- Do not require real async queue workers beyond persistent outbox/inbox rows and explicit Docker-testable commands/services.
- Do not rewrite M3 allocation or M4 reservation/local-stock behavior except as already consumed by M5 checkout.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, reproduction/evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy before validating.
3. Compare the Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm whether Backend changed only approved implementation/handoff paths.
5. Inspect M5 routes, console command wiring, migration, auth/session services, commerce service, idempotency service, controllers, fixtures, and feature tests listed in the Backend handoff.
6. Inspect OpenAPI sections for all approved customer, tenant admin, and webhook endpoints and compare request/response/header behavior against implementation.
7. Inspect `docs/permissions.md`, `docs/events.md`, `docs/status-enums.md`, and `docs/erd.md` against implemented order, ticket, wallet, ledger, payment, topup, webhook, idempotency, and sold sync behavior.
8. Validate customer auth/session safety, tenant isolation, refresh rotation/renewal, logout revocation, and no password/token hash leakage.
9. Validate checkout, wallet ledger, payment contract, payment webhook finalization, order/ticket creation, local-stock sold state, outbox events, and idempotency replay/non-duplication.
10. Validate sold sync command/service, sync inbox dedupe, central stock sold mutation, and retry safety.
11. Validate customer wallet/order/ticket/topup read/write tenant/customer isolation.
12. Validate tenant admin order/ticket/wallet/topup permissions, default deny, tenant access, audit, redaction, idempotency, ledger adjustments, refunds, and topup approval/reject/cancel behavior.
13. Validate webhook callback dedupe and unsigned callback risk against current OpenAPI signature placeholder.
14. Validate topup domain-status to OpenAPI presentation mapping and test coverage.
15. Run all required validation commands through Docker only.
16. Write a QA report with pass/fail status, evidence, defects, known risks/questions, validation results, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md`.
- QA report states whether the M5 implementation passes, conditionally passes, or fails.
- QA report covers all approved M5 endpoints.
- QA report covers customer auth/profile/cart/checkout/wallet/order/ticket/topup, tenant admin order/ticket/wallet/topup, payment/topup webhooks, idempotency, wallet ledger, outbox/inbox, and sold sync.
- QA report lists every validation command run and result.
- QA report identifies any source-of-truth mismatch or behavioral defect with file/evidence references.
- QA report explicitly evaluates Backend's known risks: fixed placeholder unit price, stub payment providers, unsigned callback acceptance, explicit sold sync command, and topup status mapping.
- QA report confirms no out-of-scope customer/back-office/source-of-truth doc changes were required by QA.
- QA report recommends the next Coordinator action.

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

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,360p' apps/platform-api/routes/api.php
sed -n '1,220p' apps/platform-api/routes/console.php
sed -n '1,520p' apps/platform-api/database/migrations/2026_05_07_000001_create_checkout_wallet_sold_sync_tables.php
sed -n '1,520p' apps/platform-api/app/Shared/Auth/CustomerAuthService.php
sed -n '1,420p' apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
sed -n '1,760p' apps/platform-api/app/Shared/Commerce/CommerceService.php
sed -n '1,360p' apps/platform-api/app/Shared/Idempotency/IdempotencyService.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerAuthController.php
sed -n '1,620p' apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php
sed -n '1,620p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantCommerceController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/WebhookController.php
sed -n '1,620p' apps/platform-api/tests/Support/M5CommerceFixtures.php
sed -n '1,520p' apps/platform-api/tests/Feature/CustomerAuthTest.php
sed -n '1,560p' apps/platform-api/tests/Feature/CustomerCheckoutTest.php
sed -n '1,420p' apps/platform-api/tests/Feature/WalletLedgerTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/CustomerTopupTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/TenantOrderTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/TenantWalletTest.php
sed -n '1,520p' apps/platform-api/tests/Feature/TenantTopupTest.php
sed -n '1,520p' apps/platform-api/tests/Feature/PaymentWebhookTest.php
sed -n '1,420p' apps/platform-api/tests/Feature/SoldSyncTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/IdempotencyServiceTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m5-checkout-wallet-sold-sync-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
endpoint coverage
customer auth/session findings
checkout and wallet ledger findings
idempotency findings
order/ticket/topup findings
tenant admin authorization and permission findings
payment and topup webhook findings
sold sync findings
outbox/inbox event findings
audit and redaction findings
topup status mapping findings
known risk assessment
defects with severity and evidence
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
