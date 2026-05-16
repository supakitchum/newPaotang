# 20260516 Stock Generation Realtime Progress - QA Dispatch Orchestrator Handoff

Task: `stock-generation-realtime-progress-qa-dispatch`
Agent: Orchestrator

## Context

Backend Develop and BO Develop have both completed implementation handoffs for:

```text
stock-generation-realtime-progress
```

Backend handoff:

```text
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
```

BO handoff:

```text
ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md
```

BO work was pushed on:

```text
origin/codex/stock-generation-realtime-progress-bo
```

Orchestrator fast-forwarded the shared `develop` worktree to include BO commits:

```text
3cc1ed0c22645be585353fe1ec9a506299e18d4b
5eb3f00
0bf4bf3
```

## Implementation Under QA

Backend implementation commit reported by Backend:

```text
1f0c19b1d1dbd0502a7cbd40cb3dbd709fcfb1f4
```

Backend handoff commit on shared history:

```text
9fb6732455235090ca30a54d85808159ccd0c50a
```

BO implementation commit reported by BO:

```text
3cc1ed0c22645be585353fe1ec9a506299e18d4b
```

Latest BO handoff refresh commit:

```text
0bf4bf3
```

## QA Task

QA Tester should now start:

```text
ai-agents/tasks/20260516-stock-generation-realtime-progress-qa.md
```

QA must read the Backend and BO handoffs before testing.

## Key Contract To Validate

Realtime auth endpoint:

```text
POST /api/v1/admin/central/realtime/auth
```

Private channel used by BO:

```text
private-admin.central.stock-generation.game.{game_id}
```

Event name:

```text
stock.generation.progress.updated
```

Minimum QA proof required:

```text
backend channel auth requires central admin scope and stock.generate
tenant/partner users cannot subscribe to central stock generation channels
backend emits queued/processing/chunk completed/completed/failed progress events
payload includes required progress fields
BO subscribes only after admin session and selected game are ready
generation-batches is not called every 5 seconds while active batches exist
REST is limited to initial snapshot, manual refresh, and low-frequency fallback
fallback polling is 30-60 seconds only when websocket is unavailable
reconnect performs one fresh snapshot
unsubscribe cleanup exists
summary widgets refresh from progress events without chatty polling
runtime restore/login smoke passes before PASS
```

## QA Runtime Guardrails

All destructive database commands must use the test database only:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime database `newpaotang` must not be wiped.

Before a clean PASS, QA must run and record the restore/login smoke from the QA task, including:

```text
platform:smoke seeded-logins
/login
/admin/login
```

## Known Risks To Report, Not Hide

Backend and BO both document that production websocket delivery still depends on Reverb/runtime readiness. If the QA environment has no websocket server or realtime URL/key configured, QA must report `PASS WITH RISK` or `BLOCKED` as appropriate, not claim authenticated realtime was fully exercised.

## Orchestrator Notes

No app implementation files were edited by Orchestrator. Orchestrator only fast-forwarded the shared branch to include BO commits, updated the Board, and dispatched QA.

## Next Agent

QA Tester
