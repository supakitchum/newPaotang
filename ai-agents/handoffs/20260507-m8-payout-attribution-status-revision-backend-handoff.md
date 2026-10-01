# 20260507-m8-payout-attribution-status-revision Handoff

## Agent

Backend Develop

## Task

Close the focused M8 QA defects:

- D1/P2: unsupported affiliate payout methods were silently coerced to `bank_transfer`.
- D2/P2: documented `pending` affiliate attributions were ignored by commission calculation.

## What Was Done

- Updated affiliate payout creation so `payout_method` is validated against the supported allow-list before any idempotency write, payout row insert, or audit log.
- Changed `affiliate_attributions.status` migration default from undocumented `active` to documented `pending`.
- Updated commission calculation to select only eligible `pending` attributions for paid orders.
- Kept successful commission calculation transition behavior: eligible attributions become `converted`, set `order_id`, and set `converted_at`.
- Added regression coverage for invalid payout method no-mutation behavior, valid payout method behavior, pending attribution conversion, and expired/cancelled attribution skipping.

## Files Changed

- `apps/platform-api/app/Shared/Growth/GrowthService.php`
- `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php`
- `apps/platform-api/tests/Feature/AffiliateTest.php`
- `apps/platform-api/tests/Feature/CommissionTest.php`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php`

## Validation

All validation was run through Docker only:

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

No host PHP, Composer, or Artisan commands were run. File inspection/editing used shell read commands and `apply_patch`; all Laravel runtime/test/migration/command execution used `docker compose run --rm platform-api ...`.

## Invalid Payout Method Rejection Behavior

- `createPayout()` now preserves the requested `payout_method` and rejects unsupported values, for example `crypto`, with the existing `validation_failed` envelope.
- Rejection happens before `tenantIdempotentWrite()`, so invalid requests do not create:
  - `affiliate_payouts`
  - `audit_logs`
  - idempotency success response rows in `idempotency_keys`
- `AffiliateTest` asserts the invalid method response and missing mutation rows.

## Valid Payout Method Behavior

- Supported methods remain `bank_transfer`, `manual_cash`, and `wallet_credit`.
- Existing valid `bank_transfer` payout create/approve behavior still passes and remains audited/redacted.

## Affiliate Attribution Status Values

- `affiliate_attributions.status` migration default is now `pending`.
- M8 fixtures and tests now seed new affiliate attribution records as `pending`.
- Documented status set remains aligned with `docs/status-enums.md`: `pending`, `converted`, `expired`, `cancelled`.

## Pending Attribution Commission Behavior

- `commission:calculate` / `GrowthService::calculateCommissions()` now searches paid-order attributions with `status = pending`.
- On successful commission creation, the selected attribution is updated to:
  - `status = converted`
  - `order_id = <paid order id>`
  - `converted_at = now()`
- `CommissionTest` asserts pending attribution is picked up, a commission transaction/outbox event is created, and attribution becomes converted.

## Expired/Cancelled Attribution Skip Behavior

- Commission calculation no longer depends on undocumented `active` and only selects `pending`; therefore `expired` and `cancelled` attributions are skipped.
- `CommissionTest` covers both `expired` and `cancelled` and asserts no commission transaction is created and attribution status remains unchanged.

## Known Risks

- This revision intentionally does not change internal `commission_transactions.status = calculated`; Coordinator marked that as non-blocking unless it breaks documented API behavior.
- Real external payout provider integration and real export file generation remain out of scope.
- Existing records created before this migration correction with `affiliate_attributions.status = active` are not migrated because this project is still using fresh migrations in the current milestone flow.

## Questions For Coordinator

None.

## Next Agent

Orchestrator
