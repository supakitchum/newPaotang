# Back Office P5 Tenant Affiliate Commission Typed Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO tenant affiliate/commission typed workflow implementation to QA Tester.

## Source

Coordinator P5 tenant agents/agent quotas typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
```

BO implementation task and handoff:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: fdd8ae946c52fb3ce7e4ffd71615cab546433cf2
BO handoff commit: 2462ce91a94f676a4fb590ee2e84921aef5c6e66
```

BO added typed tenant workflows for:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Affiliate program workflow:

```text
typed create via POST /admin/tenant/affiliate-programs
typed update via PATCH /admin/tenant/affiliate-programs/{affiliate_program_id}
reason-confirmed archive via DELETE /admin/tenant/affiliate-programs/{affiliate_program_id}
```

Affiliate account workflow:

```text
typed create via POST /admin/tenant/affiliates
typed update via PATCH /admin/tenant/affiliates/{affiliate_id}
no archive/delete action because backend does not expose one for affiliate accounts
```

Affiliate link workflow:

```text
typed create via POST /admin/tenant/affiliate-links
typed update via PATCH /admin/tenant/affiliate-links/{affiliate_link_id}
reason-confirmed archive via DELETE /admin/tenant/affiliate-links/{affiliate_link_id}
```

Commission rule workflow:

```text
typed create via POST /admin/tenant/commission-rules
typed update via PATCH /admin/tenant/commission-rules/{commission_rule_id}
reason-confirmed archive via DELETE /admin/tenant/commission-rules/{commission_rule_id}
```

BO reports tenant scope, `X-Tenant-Id`, idempotency behavior, list/detail/filter/cursor behavior, backend freeze, and customer frontend freeze were preserved.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
real authenticated tenant menus
typed create/update/archive workflows
tenant scope and X-Tenant-Id evidence
idempotency evidence for write calls
safe relation fixture evidence for affiliate links and commission rules
```

QA must not enter the Customer frontend.

## Validation Plan Given To QA

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AffiliateTest
docker compose run --rm platform-api php artisan test --filter=CommissionTest
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
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `tenant:affiliate_programs`, `tenant:affiliate_accounts`, `tenant:affiliate_links`, and/or `tenant:commission_rules` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
