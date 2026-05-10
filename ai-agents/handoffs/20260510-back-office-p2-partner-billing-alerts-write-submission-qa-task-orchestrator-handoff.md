# Back Office P2 Partner Billing Alerts Write Submission QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route Coordinator-reviewed P2 non-destructive QA pass to focused write-submission QA.

## Source

Coordinator QA review:

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-write-submission-qa.md
```

No implementation code was changed by Orchestrator.

## QA Scope

Write-submission rows:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:billing_plans
central:alert_policies
central:alert_events
```

Out of scope:

```text
central:partner_monitoring
central:partner_usage
```

These remain Coordinator permission/UX decision items.

## Routing

Next agent:

```text
QA Tester
```

Expected report:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md
```

Expected artifacts:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/
```

## Guardrails

- Use local Docker QA fixture data only.
- Capture before/after API evidence and real central-menu browser evidence.
- Do not use Customer frontend.
- Do not edit implementation.
- Backend and customer frontend remain frozen.

## Next Agent

QA Tester
