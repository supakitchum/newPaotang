# Coordinator Handoff - Back Office P1 Topups Customer Context Remediation QA Review

Date: 2026-05-10
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p1-topups-customer-context-remediation`
Next Task: `back-office-p2-partner-billing-alerts-workflows`

## Summary

QA passed the topups customer-context remediation. Coordinator approves the remediation and closes the P1 money/stock CRUD/API workflow slice for BO coverage counting.

Official BO completion is now 11/56 menus, or 19.6%, based only on verified working CRUD/API workflow coverage. Do not count route presence, menu visibility, or catalog entries as completion.

## Artifacts

- Decision: `ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md`
- QA report: `ai-agents/reports/20260510-back-office-p1-topups-customer-context-remediation-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260510-back-office-p1-topups-customer-context-remediation-qa/`
- Updated matrix: `docs/back-office-crud-coverage.md`

## Accepted Complete Rows

- `central:stock_generation`
- `central:allocations`
- `central:stock_recall`
- `tenant:local_stock`
- `tenant:stock_sync`
- `tenant:reservations`
- `tenant:orders`
- `tenant:wallets`
- `tenant:topups`
- `tenant:payouts`
- `tenant:payment_settings`

## Remaining Coverage

- 43 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Next Instruction For Orchestrator

Open task `back-office-p2-partner-billing-alerts-workflows` and dispatch BO Develop against the next matrix priority:

- `central:partners`
- `central:partner_provisioning`
- `central:partner_quotas`
- `central:partner_monitoring`
- `central:partner_usage`
- `central:billing_plans`
- `central:alert_policies`
- `central:alert_events`

BO Develop should implement typed forms/modals/workflows and API connections where the backend contract already supports them. If a backend contract gap is discovered, report the exact missing route/payload and stop that row for Coordinator decision instead of modifying backend by default.

QA Tester must test real menus and API-backed behavior. For customer-related CRUD/workflow checks, QA must send API requests first instead of entering the Customer UI first.

## Guardrails

- Backend remains complete/frozen for BO unless Coordinator explicitly approves a targeted remediation.
- Customer frontend remains frozen.
- Docker-only for application/runtime/test commands.
- Keep BO percentage derived from `docs/back-office-crud-coverage.md` row status and QA evidence only.
