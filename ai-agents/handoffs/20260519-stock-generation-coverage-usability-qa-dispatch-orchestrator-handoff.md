# 20260519 Stock Generation Coverage Usability - QA Dispatch Orchestrator Handoff

Task: `stock-generation-coverage-usability-qa-dispatch`
Agent: Orchestrator

## Context

Backend Develop and BO Develop completed implementation handoffs for:

```text
stock-generation-coverage-usability
```

Backend handoff:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

BO handoff:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-bo-handoff.md
```

BO work was pushed on:

```text
origin/codex/stock-generation-coverage-usability-bo
```

This QA dispatch was created from a clean Orchestrator worktree based on the BO branch because the main local worktree had unrelated dirty files that overlap BO-owned paths.

## Implementation Under QA

Backend implementation commit:

```text
bc8b9dda05e9e6d30aea0d8919689b6a0b45e7d3
```

Backend handoff commit on shared history:

```text
455a1ad
```

BO implementation commit:

```text
4bd749f8371e04cdffbdd4f88ad2e1454d0c957c
```

BO handoff commit:

```text
7f55f429e4f5e8fbb34dd99630674d2cd99c88d7
```

## QA Task

QA Tester should now start:

```text
ai-agents/tasks/20260519-stock-generation-coverage-usability-qa.md
```

QA must read both implementation handoffs before testing.

## Required QA Focus

Validate the full integrated Backend + BO workflow:

```text
Generation progress action opens and renders real batch details
Stock Generation row action opens full-number detail
full-number detail shows virtual unmaterialized capacity honestly
full-number detail shows materialized stock_items/local_stock_items and real image fields when present
Stock Generation filters use backend API for game_id, number/full_number, front3, back3, back2, and status
Tickets sort uses backend sort_by=total_count and returns virtual generated capacity order
Stock Settings saves and reloads central/partner stock_pattern_coverage_default values
Stock Pattern Coverage loads saved defaults into empty/new forms
partner lower/equal central coverage saves
partner greater than central returns visible validation error and does not save
partner per-number override greater than central effective value is rejected
runtime restore/login smoke passes before clean PASS
```

## Backend Contracts To Exercise

```text
GET /api/v1/admin/central/stock
GET /api/v1/admin/central/stock/{game_id}/numbers/{full_number}
GET /api/v1/admin/central/stock/settings
PATCH /api/v1/admin/central/stock/settings
GET /api/v1/admin/central/stock/patterns
GET /api/v1/admin/central/stock/limit-overrides
PUT /api/v1/admin/central/stock/limit-settings
PUT /api/v1/admin/central/stock/limit-overrides
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

The main local worktree still has unrelated dirty files. QA should use a clean worktree or record any unrelated dirty files and leave them untouched.

## Next Agent

QA Tester
