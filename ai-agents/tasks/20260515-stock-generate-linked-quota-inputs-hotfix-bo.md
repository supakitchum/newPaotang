# stock-generate-linked-quota-inputs-hotfix-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back-office hotfix for:

```text
stock-generate-linked-quota-inputs-hotfix
```

Coordinator requires the Stock Generate form to show linked quota values while the operator types, default Stock Gen Game to the current draw/current game, remove `ALL` from Stock Generate, and prevent all-game/empty-game generate payloads.

## Objective

Make the Stock Generate form safer and clearer for quota-based generation by making quota dependencies visible before submit and by forcing generation against a concrete current game.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-decision.md
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-coordinator-handoff.md
ai-agents/decisions/20260515-stock-generation-summary-widgets-qa-review-decision.md
docs/api-conventions.md
docs/openapi.yaml
docs/admin-dashboard-template-guidelines.md
docs/back-office-crud-coverage.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockSummaryWidgets.vue
```

## Required Business Rule

The three quota inputs are linked:

```text
back2_count_per_number = back3_count_per_number * 10
front3_count_per_number = back3_count_per_number
total_count = back3_count_per_number * 1000
```

Examples:

```text
back2 = 10  => back3 = 1,  front3 = 1,  total = 1000
back2 = 30  => back3 = 3,  front3 = 3,  total = 3000
back3 = 2   => back2 = 20, front3 = 2,  total = 2000
front3 = 4  => back2 = 40, back3 = 4,  total = 4000
```

If `back2` is not divisible by 10, show an inline conflict/validation message before submit.

## Scope

Implement BO support for:

```text
when operator edits 2-tail per number, immediately show required 3-tail and 3-front values
when operator edits 3-tail per number, immediately show required 2-tail and 3-front values
when operator edits 3-front per number, immediately show required 2-tail and 3-tail values
keep total_count helper/input consistent with the same rule if present
show inline validation before submit when dependencies conflict
block submit or clearly invalidate the modal when dependencies conflict
submit valid payload using back2_count_per_number, back3_count_per_number, and front3_count_per_number
default Stock Generate game selector to the current draw/current game
remove ALL option from Stock Generate game selector
prevent all-game/empty-game generate payloads
keep Stock summary widgets aligned with the selected current game
show clear empty/error state when no current draw/current game is available
ensure legacy start_number/count/range/number_digits fields do not return
ensure previous Stock summary widgets remain visible and unaffected
```

Use existing BO form, modal, filter, and game-selection patterns. Keep the UI compact and operational.

## Backend Escalation Rule

Backend Develop is not expected for this hotfix.

However, if the current game/list API does not expose a reliable current draw/current game marker and there is no existing BO pattern to determine it safely, stop that part and write a blocker in the BO handoff. Do not guess a current game from arbitrary ordering. Recommended next agent in that case is `Orchestrator` so Backend can be added before QA.

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing quota algorithm
changing backend validation unless BO cannot meet the contract
changing stock summary endpoint behavior
changing import stock flow
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md only if BO coverage notes need updating
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-bo-handoff.md
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

1. Review the Coordinator decision/handoff and existing Stock Generate form configuration.
2. Identify current game/list API fields and existing BO current-game selection patterns.
3. Implement linked quota helper/validation behavior for all three manual quota fields.
4. Keep `total_count` consistent with the linked quota rule.
5. Remove `ALL` from Stock Generate game selection and block empty/all-game submit payloads.
6. Default game selection to current draw/current game when available.
7. Verify stock summary widgets still follow the selected game.
8. Add/update BO structural checks where repo patterns exist.
9. Commit and push only BO-owned changes plus the BO handoff.

## Acceptance Criteria

```text
typing 2-tail shows required 3-tail and 3-front values immediately
typing 3-tail shows required 2-tail and 3-front values immediately
typing 3-front shows required 2-tail and 3-tail values immediately
invalid 2-tail not divisible by 10 shows inline validation before submit
dependency conflicts block submit or clearly mark the modal invalid
valid payload still uses back2_count_per_number, back3_count_per_number, front3_count_per_number
total_count helper/input remains consistent if present
Stock Generate game selector defaults to current draw/current game
Stock Generate game selector does not offer ALL
generate cannot submit all-game/empty-game selection
stock summary widgets remain visible and aligned with selected current game
legacy start_number/count/range/number_digits fields do not return
Docker-only validation passes
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

Run any repo-available structural checks for admin operations, stock generation, or stock summary widgets and record exact commands.

If browser smoke is possible:

```sh
docker compose -p newpaotang up -d platform-api back-office
```

Record route/form workflow evidence in the handoff. Do not run destructive DB commands against runtime DB `newpaotang`.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-bo-handoff.md
```

Must include:

```text
commit hash
files changed
linked quota UI behavior
inline validation/conflict behavior
submit payload behavior
current game default source
ALL removal / empty-game prevention
stock summary widget regression notes
validation commands and results
manual/browser evidence if available
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

BO Develop
