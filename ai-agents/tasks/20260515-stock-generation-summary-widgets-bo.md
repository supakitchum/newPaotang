# stock-generation-summary-widgets-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back-office widget UI for:

```text
stock-generation-summary-widgets
```

Coordinator requires widgets on Stock Generation showing total stock tickets, 2-tail coverage, 3-tail coverage, 3-front coverage, and stock status totals.

## Backend Dependency

Start final API wiring only after Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
```

Use the final Backend handoff/OpenAPI contract. The preferred endpoint is:

```text
GET /api/v1/admin/central/stock/summary
```

## Objective

Add compact summary widgets to the central Stock Generation view so operators can verify quota distribution and stock status totals without manually aggregating paginated stock rows.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-stock-generation-summary-widgets-decision.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-coordinator-handoff.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
docs/api-conventions.md
docs/openapi.yaml
docs/admin-dashboard-template-guidelines.md
docs/back-office-crud-coverage.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
```

## Scope

Implement BO support for:

```text
compact widget band above the Generate Stock action/table area on the central stock operations view
Total tickets widget
2-tail coverage widget
3-tail coverage widget
3-front coverage widget
Status totals widget
API call to the backend summary endpoint
widgets update when game_id filter changes
optional batch_id wiring only if the central stock view already exposes batch filtering cleanly
loading state that does not render misleading zero values
error state that is visible but non-blocking
empty/no-game state that is explicit and not misleading
Generate Stock flow remains usable even if summary endpoint fails
status totals display available, allocated, sold, recalled, voided, and total if provided
coverage display includes distinct_count / expected_distinct plus min/max/count summary per value
```

Prefer existing admin components and operation page patterns. This is an operations dashboard surface, so keep it compact and scan-friendly.

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing backend response shape
changing stock generation quota algorithm
adding charts or decorative landing-page UI
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md only if BO coverage notes need updating
ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. Stage only files in this task scope.

## Required Steps

1. Read the Backend handoff and OpenAPI contract.
2. Locate the central stock operations / stock generation view and current game filter flow.
3. Add a compact widget band above Generate Stock action/table area.
4. Wire widgets to `GET /admin/central/stock/summary` using existing admin API conventions.
5. Refresh widgets when the selected game filter changes.
6. Preserve Generate Stock behavior if summary fails.
7. Add loading/error/empty states.
8. Update structural checks or tests where the repo has BO check scripts for operations catalog/page behavior.
9. Commit and push only BO-owned changes plus the BO handoff.

## Acceptance Criteria

```text
central stock view shows Total tickets, 2-tail coverage, 3-tail coverage, 3-front coverage, and Status totals widgets
widgets call the backend summary endpoint instead of aggregating paginated stock rows
widgets update when game_id filter changes
loading state does not show misleading zero values
empty state is explicit when no game/no stock is selected
summary API errors are visible but do not block Generate Stock
Generate Stock flow still exposes total_count and manual quota fields from the previous quota contract
removed start/count/range/number_digits fields do not return
BO validation commands pass through Docker
implementation and handoff are committed and pushed
```

## Validation Commands

Use Docker commands only. Do not run Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Run any repo-available BO structural checks related to admin operations/stock generation and record exact commands.

If browser smoke is possible:

```sh
docker compose -p newpaotang up -d platform-api back-office
```

Record route/API workflow evidence in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md
```

Must include:

```text
commit hash
files changed
route/view/components changed
API endpoint used
widget payload mapping
game filter refresh behavior
loading/error/empty behavior
Generate Stock regression notes
validation commands and results
manual/browser evidence if available
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

BO Develop
