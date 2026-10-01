# M7 Reward Result Engine Decision

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
```

The platform now has approved tenant foundation, stock allocation/local stock, reservation/checkout/wallet/order/ticket/topup backend, and the customer frontend adapter integration.

The main execution plan now moves to:

```text
Milestone 7: Reward Result Engine
```

M7 is backend-first. It creates the reward/result engine and API surface that customer result pages and later back-office screens will consume. Back-office UI implementation is not part of this slice.

## Decision

Start M7 Reward Result Engine.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep it as one implementation task unless a real schema/API blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
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

Implement the Platform API reward result engine foundation: reward result recording, prize validation, chunked ticket checking, idempotent winning ticket creation, reward verification/publish/versioning, public result APIs, customer ticket reward status, customer reward claim foundation, and tenant admin reward claim management.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/erd.md
docs/status-enums.md
docs/events.md
docs/permissions.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
document/15_EXECUTION_PLAN.md
document/09_AI_WORK_INSTRUCTIONS.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

## Scope

Approved implementation scope:

```text
apps/platform-api/**
```

Approved backend surfaces:

```text
reward result schema and migrations
reward result/prize service layer
reward checking service with chunked processing
winning ticket creation and idempotency rules
reward publish log and version handling
reward.published.v1 outbox/event persistence if current outbox pattern supports it
central admin reward APIs
public published result APIs
customer ticket reward status API
customer reward claim APIs
tenant admin reward claim APIs
feature tests and focused service tests
```

Approved Platform API endpoint targets:

```text
GET /api/v1/admin/central/rewards
POST /api/v1/admin/central/rewards
GET /api/v1/admin/central/rewards/{reward_result_id}
PATCH /api/v1/admin/central/rewards/{reward_result_id}
GET /api/v1/admin/central/rewards/{reward_result_id}/check-batches
POST /api/v1/admin/central/rewards/{reward_result_id}/verify
POST /api/v1/admin/central/rewards/{reward_result_id}/publish
POST /api/v1/admin/central/rewards/{reward_result_id}/correct
GET /api/v1/public/results/latest
GET /api/v1/public/results/{game_id}
GET /api/v1/customer/tickets/{ticket_id}/reward-status
GET /api/v1/customer/reward-claims
POST /api/v1/customer/reward-claims
GET /api/v1/customer/reward-claims/{claim_id}
GET /api/v1/admin/tenant/reward-claims
GET /api/v1/admin/tenant/reward-claims/{claim_id}
POST /api/v1/admin/tenant/reward-claims/{claim_id}/approve
POST /api/v1/admin/tenant/reward-claims/{claim_id}/reject
POST /api/v1/admin/tenant/reward-claims/{claim_id}/pay
```

## Implementation Requirements

```text
Preserve existing module conventions under apps/platform-api.
Do not change docs/openapi.yaml unless Coordinator explicitly approves a contract correction.
Create migrations for reward_results, reward_prizes, reward_check_batches, reward_check_items, winning_tickets, reward_publish_logs, and reward claims if no existing table supports the OpenAPI claim flow.
Use UUID/string ids consistent with existing platform tables.
Use status values from docs/status-enums.md.
Central reward admin APIs must require central admin auth and mapped reward permissions.
Tenant reward claim APIs must require tenant admin auth, selected tenant context, and mapped reward_claim permissions.
Customer reward APIs must resolve tenant by Host and authenticated customer token; never leak another tenant/customer claim or ticket.
Record reward result and prize rows idempotently for repeated POST/PATCH/verify/publish/correct writes where OpenAPI requires Idempotency-Key.
Validate prize numbers and duplicate prize rows before accepting a reward result.
Checking must process sold tickets for the target game by tenant/chunks and must not run heavy matching inside public result HTTP requests.
For this slice, a synchronous command/service-driven check is acceptable if it is deterministic, chunk-aware, and testable through Docker.
Create winning_tickets idempotently with unique(game_id, ticket_id, prize_type, prize_number).
Retrying a check must not duplicate winning_tickets, check_items, ledger/wallet movements, or publish logs.
Verification must require completed checking and a stable summary.
Publish must require verified status, create reward_publish_logs, increment or set reward version, emit/persist reward.published.v1 when current event/outbox patterns allow, and invalidate/use cache version keys where practical.
Public result endpoints must return only published results, resolve tenant by Host, be cache-friendly, return ETag where practical, and must not perform ticket matching.
Customer ticket reward status must return pending/non-winning/winning style state from published/check results without exposing other customer data.
Customer reward claim creation must require a winning ticket owned by the authenticated customer and use Idempotency-Key.
Tenant reward claim approve/reject/pay must be audited and idempotent.
Wallet-credit payout may reuse existing wallet ledger patterns if safe in this slice; bank/manual payouts can remain status/audit records without real external bank integration.
Use existing ApiErrorResponse/error envelope patterns and avoid raw exception details.
Write focused tests for permissions, tenant isolation, idempotency, check retry behavior, publish/version behavior, public results, customer reward status, and reward claim lifecycle.
```

## Out Of Scope

```text
Do not edit apps/customer unless a tiny API fixture correction is explicitly required by tests and documented.
Do not edit apps/back-office.
Do not implement back-office screens.
Do not implement real bank transfer integration.
Do not implement real notification providers.
Do not implement long-running queue worker daemon infrastructure beyond testable command/service hooks.
Do not change checkout, wallet, topup, or ticket purchase behavior except for reward claim payout integration if needed.
Do not implement affiliate, commission, reports, settlement, or billing.
Do not upgrade Laravel/PHP dependencies.
```

## Acceptance Criteria

```text
Migrations run from an empty testing database.
Central admin can record, view, update draft, verify, publish, correct, and list reward results with permission checks.
Reward result record validates prize input and records audit/idempotency for writes.
Reward check processes sold tickets by game and tenant chunks.
Retrying reward check does not duplicate winning_tickets.
Verified summary is required before publish.
Publish increments/sets reward version, writes publish log, and exposes published results through public endpoints.
Public result endpoints are cache-friendly and do not perform heavy matching in the request path.
Customer ticket reward status is tenant/customer scoped.
Customer reward claim create/list/detail is tenant/customer scoped and idempotent.
Tenant admin reward claim list/detail/approve/reject/pay is tenant scoped, permission checked, audited, and idempotent where applicable.
No apps/customer or apps/back-office changes are made.
Backend Develop writes a handoff to ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands. Backend Develop and QA must not run host PHP/Composer/Artisan.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

If Backend Develop creates a dedicated command for reward checking, include a Docker-only command invocation in the handoff and tests.

## Known Risks

```text
OpenAPI has reward claim endpoints but docs/erd.md does not currently list a reward_claims table; Backend Develop may add the minimum table needed to satisfy the OpenAPI contract and must document the table shape in the handoff.
Real async queue daemon and external notification delivery are not approved in this slice; service/command hooks plus persisted events are acceptable.
Real bank transfer payout is not approved; tenant reward claim pay can record manual/bank payout status and audit, while wallet_credit may use existing wallet ledger if safe.
Public result cache can start with ETag/version headers and deterministic queries if a full cache invalidation layer is too broad for this slice.
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
