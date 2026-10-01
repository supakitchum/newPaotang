# m7-reward-claim-payout-validation-revision - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused M7 payout validation revision for:

```text
D1/P1 - Tenant reward pay accepts unsupported payout methods and still marks claims paid.
D2/P1 - Reward claim payout can post a negative wallet credit.
D3/P2 - Required tenant claim action reasons are not enforced.
```

Validate the revision against the Coordinator QA review decision, the focused Backend Develop revision task, the Backend Develop handoff, the original M7 QA report, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md
ai-agents/handoffs/20260507-m7-reward-result-engine-qa-review-coordinator-handoff.md
ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
```

## Objective

Validate that Backend Develop closed D1/P1, D2/P1, and D3/P2 without expanding scope:

```text
1. Unsupported tenant reward claim payout methods are rejected before mutation.
2. Zero or negative approved/paid reward amounts are rejected before mutation or wallet ledger write.
3. Tenant reward claim approve, reject, and pay require non-empty reason.
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
- ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
- ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
- apps/platform-api/composer.json

## Scope

Validate only the focused D1/P1, D2/P1, and D3/P2 revision.

Inspect the approved revision files and related evidence:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/tests/Feature/RewardClaimTest.php
apps/platform-api/tests/Feature/RewardEngineTest.php only if touched or relevant to shared fixture fallout
apps/platform-api/tests/Support/M7RewardFixtures.php only if touched or relevant to test setup
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
```

Validate D1/P1 closure:

- Tenant claim `pay` validates `payout_method` before idempotent write mutation.
- Allowed payout methods are exactly `wallet_credit`, `bank_transfer`, and `manual_cash`.
- Unsupported values such as `crypto` return the existing validation error envelope.
- Failed payout method validation does not mutate `reward_claims`, `winning_tickets`, `tickets`, `wallet_ledger`, or outbox rows.

Validate D2/P1 closure:

- `approved_amount.amount` and `paid_amount.amount` overrides are validated before idempotent write mutation.
- Zero and negative amounts are rejected.
- Wallet-credit payout cannot post a non-positive ledger credit.
- Failed amount validation does not mark claims paid and does not mutate wallet balance or ledger rows.
- If positive overrides above prize amount remain allowed, document that this matches Backend handoff and is outside the current defect scope.

Validate D3/P2 closure:

- Approve, reject, and pay require `reason` as a non-empty string.
- Missing and blank reasons return validation error before idempotent write mutation.
- Valid reasons still populate `admin_note`/audit behavior.

Validate regression coverage:

- Invalid payout method rejected without mutation.
- Zero/negative approved and paid amounts rejected without mutation.
- Approve/reject/pay missing or blank reason rejected.
- Supported `wallet_credit`, `bank_transfer`, and `manual_cash` flows remain valid.
- Existing idempotency replay/conflict behavior remains intact for valid requests.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not re-test or redesign the full M7 reward engine beyond evidence needed for D1/P1, D2/P1, and D3/P2 closure.
- Do not rewrite reward engine schema.
- Do not change reward checking algorithms.
- Do not redesign public result APIs.
- Do not implement real bank transfer integration.
- Do not implement notification providers.

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

If a defect requires code or contract changes, record it in the QA report with severity, evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend revision handoff against the focused revision task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm whether the revision changed only approved files plus the Backend handoff.
5. Inspect `TenantRewardClaimController` to verify pre-mutation validation for payout method, non-positive amounts, and reason.
6. Inspect `RewardService` to verify defensive guards before wallet ledger, claim, winning ticket, ticket, and outbox mutation paths.
7. Inspect `RewardClaimTest` and fixtures for regression coverage of invalid payout method, non-positive amounts, required reasons, mutation safety, and supported payout methods.
8. Verify failed validations happen before idempotent write mutation and do not store idempotent success responses.
9. Verify failed validations do not mutate claim, ticket, winning ticket, wallet ledger, wallet balance, or outbox state.
10. Verify valid `wallet_credit`, `bank_transfer`, and `manual_cash` pay flows remain valid.
11. Verify existing happy path and idempotency behavior still pass.
12. Run all required validation commands through Docker only.
13. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m7-reward-claim-payout-validation-revision-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report verifies D1/P1 is closed or identifies why it remains open.
- QA report verifies D2/P1 is closed or identifies why it remains open.
- QA report verifies D3/P2 is closed or identifies why it remains open.
- QA report confirms Docker validation results for migration, `RewardClaim`, `Reward`, and full test suite.
- QA report confirms no out-of-scope app, customer, back-office, source-of-truth doc, decision, task, handoff, or Board changes were made by QA.
- QA report confirms Backend changes stayed within approved focused revision scope or lists scope drift defects.
- QA report confirms unsupported payout method is rejected before mutation.
- QA report confirms zero/negative approved or paid amount is rejected before mutation and before wallet ledger write.
- QA report confirms approve/reject/pay require non-empty reason.
- QA report confirms failed validations do not mutate `reward_claims`, `winning_tickets`, `tickets`, `wallet_ledger`, wallet balance, or outbox rows.
- QA report confirms valid supported payout methods and existing happy paths remain intact.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=RewardClaim
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
git diff --stat -- apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php apps/platform-api/app/Shared/Reward/RewardService.php apps/platform-api/tests/Feature/RewardClaimTest.php apps/platform-api/tests/Feature/RewardEngineTest.php apps/platform-api/tests/Support/M7RewardFixtures.php
rg -n "(payout_method|CLAIM_PAYOUT_METHODS|approved_amount|paid_amount|reason|validation_failed|wallet_ledger|sync_outbox|without_mutation|non_positive|blank)" apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php apps/platform-api/app/Shared/Reward/RewardService.php apps/platform-api/tests/Feature/RewardClaimTest.php apps/platform-api/tests/Support/M7RewardFixtures.php
sed -n '1,220p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
sed -n '1,860p' apps/platform-api/app/Shared/Reward/RewardService.php
sed -n '1,900p' apps/platform-api/tests/Feature/RewardClaimTest.php
sed -n '1,560p' apps/platform-api/tests/Support/M7RewardFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m7-reward-claim-payout-validation-revision-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
D1/P1 closure assessment
D2/P1 closure assessment
D3/P2 closure assessment
pre-mutation validation findings
mutation safety findings
idempotency regression findings
supported payout method regression findings
test coverage findings
scope drift findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

