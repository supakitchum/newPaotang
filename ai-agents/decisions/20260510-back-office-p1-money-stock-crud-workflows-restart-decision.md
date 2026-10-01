# Back Office P1 Money Stock CRUD Workflows Restart Decision

Date: 2026-05-10
Agent: Coordinator

## Context

The user cleared the old agent branch/task state and renamed the main development branch:

```text
deverlop -> develop
codex/* branches removed
old Orchestrator dispatch for back-office-p1-money-stock-crud-workflows was cleared
```

Current source branch:

```text
develop
```

Current baseline commit:

```text
f44bee4592e9e012f406229f9f8fbbb2c61c8571
```

The previous BO CRUD Coverage Audit remains accepted as the planning baseline:

```text
docs/back-office-crud-coverage.md
ai-agents/decisions/20260509-back-office-crud-coverage-audit-review-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-review-coordinator-handoff.md
```

## Decision

Restart the next BO implementation step from the clean `develop` baseline:

```text
back-office-p1-money-stock-crud-workflows
```

This is not a new scope. It is a clean restart of the P1 BO implementation priority after branch cleanup.

## BO Completion Baseline

Official BO completion remains:

```text
0 / 56 complete = 0% verified complete
```

Accepted CRUD coverage totals remain:

| Scope | complete | partial | not_started | api_gap | out_of_scope | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Central | 0 | 23 | 0 | 1 | 0 | 24 |
| Tenant | 0 | 31 | 0 | 1 | 0 | 32 |
| Total | 0 | 54 | 0 | 2 | 0 | 56 |

No weighted partial credit is approved for official BO completion.

## Implementation Scope

P1 menu rows:

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

Keep these rows out of completion scoring until Coordinator approves remediation or acceptance criteria:

```text
central:master_stock
tenant:commission_transactions
```

## Contract Boundary

Backend remains frozen for BO implementation.

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

If BO Develop finds an exact P1 blocker in the frozen backend contract, stop that sub-scope and report the blocker to Coordinator. Do not modify backend.

## BO Implementation Expectations

BO Develop should:

```text
use existing Meno/admin patterns and current BO composables
build typed domain forms/modals for high-risk money and stock workflows where practical
avoid raw JSON editors for operator-critical flows
keep confirmations explicit and operator-readable
use idempotency keys for writes/actions where backend expects or supports them
preserve tenant scope and X-Tenant-Id behavior
handle loading/error/empty states
update docs/back-office-crud-coverage.md row statuses after implementation
not mark a row complete until QA provides real menu workflow evidence
run all application validation through Docker only
```

## Branch And Git Rules

Use `develop` as the baseline branch.

Do not recreate `codex/*` branches unless the user or Coordinator explicitly asks for per-agent branches again.

Before any implementation task:

```text
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

The expected baseline is:

```text
f44bee4592e9e012f406229f9f8fbbb2c61c8571
```

If a worktree is dirty, the agent must report it before editing.

## Required Orchestrator Action

Create a fresh BO Develop task for:

```text
back-office-p1-money-stock-crud-workflows
```

The task must:

```text
target BO Develop
use develop commit f44bee4592e9e012f406229f9f8fbbb2c61c8571 as the baseline
scope files to apps/back-office/** and docs/back-office-crud-coverage.md
keep backend/customer/OpenAPI frozen
include Docker-only validation commands
require implementation commit and BO handoff
route to QA Tester for real menu workflow QA after BO handoff
```

## Next Agent

Orchestrator
