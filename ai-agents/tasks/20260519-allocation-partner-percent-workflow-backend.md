# allocation-partner-percent-workflow-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
allocation-partner-percent-workflow
```

Backend Develop is the first implementation agent for this workflow. BO Develop must wait for the backend handoff before final UI wiring.

## Canonical Worktree Start Gate

Backend Develop must start from the canonical worktree only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

Stop and report a blocker to Coordinator if:

```text
git top-level is not /Users/supakit/WorkSpace/www/newPaotang
the worktree is under .codex/worktrees/*, newPaotang-qa-*, newPaotang-orch-*, newPaotang-bo-*, or detached HEAD
git merge --ff-only origin/develop fails
there are uncommitted changes that Backend Develop did not create and they overlap this task
```

The backend handoff must include the worktree path and HEAD used.

## Objective

Rework central allocation backend contracts from raw ids/requested counts to the virtual stock partner percent workflow:

```text
allocation list/detail exposes partner/tenant/game display metadata
allocation filters support BO option/select sources
create allocation accepts allocation_percent instead of requested_count
backend calculates allocation count from generated/available virtual supply and partner percent contract
partner/agent stock percent is centrally configurable
active partner percent total per game must be <= 100%
recall-all allocation endpoint exists
redistribute-after-recall endpoint exists
OpenAPI/docs/tests are updated
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
docs/coordinator-agent-handoff.md
```

Relevant sections:

```text
docs/virtual-stock-realtime.md#allocation-and-partner-percent-rework
docs/coordinator-agent-handoff.md#allocation-partner-percent-workflow
```

## Scope

Backend Develop owns:

```text
Allocation API percent workflow
option/source API for partner, tenant-by-partner, and current/open game selects
partner/agent stock percent contract
active partner percent sum validation per game <= 100%
allocation count calculation from generated/available virtual supply
idempotent create allocation by allocation_percent
allocation list/detail display metadata
recall-all allocation endpoint
redistribute allocation endpoint
OpenAPI updates
permission/docs updates where needed
backend tests
backend handoff
```

Terminology:

```text
"Agent" in business wording maps to the existing partners entity for this scope.
```

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO select/modal/table implementation
Customer frontend changes
physical stock generation
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/virtual-stock-realtime.md if backend contract clarification is required
backend-owned docs when needed
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
real credential files or local environment secrets
```

## Required Backend Behavior

Allocation list/detail must include display metadata:

```text
partner_id
partner_code
partner_name
tenant_id
tenant_code
tenant_name
game_id
game_code
game_name
allocation_percent
allocated_count
remaining_count
recalled_count
status
```

Allocation filters and option sources must support BO selects:

```text
partner selector by partner name/code
tenant selector constrained by selected partner
game selector by game name/code/current status
```

Partner/tenant rules:

```text
if selected partner has exactly one active tenant, API must expose enough data for BO to auto-fill tenant_id
if selected partner has multiple active tenants, tenant_id must be explicitly selectable/required
if selected partner has no active tenant, create allocation must return a clear validation error
```

Create allocation must retire BO-facing `requested_count`:

```text
request field: allocation_percent
valid range: > 0 and <= 100
backend calculates target allocation count from generated/available virtual supply and partner percent contract
idempotency replay returns the same allocation and does not allocate twice
```

Partner/agent stock percent:

```text
store per partner per game if game-specific model is required by current stock_partner_distributions
expose default/global partner percent only if the backend can clearly define how it applies to future games
active partner percents for a game must sum to <= 100%
backend validation is source of truth
percent changes must not corrupt already sold/reserved stock
if percent update would put a partner below already allocated/reserved/sold usage, reject it or require a separate recall/rebalance workflow
```

Required endpoints:

```text
GET /admin/central/allocations
POST /admin/central/allocations
POST /admin/central/allocations/{allocation_id}/recall-all
POST /admin/central/allocations/{allocation_id}/redistribute
```

Add option endpoints or catalog option sources for:

```text
partners
tenants-by-partner
current/open games
```

Add or extend endpoint for partner stock percent update.

## Required Steps

1. Inspect current allocation, partner, tenant, game, virtual stock, and OpenAPI contracts.
2. Choose and document the storage/contract for partner stock percent.
3. Update allocation resource/list/filter contracts with partner/tenant/game display metadata.
4. Add option source endpoints or catalog-compatible APIs for partner/tenant/game selects.
5. Replace create allocation backend contract with percent-based input while rejecting or deprecating BO use of `requested_count`.
6. Implement generated/available virtual supply calculation for allocation target count.
7. Implement idempotent create allocation by `allocation_percent`.
8. Implement active partner percent sum validation per game `<= 100%`.
9. Protect sold/reserved/allocated stock when partner percent changes.
10. Implement recall-all endpoint with reason and idempotency key.
11. Implement redistribute endpoint after full recall; reject redistribute when recall-all is not complete.
12. Update OpenAPI and backend docs.
13. Add focused backend tests for filters/display metadata, option sources, percent create, idempotency, partner percent validation, recall-all, and redistribute.
14. Commit scoped backend changes and write backend handoff.

## Acceptance Criteria

```text
allocation list/detail returns partner/tenant/game display names and allocation_percent
allocation filters support BO select workflows
partner option data allows single-tenant auto-fill and multi-tenant explicit selection
create allocation accepts allocation_percent and does not require requested_count
backend calculates allocation target from virtual supply and percent contract
idempotency replay does not double allocate
total active partner percent per game cannot exceed 100%
invalid no-tenant partner selection returns clear validation error
recall-all endpoint recalls all remaining stock for allocation/partner/game
redistribute endpoint works only after recall-all completion
OpenAPI/docs match implementation
backend tests pass through Docker with test DB isolation
handoff includes commit hash
```

## Validation Commands

Use Docker commands only. Destructive database commands must use `newpaotang_test`.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Add or run focused allocation/partner tests for the new contracts. Validate OpenAPI syntax through Docker and record the command.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

Must include:

```text
worktree path and HEAD used
commit hash
files changed
API routes/contracts changed
option source contract for partners/tenants/games
partner stock percent storage/model
allocation_percent calculation behavior
idempotency behavior
partner percent sum <= 100 validation behavior
recall-all contract
redistribute contract
OpenAPI/docs changes
test DB isolation evidence
validation commands/results
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

Backend Develop
