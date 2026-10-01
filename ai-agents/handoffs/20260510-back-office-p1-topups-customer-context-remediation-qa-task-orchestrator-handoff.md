# Back Office P1 Topups Customer Context Remediation QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO topups customer context remediation to QA Tester.

## Source

Coordinator QA review:

```text
ai-agents/decisions/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-review-coordinator-handoff.md
```

BO remediation task and handoff:

```text
ai-agents/tasks/20260510-back-office-p1-topups-customer-context-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p1-topups-customer-context-remediation-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: fd57c58de28d885de4c2dc69d24b190f0434a10b
BO handoff commit: 8f3e3b794ed3df18faf3584826287c5e470193b2
```

BO reports topup Approve, Reject, and Cancel confirmation context now includes:

```text
id
tenant_id
reference
customer_id
member_id
customer.id
customer.name
customer.phone
customer.email
status
amount.amount
amount.currency
channel
```

BO reports typed amount/bonus controls, notify customer control, and reason guards remain intact.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
API-first tenant topup/customer validation
real authenticated BO tenant topups menu
topup approve modal customer/member context
topup reject modal customer/member context
topup cancel modal customer/member context
reason guards remain required
typed amount/bonus/notify controls remain intact
```

Because BO touched shared confirmation rendering, QA should also perform small smoke checks for:

```text
tenant:orders Update or Cancel
tenant:wallets adjust
```

Other already-passing P1 evidence may be reused unless this focused smoke reveals a shared regression.

## Customer-Related CRUD QA Policy

QA must validate customer/member/customer-facing context with API requests before entering Customer frontend.

For this task:

```text
send tenant topup API requests first against Docker/local platform API data
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
ai-agents/reports/20260510-back-office-p1-topups-customer-context-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide approval for the P1 BO workflow slice. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
