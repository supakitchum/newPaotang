# m4-stock-search-store-filter - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused M4 revision for:

```text
D1/P2 - Public stock search ignores the documented store filter
```

Validate the revision against the Coordinator QA review decision, the Backend revision task, the Backend revision handoff, the original M4 public stock search contract, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md
ai-agents/handoffs/20260506-m4-local-stock-booking-qa-review-coordinator-handoff.md
ai-agents/tasks/20260506-m4-stock-search-store-filter-backend.md
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
```

## Objective

Validate that `GET /api/v1/public/stock/search` now applies the documented `store_id` filter inside resolved tenant and requested game scope, returns only stock associated with the requested store/seller, never leaks another tenant's stock, and still composes with the approved search filters and pagination behavior.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/status-enums.md
- docs/events.md
- docs/erd.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
- ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
- ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
- ai-agents/tasks/20260506-m4-local-stock-booking-qa.md
- ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
- ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md
- ai-agents/handoffs/20260506-m4-local-stock-booking-qa-review-coordinator-handoff.md
- ai-agents/tasks/20260506-m4-stock-search-store-filter-backend.md
- ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md

## Scope

Validate only the focused revision for:

```text
GET /api/v1/public/stock/search
store_id query filter
tenant-local local_stock_items store/seller association
stock sync store_id persistence/default behavior
```

Inspect only approved revision files and related evidence:

```text
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
```

Validate that:

- `local_stock_items` has a suitable nullable `store_id` or equivalent store/seller association.
- Local stock uniqueness/indexing remains tenant/game/store safe.
- Stock sync persists store association when event payload contains `store_id`, `seller_id`, `store.id`, `seller.id`, `store`, or `seller`.
- Stock sync defaults safely when M3 `stock.allocated.v1` payload has no store signal.
- `PartnerStoreService::searchLocalStock()` validates and applies non-empty `store_id` inside tenant/game/available-stock scope.
- `store_id` returns only stock associated with the requested store/seller.
- `store_id` never leaks another tenant's stock.
- `number`, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit` still work with `store_id` as applicable.
- No M3 central allocation behavior, reservation behavior, tenant admin behavior, outbox payload behavior, customer app, back-office app, or source-of-truth docs were changed.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates another follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not create or edit `apps/back-office/**`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not implement public store list.
- Do not implement customer auth/login.
- Do not implement cart, checkout, order, payment, wallet, tickets, sold sync, reward, or UI.
- Do not require a first-class tenant store/seller table in this revision unless Coordinator creates a separate task.
- Do not change reservation locking, expiration, tenant admin stock/sync/reservation behavior, outbox event payloads, or broad idempotency semantics.
- Do not rewrite M3 central allocation behavior.
- Do not require real export file generation or async workers.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend revision handoff against the Backend revision task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm whether the revision changed only approved files plus the Backend handoff.
5. Inspect the local stock migration and verify store association/indexing is tenant/game/store safe.
6. Inspect `PartnerStoreService` search and sync behavior for store association persistence, defaulting, validation, and filtering.
7. Inspect `PartnerStoreFixtures`, `PublicStockSearchTest`, and `LocalStockSyncTest` for focused regression coverage.
8. Verify two stores under one tenant can have matching searchable values and `store_id` returns only the requested store's stock.
9. Verify `store_id` never leaks another tenant's stock.
10. Verify `number`, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit` behavior still composes with `store_id`.
11. Evaluate Backend's questions about future first-class tenant store/seller table and whether `LocalStockItem` responses should include `store_id` as risks/questions for Coordinator.
12. Run all required validation commands through Docker only.
13. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m4-stock-search-store-filter-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report verifies D1/P2 is closed or identifies why it remains open.
- QA report confirms `store_id` filter applies within resolved tenant and requested game scope.
- QA report confirms same-tenant matching searchable values can be store-filtered.
- QA report confirms no cross-tenant stock leak with `store_id`.
- QA report confirms `number`, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit` still work with `store_id` where applicable.
- QA report lists all validation commands run and results.
- QA report includes Backend's store registry / response-shape questions as Coordinator risks/questions.
- QA report confirms no out-of-scope app, docs, decision, task, handoff, or Board changes were made by QA.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,460p' apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
sed -n '1,560p' apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
sed -n '1,360p' apps/platform-api/tests/Support/PartnerStoreFixtures.php
sed -n '1,560p' apps/platform-api/tests/Feature/PublicStockSearchTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/LocalStockSyncTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260506-m4-stock-search-store-filter-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
D1/P2 closure assessment
store_id schema/index findings
stock sync store association findings
public stock search filter findings
tenant isolation findings
filter composition findings
regression findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
