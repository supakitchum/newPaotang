# Back Office P1 Topups Customer Context Remediation Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch:

```text
back-office-p1-topups-customer-context-remediation
```

## Coordinator Source

```text
ai-agents/decisions/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md
```

## What Was Done

Created the BO Develop remediation task:

```text
ai-agents/tasks/20260510-back-office-p1-topups-customer-context-remediation-bo.md
```

No application implementation code was changed by Orchestrator.

## Current Branch Context

```text
branch: develop
Coordinator review commit before dispatch: 1fa13314c05200b9183f86958f9484b64e707604
```

The worktree had unrelated dirty files before this Orchestrator dispatch. The BO task records them and instructs BO Develop not to modify, stage, commit, or clean them for this remediation.

Known unrelated dirty files:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/*.php
```

## Coordinator Decision Summary

Focused tenant orders remediation passed QA:

```text
tenant:orders list, detail, Update, Cancel, and Refund now show nested customer context.
API-first validation passed before BO browser testing.
Customer frontend was not used.
```

New finding:

```text
tenant:topups approve/cancel confirmations omit customer context even though the API returns nested customer data.
```

Coordinator assessment:

```text
This is a BO mapping/context issue, not a backend contract gap.
```

Owner:

```text
BO Develop
```

Backend remains frozen. Customer frontend remains frozen.

## Remediation Given To BO

BO Develop must:

```text
map nested customer data for tenant topups
show customer/member context in approve, reject, and cancel confirmations
preserve typed amount, bonus, notify controls, and reason guards
preserve topup list/detail behavior
avoid backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, and report edits
report exact missing API data if nested customer fields are insufficient
commit and push scoped changes
handoff back to Orchestrator
```

## Customer-Related CRUD QA Policy

Coordinator recorded the user instruction:

```text
For customer/member/customer-facing CRUD and workflows, QA must validate with API requests first before entering the Customer frontend.
```

For this remediation, QA retest should start with API-first tenant topup/customer fixture or contract validation. Customer UI regression remains out of scope unless Coordinator explicitly scopes it later.

## Validation Plan Given To BO

Docker-only application validation:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Next Step After BO Handoff

If BO completes the remediation without reporting a backend/API data blocker, Orchestrator should create a focused QA Tester task for:

```text
API-first tenant topup/customer validation
real authenticated BO tenant topups menu
topup approve modal customer/member context
topup reject modal customer/member context
topup cancel modal customer/member context
reason guards remain required
typed amount/bonus/notify controls remain intact
no Customer frontend usage before API validation
```

QA may reuse the tenant orders passed evidence unless BO changes shared code that affects tenant orders.

If BO reports that nested customer data is insufficient, Orchestrator should route back to Coordinator for a contract/data decision.

## Next Agent

BO Develop
