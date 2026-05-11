# Back Office P5 Ticket Status Filter Remediation Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-ticket-status-filter-remediation
```

## Source

Coordinator P5-A QA review and remediation handoff:

```text
ai-agents/decisions/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
```

## What Was Done

Created BO Develop remediation task:

```text
ai-agents/tasks/20260511-back-office-p5-ticket-status-filter-remediation-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

P5-A read/summary/list/detail QA returned partial PASS.

Coordinator promoted five rows to complete:

```text
central:dashboard
tenant:dashboard
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

Official BO completion is now:

```text
41 / 56 menus = 73.2%
```

Held row:

```text
tenant:tickets
```

Finding:

```text
The tenant tickets page lists API status active, but the BO status dropdown only offers open, pending, resolved, and closed.
```

## Remediation Given To BO

BO Develop must:

```text
add active to the tenant tickets status filter options, or document any Coordinator-level contract contradiction
preserve existing useful ticket filters unless proven unsupported by the frozen contract
preserve tenant ticket list/detail behavior
preserve tenant scope and X-Tenant-Id behavior
avoid backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, and report edits
commit and push scoped changes
handoff back to Orchestrator
```

Backend remains frozen. Customer frontend remains frozen.

## Validation Plan Given To BO

Docker-only application validation:

```sh
git diff --check
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
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes remediation without reporting a blocker, Orchestrator should create a focused QA Tester task for:

```text
tenant:tickets only
real authenticated tenant tickets menu
active status option visible in the filter
filtering by active returns or preserves the active ticket fixture row where fixture data exists
ticket list/detail behavior remains intact
tenant scope and X-Tenant-Id remain correct
```

## Next Agent

BO Develop
