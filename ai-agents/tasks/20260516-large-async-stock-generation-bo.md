# large-async-stock-generation-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back-office part of:

```text
large-async-stock-generation
```

BO must support large stock generation totals, remove the old 10,000 cap, and poll backend batch progress.

## Backend Dependency

Start final implementation only after Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
```

Use the final Backend handoff/OpenAPI contract for:

```text
POST /api/v1/admin/central/stock/generate
GET /api/v1/admin/central/stock/generation-batches
GET /api/v1/admin/central/stock/generation-batches/{batch_id}
```

## Objective

Update Stock Generation BO so operators can submit totals above 10,000, see queued/processing progress, handle failures, and preserve the linked quota/current-game behavior from the prior hotfix.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-qa-review-decision.md
docs/api-conventions.md
docs/openapi.yaml
docs/admin-dashboard-template-guidelines.md
docs/back-office-crud-coverage.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockSummaryWidgets.vue
```

## Scope

Implement BO support for:

```text
remove "not exceed 10,000" validation/copy from Stock Generate
allow large total_count/manual quota values within backend contract
preserve linked quota input behavior
preserve current game default
preserve no ALL option and empty-game prevention
after large submit, show queued/processing batch state from backend response
poll generation batch detail/list endpoints for generated_count / requested_count progress
show total_rounds/processed_rounds/chunk_rounds if backend returns them
prevent duplicate submit while the same batch is queued/processing
show failed state and failure_reason
distinguish stock completion from image pending/processing where backend exposes it
refresh stock summary widgets after progress updates/completion
keep Generate Stock small/sync path usable
loading/error/empty states for progress widget/panel
```

Prefer existing BO admin operation patterns and compact operational UI.

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing backend response shape
changing quota algorithm
adding decorative dashboards unrelated to progress
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md only if BO coverage notes need updating
ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
ai-agents/decisions/**
real credential files or local environment secrets
```

## Acceptance Criteria

```text
Stock Generate no longer blocks totals above 10,000 in BO validation/copy
linked quota inputs from prior hotfix still work
current game default / no ALL / empty-game prevention still work
large submit displays queued/processing batch state
BO polls batch progress generated_count / requested_count
duplicate submit is prevented while same batch is queued/processing
failed batch state and failure_reason are visible
stock completed state is distinct from image pending/processing where exposed
stock summary widgets refresh after progress updates/completion
small/sync generation path remains usable
BO Docker validation passes
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

Run any repo-available BO structural checks for Stock Generate, linked quota, summary widgets, or async progress and record exact commands.

If browser smoke is possible:

```sh
docker compose -p newpaotang up -d platform-api back-office
```

Record route/form/progress evidence in the handoff. Do not run destructive DB commands against runtime DB `newpaotang`.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md
```

Must include:

```text
commit hash
files changed
large total UI behavior
batch progress polling behavior
duplicate submit prevention
failed/failure_reason behavior
stock vs image state behavior
linked quota/current game/no ALL regression notes
summary widget refresh behavior
validation commands and results
manual/browser evidence if available
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

BO Develop
