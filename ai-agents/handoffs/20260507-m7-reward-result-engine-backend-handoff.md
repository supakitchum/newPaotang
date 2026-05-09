# m7-reward-result-engine Backend Handoff

## Agent

Backend Develop

## Task

Implement Milestone 7 Reward Result Engine backend slice in `apps/platform-api`.

## What Was Done

- Added reward/result engine schema, reward claim schema, and related indexes/foreign keys.
- Implemented central admin reward result APIs for list/create/view/update/check-batches/verify/publish/correct.
- Implemented deterministic service-driven reward checking over sold tickets in chunks.
- Implemented `reward:check` Artisan command for Docker-testable reward checking.
- Implemented public published result APIs with tenant host resolution, published-only behavior, `ETag`, and `Cache-Control`.
- Implemented customer ticket reward status and reward claim list/create/detail APIs under customer host/session tenant scope.
- Implemented tenant admin reward claim list/detail/approve/reject/pay APIs with permission checks, idempotency, audit, and wallet-credit payout through existing wallet ledger behavior.
- Persisted `reward.published.v1` outbox events on publish.
- Added focused Reward feature tests and fixture helpers.

## Files Changed

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

## Schema / Migrations Added

```text
reward_results
reward_prizes
reward_check_batches
reward_check_items
winning_tickets
reward_publish_logs
reward_claims
```

`reward_claims` was added because `docs/openapi.yaml` includes reward claim APIs but `docs/erd.md` did not define a claim table. Shape includes tenant/customer/ticket/winning-ticket ownership, payout method, wallet/ledger link, status, audit timestamps, bank-account placeholder JSON, idempotency key/hash, and admin review/pay actors.

## Endpoint Coverage

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

## Permission Coverage

```text
central reward list/view: reward.view
central reward create/update: reward.create
central reward check batches: reward.audit
central reward verify: reward.verify
central reward publish: reward.publish
central reward correct: reward.correct
tenant claim list/detail: reward_claim.view
tenant claim approve: reward_claim.approve
tenant claim reject: reward_claim.reject
tenant claim pay: reward_claim.pay
```

Admin endpoints continue to require `admin.auth` plus `admin.scope:central` or `admin.scope:tenant`.

## Idempotency Behavior

```text
central reward create/update/verify/publish/correct use Idempotency-Key through IdempotencyService
customer reward claim create uses tenant_id + customer_id + route key + Idempotency-Key
tenant reward claim approve/reject/pay use tenant_id + admin_id + route key + Idempotency-Key
same key + same payload replays stored response
same key + different payload returns idempotency_conflict
```

## Tenant Isolation Behavior

```text
public result APIs resolve tenant by Host and return only published result data
customer reward APIs use customer.auth host/session tenant guard and re-check Host tenant context in controller
customer ticket reward status queries by tenant_id + customer_id + ticket_id
customer claim list/detail/create queries by tenant_id + customer_id
tenant admin claim APIs query only selected X-Tenant-Id from the active tenant admin session
```

No `apps/customer` or `apps/back-office` files were changed by this Backend task.

## Reward Check Retry Behavior

Reward checks are deterministic and chunk-aware through `RewardService::processRewardCheck()` and `php artisan reward:check`.

```text
checks process tickets for the target game only
check batches/items store chunk progress
winning_tickets uses unique(game_id, ticket_id, prize_type, prize_number)
retrying a recorded/checking result rebuilds check rows and does not duplicate winning_tickets
public result requests never run ticket matching
```

## Publish / Version / Event Behavior

```text
verify requires completed reward checking and summary_ready status
publish requires verified status
publish sets/keeps reward version, writes reward_publish_logs, updates game status to reward_published, and persists reward.published.v1 in sync_outbox with producer reward_engine
correct creates an audited corrected status for published/verified result records
```

## Public Cache Behavior

```text
GET /public/results/latest and /public/results/{game_id} return published results only
responses include ETag: "reward-<game_id>-v<version>"
responses include Cache-Control: public, max-age=60
unknown/unpublished result returns existing resource_not_found error envelope
tenant maintenance uses existing maintenance_active response behavior
```

## Claim Lifecycle Behavior

```text
customer claim creation requires a published winning ticket owned by the authenticated tenant customer
submitted claims block duplicate claims for the same winning_ticket_id
tenant admin approve moves submitted/under_review to approved
tenant admin reject moves submitted/under_review/approved to rejected
tenant admin pay moves approved to paid
wallet_credit pay posts a wallet_ledger credit and writes wallet.updated.v1 outbox
paid claims update winning_tickets.status to paid and tickets.status to paid_out
bank_transfer/manual_cash remain status/audit records without real bank integration
```

## Validation

All commands were run through Docker only.

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Reward: PASS, 3 tests, 117 assertions
docker compose run --rm platform-api php artisan test: PASS, 83 tests, 1257 assertions
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10: PASS, Processed reward tickets: 0
```

## Known Risks

```text
Real async queue daemon infrastructure is still out of scope; reward checking is service/command-driven and Docker-testable.
Real bank transfer and notification provider integrations are not implemented; bank/manual payouts are recorded as status/audit only.
Reward prize matching supports exact full-number matching plus prize_type names containing front3/back3/back2 for positional matches. More advanced lottery prize rules need a Coordinator-approved contract if required.
Public caching starts with deterministic ETag/Cache-Control headers, not a distributed cache invalidation layer.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

Reason:

```text
QA should receive a task only after Backend Develop produces a handoff.
```
