# Back Office P5 Remaining Partial Workflow Closure Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Plan and start P5 closure for remaining partial Back Office rows:

```text
back-office-p5-remaining-partial-workflow-closure-planning
```

## Source

Coordinator P4 closure review:

```text
ai-agents/decisions/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

## What Was Done

Created first P5 QA-only slice:

```text
ai-agents/tasks/20260511-back-office-p5-read-summary-list-detail-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## Current Coverage Baseline

Coordinator-approved BO completion:

```text
36 / 56 complete = 64.3%
18 partial
2 api_gap
```

API-gap rows:

```text
central:master_stock
tenant:commission_transactions
```

Backend remains frozen except recorded API-gap decisions. Customer frontend remains frozen.

## P5 Split Plan

### Slice P5-A: QA-only read/summary/list/detail closure

Dispatched now to QA Tester:

```text
central:dashboard
tenant:dashboard
tenant:tickets
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

Reason:

```text
These rows appear to be read-only or read-mostly under the current frozen backend contract and already have BO routes/catalog support. They need real authenticated menu workflow proof, API-backed content evidence, scope headers, and useful operator context before Coordinator can decide completion.
```

### Slice P5-B: BO typed CRUD/action implementation candidates

Hold for later BO Develop tasks after P5-A returns:

```text
central:games
tenant:price_rules
tenant:customers
tenant:agents
tenant:agent_quotas
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
tenant:seo_settings
```

Reason:

```text
The matrix shows missing typed create/update/delete/action workflows, JSON-only forms, missing surfaced actions, or insufficient domain-specific operators. These should be split into small BO implementation slices followed by QA.
```

Suggested future grouping:

```text
P5-B1 central games typed create/update/close/archive workflow
P5-B2 tenant price rules and customers typed CRUD/status workflows
P5-B3 tenant agent and agent quota workflows
P5-B4 tenant affiliate program/account/link/attribution/commission workflows
P5-B5 tenant SEO settings/pages/redirects workflow
```

### Coordinator decision candidates

Do not dispatch implementation yet:

```text
central:partner_monitoring
central:partner_usage
central:master_stock
tenant:commission_transactions
```

Reason:

```text
central:partner_monitoring and central:partner_usage have backend update APIs, but seeded menu permissions are view-only and BO intentionally blocks update UI pending Coordinator permission decision.
central:master_stock and tenant:commission_transactions remain explicit API gaps in the frozen backend contract.
```

## Guardrails Passed To QA

```text
Do not count route/catalog/menu presence as completion.
Use real authenticated BO menus.
Use API evidence rather than Customer UI for customer-adjacent rows.
Do not use Customer frontend.
Backend remains frozen.
Customer frontend remains frozen.
Use Docker-only validation for all application commands.
Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.
Do not touch unrelated dirty files.
```

## Validation Plan Given To QA

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected QA Output For P5-A

```text
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/**
```

## Next Step After P5-A QA

QA should route to:

```text
Coordinator
```

After Coordinator review, Orchestrator should continue with BO implementation slices for the remaining typed CRUD/action candidates or with Coordinator decision requests for permission/API-gap rows.

## Next Agent

QA Tester
