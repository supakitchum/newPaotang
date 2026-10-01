# Back Office P5 Master Stock Commission Transactions Remediation QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO remediation to QA Tester:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

## Source

Coordinator QA review decision and handoff:

```text
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-coordinator-handoff.md
```

BO remediation task and completion handoff:

```text
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md
```

Previous QA evidence:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/api/api-evidence.json
```

## What Was Done

Created focused QA Tester task:

```text
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Under Test

BO Develop remediated:

```text
central:master_stock
tenant:commission_transactions
```

Implementation commit:

```text
885f84a9db5ed37e20c112c73f498510321f06d7
```

BO handoff commit:

```text
07f2dec6eab71d6affccf6642165c949589e5d4c
```

Changed implementation file:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

## BO Remediation Summary

For `central:master_stock`, BO reports:

```text
full_number, front3, back3, and back2 are now visible in the list
unsupported number list filter was removed
unsupported export ticket number input was removed
export still uses POST /admin/central/stock/exports
central scope and existing idempotent collection-action behavior were preserved
no GET /admin/central/stock/{stock_item_id} detail endpoint was added or called
```

For `tenant:commission_transactions`, BO reports:

```text
commission-specific columns now include affiliate_account_id, order_id, commission_rule_id, transaction_type, amount, status, calculated_at, and approved_at
status filter now includes calculated, approved, and reversed
approve action context now includes amount, affiliate/order/rule context, transaction type, status, and timestamps
approve still requires reason
tenant scope, X-Tenant-Id, and existing idempotent action behavior were preserved
no GET /admin/tenant/commission-transactions/{commission_id} detail endpoint was added or called
```

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused real-menu QA only:

```text
central:master_stock
/admin/central/stock
GET /admin/central/stock
POST /admin/central/stock/exports

tenant:commission_transactions
/admin/tenant/growth/commission-transactions
GET /admin/tenant/commission-transactions
POST /admin/tenant/commission-transactions/{commission_id}/approve
```

QA must verify:

```text
central stock list shows full_number plus number part context
central stock no longer exposes or sends unsupported number filter
central stock export no longer exposes unsupported ticket number input
central stock export uses central scope and Idempotency-Key
commission transaction list shows commission-specific context
commission status filter includes calculated and can find approvable rows
commission approve modal shows amount plus affiliate/order/rule context and requires reason
commission approve uses tenant scope, X-Tenant-Id, and Idempotency-Key
no calls to undocumented GET /admin/central/stock/{stock_item_id}
no calls to undocumented GET /admin/tenant/commission-transactions/{commission_id}
Customer frontend not used
```

## Validation Plan Given To QA

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=CommissionTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected QA Output

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `central:master_stock` and/or `tenant:commission_transactions` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
