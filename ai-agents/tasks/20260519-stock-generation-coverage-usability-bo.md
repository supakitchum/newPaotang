# stock-generation-coverage-usability-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
stock-generation-coverage-usability
```

## Backend Dependency

Start final implementation only after Backend Develop completes and pushes:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

Use the backend handoff and `docs/openapi.yaml` as the final source for route names, payloads, validation errors, and sort/filter semantics.

## Objective

Make Stock Generation and Stock Pattern Coverage usable in BO:

```text
progress action/detail view renders real data
Stock Generation row has full-number detail action
full-number detail shows capacity, materialized tickets, and image status/URLs
filters call backend API and reset correctly
Tickets header sorts by backend total_count state
Stock Settings has central/partner default coverage form
new/empty Stock Pattern Coverage forms load saved defaults
partner coverage UI shows central ceiling and prevents obvious invalid input
backend validation errors remain visible
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-coordinator-handoff.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-backend.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

## Scope

BO Develop owns:

```text
Generation progress action/detail view rendering
Stock Generation row action for full-number detail
detail modal/page showing virtual capacity, materialized tickets, and image status/URLs
filter wiring and reset behavior
Tickets sortable header using backend API sort state
Stock Settings form for central/partner coverage defaults
Stock Pattern Coverage loading defaults into empty/new forms
Partner coverage UI ceiling display and client-side guard
BO handoff
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing backend contracts without Orchestrator/Coordinator routing
browser-only filtering/sorting as the source of truth
faking image rows for unmaterialized virtual tickets
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md if BO coverage wording changes
ai-agents/handoffs/20260519-stock-generation-coverage-usability-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real credential files or local environment secrets
```

## Dirty Worktree Guard

Before editing, run:

```sh
git status --short --branch
```

If there are existing dirty files in BO-owned paths, treat them as existing user/agent work. Do not revert them. Work with them only if required for this task and record the pre-existing dirty state in the handoff. Stage only files in this task scope.

## Required Steps

1. Read the backend handoff and final OpenAPI contract before editing.
2. Fix the Generation progress action/detail view so selecting it renders the actual batch/progress data.
3. Add a Stock Generation row action such as `View number`.
4. Build the full-number detail modal/page from backend data:

```text
game_id
full_number
front3/back3/back2
generated supply / total_count
available/reserved/sold counts
central effective limits
partner effective limits if partner scope is selected
materialized stock_items
materialized local_stock_items
real image_url/image_thumb_url/image_generation_status/image_generation_error fields
clear message for unmaterialized virtual capacity without per-ticket image rows
```

5. Wire filters to backend API state for `game_id`, number/full_number search, `front3`, `back3`, `back2`, and `status`. Reset must clear backend query state.
6. Wire `Tickets` sortable header to backend `sort_by=total_count` and `sort_dir`.
7. Add Stock Settings form for central and partner default coverage values:

```text
central.back2_limit
central.back3_limit
central.front3_limit
partner.back2_limit
partner.back3_limit
partner.front3_limit
```

8. Ensure new/empty Stock Pattern Coverage forms load saved defaults without silently rewriting existing saved game/scope limits.
9. Show central ceiling beside partner fields and prevent obvious partner > central input, while still showing backend `422 validation_failed` field errors clearly.
10. Preserve existing BO layout conventions and avoid hiding backend validation errors.
11. Commit scoped BO changes and write the BO handoff.

## Acceptance Criteria

```text
progress action opens and shows real batch details
Stock Generation row action opens full-number detail
full-number detail distinguishes virtual capacity from materialized ticket/image rows
filters call backend API and work after reset
Tickets sort uses backend total_count sort state
Stock Settings saves and reloads default central/partner coverage values
empty/new Stock Pattern Coverage forms load saved defaults
partner lower/equal central is accepted by UI
partner greater than central is blocked or shows backend field error
BO lint/test/build pass through Docker
handoff includes commit hash and validation results
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Run any existing BO structural scripts that cover stock generation/settings and document them in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-bo-handoff.md
```

Must include:

```text
commit hash
files changed
backend routes/contracts consumed
progress detail behavior
full-number detail UI behavior
filter and reset behavior
Tickets sort behavior
Stock Settings defaults behavior
Stock Pattern Coverage default-loading behavior
partner ceiling UI and backend error display behavior
validation commands and results
manual/browser evidence if available
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

BO Develop
