# M8 Affiliate, Agent, Reports, Settlement Decision

## Context

Approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
ai-agents/decisions/20260507-m7-reward-result-engine-approval-decision.md
```

The platform now has approved tenant/admin foundation, provisioning, stock allocation/local stock, checkout/wallet/order/ticket/topup, customer integration, and reward/result backend.

The main execution plan now moves to:

```text
Milestone 8: Affiliate, Agent, Reports, Settlement
```

M8 is backend/API foundation work. It prepares the platform APIs and services that later back-office screens will consume. Back-office UI implementation is not part of this slice.

## Decision

Start M8 Affiliate, Agent, Reports, Settlement.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep it as one implementation task unless a real schema/API blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Objective

Implement the Platform API foundation for tenant agent management, affiliate accounts/programs/links/attribution, commission rules and worker-driven commission transactions, affiliate payouts, tenant/central reports and export jobs, and central partner settlement summaries.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/erd.md
docs/status-enums.md
docs/events.md
docs/permissions.md
document/03_PARTNER_STORE_MODULE.md
document/06_AFFILIATE_PARTNER.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
ai-agents/decisions/20260507-m7-reward-result-engine-approval-decision.md
```

## Scope

Approved implementation scope:

```text
apps/platform-api/**
```

Approved backend surfaces:

```text
agent schema and tenant admin APIs
agent quota schema and tenant admin quota API
affiliate program/account/link/attribution schema and tenant admin APIs
commission rules and commission transactions
worker/command/service-driven commission calculation from paid orders
commission.calculated.v1 outbox/event persistence if current event pattern supports it
affiliate payout contract and approval flow
tenant report endpoints and report export job foundation
central report endpoints and report export job foundation
central partner settlement list/detail/approve foundation
focused feature/service tests
```

Approved Platform API endpoint targets:

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

## Implementation Requirements

```text
Preserve existing module conventions under apps/platform-api.
Do not change docs/openapi.yaml unless Coordinator explicitly approves a contract correction.
Use UUID/string ids consistent with existing platform tables.
Use status values from docs/status-enums.md where defined; if a status is not defined, use a minimal documented internal enum in the Backend handoff.
Tenant admin APIs must require admin auth, tenant scope, selected X-Tenant-Id, and mapped permissions from docs/permissions.md.
Central report/settlement APIs must require central admin auth and mapped report/settlement permissions.
Every tenant-owned query must filter by the selected tenant; central drill-down may filter by tenant_id only where OpenAPI allows.
Write actions must use Idempotency-Key where OpenAPI requires it.
Write actions must audit through existing audit patterns and redact sensitive payloads such as bank account details.
Agent and affiliate records must be tenant-scoped and must never create new codebases or tenant clones.
Affiliate links must be unique and tenant-scoped; archived links/programs/rules must not be used for new attribution/commission calculation.
Affiliate attribution must link tenant/customer/order context where available and must not leak across tenants.
Commission must be calculated by a service/command/worker path, not directly in checkout controller.
Commission transactions must reference order_id and commission_rule_id.
Commission calculation must be idempotent and must not duplicate transactions on retry.
Commission reversal must use ledger/reversal transaction rows, not delete original transactions.
commission.calculated.v1 should be persisted in sync_outbox if current event patterns support it.
Payout creation/approval must validate positive amounts and supported payout method/status transitions.
Reports must enforce tenant scope and avoid heavy write-path logic.
Report export jobs can be queued/ready placeholders if real file generation/storage is too broad; status/download behavior must match OpenAPI enough for UI integration.
Central settlement summaries must summarize partner/tenant sales and commission data from approved M5/M8 records.
Settlement approval must be idempotent, audited, and must not mutate underlying orders/commissions by deletion.
Use existing ApiErrorResponse/error envelope patterns and avoid raw exception details.
Write focused tests for tenant isolation, permissions, idempotency, commission retry behavior, reversal behavior, reports scope, export job scope, payout validation, and settlement summaries.
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not edit apps/back-office.
Do not implement back-office screens.
Do not implement public affiliate tracking pixel/cookie UI unless already available as a safe API-only helper.
Do not modify checkout controller to calculate commission synchronously.
Do not implement real bank transfer provider integration.
Do not implement real file storage/CDN export delivery beyond safe placeholder/signed URL contract.
Do not implement billing plan/payment collection for platform subscriptions.
Do not implement M9 maintenance/support/security hardening.
Do not upgrade Laravel/PHP dependencies.
```

## Acceptance Criteria

```text
Migrations run from an empty testing database.
Tenant agent APIs are tenant-scoped, permission checked, audited, and idempotent where applicable.
Tenant affiliate account/program/link/attribution APIs are tenant-scoped, permission checked, and idempotent where applicable.
Commission rules and commission transactions are tenant-scoped and permission checked.
Commission calculation runs from command/service/worker path and not checkout controller.
Commission calculation references order_id and commission_rule_id.
Retrying commission calculation does not duplicate transactions.
Commission reversal uses reversal transaction rows, not delete.
Affiliate payout create/approve validates positive amounts and allowed status transitions.
Tenant reports enforce selected tenant scope.
Central reports enforce central scope and tenant drill-down only where allowed.
Report export jobs are scoped correctly and idempotent.
Central settlement list/detail/approve summarizes partner sales and commission data and is permission checked/idempotent.
No apps/customer or apps/back-office changes are made.
Backend Develop writes a handoff to ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands. Backend Develop and QA must not run host PHP/Composer/Artisan.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Agent
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test --filter=Settlement
docker compose run --rm platform-api php artisan test
```

If Backend Develop creates dedicated commands for commission calculation or report building, include Docker-only invocations in the handoff and tests.

## Known Risks

```text
OpenAPI uses generic AdminResource/AdminResourceListResponse for many M8 admin endpoints; Backend Develop must choose stable resource fields and document them in the handoff.
Real external payout/bank transfer is not approved; payout approval can be status/audit/ledger-contract only.
Real export file storage/CDN delivery may be represented by queued/ready export job contract if full storage is too broad.
Affiliate attribution from customer browser tracking may need a later customer/frontend slice; this slice can create tenant admin/API foundation and order-linked attribution service hooks.
Back-office UI starts after backend APIs are approved.
```

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```
