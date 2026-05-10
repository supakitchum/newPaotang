# Back Office P2 Partner Billing Alerts Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO P2 partner/billing/alerts implementation to QA Tester.

## Source

BO Develop handoff:

```text
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

Coordinator next-priority decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 3c6750af9448cc72e56167231b750046ee6e6c19
BO handoff commit: 3c33e44b515a1ddb118061e1dcd7c828f4e256e0
```

BO surfaced typed workflows for:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:billing_plans
central:alert_policies
central:alert_events
```

BO preserved list/detail and intentionally did not expose update actions for:

```text
central:partner_monitoring
central:partner_usage
```

Reason:

```text
Backend PATCH endpoints require partner.monitoring.manage and partner.usage.manage, but seeded menu rows are view-only.
```

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

QA must test real authenticated BO central menu workflows, not only build/lint/unit checks:

```text
central partners list/detail/create/update/suspend
central partner provisioning provision/suspend
central partner quotas create/update
central partner monitoring list/detail and permission ambiguity
central partner usage list/detail and permission ambiguity
central billing plans create/update typed forms
central alert policies create/update typed forms
central alert events acknowledge/resolve
```

QA must not mark a row complete unless verified from the real menu with evidence.

## Validation Plan Given To QA

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty file existed:

```text
apps/platform-api/.phpunit.result.cache
```

This was not edited, staged, committed, or cleaned by Orchestrator. QA should also leave it untouched if still dirty.

## Expected QA Output

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA finds implementation defects, report severity and likely owner. If QA finds frozen backend contract or permission blockers, route to Coordinator for decision rather than editing backend or permissions.

## Next Agent

QA Tester
