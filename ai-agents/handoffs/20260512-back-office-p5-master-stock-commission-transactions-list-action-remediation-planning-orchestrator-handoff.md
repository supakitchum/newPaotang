# Back Office P5 Master Stock Commission Transactions List Action Remediation Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

## Source

Coordinator QA review and remediation handoff:

```text
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-coordinator-handoff.md
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-result-orchestrator-handoff.md
```

## What Was Done

Created BO Develop remediation task:

```text
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused list/action-only QA returned FAIL.

Coordinator did not promote:

```text
central:master_stock
tenant:commission_transactions
```

Official BO completion remains:

```text
54 / 56 menus = 96.4%
2 partial
0 api_gap
```

Backend/API evidence passed. Remediation owner is BO Develop unless BO proves the current list/action contract is insufficient.

## Remediation Given To BO

BO Develop must fix:

```text
central:master_stock list/export inspection context
tenant:commission_transactions list/approve inspection context
```

For `central:master_stock`, BO must:

```text
show actual stock number fields from the existing list resource, especially full_number
include useful number parts such as front3, back3, and back2 where useful
remove unsupported number filter from the BO catalog unless a backend contract change is explicitly approved
preserve game_id/status/cursor/limit list behavior
preserve export through POST /admin/central/stock/exports
avoid inventing or calling GET /admin/central/stock/{stock_item_id}
```

For `tenant:commission_transactions`, BO must:

```text
use commission transaction-specific table columns
include affiliate account, order, commission rule, transaction type, status, and amount context
include calculated status in filters so approvable rows can be found
ensure approve confirmation shows safe row context, especially amount and affiliate/order/rule context
preserve tenant scope, X-Tenant-Id, and Idempotency-Key behavior
avoid inventing or calling GET /admin/tenant/commission-transactions/{commission_id}
```

Backend remains frozen. Customer frontend remains frozen.

## Validation Plan Given To BO

Docker-only application validation:

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

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes remediation without reporting a blocker, Orchestrator should create focused QA Tester task for:

```text
central:master_stock
tenant:commission_transactions
```

QA should verify real menu workflows for:

```text
central stock full_number/list/filter/export context
commission transaction calculated filter/list/approve context
central and tenant scope headers
Idempotency-Key on export and approve
no undocumented detail endpoint calls
Customer frontend not used
```

## Next Agent

BO Develop
