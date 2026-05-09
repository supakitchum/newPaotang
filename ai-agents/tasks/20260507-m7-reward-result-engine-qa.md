# m7-reward-result-engine - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Milestone 7 backend slice:

```text
m7-reward-result-engine
```

Validate the completed `apps/platform-api` reward/result engine implementation against the Coordinator M7 decision, the Backend Develop task, the Backend Develop handoff, source-of-truth API/contracts, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
ai-agents/handoffs/20260507-m7-reward-result-engine-coordinator-handoff.md
ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

## Objective

Validate the Platform API reward result engine foundation:

```text
reward result recording
prize validation
chunked ticket checking
idempotent winning ticket creation
reward verification/publish/versioning
reward.published.v1 outbox persistence
public result APIs
customer ticket reward status
customer reward claim APIs
tenant admin reward claim management
central admin reward management
tests and Docker validation
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
- ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
- ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
- apps/platform-api/composer.json

## Scope

Validate Backend Develop changes only within approved implementation scope:

```text
apps/platform-api/**
```

Inspect at least the files Backend Develop reported changing:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralRewardController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerRewardController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PublicRewardController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/database/migrations/2026_05_07_000002_create_reward_result_engine_tables.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/tests/Feature/RewardClaimTest.php
apps/platform-api/tests/Feature/RewardEngineTest.php
apps/platform-api/tests/Support/M7RewardFixtures.php
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
```

Validate schema coverage:

```text
reward_results
reward_prizes
reward_check_batches
reward_check_items
winning_tickets
reward_publish_logs
reward_claims
```

Validate approved Platform API endpoint coverage:

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

Validate behavior:

- Central reward APIs require central admin auth and reward permissions.
- Tenant reward claim APIs require tenant admin auth, selected tenant context, and reward claim permissions.
- Customer reward APIs resolve tenant by `Host` and authenticated customer token.
- Public result APIs resolve tenant by `Host`, return only published results, expose cache-friendly `ETag`/`Cache-Control`, and do not run reward matching in request path.
- Reward result create/update/verify/publish/correct are idempotent where `Idempotency-Key` applies.
- Prize input validation and duplicate prize protection exist.
- Reward checking is deterministic, chunk-aware, and processes sold tickets by target game/tenant.
- Retrying reward checking does not duplicate `winning_tickets`, check rows, ledger movements, or publish logs.
- `winning_tickets` uniqueness covers `(game_id, ticket_id, prize_type, prize_number)`.
- Verify requires completed checking and a stable summary.
- Publish requires verified status, writes publish log, sets/increments version, and persists `reward.published.v1` outbox event if current outbox pattern supports it.
- Customer ticket reward status is tenant/customer scoped and does not expose other customer data.
- Customer reward claim create/list/detail is tenant/customer scoped and idempotent.
- Tenant admin reward claim approve/reject/pay is tenant scoped, permission checked, audited, and idempotent where applicable.
- Wallet-credit payout reuses existing wallet ledger behavior safely, while bank/manual payouts remain status/audit records without real bank integration.
- Errors use existing API error envelope patterns and avoid raw exception details.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not implement back-office screens.
- Do not implement real bank transfer integration.
- Do not implement real notification providers.
- Do not implement long-running queue worker daemon infrastructure.
- Do not change checkout, wallet, topup, or ticket purchase behavior beyond validating reward payout integration.
- Do not implement affiliate, commission, reports, settlement, or billing.
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
3. Compare the Backend Develop handoff against the M7 decision and Backend task.
4. Inspect `git status --short` and confirm Backend changed only approved `apps/platform-api/**` plus its handoff.
5. Inspect migration/schema for the required reward/result/check/winning/publish/claim tables, indexes, foreign keys, UUID/string ids, and uniqueness constraints.
6. Inspect route registration for every approved M7 endpoint and the `reward:check` command.
7. Inspect central reward controller/service behavior for create/list/view/update/check-batches/verify/publish/correct.
8. Inspect customer reward controller/service behavior for ticket reward status and reward claim list/create/detail.
9. Inspect tenant reward claim controller/service behavior for list/detail/approve/reject/pay.
10. Inspect public reward controller/service behavior for published-only results, host tenant resolution, ETag/cache headers, and no request-path matching.
11. Inspect permission checks and RBAC/seed behavior for `reward.*` and `reward_claim.*` permissions.
12. Inspect idempotency behavior for central reward writes, customer claim create, and tenant claim approve/reject/pay.
13. Inspect reward check retry behavior and confirm no duplicate `winning_tickets`, check rows, ledger/wallet movements, or publish logs on retry.
14. Inspect publish/version/outbox behavior for `reward.published.v1`.
15. Inspect wallet-credit payout behavior and audit/status handling for bank/manual payout modes.
16. Inspect tests and fixtures for coverage of permissions, tenant isolation, idempotency, check retry, publish/version, public results, customer reward status, and claim lifecycle.
17. Run all required validation commands through Docker only.
18. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md`.
- QA report states whether M7 Reward Result Engine passes, conditionally passes, or fails.
- QA report confirms Docker validation results for migration, Reward tests, full test suite, and `reward:check`.
- QA report confirms no out-of-scope app, customer, back-office, source-of-truth doc, decision, task, handoff, or Board changes were made by QA.
- QA report confirms Backend changes stayed within approved implementation scope or lists scope drift defects.
- QA report confirms migrations run from an empty testing database.
- QA report confirms central admin reward APIs and permission checks.
- QA report confirms reward result validation, idempotency, audit, status transitions, verify/publish/correct flow.
- QA report confirms chunked reward checking and retry idempotency.
- QA report confirms `winning_tickets` uniqueness and no duplicate behavior.
- QA report confirms publish/version/publish-log and `reward.published.v1` outbox behavior.
- QA report confirms public result APIs are published-only, tenant-host scoped, cache-friendly, and do not perform ticket matching.
- QA report confirms customer ticket reward status and reward claim APIs are tenant/customer scoped.
- QA report confirms tenant admin reward claim lifecycle is tenant scoped, permission checked, audited, and idempotent where applicable.
- QA report confirms wallet-credit payout behavior or documents any limitation.
- QA report documents known risks and whether each is acceptable for Coordinator Gate review.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
git diff --stat -- apps/platform-api
rg -n "(reward|Reward|reward_claim|winning_tickets|reward\\.published\\.v1|Idempotency|ETag|Cache-Control|reward:check)" apps/platform-api/app apps/platform-api/routes apps/platform-api/database apps/platform-api/tests
sed -n '1,360p' apps/platform-api/database/migrations/2026_05_07_000002_create_reward_result_engine_tables.php
sed -n '1,760p' apps/platform-api/app/Shared/Reward/RewardService.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralRewardController.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/PublicRewardController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerRewardController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,220p' apps/platform-api/routes/console.php
sed -n '1,760p' apps/platform-api/tests/Feature/RewardEngineTest.php
sed -n '1,760p' apps/platform-api/tests/Feature/RewardClaimTest.php
sed -n '1,520p' apps/platform-api/tests/Support/M7RewardFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
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
idempotency findings
tenant isolation findings
reward checking and retry findings
verify/publish/correct findings
publish version and event/outbox findings
public result cache findings
customer reward status findings
customer reward claim findings
tenant reward claim lifecycle findings
wallet payout/audit findings
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

