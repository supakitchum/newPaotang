# m7-reward-claim-payout-validation-revision - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

M7 Reward Result Engine is not approved yet. QA reported `FAIL` with three payout validation defects:

```text
D1/P1 - Tenant reward pay accepts unsupported payout methods and still marks claims paid.
D2/P1 - Reward claim payout can post a negative wallet credit.
D3/P2 - Required tenant claim action reasons are not enforced.
```

Create one focused Backend Develop revision to close only these defects.

This task is authorized by:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md
ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md
ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
```

Keep this revision focused. Do not expand into schema rewrites, public result API redesign, reward checking algorithm changes, customer app, back-office, real bank transfer integration, notification providers, or source-of-truth docs.

## Objective

Close the three QA defects blocking M7 approval:

```text
1. Reject unsupported tenant reward claim payout methods before any state mutation.
2. Reject zero or negative approved/paid reward amounts before any state mutation or wallet ledger write.
3. Enforce non-empty reason for tenant reward claim approve, reject, and pay actions.
```

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/status-enums.md
- docs/permissions.md
- docs/events.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
- ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
- ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
- ai-agents/tasks/20260507-m7-reward-result-engine-qa.md
- ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
- ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md
- ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md
- apps/platform-api/composer.json

## Scope

Approved revision scope:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/tests/Feature/RewardClaimTest.php
apps/platform-api/tests/Feature/RewardEngineTest.php only if needed for shared fixture fallout
apps/platform-api/tests/Support/M7RewardFixtures.php only if needed for test setup
```

Required payout method validation fixes:

- Validate `payout_method` for tenant reward claim pay against:
  - `wallet_credit`
  - `bank_transfer`
  - `manual_cash`
- Reject unsupported values such as `crypto` using the existing validation error envelope.
- Validation must happen before any state mutation.
- Failed payout method validation must not update:
  - `reward_claims`
  - `winning_tickets`
  - `tickets`
  - `wallet_ledger`
  - outbox rows

Required amount validation fixes:

- Validate `approved_amount` and `paid_amount` overrides before state mutation.
- Reject zero and negative amounts.
- Ensure `wallet_credit` ledger writes only positive reward payout credits.
- If implementation caps approved/paid amount at the winning prize amount, document that behavior in handoff and tests.
- Failed amount validation must not create negative ledger credits or mark claims paid.

Required reason validation fixes:

- Require `reason` as a non-empty string for approve, reject, and pay.
- Return validation error before invoking idempotent write mutation when reason is missing or blank.
- Preserve audit/admin note behavior for valid reasons.

Required regression tests:

- Invalid `payout_method` is rejected and does not mark claim paid.
- Negative and zero wallet-credit payout amounts are rejected and do not alter wallet balance.
- Approve, reject, and pay require reason.
- Existing happy path tests continue passing.

## Out Of Scope

- Do not rewrite reward engine schema.
- Do not change reward checking algorithms.
- Do not redesign public result APIs.
- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not implement real bank transfer integration.
- Do not implement notification providers.
- Do not change `docs/openapi.yaml`, source-of-truth docs, or `document/**` unless Coordinator explicitly approves a contract correction.
- Do not broaden this revision into unrelated M7 cleanup.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/tests/Feature/RewardClaimTest.php
apps/platform-api/tests/Feature/RewardEngineTest.php
apps/platform-api/tests/Support/M7RewardFixtures.php
```

Only edit `RewardEngineTest.php` or `M7RewardFixtures.php` if needed for shared fixture fallout. Keep changes narrowly scoped.

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

If closing D1/P1, D2/P1, or D3/P2 requires schema rewrites, public result API redesign, source-of-truth contract changes, customer/frontend changes, back-office changes, real bank integration, or notification providers, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read the M7 QA report defects D1/P1, D2/P1, and D3/P2 and the Coordinator QA review decision before editing.
3. Inspect current `TenantRewardClaimController`, `RewardService`, `RewardClaimTest`, and fixtures before editing.
4. Add validation so unsupported tenant reward claim payout methods are rejected before idempotent mutation or state changes.
5. Add validation so zero or negative `approved_amount` and `paid_amount` values are rejected before idempotent mutation or state changes.
6. Ensure wallet-credit payout cannot post a non-positive ledger credit.
7. Add validation so approve, reject, and pay require non-empty `reason` before idempotent mutation.
8. Ensure failed validation does not mutate claim, ticket, winning ticket, wallet ledger, or outbox state.
9. Preserve existing idempotency replay/conflict behavior for valid requests.
10. Preserve valid wallet-credit, bank-transfer, and manual-cash payout behavior.
11. Add focused regression tests for invalid payout method, non-positive amounts, and missing/blank reasons.
12. Keep existing happy path tests passing.
13. Avoid any out-of-scope file changes.
14. Run validation commands through Docker only.
15. Write the required Backend Develop handoff.

## Acceptance Criteria

- D1/P1 is closed: unsupported `payout_method` values are rejected before any state mutation.
- D2/P1 is closed: zero and negative `approved_amount`/`paid_amount` values are rejected before any state mutation or wallet ledger write.
- D3/P2 is closed: approve, reject, and pay require non-empty `reason`.
- Failed validations do not mutate `reward_claims`, `winning_tickets`, `tickets`, `wallet_ledger`, or outbox rows.
- Valid `wallet_credit`, `bank_transfer`, and `manual_cash` flows continue working.
- Existing idempotency behavior for valid requests is preserved.
- Regression tests cover invalid payout method, zero/negative amount, required reasons, and happy path.
- No `apps/customer`, `apps/back-office`, docs, decisions, tasks, reports, or Board changes are made.
- Docker validation passes.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=RewardClaim
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

Backend Develop must also document evidence that:

```text
invalid payout_method is rejected before mutation
non-positive approved/paid amount is rejected before mutation
approve/reject/pay reason is required
failed validations do not mutate claim, ticket, winning ticket, wallet ledger, or outbox state
no host PHP/Composer/Artisan commands were run
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
D1/P1 closure evidence
D2/P1 closure evidence
D3/P2 closure evidence
mutation safety evidence
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: QA should receive a focused follow-up task only after Backend Develop produces a handoff.

