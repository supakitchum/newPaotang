# 20260519 Stock Generation Coverage Usability - BO Dispatch Orchestrator Handoff

Task: `stock-generation-coverage-usability-bo-dispatch`
Agent: Orchestrator

## Context

Backend Develop completed and pushed the backend dependency for:

```text
stock-generation-coverage-usability-backend
```

Backend handoff:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

Backend implementation commit:

```text
bc8b9dda05e9e6d30aea0d8919689b6a0b45e7d3
```

Backend handoff commit on shared history:

```text
455a1ad
```

## Backend Contract BO Must Use

Primary BO task:

```text
ai-agents/tasks/20260519-stock-generation-coverage-usability-bo.md
```

Routes/contracts from Backend handoff:

```text
GET /api/v1/admin/central/stock
GET /api/v1/admin/central/stock/{game_id}/numbers/{full_number}
GET /api/v1/admin/central/stock/settings
PATCH /api/v1/admin/central/stock/settings
PUT /api/v1/admin/central/stock/limit-settings
PUT /api/v1/admin/central/stock/limit-overrides
GET /api/v1/admin/central/stock/patterns
GET /api/v1/admin/central/stock/limit-overrides
```

Grouped stock list behavior:

```text
filters: game_id, number/full_number, front3, back3, back2, status
sort_by=total_count sorts by virtual generated capacity, then full_number
virtual grouped stock reads from base_lottery_numbers plus counters/limits
empty filtered pages return empty list when base numbers exist
```

Full-number detail route:

```text
GET /api/v1/admin/central/stock/{game_id}/numbers/{full_number}
```

Full-number detail must be displayed honestly:

```text
generated capacity
availability/counters
central and partner effective limits
materialized stock_items
materialized local_stock_items
real image fields when materialized rows exist
unmaterialized virtual capacity without fake ticket/image rows
```

Stock settings default storage:

```text
platform_system_settings.stock_pattern_coverage_default
```

Expected payload shape:

```json
{
  "central": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner": { "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
}
```

Partner validation:

```text
partner default settings above central return 422 validation_failed
partner per-number overrides above central effective limit return 422 validation_failed
BO must show backend field errors clearly
```

## Orchestrator Review

I reviewed the Backend handoff and found enough contract detail for BO to proceed:

```text
full-number detail route documented
filter behavior documented
total_count virtual sort approach documented
settings default key/payload documented
partner <= central validation behavior and error shape documented
Docker validation and test DB isolation reported
```

No app implementation files were edited by Orchestrator.

## Dirty Worktree Note

At dispatch time, the local worktree still contains unrelated dirty implementation files from other agents/user work. BO must inspect `git status --short --branch`, preserve unrelated dirty files, and stage only BO task scope plus its BO handoff.

## Next Agent

BO Develop
