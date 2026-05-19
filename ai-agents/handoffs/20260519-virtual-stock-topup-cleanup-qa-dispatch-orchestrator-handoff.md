# 20260519 Virtual Stock Topup Cleanup - QA Dispatch Orchestrator Handoff

Task: `virtual-stock-topup-cleanup-qa-dispatch`
Agent: Orchestrator

## Context

Backend Develop and BO Develop completed implementation handoffs for:

```text
virtual-stock-topup-cleanup
```

Backend handoff:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-backend-handoff.md
```

BO handoff:

```text
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-bo-handoff.md
```

BO work was pushed on:

```text
origin/codex/virtual-stock-topup-cleanup-bo
```

Orchestrator fast-forwarded the shared `develop` worktree to include the BO commits before this QA dispatch.

## Implementation Under QA

Backend implementation commit:

```text
c61b8ef5bd6612d1734616acb8a6f1d259e4d5c4
```

Backend handoff commit on shared history:

```text
d03ce97
```

BO implementation commit:

```text
c1e92e26c9d98dae6eab71c0f722d702d4a65565
```

BO handoff commit:

```text
a1508edb05916172ca37415e0f51dd8aff3074ae
```

## QA Task

QA Tester should now start:

```text
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-qa.md
```

QA must read both implementation handoffs before testing.

## Required QA Focus

Validate the integrated Backend + BO behavior:

```text
initial virtual generate creates profile/supply
second virtual generate/top-up increases generated supply without replacing profile/counters
idempotency replay does not add supply twice
seed is not visible or required in BO/API
physical/quota generation options and payloads are gone/rejected
customer search availability increases after top-up where limits allow
reservation still lazily materializes real tickets
Stock Generation detail shows owner/no-agent and real image data only when present
limits cannot exceed generated combined virtual supply
Stock Pattern Coverage updates through socket without manual refresh after reserve/sold/top-up/limit changes
two-browser realtime still works after top-up
runtime restore/login smoke passes
```

## Backend/BO Contracts To Exercise

```text
POST /admin/central/stock/generate
GET /admin/central/stock/{game_id}/numbers/{full_number}
GET /admin/central/stock/generation-batches
GET /admin/central/stock/generation-batches/{batch_id}
GET /admin/central/stock/patterns
PUT /admin/central/stock/limit-settings
GET /admin/central/stock/limit-overrides
PUT /admin/central/stock/limit-overrides
POST /admin/central/realtime/auth
private-admin.central.stock.coverage.game.{game_id}
stock.coverage.updated
```

## Runtime Guardrails

QA must not wipe runtime DB `newpaotang`.

All destructive DB setup must use:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Before a clean PASS, QA must run and record:

```text
platform:smoke seeded-logins
/login
/admin/login
back-office restart/recreate after build/browser QA
```

## Orchestrator Notes

No app implementation files were edited by Orchestrator. This dispatch only updates Board state and creates this QA handoff.

At dispatch time, the only local dirty file observed in this worktree was:

```text
apps/platform-api/.phpunit.result.cache
```

It was not staged or committed by Orchestrator.

## Next Agent

QA Tester
