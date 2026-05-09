# 20260507-m8-affiliate-agent-reports-settlement - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the Milestone 8 Platform API foundation for tenant agent management, affiliate management, commission calculation and payout flows, tenant/central reports with export job placeholders, and central partner settlement summaries.

This task follows Coordinator decision:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
```

## Objective

Build the backend/API foundation in `apps/platform-api` so Back Office can later manage agents, affiliate accounts/programs/links/attributions, commission rules/transactions, affiliate payouts, tenant reports/export jobs, central reports/export jobs, and central settlements.

Commission calculation must run through a service/command/worker path from paid orders, not synchronously inside the checkout controller.

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

## Scope

Can implement only inside `apps/platform-api/**` plus the backend handoff file listed below.

Backend surface to implement:

- Agent schema and tenant admin APIs.
- Agent quota schema and tenant admin quota API.
- Affiliate account, program, link, and attribution schema and tenant admin APIs.
- Commission rules and commission transactions.
- Worker/command/service-driven commission calculation from paid orders.
- `commission.calculated.v1` outbox persistence if the existing `sync_outbox` pattern supports it.
- Affiliate payout contract and approval flow.
- Tenant report endpoints and report export job foundation.
- Central report endpoints and report export job foundation.
- Central partner settlement list/detail/approve foundation.
- Focused feature/service tests for the behavior above.

Endpoint targets:

```text
GET    /api/v1/admin/tenant/agents
POST   /api/v1/admin/tenant/agents
GET    /api/v1/admin/tenant/agents/{agent_id}
PATCH  /api/v1/admin/tenant/agents/{agent_id}
PATCH  /api/v1/admin/tenant/agents/{agent_id}/quotas
GET    /api/v1/admin/tenant/affiliate-programs
POST   /api/v1/admin/tenant/affiliate-programs
GET    /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
PATCH  /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
DELETE /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
GET    /api/v1/admin/tenant/affiliate-links
POST   /api/v1/admin/tenant/affiliate-links
GET    /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
PATCH  /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
DELETE /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
GET    /api/v1/admin/tenant/affiliate-attributions
GET    /api/v1/admin/tenant/affiliate-attributions/{attribution_id}
GET    /api/v1/admin/tenant/affiliates
POST   /api/v1/admin/tenant/affiliates
GET    /api/v1/admin/tenant/affiliates/{affiliate_id}
PATCH  /api/v1/admin/tenant/affiliates/{affiliate_id}
GET    /api/v1/admin/tenant/commission-rules
POST   /api/v1/admin/tenant/commission-rules
GET    /api/v1/admin/tenant/commission-rules/{commission_rule_id}
PATCH  /api/v1/admin/tenant/commission-rules/{commission_rule_id}
DELETE /api/v1/admin/tenant/commission-rules/{commission_rule_id}
GET    /api/v1/admin/tenant/commission-transactions
POST   /api/v1/admin/tenant/commission-transactions/{commission_id}/approve
GET    /api/v1/admin/tenant/payouts
POST   /api/v1/admin/tenant/payouts
POST   /api/v1/admin/tenant/payouts/{payout_id}/approve
GET    /api/v1/admin/tenant/reports/{report_key}
POST   /api/v1/admin/tenant/reports/{report_key}/exports
GET    /api/v1/admin/tenant/export-jobs/{export_job_id}
GET    /api/v1/admin/tenant/export-jobs/{export_job_id}/download
GET    /api/v1/admin/central/reports/{report_key}
POST   /api/v1/admin/central/reports/{report_key}/exports
GET    /api/v1/admin/central/export-jobs/{export_job_id}
GET    /api/v1/admin/central/export-jobs/{export_job_id}/download
GET    /api/v1/admin/central/settlements
GET    /api/v1/admin/central/settlements/{settlement_id}
POST   /api/v1/admin/central/settlements/{settlement_id}/approve
```

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement Back Office screens.
- Do not edit `docs/openapi.yaml` unless Coordinator explicitly approves a contract correction.
- Do not implement public affiliate tracking pixel/cookie UI unless an already-safe API-only helper exists.
- Do not modify checkout controller logic to calculate commission synchronously.
- Do not implement a real bank transfer provider integration.
- Do not implement real file storage/CDN export delivery beyond a safe placeholder or signed URL contract.
- Do not implement billing plan/payment collection for platform subscriptions.
- Do not implement M9 maintenance/support/security hardening.
- Do not upgrade Laravel/PHP dependencies.
- Do not create tenant-specific codebases, clone apps, or per-tenant runtimes.

## File Ownership

Can edit:

```text
apps/platform-api/**
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/**
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
```

## Required Steps

1. Inspect the current Platform API conventions before editing:
   - `apps/platform-api/routes/api.php`
   - existing controllers under `apps/platform-api/app/Modules/Platform/Http/Controllers`
   - existing shared services under `apps/platform-api/app/Shared`
   - existing migrations and feature tests.
2. Add migrations for the M8 backend foundation using string/UUID-style ids consistent with existing platform tables.
3. Add services/controllers/routes for the endpoint targets above.
4. Use existing auth, tenant scope, permission, idempotency, audit, and error-envelope patterns:
   - `admin.auth`
   - `admin.scope:tenant`
   - `admin.scope:central`
   - `PermissionService`
   - `IdempotencyService`
   - `AuditLogger`
   - `ApiErrorResponse`
5. Enforce selected tenant scope from `X-Tenant-Id` for every tenant-owned query and write.
6. Enforce central scope for central reports and settlements.
7. Use permission codes from `docs/permissions.md`. At minimum:
   - tenant agents: `agent.view`, `agent.create`, `agent.update`, `agent.quota.manage`
   - tenant affiliates: `affiliate.view`, `affiliate.create`, `affiliate.update`
   - tenant affiliate programs: `affiliate_program.view`, `affiliate_program.manage`
   - tenant affiliate links: `affiliate_link.view`, `affiliate_link.manage`
   - tenant attributions: `affiliate_attribution.view`
   - tenant commissions: `commission.view`, `commission.approve`, `commission_rule.view`, `commission_rule.manage`
   - tenant payouts: `payout.manage`
   - tenant reports/exports: `report.view`
   - central reports/exports: `report.view`
   - central settlements: `settlement.view`, `settlement.approve`
8. Use status values from `docs/status-enums.md`. If a needed internal state is missing, keep it minimal and document it in the backend handoff.
9. Make affiliate links tenant-scoped and unique. Archived links/programs/rules must not be used for new attribution or commission calculation.
10. Make attributions tenant/customer/order-aware where available and prevent cross-tenant reads or writes.
11. Implement commission calculation as a service plus command/worker-safe entry point from paid orders:
    - no commission calculation inside the checkout controller
    - commission transaction rows reference `order_id` and `commission_rule_id`
    - retries are idempotent and do not duplicate transactions
    - reversals create reversal rows instead of deleting original rows
12. Persist `commission.calculated.v1` in `sync_outbox` if the existing outbox table/pattern can safely represent it in this slice.
13. Implement payout create/approve validation:
    - positive amounts only
    - supported payout methods only
    - allowed status transitions only
    - redact bank/account details in audit payloads.
14. Implement report endpoints as scoped aggregate reads. Keep heavy report-building logic out of write paths.
15. Implement export jobs with scoped queue/ready placeholders if real file generation/storage is too broad. Download behavior must match OpenAPI enough for UI consumption.
16. Implement central settlement list/detail/approve summaries from approved M5/M8 records:
    - summarize partner/tenant sales and commission data
    - approval is idempotent and audited
    - approval must not mutate orders/commissions by deletion.
17. Add focused tests covering tenant isolation, permissions, idempotency, commission retry/reversal, reports scope, export job scope, payout validation, and settlement summaries.
18. Run validation through Docker only and record the results in the backend handoff.

## Acceptance Criteria

- Migrations run from an empty testing database.
- Tenant agent APIs are tenant-scoped, permission checked, audited, and idempotent where applicable.
- Tenant affiliate account/program/link/attribution APIs are tenant-scoped, permission checked, and idempotent where applicable.
- Commission rules and commission transactions are tenant-scoped and permission checked.
- Commission calculation runs from a command/service/worker path and not from the checkout controller.
- Commission calculation references `order_id` and `commission_rule_id`.
- Retrying commission calculation does not duplicate transactions.
- Commission reversal uses reversal rows, not deletion.
- Affiliate payout create/approve validates positive amounts and allowed status transitions.
- Tenant reports enforce selected tenant scope.
- Central reports enforce central scope and allow tenant drill-down only where OpenAPI allows.
- Report export jobs are scoped correctly and idempotent.
- Central settlement list/detail/approve summarizes partner sales/commission data and is permission checked/idempotent.
- API errors use the existing `ApiErrorResponse` envelope without raw exception details.
- Sensitive payout/bank payload values are redacted in audit logs.
- No `apps/customer` or `apps/back-office` changes.
- No `docs/openapi.yaml` change unless Coordinator approval exists.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Agent
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test --filter=Settlement
docker compose run --rm platform-api php artisan test
```

If dedicated commands for commission calculation or report building are created, include Docker-only invocations in the backend handoff and tests.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation commands and results
documented API response fields if OpenAPI uses generic AdminResource shapes
any internal enum values added because they were missing from docs/status-enums.md
known risks
next agent
```

Next agent after backend handoff:

```text
Orchestrator
```

Do not create a QA task directly. Orchestrator will create the QA task after this backend handoff exists.
