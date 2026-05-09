# m7-reward-claim-payout-validation-revision Backend Handoff

## Agent

Backend Develop

## Task

Close M7 reward claim payout validation defects D1/P1, D2/P1, and D3/P2 only.

## What Was Done

- Added tenant reward claim action payload validation before idempotent write callbacks run.
- Enforced non-empty string `reason` for approve, reject, and pay.
- Enforced tenant claim pay `payout_method` allow-list: `wallet_credit`, `bank_transfer`, `manual_cash`.
- Enforced positive `approved_amount.amount` and `paid_amount.amount` overrides.
- Added defensive service guards so non-positive amounts and unsupported payout methods cannot reach wallet ledger/state mutation paths if an internal caller bypasses controller validation.
- Added regression coverage for invalid payout method, zero/negative approved and paid amounts, missing/blank reasons, mutation safety, and supported `bank_transfer`/`manual_cash` payout behavior.
- Preserved existing happy path wallet-credit payout, idempotency, tenant permission, and tenant scope behavior.

## Files Changed

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/tests/Feature/RewardClaimTest.php
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
```

No `apps/customer`, `apps/back-office`, docs, decisions, tasks, reports, or Board files were edited by this Backend Develop revision.

## API Endpoints Implemented / Updated

Existing endpoints updated with stricter pre-mutation validation:

```text
POST /api/v1/admin/tenant/reward-claims/{claim_id}/approve
POST /api/v1/admin/tenant/reward-claims/{claim_id}/reject
POST /api/v1/admin/tenant/reward-claims/{claim_id}/pay
```

## Permissions / Tenant Checks Enforced

Existing enforcement was preserved:

```text
approve: tenant admin auth + X-Admin-Scope=tenant + X-Tenant-Id + reward_claim.approve
reject: tenant admin auth + X-Admin-Scope=tenant + X-Tenant-Id + reward_claim.reject
pay: tenant admin auth + X-Admin-Scope=tenant + X-Tenant-Id + reward_claim.pay
```

Validation runs only after tenant admin auth/permission resolution and before idempotent write mutation. Service writes still lock/query claims by selected tenant id.

## Validation

All required runtime commands were run through Docker only. No host PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands were run.

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS

docker compose run --rm platform-api php artisan test --filter=RewardClaim
PASS, 6 tests, 281 assertions

docker compose run --rm platform-api php artisan test --filter=Reward
PASS, 7 tests, 321 assertions

docker compose run --rm platform-api php artisan test
PASS, 87 tests, 1461 assertions
```

Note: an interim `RewardClaim` run failed while the new regression test helper used a too-long generated partner id and a JSON assertion path for a dotted field key. The test helper/assertion was corrected, then all required validation commands passed.

## D1/P1 Closure Evidence

- `TenantRewardClaimController::pay()` now validates `payout_method` before calling the idempotent write callback.
- Allowed values are centralized as `RewardService::CLAIM_PAYOUT_METHODS`.
- Unsupported values such as `crypto` return the existing `validation_failed` error envelope with field `payout_method`.
- `RewardService::payTenantClaim()` also rejects unsupported methods before wallet ledger, claim, winning ticket, or ticket mutation.
- Regression test: `test_RewardClaim_pay_rejects_invalid_payout_method_without_mutation`.

## D2/P1 Closure Evidence

- `TenantRewardClaimController::approve()` rejects zero/negative `approved_amount.amount` before idempotent write mutation.
- `TenantRewardClaimController::pay()` rejects zero/negative `paid_amount.amount` before idempotent write mutation.
- `RewardService::approveTenantClaim()` and `RewardService::payTenantClaim()` defensively reject non-positive computed amounts before state updates.
- `wallet_credit` ledger write now remains behind a positive amount guard.
- Regression test: `test_RewardClaim_rejects_non_positive_approved_and_paid_amounts_without_mutation`.
- This revision does not cap positive approved/paid amounts at the winning prize amount; existing positive override behavior is preserved.

## D3/P2 Closure Evidence

- `reason` is now required as a non-empty string for approve, reject, and pay before idempotent write mutation.
- Blank strings such as `"   "` are rejected.
- Valid reasons continue to populate `admin_note` and audit payloads through the existing service behavior.
- Regression test: `test_RewardClaim_approve_reject_and_pay_require_reason`.

## Mutation Safety Evidence

Regression snapshots compare state before and after failed validations and assert no changes to:

```text
reward_claims status/prize_amount/payout_method/payout_ledger_id/paid_at
winning_tickets status
tickets status
wallets balance_amount
wallet_ledger row count
sync_outbox row count
```

Covered failed validation cases:

```text
invalid payout_method
negative approved_amount
zero approved_amount
negative paid_amount
zero paid_amount
missing/blank approve reason
missing/blank reject reason
missing/blank pay reason
```

Supported `bank_transfer` and `manual_cash` pay flows were also verified to remain valid and not create reward-claim wallet ledger rows.

## Known Risks

```text
Real bank transfer integration remains out of scope; bank_transfer/manual_cash still record status/audit only.
Positive approved/paid amount overrides above the winning prize amount remain allowed by the existing implementation because this revision only closes the non-positive amount defect.
Real async reward queue and notification providers remain out of scope.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

Reason:

```text
Orchestrator should create the focused QA follow-up task for D1/P1, D2/P1, and D3/P2 closure verification.
```
