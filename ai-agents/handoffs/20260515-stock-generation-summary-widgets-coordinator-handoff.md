# Stock Generation Summary Widgets Coordinator Handoff

## Agent

Coordinator

## Task

Open work for stock generation summary widgets.

## Source Request

User requested widgets for Stock Generation showing:

```text
ยอดรวมสลาก
ยอดรวมเลข 2 ท้าย
ยอดรวมเลข 3 ท้าย
ยอดรวมเลข 3 หน้า
จำนวนรวมตามสถานะ
```

## Coordinator Decision

Decision file:

```text
ai-agents/decisions/20260515-stock-generation-summary-widgets-decision.md
```

Coordinator decided this needs an Orchestrator split because it likely touches:

```text
apps/platform-api/**
docs/openapi.yaml
docs/permissions.md
apps/back-office/**
ai-agents/tasks/**
ai-agents/reports/**
```

## Scope For Orchestrator

Create task prompts for:

```text
Backend Develop
BO Develop
QA Tester
```

Recommended order:

```text
Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

Backend must expose a widget-friendly aggregate endpoint rather than forcing BO to aggregate paginated rows.

Preferred endpoint:

```text
GET /admin/central/stock/summary
```

Required widget concepts:

```text
total stock tickets
number coverage for back2
number coverage for back3
number coverage for front3
stock status counts
```

## Important Rules

- Orchestrator must not implement code.
- Backend/BO must receive task briefs before implementation.
- QA must use the test database isolation policy:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

- QA must not wipe runtime DB `newpaotang`.

## Validation Already Done By Coordinator

Read/inspected:

```text
ai-agents/roles/orchestrator.md
ai-agents/prompts/open-chat-orchestrator.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
```

No implementation was changed by Coordinator.

## Next Agent

Orchestrator

