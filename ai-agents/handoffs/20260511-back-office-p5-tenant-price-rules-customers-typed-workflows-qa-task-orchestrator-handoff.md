# Back Office P5 Tenant Price Rules Customers Typed Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO tenant price rules/customers typed workflow implementation to QA Tester.

## Source

Coordinator P5 central games typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-central-games-typed-workflow-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-qa-review-coordinator-handoff.md
```

BO implementation task and handoff:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 10ce1bfb720d561e0fab6f886c45f04337a6e239
BO handoff commit: 187e21a14968ef0983f60fb943c4173469921bcf
```

BO added typed tenant workflows for:

```text
tenant:price_rules
tenant:customers
```

Price rule workflow:

```text
typed create via POST /admin/tenant/price-rules
typed update via PATCH /admin/tenant/price-rules/{price_rule_id}
reason-confirmed archive via DELETE /admin/tenant/price-rules/{price_rule_id}
```

Customer/member workflow:

```text
typed create via POST /admin/tenant/members
typed update via PATCH /admin/tenant/members/{member_id}
reason-confirmed status change via POST /admin/tenant/members/{member_id}/status
```

BO reports tenant scope, `X-Tenant-Id`, idempotency behavior, list/detail/filter/cursor behavior, and customer frontend freeze were preserved.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
tenant:price_rules
tenant:customers
real authenticated tenant menus
typed create/update/archive or status workflows
tenant scope and X-Tenant-Id evidence
idempotency evidence for write calls
BO/API-only customer-related evidence
```

QA must not enter the Customer frontend.

## Validation Plan Given To QA

Docker-only:

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

## Expected QA Output

```text
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `tenant:price_rules` and/or `tenant:customers` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
