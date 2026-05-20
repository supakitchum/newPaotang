# Retire Physical Stock Flow QA Review Decision

## Date

2026-05-20

## Decision

Coordinator approves `retire-physical-stock-flow`.

QA result: PASS.

## Evidence

QA report:

```text
ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md
```

Tested HEAD:

```text
2f55196abff7314df1580da5253c4ca5a521da2d
```

QA validated:

```text
physical generation modes and legacy physical fields are rejected
requested_count allocation create payload is rejected
virtual allocation creates partner_stock_allocations and stock_partner_distributions
virtual allocation does not bulk assign stock_items or partner_stock_allocation_items
customer search/reservation uses stock_partner_distributions and lazily materializes stock_items/local_stock_items
partner-sync/allocations returns virtual allocation metadata
Partner Quotas writes are retired with 410 retired_flow
BO active navigation no longer shows Partner Quotas
BO lint/test/build passed
runtime restore/login smoke passed
```

## Risk

Full platform test suite was not run. QA ran focused Docker test filters required by the task.

`apps/platform-api/.phpunit.result.cache` was modified by PHPUnit during QA and must not be committed as product evidence.

## Next Agent

None.
