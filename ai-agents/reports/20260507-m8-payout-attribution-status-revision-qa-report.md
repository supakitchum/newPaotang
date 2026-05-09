# M8 Payout Attribution Status Revision QA Report

Date: 2026-05-07 18:02:21 +07
QA: Codex QA Tester
Result: PASS
Recommended next agent: Coordinator

## Summary

Focused QA validates that the M8 D1/D2 revision closes both previously blocking defects:

- Unsupported affiliate payout methods now return `validation_failed` before payout, audit, or idempotency-success mutation.
- Affiliate attribution status behavior now aligns with `docs/status-enums.md`: new attributions default to `pending`, `pending` is commission-eligible, successful commission calculation converts the attribution, and `expired`/`cancelled` are skipped.

No new defects were found in this focused revision.

## Scope Reviewed

- `ai-agents/tasks/20260507-m8-payout-attribution-status-revision-qa.md`
- `ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md`
- `ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md`
- `ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-qa-task-orchestrator-handoff.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md`
- `ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/status-enums.md`
- Relevant OpenAPI/API convention references for payout/idempotency validation behavior.

## Files Inspected

- `apps/platform-api/app/Shared/Growth/GrowthService.php`
- `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php`
- `apps/platform-api/tests/Feature/AffiliateTest.php`
- `apps/platform-api/tests/Feature/CommissionTest.php`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/app/Modules/**` via `rg` for checkout separation evidence.

## Scope Drift

Backend reported only the approved focused files plus its handoff. Because `apps/platform-api/**` is untracked as a larger workspace unit in this multi-agent branch, `git status --short` cannot produce a normal tracked diff for those individual files, but the focused files inspected match the approved revision list. QA did not modify app code, docs, decisions, tasks, handoffs, or Board; QA only added this report under `ai-agents/reports/**`.

## Payout Validation

PASS.

- `createPayout()` keeps the submitted `payout_method` and checks it against `PAYOUT_METHODS`.
- Unsupported values such as `crypto` return `validation_failed`.
- Validation happens before `tenantIdempotentWrite()`, so invalid payout methods do not create payout rows, audit rows, or idempotency success responses.
- `AffiliateTest` covers invalid method no-mutation and valid `bank_transfer` create/approve behavior.
- Supported methods remain `bank_transfer`, `manual_cash`, and `wallet_credit`.

Evidence:

- `apps/platform-api/app/Shared/Growth/GrowthService.php:841-865`
- `apps/platform-api/tests/Feature/AffiliateTest.php:82-117`

## Attribution Status

PASS.

- `affiliate_attributions.status` migration default is `pending`, matching `docs/status-enums.md`.
- M8 fixtures seed attribution rows as `pending`.
- Commission calculation selects pending attributions by order id or customer id.
- Successful calculation updates the selected attribution to `converted`, sets `order_id`, and sets `converted_at`.
- `expired` and `cancelled` attribution rows are skipped and remain unchanged.

Evidence:

- `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php:115-124`
- `apps/platform-api/app/Shared/Growth/GrowthService.php:1263-1278`
- `apps/platform-api/app/Shared/Growth/GrowthService.php:1381-1386`
- `apps/platform-api/tests/Feature/CommissionTest.php:23-46`
- `apps/platform-api/tests/Feature/CommissionTest.php:104-127`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php:243-257`

## Checkout Separation

PASS. `rg` found commission calculation only in `GrowthService` and `routes/console.php`; no checkout controller/module path introduces inline commission calculation.

## Test Coverage

PASS. The revised tests now cover:

- unsupported payout method rejection and no mutation
- valid payout creation/approval
- pending attribution pickup and conversion
- expired/cancelled attribution skip behavior
- existing commission idempotency, outbox, reversal, and report regressions

## Docker Validation

All required validation commands were run through Docker only.

```text
PASS docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS docker compose run --rm platform-api php artisan test --filter=Affiliate
     Tests: 1 passed (22 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Commission
     Tests: 3 passed (24 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Report
     Tests: 3 passed (31 assertions)
PASS docker compose run --rm platform-api php artisan test
     Tests: 94 passed (1565 assertions)
PASS docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
     Calculated commission transactions: 0
```

## Known Risks / Coordinator Questions

- Existing broad M8 non-blocking risks remain: placeholder export URLs, no real external payout provider integration, and future customer/browser affiliate attribution work.
- Internal `commission_transactions.status = calculated` remains a previously accepted Coordinator caveat unless a later contract task changes it.
- No new Coordinator questions.

## Recommendation

Approve the focused D1/D2 revision and return to Coordinator Gate review for M8 approval.

## Next Agent

Coordinator
