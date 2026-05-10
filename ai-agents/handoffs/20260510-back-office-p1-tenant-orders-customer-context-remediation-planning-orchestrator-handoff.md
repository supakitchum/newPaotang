# Back Office P1 Tenant Orders Customer Context Remediation Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

## Coordinator Source

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

## What Was Done

Created the BO Develop remediation task:

```text
ai-agents/tasks/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo.md
```

No application implementation code was changed by Orchestrator.

## Current Branch Context

```text
branch: develop
Coordinator review commit before dispatch: 934a48013b8366430b34ac624de3dbdb64831cca
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

QA report is accepted as evidence, but the P1 BO workflow slice remains blocked.

Blocking defect:

```text
tenant:orders destructive/financial actions omit customer context
```

Root cause:

```text
BO reads customer_id as top-level, while the admin order API already returns customer data as nested customer.
```

Owner:

```text
BO Develop
```

Backend remains frozen. Customer frontend remains frozen.

## Remediation Given To BO

BO Develop must:

```text
fix tenant order customer context mapping from nested customer data
show customer/member context in tenant order list and order detail
show customer/member context in Update, Cancel, and Refund confirmations
preserve typed controls and reason guards
preserve tenant scope, order id, order status, payment/status, and amount context
avoid backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, and report edits
report exact missing API data if nested customer fields are insufficient
commit and push scoped changes
handoff back to Orchestrator
```

## Customer-Related CRUD QA Policy

Coordinator recorded the new user instruction:

```text
For customer/member/customer-facing CRUD and workflows, QA must validate with API requests first before entering the Customer frontend.
```

For this remediation, QA retest should start with API-first tenant order/customer fixture or contract validation. Customer UI regression remains out of scope unless Coordinator explicitly scopes it later.

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
API-first tenant order/customer context validation
real authenticated BO tenant orders menu
tenant orders list customer column
order detail customer context
Update modal customer context
Cancel modal customer context
Refund modal customer context
reason guards remain required
no Customer frontend usage before API validation
```

If BO reports that nested customer data is insufficient, Orchestrator should route back to Coordinator for a contract/data decision.

## Next Agent

BO Develop
