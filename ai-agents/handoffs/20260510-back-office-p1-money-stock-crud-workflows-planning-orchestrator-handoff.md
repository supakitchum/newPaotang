# Back Office P1 Money Stock CRUD Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch:

```text
back-office-p1-money-stock-crud-workflows
```

## Coordinator Source

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-review-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-review-coordinator-handoff.md
```

## What Was Done

Created BO Develop task:

```text
ai-agents/tasks/20260510-back-office-p1-money-stock-crud-workflows-bo.md
```

No implementation code was changed by Orchestrator.

## Routing

Next agent:

```text
BO Develop
```

## Accepted Planning Baseline

Coordinator accepted:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

Official corrected BO completion:

```text
0 / 56 complete = 0% verified complete
```

Completion is counted only from real end-to-end CRUD/API workflow coverage with QA evidence. Route/catalog/menu/OpenAPI presence does not count by itself.

## P1 Scope Given To BO

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

Keep as API gaps for now:

```text
central:master_stock
tenant:commission_transactions
```

Coordinator has not approved backend remediation. Backend contract remains frozen.

## Implementation Guardrails

BO Develop must:

```text
use current Meno/admin BO patterns
prefer typed domain forms/modals for high-risk money and stock workflows
avoid raw JSON editors for operator-critical flows where practical
keep confirmation copy explicit and operator-readable
use idempotency keys for writes/actions where backend expects or supports them
preserve tenant scope and X-Tenant-Id behavior
update docs/back-office-crud-coverage.md without marking rows complete before QA
run app validation through Docker only
commit scoped changes and record commit hash
```

BO Develop must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
```

## Validation Plan Given To BO

Docker-only application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
docker compose exec -T platform-api php artisan route:list
```

Local static reads such as `git status --short`, `rg`, `sed`, `ls`, and `git diff --check` are allowed.

## QA Routes To Prepare

```text
/admin/central/stock
/admin/central/allocations
/admin/tenant/stock
/admin/tenant/stock-sync
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/wallets
/admin/tenant/topups
/admin/tenant/growth/payouts
/admin/tenant/payment-settings
```

QA must test access through actual menus and real workflows, not only direct URLs or build/lint/unit checks.

## Next Step After BO Handoff

If BO implementation completes without Coordinator-level backend/API blockers, Orchestrator should create a QA Tester task for real P1 menu workflow QA.

If BO reports a frozen-contract blocker for a P1 workflow, Orchestrator should route back to Coordinator for a backend/API-gap decision.

## Next Agent

BO Develop
