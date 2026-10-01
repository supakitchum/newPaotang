# back-office-p5-master-stock-commission-transactions-list-action-remediation - BO Handoff

## Summary

BO Develop remediated the focused list/action-only QA findings for:

```text
central:master_stock
tenant:commission_transactions
```

Implementation commit:

```text
885f84a9db5ed37e20c112c73f498510321f06d7
```

Next Agent:

```text
Orchestrator
```

## Files Changed

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Handoff file:

```text
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md
```

No backend, customer frontend, OpenAPI, Docker, GitHub workflow, BOARD, task, decision, or report files were edited.

## central:master_stock Remediation

Route:

```text
/admin/central/stock
```

Preserved API connections:

```text
GET /admin/central/stock
POST /admin/central/stock/exports
POST /admin/central/stock/{stock_item_id}/recall
```

Before list columns:

```text
id
partner_id
number
status
```

After list columns:

```text
id
game_id
partner_id
full_number
front3
back3
back2
status
```

`full_number` is now visible directly in the master stock list, with `front3`, `back3`, and `back2` exposed as supporting number parts.

Before list filters:

```text
game_id
status
number
cursor
limit
```

After list filters:

```text
game_id
status
cursor
limit
```

The unsupported `number` list filter was removed because the backend/OpenAPI list contract supports only `game_id`, `status`, `cursor`, and `limit`.

Before export fields:

```text
game_id
filters.status
number
```

After export fields:

```text
game_id
filters.status
```

The unsupported export ticket number field was also removed. Export still uses:

```text
POST /admin/central/stock/exports
```

with central scope and the existing idempotent collection-action behavior.

Recall confirmation/action context now includes:

```text
id
game_id
full_number
front3
back3
back2
status
partner_id
tenant_id
allocation_id
```

No `GET /admin/central/stock/{stock_item_id}` detail endpoint was added, invented, or called.

## tenant:commission_transactions Remediation

Route:

```text
/admin/tenant/commission-transactions
```

Preserved API connections:

```text
GET /admin/tenant/commission-transactions
POST /admin/tenant/commission-transactions/{commission_id}/approve
```

Before list columns:

```text
id
name
status
created_at
```

After list columns:

```text
id
affiliate_account_id
order_id
commission_rule_id
transaction_type
amount
status
calculated_at
approved_at
```

The list now shows commission transaction-specific context for affiliate account, order, commission rule, transaction type, amount, status, calculation time, and approval time.

Before list filters:

```text
status: pending, approved, rejected, paid
cursor
limit
```

After list filters:

```text
status: calculated, approved, reversed
cursor
limit
```

The `calculated` status filter is available so approvable commission rows can be found.

Approve action behavior:

```text
POST /admin/tenant/commission-transactions/{commission_id}/approve
```

Approve still requires a reason and preserves tenant scope, `X-Tenant-Id`, and the existing idempotent action behavior.

Approve confirmation/action context now includes:

```text
id
tenant_id
affiliate_account_id
order_id
commission_rule_id
transaction_type
status
amount.amount
amount.currency
calculated_at
approved_at
```

This gives QA and operators safe approve context for amount, affiliate/account, order, rule, transaction type, and status before submission.

No `GET /admin/tenant/commission-transactions/{commission_id}` detail endpoint was added, invented, or called. The catalog still marks the missing detail route as an API gap note while keeping list/approve-only behavior.

## Validation

All required validation was run after the final source change.

```text
PASS git diff --check
PASS docker compose up -d postgres valkey platform-api back-office
PASS docker compose run --rm platform-api php artisan migrate:fresh --seed
PASS docker compose run --rm platform-api php artisan test --filter=CentralStockTest
     Tests: 1 passed (33 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=CommissionTest
     Tests: 3 passed (24 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
     Tests: 5 passed (26 assertions)
PASS docker compose run --rm back-office npm run lint
PASS docker compose run --rm back-office npm run test
PASS docker compose run --rm back-office npm run build
PASS docker compose up -d --force-recreate back-office
```

Non-blocking build warnings observed:

```text
(node:18) [DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg referenced in /admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```

## Workspace Notes

Known unrelated dirty files were present and left untouched:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

The local QA credential file above was not staged or committed.

## Blockers

```text
None.
```

