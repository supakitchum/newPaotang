# Back Office P1 Tenant Orders Customer Context Remediation QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO tenant orders customer context remediation to QA Tester.

## Source

Coordinator QA review:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
```

BO remediation task and handoff:

```text
ai-agents/tasks/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 126a2ee94d609233e99be8099671300bf54c75f9
BO handoff commit: 9079fd6ae9650639fd0dd092001555eb83851cae
```

BO reports it fixed tenant order customer context mapping from nested admin API response fields:

```text
customer.id
customer.name
customer.phone
customer.email
```

Fallbacks preserved:

```text
customer_id
member_id
```

BO reports Update, Cancel, and Refund confirmations now include customer/member context and keep reason guards intact.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
API-first tenant order/customer context validation
real authenticated BO tenant orders menu
tenant orders list Customer column
order detail customer/member context
Update modal customer/member context
Cancel modal customer/member context
Refund modal customer/member context
reason guards remain required
typed controls remain intact
```

Because BO touched shared confirmation/page components, QA should also perform small smoke checks for:

```text
tenant:wallets adjust
tenant:topups approve or cancel
tenant:reservations cancel
```

Other already-passing P1 evidence may be reused unless this focused smoke reveals a shared regression.

## Customer-Related CRUD QA Policy

QA must validate customer/member/customer-facing context with API requests before entering Customer frontend.

For this task:

```text
send tenant order API requests first against Docker/local platform API data
capture sanitized API evidence before BO browser workflow
do not use Customer frontend before API validation
do not use Customer frontend at all unless Coordinator explicitly adds that scope later
```

## Validation Plan Given To QA

Docker-only:

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

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if they are still dirty.

## Expected QA Output

```text
ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide approval for the P1 BO workflow slice. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
