# M7 Reward Result Engine QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
ai-agents/tasks/20260507-m7-reward-result-engine-qa.md
ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
```

QA result:

```text
FAIL
```

Docker validation evidence passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Reward: PASS, 3 tests, 117 assertions
docker compose run --rm platform-api php artisan test: PASS, 83 tests, 1257 assertions
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10: PASS
```

QA confirmed broad M7 implementation coverage, including schema, routes, reward checking, public result APIs, central reward APIs, customer reward status/claim APIs, tenant claim APIs, publish logs, and `reward.published.v1` outbox persistence.

QA found three payout validation defects:

```text
D1/P1 - Tenant reward pay accepts unsupported payout methods and still marks claims paid.
D2/P1 - Reward claim payout can post a negative wallet credit.
D3/P2 - Required tenant claim action reasons are not enforced.
```

## Decision

Do not approve M7 yet.

Route a focused Backend Develop revision through Orchestrator to close D1/P1, D2/P1, and D3/P2 before M7 approval. The migration and main test suite are healthy, but reward payout safety and audit validation must be fixed before Gate F can pass.

## Orchestrator Instruction

Create one focused Backend Develop task:

```text
ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Revision Objective

Close the three QA defects blocking M7 approval:

```text
1. Reject unsupported tenant reward claim payout methods before any state mutation.
2. Reject zero or negative approved/paid reward amounts before any state mutation or wallet ledger write.
3. Enforce non-empty reason for tenant reward claim approve, reject, and pay actions.
```

## Approved Scope

Backend Develop may edit only the platform-api reward claim validation and tests needed for these defects:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/tests/Feature/RewardClaimTest.php
apps/platform-api/tests/Feature/RewardEngineTest.php only if needed for shared fixture fallout
apps/platform-api/tests/Support/M7RewardFixtures.php only if needed for test setup
```

## Required Fixes

Payout method validation:

```text
Validate payout_method for tenant claim pay against wallet_credit, bank_transfer, and manual_cash.
Reject unsupported values such as crypto with the existing validation error envelope.
Do not update reward_claims, winning_tickets, tickets, wallet_ledger, or outbox rows when method validation fails.
```

Amount validation:

```text
Validate approved_amount and paid_amount overrides before state mutation.
Reject non-positive amounts.
Ensure wallet_credit ledger writes only positive reward payout credits.
If implementation chooses to cap approved/paid amount at the winning prize amount, document that behavior in the handoff and tests.
Do not create negative ledger credits or mark claims paid when amount validation fails.
```

Reason validation:

```text
Require reason as a non-empty string for approve, reject, and pay.
Return validation error before invoking idempotent write mutation when reason is missing or blank.
Preserve audit/admin_note behavior for valid reasons.
```

Regression tests:

```text
Add tests that invalid payout_method is rejected and does not mark claim paid.
Add tests that negative and zero wallet_credit payout amounts are rejected and do not alter wallet balance.
Add tests that approve/reject/pay require reason.
Keep existing happy path tests passing.
```

## Out Of Scope

```text
Do not rewrite reward engine schema.
Do not change public result APIs unless directly broken by the revision.
Do not change reward checking algorithms.
Do not edit apps/customer.
Do not edit apps/back-office.
Do not implement real bank transfer integration.
Do not implement notification providers.
Do not change docs/openapi.yaml unless Coordinator explicitly approves a contract correction.
```

## Validation Requirements

Backend Develop must run Docker-only validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=RewardClaim
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

Backend Develop must also document evidence that no host PHP/Composer/Artisan commands were run.

## QA Follow-Up Instruction

After Backend Develop handoff, Orchestrator must create a focused QA task for the same payout validation defects. QA should rerun Docker validation and inspect that invalid requests do not mutate claim, ticket, winning ticket, wallet ledger, or outbox state.

## Accepted Non-Blocking Risks

```text
Real async queue worker infrastructure remains out of scope.
Real bank transfer and notification providers remain out of scope.
Advanced Thai lottery prize rules remain a later Coordinator-approved contract clarification if needed.
Public result data is game-level shared result data while tenant Host still controls access/maintenance/cache behavior.
```

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```
