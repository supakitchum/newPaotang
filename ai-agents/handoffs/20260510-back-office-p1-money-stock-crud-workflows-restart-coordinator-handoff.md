# Back Office P1 Money Stock CRUD Workflows Restart Coordinator Handoff

## Agent

Coordinator

## Task

Restart P1 BO money/stock CRUD workflow implementation after branch cleanup.

## What Was Done

Recorded the restart decision:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
```

Updated Board to point Orchestrator at this fresh Coordinator handoff.

Confirmed current branch policy:

```text
main development branch: develop
old misspelled branch: deverlop removed
old codex/* branches removed
```

## Current Baseline

```text
branch: develop
commit: f44bee4592e9e012f406229f9f8fbbb2c61c8571
```

## BO Baseline

The accepted BO CRUD Coverage Audit remains the source of truth:

```text
docs/back-office-crud-coverage.md
```

Official BO completion:

```text
0 / 56 complete = 0% verified complete
```

Matrix totals:

| Scope | complete | partial | not_started | api_gap | out_of_scope | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Central | 0 | 23 | 0 | 1 | 0 | 24 |
| Tenant | 0 | 31 | 0 | 1 | 0 | 32 |
| Total | 0 | 54 | 0 | 2 | 0 | 56 |

## Required Orchestrator Action

Create a fresh BO Develop task:

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

## Task Boundaries

BO Develop may edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/**
ai-agents/reports/**
```

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

Backend remains frozen. If a P1 workflow is blocked by the frozen backend contract, report the exact blocker to Coordinator.

## Branch Rules

Use `develop` as the baseline branch.

Do not recreate `codex/*` branches unless the user or Coordinator explicitly asks for per-agent branches again.

Expected starting commit:

```text
f44bee4592e9e012f406229f9f8fbbb2c61c8571
```

## Validation Expectations

Orchestrator must give BO Develop Docker-only validation commands, including at minimum:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

No Node, npm, PHP, Composer, Artisan, Nuxt, Vite, migration, test, or build command may run on the host machine.

## QA Direction

After BO Develop completes implementation and handoff, route to QA Tester.

QA must test real BO menus and workflows:

```text
menu navigation
list/detail where applicable
typed create/update/action/export modals
write/action safety and idempotency
permission and tenant-scope behavior
X-Tenant-Id handling
loading/error/empty states
mobile sanity for tables and modals
non-destructive evidence for risky actions where needed
```

Build/lint/unit test alone is not enough.

## Known Risks

```text
npm audit risk remains outside this task.
Meno legal/license confirmation remains required before staging, production, client delivery, or final release.
Production/Ops gates remain outside BO implementation.
Backend API contract remains frozen unless Coordinator approves remediation.
Customer frontend remains frozen.
```

## Questions For Coordinator

None at dispatch time.

## Next Agent

Orchestrator
