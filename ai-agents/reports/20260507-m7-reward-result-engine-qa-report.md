# QA Report: M7 Reward Result Engine

## Task

`20260507-m7-reward-result-engine-qa`

## Scope Tested

Validated the Backend Develop M7 reward/result engine implementation in `apps/platform-api/**` against:

- `ai-agents/decisions/20260507-m7-reward-result-engine-decision.md`
- `ai-agents/tasks/20260507-m7-reward-result-engine-backend.md`
- `ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/docker-runtime-policy.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/permissions.md`
- `docs/frontend-routes.md`
- `docs/customer-api-integration-map.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `apps/platform-api/composer.json`

Inspected the reported Backend Develop files:

- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralRewardController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerRewardController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/PublicRewardController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php`
- `apps/platform-api/app/Shared/Reward/RewardService.php`
- `apps/platform-api/database/migrations/2026_05_07_000002_create_reward_result_engine_tables.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/tests/Feature/RewardClaimTest.php`
- `apps/platform-api/tests/Feature/RewardEngineTest.php`
- `apps/platform-api/tests/Support/M7RewardFixtures.php`

## Commands Run

All runtime validation commands were run through Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10
```

Read-only evidence commands included `git status --short`, `git diff --stat -- apps/platform-api`, `rg`, `sed`, `nl -ba`, and `cat`.

## Test Results

Result: FAIL

Docker validation results:

- `migrate:fresh --seed --env=testing`: PASS. Migrations ran from an empty testing database and seeded RBAC defaults.
- `php artisan test --filter=Reward`: PASS, 3 tests, 117 assertions.
- `php artisan test`: PASS, 83 tests, 1257 assertions.
- `php artisan reward:check --env=testing --chunk=10`: PASS, `Processed reward tickets: 0`.

Implemented coverage confirmed:

- Required M7 routes are registered.
- `reward:check` command is registered.
- Migration adds `reward_results`, `reward_prizes`, `reward_check_batches`, `reward_check_items`, `winning_tickets`, `reward_publish_logs`, and `reward_claims`.
- `winning_tickets` has the required uniqueness on `(game_id, ticket_id, prize_type, prize_number)`.
- Central reward APIs enforce central admin scope plus `reward.*` permission checks in controller/service paths.
- Tenant reward claim APIs enforce tenant admin scope plus `reward_claim.*` permission checks in controller/service paths.
- Customer reward APIs use customer auth, Host tenant resolution, and tenant/customer scoped ticket and claim queries.
- Public result APIs resolve tenant Host, return published-only results, set `ETag` and `Cache-Control`, and do not perform ticket matching in request path.
- Reward check is command/service-driven, chunk-aware, and uses deterministic `updateOrInsert` for winning tickets.
- Publish writes `reward_publish_logs` and persists `reward.published.v1` in `sync_outbox`.
- Reward-focused tests cover central record/check/verify/publish/correct, public results, customer reward status, customer claim creation, tenant approve/pay, wallet ledger credit, and selected cross-tenant rejection.

## Defects

### D1/P1: Tenant reward pay accepts unsupported payout methods and still marks claims paid

`PayRewardClaimRequest` restricts `payout_method` to `wallet_credit`, `bank_transfer`, or `manual_cash`, and the task requires tenant claim pay to be permission checked, audited, and safe. `RewardService::payTenantClaim()` reads any submitted `payout_method`, only posts a ledger for `wallet_credit`, and then updates the claim to `paid`, updates the winning ticket to `paid`, and updates the ticket to `paid_out` regardless of whether the method is supported. A request such as `{"payout_method":"crypto","reason":"..."}` can therefore close a claim as paid without a wallet ledger or recognized bank/manual payout path.

Evidence:

- `docs/openapi.yaml:8347-8354`
- `apps/platform-api/app/Shared/Reward/RewardService.php:738-760`
- `apps/platform-api/tests/Feature/RewardClaimTest.php` covers a valid `wallet_credit` pay path but does not cover invalid `payout_method` rejection.

Recommended owner: Backend Develop.

Recommended fix: validate `payout_method` against `wallet_credit`, `bank_transfer`, and `manual_cash` before mutating claim/ticket state; return the existing validation error envelope for invalid methods.

### D2/P1: Reward claim payout can post a negative wallet credit

`RewardService::approveTenantClaim()` and `payTenantClaim()` accept `approved_amount`/`paid_amount` through `moneyAmount()` without validating that the amount is positive. For `wallet_credit`, `payTenantClaim()` passes that amount to `CommerceService::postLedger()` as a credit, and `postLedger()` uses the amount as-is for credit entries. A negative `paid_amount` therefore creates a negative credit ledger, reduces the customer wallet balance, and still marks the claim, winning ticket, and ticket as paid.

Evidence:

- `apps/platform-api/app/Shared/Reward/RewardService.php:681`
- `apps/platform-api/app/Shared/Reward/RewardService.php:738-760`
- `apps/platform-api/app/Shared/Commerce/CommerceService.php:1255-1268`
- `apps/platform-api/tests/Feature/RewardClaimTest.php` does not cover zero/negative `approved_amount` or `paid_amount`.

Recommended owner: Backend Develop.

Recommended fix: validate override amounts before mutation. At minimum reject non-positive amounts and ensure wallet-credit ledger posts only positive reward payouts. Consider whether over-approval/over-payment above winning prize amount is allowed; if not, reject it too.

### D3/P2: Required tenant claim action reasons are not enforced

OpenAPI requires `reason` for tenant claim approve, reject, and pay requests. The controller only validates `Idempotency-Key`, and the service stores `admin_note` as `null` when `reason` is missing. This weakens the required audit trail for reward payout decisions and allows audited state transitions without the contract-required reason.

Evidence:

- `docs/openapi.yaml:8325-8354`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php:47-77`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php:98-106`
- `apps/platform-api/app/Shared/Reward/RewardService.php:688`
- `apps/platform-api/app/Shared/Reward/RewardService.php:715`
- `apps/platform-api/app/Shared/Reward/RewardService.php:756`

Recommended owner: Backend Develop.

Recommended fix: validate `reason` as a required non-empty string for approve/reject/pay before invoking the write mutation and idempotency storage.

## Risks / Not Tested

- Real async queue worker infrastructure remains out of scope; QA validated the service/command-driven `reward:check` path.
- Real bank transfer and notification providers remain out of scope; bank/manual payouts are expected to be status/audit records only.
- Advanced Thai lottery prize rules beyond exact full-number and front3/back3/back2 style matching remain a Coordinator-approved contract clarification risk.
- Public result APIs resolve Host for tenant/domain/maintenance checks, but public reward result data is game-level rather than tenant-specific. QA did not mark this as a blocker because the M7 implementation treats reward results as central game results shared by tenants.
- Workspace contains many pre-existing dirty/untracked files from the multi-agent workflow. QA did not revert or edit unrelated files.
- QA did not edit `apps/platform-api/**`, `apps/customer/**`, `apps/back-office/**`, docs, decisions, tasks, handoffs, or Board. QA only wrote this report.

## Recommendation

Route a focused Backend Develop revision before Coordinator approval. The migration and automated test validation pass, but M7 should not pass Gate review while tenant reward pay can mark claims paid with unsupported payout methods or negative wallet-credit amounts.

## Next Agent

Coordinator
