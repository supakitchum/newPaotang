# Back Office P2 Partner Billing Alerts Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p2-partner-billing-alerts-workflows
```

## Source

Coordinator QA review and next-priority handoff:

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

## What Was Done

Created BO Develop task:

```text
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md
```

No implementation code was changed by Orchestrator.

## BO Scope Dispatched

P2 matrix rows:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:partner_monitoring
central:partner_usage
central:billing_plans
central:alert_policies
central:alert_events
```

BO Develop is instructed to implement typed workflows and API connections where the frozen backend contract supports them, update matrix notes without marking rows complete before QA, commit implementation changes, and hand back to Orchestrator.

## Guardrails Passed To BO

```text
Backend remains frozen.
Customer frontend remains frozen.
Do not edit docs/openapi.yaml.
Do not change permission/security semantics.
Use Docker-only application/runtime/test commands.
Do not count route/catalog/menu presence as BO completion.
Do not mark rows complete before QA verifies real menu workflows.
```

Special ambiguity called out:

```text
central:partner_monitoring and central:partner_usage have backend update APIs, but seeded permissions are view permissions.
If permission intent is ambiguous, BO must report the blocker instead of changing permission/security behavior.
```

## Validation Plan Given To BO

Docker-only:

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

## Expected BO Output

```text
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

BO handoff must include commit hash, files changed, validation, known risks/blockers, and next agent.

## Next Agent

BO Develop
