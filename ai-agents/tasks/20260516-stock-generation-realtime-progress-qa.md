# stock-generation-realtime-progress-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate completed Backend and BO delivery for:

```text
stock-generation-realtime-progress
```

QA must prove that `generation-batches` is no longer polled frequently and stock generation progress updates through realtime websocket events.

## QA Start Gate

Do not start until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md
```

If websocket runtime is blocked, QA must report the blocker clearly. Do not accept a structural-only implementation that still relies on frequent polling.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260516-stock-generation-realtime-progress-decision.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-coordinator-handoff.md
ai-agents/tasks/20260516-stock-generation-realtime-progress-backend.md
ai-agents/tasks/20260516-stock-generation-realtime-progress-bo.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md
```

## Scope

Validate:

```text
backend channel auth requires central admin and stock.generate
partner/tenant users cannot subscribe
batch queued/processing/chunk completed/completed/failed events are emitted
event payload contains required progress fields
BO subscribes after admin session is ready
BO UI updates progress from realtime events
generation-batches endpoints are used for initial snapshot/manual refresh only
no active 5-second generation-batches polling remains
fallback polling, if any, is low frequency only
reconnect triggers one fresh snapshot
BO unsubscribes/cleans up on unmount
large async generation still completes correctly
runtime restore/login smoke passes before clean PASS
```

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive database commands must explicitly target test DB `newpaotang_test`:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests must run with:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

## Required Evidence

QA report must include:

```text
network evidence showing generation-batches is not called every 5 seconds
realtime/websocket evidence showing progress events received
backend test evidence for channel auth and event dispatch
BO lint/test/build results
test DB isolation evidence
runtime restore/login smoke evidence
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Mandatory runtime restore/login smoke before clean PASS:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
curl --max-time 5 -i -s http://localhost:3100/admin/login
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260516-stock-generation-realtime-progress-qa-report.md
```

Result must be one of:

```text
PASS
FAIL
PASS WITH RISK
BLOCKED
```

## Next Agent

QA Tester

