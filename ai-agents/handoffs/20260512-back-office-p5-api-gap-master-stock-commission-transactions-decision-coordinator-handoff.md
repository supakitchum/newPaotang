# Coordinator Handoff - Back Office P5 API Gap Master Stock Commission Transactions Decision

Date: 2026-05-12
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p5-api-gap-decision-master-stock-commission-transactions`
Next Task: `back-office-p5-master-stock-commission-transactions-list-action-qa`

## Summary

Coordinator accepted list/action-only scope for the two remaining API-gap rows:

```text
central:master_stock
tenant:commission_transactions
```

No backend detail endpoint remediation is opened under the current frozen contract.

Official BO completion remains 54/56 menus, or 96.4%, until focused QA proves the real menu workflows.

## Decision

See:

```text
ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md
```

## Coverage After This Decision

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

## Next Instruction For Orchestrator

Open focused QA:

```text
back-office-p5-master-stock-commission-transactions-list-action-qa
```

Expected first owner:

```text
QA Tester
```

## Required QA Scope

QA must verify:

- Real central BO menu route `/admin/central/stock`.
- `central:master_stock` list/filter inspection through `GET /admin/central/stock`.
- Export action through `POST /admin/central/stock/exports` with central scope and `Idempotency-Key`.
- Shared stock actions must not depend on a fake detail endpoint.
- Real tenant BO menu route `/admin/tenant/growth/commission-transactions`.
- `tenant:commission_transactions` list/filter workflow through `GET /admin/tenant/commission-transactions`.
- Approve action through `POST /admin/tenant/commission-transactions/{commission_id}/approve` with tenant scope, `X-Tenant-Id`, reason/context, and `Idempotency-Key`.
- No calls to undocumented `GET /admin/central/stock/{stock_item_id}`.
- No calls to undocumented `GET /admin/tenant/commission-transactions/{commission_id}`.
- Customer frontend must not be used.

## Validation Direction

Use Docker-only validation. Suggested minimum:

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

## Guardrails

- Do not open backend remediation for these detail endpoints unless QA proves list/action-only workflow cannot satisfy BO completion.
- Do not ask BO Develop to invent frontend-only detail pages.
- Do not count route/catalog/menu presence alone as completion.
- Promote either row only after focused real menu QA passes.
- Customer frontend remains frozen.
- Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.

## Next Agent

```text
Orchestrator
```
