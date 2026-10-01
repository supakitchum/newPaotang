# virtual-stock-topup-cleanup-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back Office UI part of:

```text
virtual-stock-topup-cleanup
```

## Backend Dependency

Start final implementation only after Backend Develop completes and pushes:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
```

Use the backend handoff and `docs/openapi.yaml` as the final source for route names, payloads, validation errors, realtime channel/event names, and top-up semantics.

## Objective

Make BO virtual-only for Stock Generation and realtime for Stock Pattern Coverage:

```text
remove seed input
remove physical/quota generation modes and fields
make Generate Stock submit virtual generate/top-up only
show initial generate vs top-up status/copy where backend exposes it
show owner/no-agent and real image actions in Stock Generation detail
subscribe Stock Pattern Coverage to websocket updates
update visible coverage rows/widgets/tabs without manual refresh
fallback to HTTP reload on reconnect or incomplete deltas
surface backend validation errors clearly
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
ai-agents/decisions/20260519-virtual-stock-topup-cleanup-decision.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-coordinator-handoff.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-backend.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
```

## Scope

BO Develop owns:

```text
remove seed input from Stock Generation
remove quota_random/physical generation mode and physical quota fields
make Generate Stock submit virtual generate/top-up only
show initial generate vs top-up state/copy where backend exposes it
add or refine Stock Generation row/detail actions for owner/no-agent and image visibility
show real image_url/image_thumb_url/generation status only for materialized tickets
subscribe Stock Pattern Coverage to websocket updates for selected game/scope/dimension
update visible coverage rows/widgets/tabs from socket deltas
fallback to HTTP reload on reconnect or incomplete event payloads
surface retired physical payload errors and supply limit errors
BO tests/build/handoff
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
changing backend realtime contract without Orchestrator/Coordinator routing
faking image rows for unmaterialized virtual capacity
aggressive polling as a substitute for websocket realtime
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md if BO coverage wording changes
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real credential files or local environment secrets
```

## Required Steps

1. Read the backend handoff and final OpenAPI/realtime contract before editing.
2. Remove seed input from Stock Generation UI and request payloads.
3. Remove physical/quota generation modes and physical quota fields from BO forms, payloads, and labels.
4. Make Generate Stock submit the backend-supported virtual generate/top-up payload only.
5. Where backend exposes top-up/layer/batch status, show initial generate vs top-up clearly.
6. Ensure Stock Generation row/detail actions expose owner/no-agent for virtual copies where backend provides it.
7. Add/refine image action/detail display so only real materialized ticket/local ticket image fields appear.
8. Do not create fake rows for unmaterialized virtual capacity.
9. Subscribe Stock Pattern Coverage to backend websocket events for selected game/scope/dimension.
10. Update visible coverage rows/widgets/tabs from focused deltas:

```text
generated_count
reserved_count
sold_count
default_limit
override_limit
limit
remaining_limit
sellable_remaining_count
status
```

11. Use HTTP reload as source-of-truth fallback on reconnect, missed events, or incomplete deltas.
12. Avoid chatty polling while websocket is connected.
13. Surface backend validation errors for retired physical payloads, invalid top-up payloads, and supply limit errors.
14. Commit scoped BO changes and write the BO handoff.

## Acceptance Criteria

```text
seed is not visible in BO
physical/quota generation modes and fields are gone from BO
Generate Stock performs virtual initial generate/top-up only
top-up state/copy is visible where backend exposes it
Stock Generation detail shows owner/no-agent and real materialized images only
unmaterialized virtual capacity remains capacity, not fake ticket/image rows
Stock Pattern Coverage receives websocket updates and refreshes visible rows/widgets/tabs without manual refresh
HTTP reload fallback runs on reconnect/incomplete payload
backend validation errors are visible
BO lint/test/build pass through Docker
handoff includes commit hash
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

Run any existing BO structural scripts for stock generation/settings/pattern coverage and record results.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md
```

Must include:

```text
commit hash
files changed
backend routes/contracts consumed
seed removal evidence
physical/quota removal evidence
generate/top-up payload behavior
owner/no-agent detail behavior
image action/detail behavior
coverage websocket subscription/channel/event behavior
delta update behavior
fallback/reconnect behavior
validation error display behavior
validation commands/results
manual/browser evidence if available
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

BO Develop
