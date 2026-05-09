# Back Office P1 Money Stock CRUD Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO P1 money/stock implementation to QA Tester.

## Source

BO Develop handoff:

```text
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

Coordinator restart decision:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p1-money-stock-crud-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 8a245b2a4244171bff786d1586570822e69671f0
Handoff commit: 3a211e8c56222e8f5c1ec0249d7ca34f5b854c2c
Route-to-Orchestrator commit: 15c94717912d810281576818ccfd9196a65c5db6
```

BO surfaced P1 workflows for:

```text
central:stock_generation
central:allocations
central:stock_recall
tenant:local_stock
tenant:stock_sync
tenant:reservations
tenant:orders
tenant:wallets
tenant:topups
tenant:payouts
tenant:payment_settings
```

BO found no backend blocker inside the frozen P1 contract.

Still out of scoring:

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

QA must test real authenticated BO menu workflows, not only build/lint/unit checks:

```text
central stock import/generate/export and recall modal context
central allocations create/cancel
tenant stock export and stock sync create batch
tenant reservation cancel
tenant order update/cancel/refund
tenant wallet adjustment and ledger related list
tenant topup approve/reject/cancel
tenant payout create/approve
tenant payment settings save and payment channel create/update/archive/detail
```

QA must not mark a row complete unless verified from the real menu with evidence.

## Validation Plan Given To QA

Docker-only:

```sh
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

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
```

These appear to be BO role/rule updates and were not edited, staged, or committed by Orchestrator. QA should also leave them untouched if they are still dirty.

## Expected QA Output

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA finds implementation defects, report severity and likely owner. If QA finds frozen backend contract blockers, route to Coordinator for backend remediation approval rather than editing backend.

## Next Agent

QA Tester
