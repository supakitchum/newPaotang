# M7 Reward Result Engine Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m7-reward-result-engine-decision.md
ai-agents/tasks/20260507-m7-reward-result-engine-backend.md
ai-agents/handoffs/20260507-m7-reward-result-engine-backend-handoff.md
ai-agents/tasks/20260507-m7-reward-result-engine-qa.md
ai-agents/reports/20260507-m7-reward-result-engine-qa-report.md
ai-agents/decisions/20260507-m7-reward-result-engine-qa-review-decision.md
ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-backend.md
ai-agents/handoffs/20260507-m7-reward-claim-payout-validation-revision-backend-handoff.md
ai-agents/tasks/20260507-m7-reward-claim-payout-validation-revision-qa.md
ai-agents/reports/20260507-m7-reward-claim-payout-validation-revision-qa-report.md
```

Initial M7 QA result:

```text
FAIL
```

Coordinator requested a focused Backend Develop revision for:

```text
D1/P1 - Tenant reward pay accepts unsupported payout methods and still marks claims paid.
D2/P1 - Reward claim payout can post a negative wallet credit.
D3/P2 - Required tenant claim action reasons are not enforced.
```

Focused revision QA result:

```text
PASS
```

Focused Docker validation evidence:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=RewardClaim: PASS, 6 tests, 281 assertions
docker compose run --rm platform-api php artisan test --filter=Reward: PASS, 7 tests, 321 assertions
docker compose run --rm platform-api php artisan test: PASS, 87 tests, 1461 assertions
```

## Decision

Approve M7 Reward Result Engine.

The focused revision closed all blocking payout validation defects. Unsupported payout methods are rejected before mutation, zero/negative approved or paid amounts are rejected before mutation or wallet ledger write, and approve/reject/pay require non-empty reasons.

## Approved Backend Scope

```text
reward result schema and migrations
reward result/prize service layer
reward checking command/service path
chunked sold-ticket checking by game/tenant
idempotent winning_tickets creation
central reward admin APIs
reward verify/publish/correct flow
reward_publish_logs
reward.published.v1 outbox persistence
public published result APIs with ETag/Cache-Control
customer ticket reward status API
customer reward claim list/create/detail APIs
tenant reward claim list/detail/approve/reject/pay APIs
wallet-credit reward payout through existing wallet ledger behavior
bank_transfer/manual_cash status and audit record behavior
focused Reward and RewardClaim regression tests
```

## Approved Endpoint Coverage

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

## Approved Behavior

```text
Migrations run from an empty testing database.
Central reward APIs require central admin auth and reward permissions.
Tenant reward claim APIs require tenant admin auth, selected tenant context, and reward_claim permissions.
Customer reward APIs resolve tenant by Host and authenticated customer token.
Public result APIs resolve tenant by Host, return only published results, expose cache-friendly headers, and do not run matching in request path.
Reward result writes are idempotent where Idempotency-Key applies.
Reward checking is service/command-driven, deterministic, chunk-aware, and does not duplicate winning_tickets on retry.
winning_tickets uniqueness covers game_id, ticket_id, prize_type, and prize_number.
Verify requires completed checking and stable summary.
Publish requires verified status, writes publish log, sets reward version, updates game reward state, and persists reward.published.v1 in sync_outbox.
Customer ticket reward status is tenant/customer scoped.
Customer reward claims are tenant/customer scoped and idempotent.
Tenant claim approve/reject/pay are tenant scoped, permission checked, audited, idempotent, and reason-required after focused revision.
Unsupported payout methods are rejected before state mutation.
Zero or negative approved/paid amounts are rejected before state mutation or wallet ledger write.
Valid wallet_credit payout posts a positive reward-claim wallet ledger credit.
Valid bank_transfer and manual_cash payouts remain status/audit records without wallet ledger rows.
```

## Accepted Residual Risks

These are accepted as non-blocking for M7 and should be handled in later slices or Coordinator contract clarification:

```text
Positive approved/paid amount overrides above the winning prize amount remain allowed by the current implementation.
Real bank transfer integration remains out of scope.
Real async queue worker daemon infrastructure remains out of scope; reward checking is service/command-driven.
Real notification providers remain out of scope.
Advanced Thai lottery prize rules beyond current exact/front/back matching remain a later contract clarification if needed.
Public reward result data is game-level shared data while tenant Host still controls access, maintenance, and cache behavior.
Back-office UI is not part of M7 approval; M7 only approves backend APIs/foundation for later UI work.
```

## Still Out Of Scope

```text
apps/customer changes
apps/back-office changes
back-office screens
affiliate, agent, commission, reports, settlement, and billing
real bank transfer provider integration
real notification provider integration
long-running queue daemon operations
Laravel/PHP dependency upgrades
```

## Reason

M7 provides the reward/result backend foundation required after checkout and sold ticket creation. The first QA run found payout safety defects in tenant reward claim payment. The focused revision closed those defects, added mutation-safety regression tests, and QA confirmed all required Docker validation commands pass.

## Impact

Gate F reward checking and publish foundation is now approved:

```text
reward results can be recorded and audited
reward checking processes sold tickets by game/tenant chunks
retry does not duplicate winning tickets
publish requires verified summary and writes publish/version/event state
public result endpoints are cache-friendly
customer reward status and reward claim foundation exists
tenant claim approve/reject/pay foundation exists with payout validation
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Coordinator
```
