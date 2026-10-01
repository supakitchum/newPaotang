# Back Office P1 Money Stock CRUD Workflows QA Report

## Summary

Agent: QA Tester

Task: `back-office-p1-money-stock-crud-workflows`

Date: 2026-05-10

Branch: `develop`

HEAD under test: `15b75ceb0b050d997edc8ed9d5b4f6ae4165bf23`

Implementation under test: `8a245b2a4244171bff786d1586570822e69671f0`

Result: QA found one blocking workflow-context defect in tenant orders. Route to Coordinator for ownership decision.

## Review Findings

### Finding 1 (apps/back-office/composables/useAdminOperationsCatalog.ts:168,286-328) [added]
[P1] Tenant order financial actions omit customer context

The tenant order catalog renders the `Customer` column from `customer_id` and uses `moneyActionContext`, which also includes `customer_id`, for Update/Cancel/Refund confirmations. The admin order API response supplies the customer as a nested `customer` object, not as top-level `customer_id`, so the order list shows `Customer` as `-` and the Update/Cancel/Refund modals omit the customer context. These are destructive/financial workflows, and QA acceptance requires typed fields plus sufficient confirmation context for safe operator decisions.

Evidence:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-from-menu.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-update-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-cancel-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-refund-modal.snapshot.txt
```

Observed:

```text
row "ord_qa_p1_alpha - Paid ..."
updateContextHasCustomer: false
cancelContextHasCustomer: false
refundContextHasCustomer: false
```

## Docker Validation

All required Docker-only validation commands passed:

```text
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Key results:

```text
AdminAuthTest: 9 passed, 78 assertions
AdminMenuTest: 5 passed, 26 assertions
AdminOperationsTest: 7 passed, 95 assertions
back-office lint: passed
back-office test: passed
back-office build: passed
```

Artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/
```

## Browser QA Coverage

Authenticated menu evidence was captured for the required central and tenant routes. QA used local Docker database fixtures only, recorded in:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/create-qa-game-fixture.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/create-qa-stock-fixture.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/create-qa-allocation-fixture.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/create-tenant-qa-fixtures.txt
```

No destructive or financial action was submitted through the UI. QA captured non-destructive modal/form evidence and verified required reason guards where applicable.

## Row Results

`central:stock_generation`: verified from real central menu. List, filters, import/generate/export typed modals, and mobile 390x844 sanity passed.

`central:allocations`: verified from real central menu. List, detail, typed create modal, cancel context, and reason guard passed.

`central:stock_recall`: verified on fixture stock row. Recall modal showed row context and required reason before confirm.

`tenant:local_stock`: verified from tenant menu. List, detail, export modal, and tenant session route passed.

`tenant:stock_sync`: verified from tenant menu. List, detail, create sync batch modal with operator note and reason passed.

`tenant:reservations`: verified under list/action-only rule. Cancel modal showed reservation/customer/status/expires context and required reason.

`tenant:orders`: blocked by Finding 1. Detail and typed Update/Cancel/Refund modals exist and require reason, but list and action modals omit customer context.

`tenant:wallets`: verified from tenant menu. List, detail, adjust modal with money fields, customer context, reason guard, ledger related list, and mobile 390x844 sanity passed.

`tenant:topups`: verified from tenant menu. Detail and approve/reject/cancel modals showed typed controls, notify control, context, and reason guards.

`tenant:payouts`: verified under Coordinator list/action-only rule. Create payout typed modal and approve modal passed; approve modal included affiliate context. Payout list itself did not show affiliate id, but the action confirmation did.

`tenant:payment_settings`: verified from tenant menu. Settings form/save controls, payment channel list/detail/create/update/archive modals, reason guard, and mobile 390x844 sanity passed.

Out of scoring, unchanged:

```text
central:master_stock
tenant:commission_transactions
```

## Workspace Notes

Existing unrelated dirty files from task dispatch were left untouched:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
```

Additional dirty files observed after validation/browser work and left untouched:

```text
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
```

User noted that Backend had previously been ordered to fix a bug. QA reviewed current handoffs and recent task context for this slice; no separate Backend remediation handoff or commit was found beyond the current BO/Orchestrator QA dispatch path.

## Routing

Next agent: Coordinator

Reason: QA Tester must not directly assign implementation work back to Backend or BO. Coordinator should decide whether Finding 1 goes to BO Develop, Backend, or both.
