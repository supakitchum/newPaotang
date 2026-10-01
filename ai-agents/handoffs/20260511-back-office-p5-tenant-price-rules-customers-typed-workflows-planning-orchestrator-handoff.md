# Back Office P5 Tenant Price Rules Customers Typed Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-tenant-price-rules-customers-typed-workflows
```

## Source

Coordinator P5 central games typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
```

## What Was Done

Created BO Develop implementation task:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused central games typed workflow QA passed. Coordinator promoted:

```text
central:games
```

Official BO completion is now:

```text
43 / 56 menus = 76.8%
```

Remaining:

```text
11 partial
2 api_gap
```

Next implementation rows:

```text
tenant:price_rules
tenant:customers
```

Reason they remain partial:

```text
BO still relies on generic JSON payload/detail workflows or incomplete surfaced actions, and the rows have not passed full real-menu typed workflow QA.
```

## Implementation Direction Given To BO

BO Develop must:

```text
implement or surface typed create/update/delete workflow for tenant:price_rules
implement or surface typed member create/update/status workflow for tenant:customers
preserve existing list/detail API connections
preserve tenant X-Tenant-Id behavior
preserve tenant scope and idempotency behavior from the existing admin API flow
avoid Customer frontend usage
avoid backend, OpenAPI, docs, compose, GitHub workflow, Board, decision, task, and report edits
commit and push scoped changes
handoff back to Orchestrator
```

Backend remains frozen. Customer frontend remains frozen.

## Contract Notes Passed To BO

Price rules typed fields should cover:

```text
code
name
game_id
rule_type
price_amount
currency
conditions
status active/archived
```

Price rule delete archives the rule and should be reason/context confirmed.

Customer/member typed fields should cover:

```text
create: name, phone, email, password, status, send_invitation
update: name, phone, email, admin_note
status action: status active/pending_verification/suspended/disabled, reason, notify_member
```

Customer-related QA must use BO/API evidence first and must not enter the Customer UI.

## Validation Plan Given To BO

Docker-only application validation:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
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
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes implementation without reporting a blocker, Orchestrator should create a focused QA Tester task for:

```text
tenant:price_rules
tenant:customers
real authenticated tenant menus
typed create/update/delete or status workflows
tenant scope and X-Tenant-Id evidence
BO/API-only customer-related evidence
```

## Next Agent

BO Develop
