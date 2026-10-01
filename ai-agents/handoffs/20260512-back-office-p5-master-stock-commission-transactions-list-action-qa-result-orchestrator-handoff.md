# Back Office P5 Master Stock Commission Transactions List Action QA Result Orchestrator Handoff

## Agent

Orchestrator

## Task

Route focused QA result back to Coordinator:

```text
back-office-p5-master-stock-commission-transactions-list-action-qa
```

## Source

Coordinator list/action-only decision and Orchestrator QA dispatch:

```text
ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision-coordinator-handoff.md
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-task-orchestrator-handoff.md
```

QA output:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/
```

## What Was Done

Orchestrator reviewed the QA report and key API/browser summary artifacts.

No implementation code was changed by Orchestrator.

QA report and artifacts were found locally after QA completed and are included with this handoff so Coordinator can review the evidence from the shared branch.

## QA Result

```text
FAIL
```

QA does not recommend promoting either remaining row yet:

```text
central:master_stock
tenant:commission_transactions
```

## Findings To Review

### Finding 1: central:master_stock

QA severity:

```text
P1
```

Summary:

```text
Master Stock list does not expose ticket numbers and sends an unsupported number filter.
```

Details:

```text
BO table/filter use number.
Backend list resource returns full_number, front3, back3, and back2.
OpenAPI list contract supports game_id, status, cursor, and limit, not number.
Browser QA saw the Number column render as '-' for QA stock rows.
Applying Number=910001 sent number=910001 and returned all three QA rows.
```

Evidence:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/03-central-stock-supported-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/04-central-stock-unsupported-number-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
```

Key QA values:

```text
stock_rows_expose_inspection_context: false
stockNumberFilter.requestSentUnsupportedNumber: true
stockNumberFilter.rowCountAfterExactNumber: 3
```

Likely owner:

```text
BO Develop
```

Reason:

```text
The backend list already returns stock number context as full_number/front3/back3/back2. The visible BO list/config needs to use supported fields and avoid unsupported filters under the accepted list/action-only contract.
```

### Finding 2: tenant:commission_transactions

QA severity:

```text
P1
```

Summary:

```text
Commission approve workflow lacks safe transaction context and cannot filter approvable rows.
```

Details:

```text
BO catalog uses generic growth columns and status options pending/approved/rejected/paid.
Backend approve path accepts status calculated with transaction_type commission.
Browser QA saw a safe calculated fixture row, but the status dropdown had no Calculated option.
The row hid affiliate account, order, commission rule, transaction type, and amount.
Approve modal showed only the commission id plus Reason, with no context block and no amount/affiliate/order.
```

Evidence:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/09-tenant-commission-calculated-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/10-tenant-commission-approve-modal.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
```

Key QA values:

```text
commission_supported_status_filter_available_for_approvable_rows: false
commission_rows_expose_inspection_context: false
commissionApproveModal.contextItemCount: 0
commissionApproveModal.includesAffiliateAccountId: false
commissionApproveModal.includesAmount: false
```

Likely owner:

```text
BO Develop
```

Reason:

```text
The backend list/action APIs passed. The gap is BO list/filter/action context for safe approval under the accepted list/action-only contract.
```

## Passing Evidence

QA confirmed the backend/API contract worked:

```text
api/api-evidence.json result: PASS
stock_list_loaded_with_rows: true
stock_export_accepted: true
commission_list_loaded_with_fixture: true
commission_approve_status_round_trip: true
all_writes_had_idempotency_key: true
central_scope_headers_present: true
tenant_scope_headers_present: true
no_stock_or_commission_detail_get_called: true
```

Browser QA also confirmed:

```text
real central menu route clicked
real tenant menu route clicked
central stock export submitted with Idempotency-Key
commission approve submitted with Idempotency-Key, tenant scope, and X-Tenant-Id
no undocumented stock detail GET was called
no undocumented commission transaction detail GET was called
Customer frontend/API was not used
```

## Validation

QA reports all required Docker-only validation passed:

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
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

## Coordinator Decision Needed

Coordinator should decide whether to route remediation to BO Develop.

Suggested remediation scope if approved:

```text
central:master_stock
- show actual stock number fields from the existing list resource, especially full_number
- remove unsupported number filter or align it with an approved backend contract
- keep list/export-only contract and do not invent detail endpoint

tenant:commission_transactions
- use commission transaction-specific columns, including affiliate account, order, rule, transaction type, status, and amount
- include calculated status in filters so approvable rows can be found
- add approve confirmation context for amount/affiliate/order/rule/transaction type/status
- keep list/approve-only contract and do not invent detail endpoint
```

Backend remediation does not appear required from QA evidence because the API contract passed. If Coordinator wants backend contract changes anyway, that should be explicit.

## Workspace Note

At Orchestrator review time, unrelated dirty files still existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Agent

```text
Coordinator
```
