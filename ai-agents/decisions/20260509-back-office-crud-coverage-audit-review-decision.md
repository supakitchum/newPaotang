# Back Office CRUD Coverage Audit Review Decision

Date: 2026-05-09
Agent: Coordinator

## Context

BO Develop completed the Back Office CRUD Coverage Audit and delivered:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

The audit applied the corrected BO progress model:

```text
Route existence, menu visibility, catalog entries, and OpenAPI availability do not count as BO completion by themselves.
BO completion requires real end-to-end UI/API workflow coverage and real menu workflow QA.
```

## Audit Acceptance

Coordinator accepts the CRUD coverage audit as the new BO planning baseline.

The matrix covers all seeded central and tenant BO menus and records each menu's route, permission, APIs, UI/API/form status, QA status, gap/blocker, and completion status.

Accepted status totals:

| Scope | complete | partial | not_started | api_gap | out_of_scope | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Central | 0 | 23 | 0 | 1 | 0 | 24 |
| Tenant | 0 | 31 | 0 | 1 | 0 | 32 |
| Total | 0 | 54 | 0 | 2 | 0 | 56 |

## Corrected BO Completion Percentage

Official BO completion under the corrected rule is:

```text
0 / 56 complete = 0% verified complete
```

This does not mean BO has no foundation. Existing BO foundation still includes:

```text
layout
auth/session shell
central and tenant dashboard pages
menu/navigation/catalog
generic operations page
some dedicated tenant workflows
API-backed list/detail/action wiring across many menus
```

However, none of the 56 menu rows can be counted as `complete` until the matching workflow has applicable UI, API connection, typed or appropriate form/action workflow, loading/error/empty states, and real menu QA evidence.

For official reporting, do not use weighted partial credit. Partial rows remain implementation backlog and may be tracked separately, but they do not increase the official BO completion percentage.

## API Gap Decisions

Rows that remain `api_gap`:

```text
central:master_stock
tenant:commission_transactions
```

Coordinator does not approve backend remediation yet.

Reason:

```text
Backend contract is frozen for BO implementation.
The first BO pass should implement the P1 money/stock workflows that are already possible against the frozen contract.
If BO Develop proves that a P1 workflow is blocked by an API gap, report the exact blocker back to Coordinator for a separate backend-remediation decision.
```

Temporary workflow interpretation:

```text
tenant:reservations and tenant:payouts may be treated as list/action-only workflows if the current API response contains enough context for a safe operator decision.
They can become complete only after the list/action UI, permission/scope behavior, action safety, idempotency, states, and real menu QA pass.
central:master_stock and tenant:commission_transactions remain api_gap until Coordinator approves either a backend detail endpoint or a list/action-only acceptance rule for those specific menus.
```

## Next BO Implementation Priority

Open the first implementation task:

```text
back-office-p1-money-stock-crud-workflows
```

Priority rows:

```text
central:stock_generation
central:allocations
central:stock_recall
tenant:local_stock
tenant:stock_sync
tenant:reservations
tenant:orders
tenant:wallets
tenant:topups
tenant:payouts
tenant:payment_settings
```

Keep `central:master_stock` out of completion scoring for this pass because it remains `api_gap`.

## Implementation Rules

BO Develop may edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/**
ai-agents/reports/**
```

Do not edit without a new Coordinator decision:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

Required BO implementation behavior:

```text
Use existing Meno/admin patterns and current BO composables.
Prefer typed domain forms/modals for high-risk money and stock workflows instead of raw JSON editors.
Keep action confirmations explicit and operator-readable.
Use idempotency keys for write/action APIs where backend expects or supports them.
Preserve tenant scope and X-Tenant-Id behavior.
Update docs/back-office-crud-coverage.md row statuses after implementation.
Do not mark a row complete until QA provides real menu workflow evidence.
Use Docker-only commands for app validation.
```

## QA Direction After P1 Implementation

QA Tester must test real BO menus and workflows, not only build/lint/unit checks.

QA scope for P1:

```text
route access through the actual central and tenant menus
list/detail where applicable
typed create/update/action/export modals
write safety and idempotency behavior
loading/error/empty states
permission and tenant-scope behavior
X-Tenant-Id handling
mobile sanity for dense tables/modals
non-destructive evidence where destructive production-like actions are unsafe
```

## Release Boundary

This decision does not approve:

```text
staging deployment
production deployment
client delivery
Gate 5 final release
npm audit closure
Meno legal/license closure
backend API contract changes
customer frontend work
```

## Next Agent

Orchestrator

## Required Orchestrator Action

Create a BO Develop task for:

```text
back-office-p1-money-stock-crud-workflows
```

The task should implement the P1 money/stock workflows against the frozen backend contract, then route to QA Tester for real menu workflow QA.
