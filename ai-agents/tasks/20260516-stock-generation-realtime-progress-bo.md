# stock-generation-realtime-progress-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back-office realtime UI part of:

```text
stock-generation-realtime-progress
```

## Backend Dependency

Start final implementation only after Backend Develop completes and pushes:

```text
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
```

Use the final backend handoff/OpenAPI/docs for websocket channel names, auth, event names, and payload shape.

## Objective

Stop frequent `generation-batches` polling and update Stock Generate progress from websocket/realtime events.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260516-stock-generation-realtime-progress-decision.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-coordinator-handoff.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
apps/back-office/components/AdminStockGenerationBatches.vue
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminAuth.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
```

## Required Scope

Implement BO support for:

```text
subscribe to backend stock generation realtime channel after admin session is ready
update batch list/detail progress from pushed events
remove active 5-second generation-batches polling loop
keep REST initial snapshot on page load
keep manual refresh action
allow only low-frequency fallback polling when websocket is unavailable, recommended 30-60 seconds
do not run websocket and 5-second list/detail polling together
show realtime connection state compactly if useful
handle reconnect by fetching one fresh snapshot after reconnect
cleanly unsubscribe on page/component unmount
preserve current game default/no ALL behavior
preserve duplicate submit prevention while a batch is queued/processing
refresh stock summary widgets on progress/completion without chatty polling
```

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
changing backend event payload
creating fake realtime with setInterval
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md if BO coverage wording changes
ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real credential files or local environment secrets
```

## Acceptance Criteria

```text
generation-batches is not called every 5 seconds while active batches exist
websocket/realtime event updates progress visible in the BO UI
initial REST snapshot still loads the current batch state
manual refresh still works
fallback polling, if present, is low frequency only and documented
reconnect fetches one fresh snapshot
unsubscribe cleanup exists
BO lint/test/build pass
implementation and handoff are committed and pushed
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

Add structural/browser evidence that `generation-batches` request frequency drops and realtime updates work.

## Next Agent

BO Develop

