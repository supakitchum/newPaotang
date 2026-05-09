# m7-reward-result-engine - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start Milestone 7 after M6 Customer API Integration approval:

```text
M7 Reward Result Engine
```

This is a backend-first slice. Implement the reward/result engine and API surface that the already-approved customer result pages and later back-office screens will consume. Back-office UI implementation is not part of this slice.

This task is authorized by:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
ai-agents/handoffs/20260507-m7-reward-result-engine-coordinator-handoff.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

Keep this as one Backend Develop implementation task unless a real schema/API blocker is found and documented for Coordinator review.

## Objective

Implement the Platform API reward result engine foundation:

```text
reward result recording
prize validation
chunked ticket checking
idempotent winning ticket creation
reward verification/publish/versioning
public result APIs
customer ticket reward status
customer reward claim foundation
tenant admin reward claim management
central admin reward management
tests
```

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/erd.md
- docs/status-enums.md
- docs/events.md
- docs/permissions.md
- docs/frontend-routes.md
- docs/customer-api-integration-map.md
- docs/workspace-app-structure.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
- ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
- ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
- ai-agents/handoffs/20260507-m7-reward-result-engine-coordinator-handoff.md
- apps/platform-api/composer.json

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

Implementation requirements:

- Preserve existing Laravel/module conventions under `apps/platform-api`.
- Create migrations for `reward_results`, `reward_prizes`, `reward_check_batches`, `reward_check_items`, `winning_tickets`, `reward_publish_logs`, and reward claims if no existing table supports the OpenAPI claim flow.
- Use UUID/string ids consistent with existing platform tables.
- Use status values from `docs/status-enums.md`.
- Central reward admin APIs must require central admin auth and mapped reward permissions.
- Tenant reward claim APIs must require tenant admin auth, selected tenant context, and mapped reward claim permissions.
- Customer reward APIs must resolve tenant by `Host` and authenticated customer token.
- Never leak another tenant/customer claim or ticket.
- Record reward result and prize rows idempotently for repeated `POST`/`PATCH`/`verify`/`publish`/`correct` writes where OpenAPI requires `Idempotency-Key`.
- Validate prize numbers and duplicate prize rows before accepting a reward result.
- Checking must process sold tickets for the target game by tenant/chunks.
- Do not run heavy ticket matching inside public result HTTP requests.
- A synchronous command/service-driven check is acceptable in this slice if it is deterministic, chunk-aware, and testable through Docker.
- Create `winning_tickets` idempotently with unique `(game_id, ticket_id, prize_type, prize_number)`.
- Retrying a check must not duplicate winning tickets, check items, ledger/wallet movements, or publish logs.
- Verification must require completed checking and a stable summary.
- Publish must require verified status, create `reward_publish_logs`, increment or set reward version, emit/persist `reward.published.v1` when current event/outbox patterns allow, and invalidate/use cache version keys where practical.
- Public result endpoints must return only published results, resolve tenant by `Host`, be cache-friendly, return `ETag` where practical, and must not perform ticket matching.
- Customer ticket reward status must return pending/non-winning/winning style state from published/check results without exposing other customer data.
- Customer reward claim creation must require a winning ticket owned by the authenticated customer and use `Idempotency-Key`.
- Tenant reward claim approve/reject/pay must be audited and idempotent.
- Wallet-credit payout may reuse existing wallet ledger patterns if safe in this slice.
- Bank/manual payouts can remain status/audit records without real external bank integration.
- Use existing `ApiErrorResponse`/error envelope patterns and avoid raw exception details.
- Write focused tests for permissions, tenant isolation, idempotency, check retry behavior, publish/version behavior, public results, customer reward status, and reward claim lifecycle.

## Out Of Scope

- Do not edit `apps/customer` unless Coordinator explicitly approves a tiny API fixture correction.
- Do not edit `apps/back-office`.
- Do not implement back-office screens.
- Do not change `docs/openapi.yaml`, source-of-truth docs, or `document/**`; if a contract correction is required, stop and document the blocker for Coordinator review.
- Do not implement real bank transfer integration.
- Do not implement real notification providers.
- Do not implement long-running queue worker daemon infrastructure beyond testable command/service hooks.
- Do not change checkout, wallet, topup, or ticket purchase behavior except for reward claim payout integration if needed and safely contained.
- Do not implement affiliate, commission, reports, settlement, or billing.
- Do not upgrade Laravel/PHP dependencies.
- Do not edit `ai-agents/BOARD.md`.

## File Ownership

Can edit:

```text
apps/platform-api/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Backend Develop may write only its required handoff under `ai-agents/handoffs/**`.

If implementation requires customer frontend, back-office, OpenAPI contract, dependency upgrade, real queue daemon, real bank integration, or notification provider changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect current `apps/platform-api` module conventions, routes, controllers, services, auth middleware, idempotency service, audit logger, migrations, seeders, and tests before editing.
3. Inspect current checkout/order/ticket/wallet/topup schema and services from M5 before designing reward tables.
4. Inspect current permission seeding and admin scope patterns before adding reward and reward claim permissions.
5. Design and create reward/result migrations needed for the OpenAPI flow.
6. Add minimal reward claim table support if no existing table satisfies OpenAPI claim endpoints; document table shape in the handoff.
7. Implement reward result/prize service layer with validation, duplicate protection, status transitions, idempotent writes, and audit logging.
8. Implement deterministic chunked reward checking over sold tickets by game/tenant.
9. Make check retries idempotent and safe against duplicate `winning_tickets`, check items, wallet/ledger movements, and publish logs.
10. Add verification flow requiring completed checking and stable summary.
11. Add publish/correct flow with version/publish log behavior and `reward.published.v1` event/outbox persistence where current patterns support it.
12. Add central admin reward endpoints with central admin auth and permission checks.
13. Add public published result endpoints with host tenant resolution, published-only behavior, cache-friendly headers, and no heavy matching.
14. Add customer ticket reward status endpoint scoped by host tenant and authenticated customer.
15. Add customer reward claim list/create/detail endpoints scoped by host tenant and authenticated customer.
16. Add tenant admin reward claim list/detail/approve/reject/pay endpoints scoped by selected tenant and permission checks.
17. Reuse wallet ledger payout behavior only if safe and scoped; otherwise record manual/bank payout status and audit without external integration.
18. Normalize errors through existing API error envelope patterns.
19. Add or update focused feature/service tests for reward engine behavior, permission checks, tenant isolation, idempotency, retries, publish/versioning, public results, customer status, and claim lifecycle.
20. Run required validation commands through Docker only.
21. Write the required Backend Develop handoff.

## Acceptance Criteria

- Migrations run from an empty testing database.
- Central admin can record, view, update draft, verify, publish, correct, and list reward results with permission checks.
- Reward result recording validates prize input and records audit/idempotency for writes.
- Reward check processes sold tickets by game and tenant chunks.
- Retrying reward check does not duplicate `winning_tickets`.
- Verified summary is required before publish.
- Publish increments/sets reward version, writes publish log, and exposes published results through public endpoints.
- Public result endpoints are cache-friendly and do not perform heavy matching in the request path.
- Customer ticket reward status is tenant/customer scoped.
- Customer reward claim create/list/detail is tenant/customer scoped and idempotent.
- Tenant admin reward claim list/detail/approve/reject/pay is tenant scoped, permission checked, audited, and idempotent where applicable.
- `reward.published.v1` is emitted/persisted if current event/outbox patterns support it, or the limitation is documented.
- No `apps/customer` or `apps/back-office` changes are made.
- No source-of-truth docs or Board changes are made.
- Docker validation passes.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

If Backend Develop creates a dedicated reward checking command, run it through Docker only and document the invocation and result in the handoff, for example:

```sh
docker compose run --rm platform-api php artisan <reward-check-command>
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
```

Must include:

```text
what was done
files changed
schema/migrations added
endpoint coverage
permission coverage
idempotency behavior
tenant isolation behavior
reward check retry behavior
publish/version/event behavior
public cache behavior
claim lifecycle behavior
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: QA should receive a task only after Backend Develop produces a handoff.

