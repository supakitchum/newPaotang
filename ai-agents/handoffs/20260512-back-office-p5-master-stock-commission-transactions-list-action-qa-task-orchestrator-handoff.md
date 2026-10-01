# Back Office P5 Master Stock Commission Transactions List Action QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route Coordinator-approved list/action-only API-gap closeout scope to QA Tester:

```text
back-office-p5-master-stock-commission-transactions-list-action-qa
```

## Source

Coordinator API-gap decision and handoff:

```text
ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision-coordinator-handoff.md
```

Orchestrator API-gap decision handoff:

```text
ai-agents/handoffs/20260512-back-office-p5-api-gap-decision-master-stock-commission-transactions-orchestrator-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Coordinator accepted list/action-only scope for:

```text
central:master_stock
tenant:commission_transactions
```

No backend detail endpoint remediation is opened under the current frozen contract.

Current coverage before this QA:

```text
54 / 56 complete = 96.4%
2 partial
0 api_gap
```

Remaining partial rows:

```text
central:master_stock
tenant:commission_transactions
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
real central menu route /admin/central/stock
central stock list/filter/export workflow
central scope and Idempotency-Key evidence for export
real tenant menu route /admin/tenant/growth/commission-transactions
commission transaction list/filter/approve workflow
tenant scope, X-Tenant-Id, reason/context, and Idempotency-Key evidence for approve
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
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `central:master_stock` and/or `tenant:commission_transactions` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
