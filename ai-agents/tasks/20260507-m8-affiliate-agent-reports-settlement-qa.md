# 20260507-m8-affiliate-agent-reports-settlement - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Milestone 8 backend slice:

```text
20260507-m8-affiliate-agent-reports-settlement
```

Validate the completed `apps/platform-api` implementation against the Coordinator M8 decision, the Backend Develop task, the Backend Develop handoff, source-of-truth API/contracts, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-coordinator-handoff.md
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
ai-agents/decisions/20260507-m7-reward-result-engine-approval-decision.md
```

## Objective

Validate the M8 Platform API foundation:

```text
tenant agent management
agent quotas
affiliate accounts/programs/links/attributions
commission rules and commission transactions
service/command-driven commission calculation from paid orders
commission retry idempotency and reversal rows
commission.calculated.v1 outbox persistence
affiliate payout create/approve flow
tenant reports and export jobs
central reports and export jobs
central settlement summaries and approval
tests and Docker validation
```

## Source Of Truth

- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/docker-runtime-policy.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/permissions.md`
- `document/03_PARTNER_STORE_MODULE.md`
- `document/06_AFFILIATE_PARTNER.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md`
- `ai-agents/decisions/20260507-m7-reward-result-engine-approval-decision.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md`
- `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-coordinator-handoff.md`
- `ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md`
- `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md`
- `apps/platform-api/composer.json`

## Scope

Validate Backend Develop changes only within approved implementation scope:

```text
apps/platform-api/**
```

Inspect at least the files Backend Develop reported changing:

```text
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/ReportController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralSettlementController.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/config/platform.php
apps/platform-api/tests/Support/M8GrowthFixtures.php
apps/platform-api/tests/Feature/AgentTest.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Feature/ReportTest.php
apps/platform-api/tests/Feature/SettlementTest.php
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
```

Validate schema coverage:

```text
agents
agent_quotas
affiliate_accounts
affiliate_programs
affiliate_links
affiliate_attributions
commission_rules
commission_transactions
affiliate_payouts
report_export_jobs
partner_settlements
sync_outbox usage for commission.calculated.v1 when supported
```

Validate approved Platform API endpoint coverage:

```text
GET /api/v1/admin/tenant/agents
POST /api/v1/admin/tenant/agents
GET /api/v1/admin/tenant/agents/{agent_id}
PATCH /api/v1/admin/tenant/agents/{agent_id}
PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas
GET /api/v1/admin/tenant/affiliate-programs
POST /api/v1/admin/tenant/affiliate-programs
GET /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
PATCH /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
DELETE /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
GET /api/v1/admin/tenant/affiliate-links
POST /api/v1/admin/tenant/affiliate-links
GET /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
PATCH /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
DELETE /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
GET /api/v1/admin/tenant/affiliate-attributions
GET /api/v1/admin/tenant/affiliate-attributions/{attribution_id}
GET /api/v1/admin/tenant/affiliates
POST /api/v1/admin/tenant/affiliates
GET /api/v1/admin/tenant/affiliates/{affiliate_id}
PATCH /api/v1/admin/tenant/affiliates/{affiliate_id}
GET /api/v1/admin/tenant/commission-rules
POST /api/v1/admin/tenant/commission-rules
GET /api/v1/admin/tenant/commission-rules/{commission_rule_id}
PATCH /api/v1/admin/tenant/commission-rules/{commission_rule_id}
DELETE /api/v1/admin/tenant/commission-rules/{commission_rule_id}
GET /api/v1/admin/tenant/commission-transactions
POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve
GET /api/v1/admin/tenant/payouts
POST /api/v1/admin/tenant/payouts
POST /api/v1/admin/tenant/payouts/{payout_id}/approve
GET /api/v1/admin/tenant/reports/{report_key}
POST /api/v1/admin/tenant/reports/{report_key}/exports
GET /api/v1/admin/tenant/export-jobs/{export_job_id}
GET /api/v1/admin/tenant/export-jobs/{export_job_id}/download
GET /api/v1/admin/central/reports/{report_key}
POST /api/v1/admin/central/reports/{report_key}/exports
GET /api/v1/admin/central/export-jobs/{export_job_id}
GET /api/v1/admin/central/export-jobs/{export_job_id}/download
GET /api/v1/admin/central/settlements
GET /api/v1/admin/central/settlements/{settlement_id}
POST /api/v1/admin/central/settlements/{settlement_id}/approve
```

Validate behavior:

- Tenant endpoints require `admin.auth`, `admin.scope:tenant`, active selected `X-Tenant-Id`, and mapped tenant RBAC checks.
- Central report and settlement endpoints require `admin.auth`, `admin.scope:central`, and mapped central RBAC checks.
- Tenant permissions are enforced for `agent.*`, `affiliate.*`, `affiliate_program.*`, `affiliate_link.*`, `affiliate_attribution.view`, `commission.*`, `commission_rule.*`, `payout.manage`, and `report.view`.
- Central permissions are enforced for `report.view`, `settlement.view`, and `settlement.approve`.
- Every tenant-owned read/write filters by selected tenant and does not leak records across tenants.
- Idempotent writes use `Idempotency-Key` and existing `IdempotencyService` replay/conflict behavior where OpenAPI/task requires it.
- API errors use the existing `ApiErrorResponse` envelope and do not expose raw exception details.
- Agent and affiliate records are tenant-scoped and do not create tenant clones, codebases, or dedicated runtimes.
- Affiliate links are unique per tenant; archived links/programs/rules/accounts are not used for new attribution or commission calculation.
- Attributions link tenant/customer/order context where available and do not leak across tenants.
- Commission calculation runs through `commission:calculate`/service/worker-safe path, not inside checkout controller.
- Commission transactions reference `order_id` and `commission_rule_id`.
- Retrying commission calculation does not duplicate transactions.
- Reversal behavior creates reversal rows with original reference instead of deleting original commission rows.
- `commission.calculated.v1` is persisted to `sync_outbox` if current outbox pattern supports it.
- Payout create/approve validates positive amount, supported payout method, allowed status transitions, and redacts bank/account details in audit payloads.
- Tenant reports enforce selected tenant scope and avoid heavy write-path logic.
- Central reports enforce central scope and allow tenant drill-down only where OpenAPI allows.
- Export jobs are scoped correctly, idempotent where applicable, and placeholder download behavior is clear and contract-compatible.
- Central settlement list/detail/approve summarizes partner/tenant sales and commission/payout data, is permission checked, idempotent, audited, and does not delete or mutate source orders/commissions incorrectly.
- Status values align with `docs/status-enums.md` or are clearly documented as minimal internal M8 states in the backend handoff. Pay special attention to `affiliate_attributions.status` and `commission_transactions.status`.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not implement Back Office screens.
- Do not implement public affiliate tracking pixel/cookie UI.
- Do not implement real bank transfer provider integration.
- Do not implement real CSV/XLSX/PDF generation/storage/CDN delivery beyond validating current placeholder behavior.
- Do not implement billing plan/payment collection for platform subscriptions.
- Do not implement M9 maintenance/support/security hardening.
- Do not upgrade Laravel/PHP dependencies.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend Develop handoff against the M8 Coordinator decision and Backend task.
4. Inspect `git status --short` and confirm Backend changed only approved `apps/platform-api/**` plus its backend handoff, or document scope drift.
5. Inspect migration/schema for required tables, indexes, foreign keys, UUID/string ids, uniqueness constraints, idempotency fields, and safe nullable relationships.
6. Inspect route registration for every approved M8 endpoint and the `commission:calculate` command.
7. Inspect `GrowthService` for agent, affiliate, commission, payout, attribution, report, export, and settlement business behavior.
8. Inspect tenant growth controller behavior for auth context, permissions, tenant scope, validation, idempotency, audit, and error envelopes.
9. Inspect report controller behavior for tenant/central scoping, report key handling, export job creation, and download behavior.
10. Inspect central settlement controller behavior for central scope, refresh/list/detail/approve, idempotency, and audit.
11. Inspect config redaction keys and verify payout/bank/account payloads are redacted in audit logs.
12. Inspect tests and fixtures for coverage of permissions, tenant isolation, idempotency, commission retry/reversal, reports scope, export job scope, payout validation, settlement summaries, and out-of-scope protection.
13. Run all required validation commands through Docker only.
14. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md`.
- QA report states whether M8 Affiliate Agent Reports Settlement passes, conditionally passes, or fails.
- QA report confirms Docker validation results for migration, Affiliate tests, Agent tests, Commission tests, Report tests, Settlement tests, full suite, and `commission:calculate`.
- QA report confirms no out-of-scope app, customer, back-office, source-of-truth doc, decision, task, handoff, or Board changes were made by QA.
- QA report confirms Backend changes stayed within approved implementation scope or lists scope drift defects.
- QA report confirms migrations run from an empty testing database.
- QA report confirms tenant agent APIs and quota behavior.
- QA report confirms tenant affiliate account/program/link/attribution APIs.
- QA report confirms permission and tenant isolation coverage for all tenant endpoints.
- QA report confirms central auth/permission/scope coverage for central reports and settlements.
- QA report confirms commission rule/transaction behavior, service/command calculation path, retry idempotency, reversal rows, and no checkout inline calculation.
- QA report confirms `commission.calculated.v1` outbox behavior or documents a justified limitation.
- QA report confirms payout validation, status transitions, audit logging, and sensitive payload redaction.
- QA report confirms tenant and central report scope and export job behavior.
- QA report confirms central settlement summaries and approval behavior.
- QA report documents any status enum drift or internal states and whether they are acceptable for Coordinator Gate review.
- QA report documents known risks and whether each is acceptable for Coordinator Gate review.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Agent
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test --filter=Settlement
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
git diff --stat -- apps/platform-api
rg -n "(agent|affiliate|commission|payout|report_export|settlement|commission\\.calculated\\.v1|commission:calculate|Idempotency|AuditLogger|admin\\.scope)" apps/platform-api/app apps/platform-api/routes apps/platform-api/database apps/platform-api/tests
sed -n '1,420p' apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
sed -n '1,900p' apps/platform-api/app/Shared/Growth/GrowthService.php
sed -n '1,520p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantGrowthController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/ReportController.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralSettlementController.php
sed -n '1,420p' apps/platform-api/routes/api.php
sed -n '1,140p' apps/platform-api/routes/console.php
sed -n '1,260p' apps/platform-api/config/platform.php
sed -n '1,760p' apps/platform-api/tests/Feature/AgentTest.php
sed -n '1,760p' apps/platform-api/tests/Feature/AffiliateTest.php
sed -n '1,760p' apps/platform-api/tests/Feature/CommissionTest.php
sed -n '1,760p' apps/platform-api/tests/Feature/ReportTest.php
sed -n '1,760p' apps/platform-api/tests/Feature/SettlementTest.php
sed -n '1,620p' apps/platform-api/tests/Support/M8GrowthFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
schema/migration findings
endpoint coverage findings
permission and auth findings
tenant isolation findings
idempotency findings
agent and quota findings
affiliate account/program/link/attribution findings
commission rule/transaction findings
commission calculation retry and reversal findings
commission outbox findings
payout validation and audit redaction findings
tenant report and export findings
central report and export findings
central settlement findings
status enum findings
test coverage findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
