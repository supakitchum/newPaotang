# M8 Affiliate Agent Reports Settlement QA Report

Date: 2026-05-07 17:42:06 +07
QA: Codex QA Tester
Result: FAIL
Recommended next agent: Backend

## Scope Reviewed

- QA task: `ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-qa.md`
- Decision: `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md`
- Backend handoff: `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md`
- Orchestrator QA handoff: `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-task-orchestrator-handoff.md`
- Implementation focus:
  - `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php`
  - `apps/platform-api/app/Shared/Growth/GrowthService.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantGrowthController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/ReportController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralSettlementController.php`
  - `apps/platform-api/routes/api.php`
  - `apps/platform-api/routes/console.php`
  - `apps/platform-api/config/platform.php`
  - M8 tests and fixtures under `apps/platform-api/tests`

## Findings

### D1 [P2] Payout create accepts unsupported payout methods by silently coercing them

`GrowthService::createPayout()` normalizes any unsupported `payout_method` to `bank_transfer` instead of returning validation failure. The M8 decision and QA acceptance require payout creation to validate supported payout methods. With the current code, a typo or unsupported external method is persisted and audited as a bank-transfer payout, which can misroute downstream payout processing once real payout execution is connected.

Evidence:
- `apps/platform-api/app/Shared/Growth/GrowthService.php:841-846`
- Acceptance reference: `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md` requires supported payout method validation.

### D2 [P2] Documented pending affiliate attributions are ignored by commission calculation

`docs/status-enums.md` defines `affiliate_attributions.status` as `pending`, `converted`, `expired`, and `cancelled`, but the M8 schema defaults attributions to `active` and commission calculation only searches customer attributions with `status = active`. If an attribution producer follows the documented enum and writes `pending`, `commission:calculate` will skip the attribution and create no commission for the paid order.

Evidence:
- `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php:115-124`
- `apps/platform-api/app/Shared/Growth/GrowthService.php:1264-1269`
- `docs/status-enums.md:273-280`

## Coverage Assessment

- Schema: M8 tables exist for agents, quotas, affiliate accounts/programs/links/attributions, commission rules/transactions, payouts, report export jobs, and settlements.
- Endpoint coverage: Tenant M8 routes and central report/settlement routes are registered and controller-backed.
- Auth/RBAC: Tenant endpoints require tenant admin scope and permission checks; central endpoints require central scope and central permissions.
- Tenant isolation: Main list/detail/write queries filter selected tenant for tenant endpoints. Central report/settlement endpoints intentionally operate centrally.
- Idempotency: Tenant and central write helpers validate `Idempotency-Key`; focused tests cover replay behavior on main flows.
- Agent/quota: Agent create/list/quota flows are covered and tenant-scoped.
- Affiliate: Account/program/link/attribution list flows are covered; archived link/program/rule exclusion is covered at least for commission rules.
- Commission/reversal/outbox: Commission calculation is command/service driven, retry-safe for duplicate commission rows, creates reversal rows instead of deleting, and persists `commission.calculated.v1` to `sync_outbox`.
- Checkout separation: No commission calculation was found in checkout controller flow; calculation is routed through `GrowthService` and `commission:calculate`.
- Payouts: Positive amount and pending-to-approved transition are implemented, but unsupported payout methods are not rejected.
- Reports/export: Tenant and central report/export job flows are covered; export files are placeholder signed URLs as acknowledged in the handoff.
- Settlement: Settlement summary refresh/list/detail/approval is covered, central-only, idempotent, and audited.
- Audit redaction: Bank/account sensitive keys are configured and the payout audit test confirms redaction.
- Status enum drift: `affiliate_attributions.status = active` is not aligned with `docs/status-enums.md`; `commission_transactions.status = calculated` is documented as an internal M8 state in the backend handoff but remains a Coordinator review caveat because the main docs list `pending`.
- Worktree scope: The repository is heavily dirty/untracked from the broader multi-agent workflow. The M8 implementation files reviewed are within the approved `apps/platform-api/**` scope plus M8 handoffs/tasks; unrelated dirty files were not modified by QA.

## Docker Validation

All required Docker validation commands completed.

```text
PASS docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS docker compose run --rm platform-api php artisan test --filter=Affiliate
     Tests: 1 passed (16 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Agent
     Tests: 1 passed (16 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Commission
     Tests: 2 passed (16 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Report
     Tests: 3 passed (31 assertions)
PASS docker compose run --rm platform-api php artisan test --filter=Settlement
     Tests: 1 passed (17 assertions)
PASS docker compose run --rm platform-api php artisan test
     Tests: 93 passed (1551 assertions)
PASS docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
     Calculated commission transactions: 0
```

## Recommendation

Do not pass Coordinator Gate yet. Send back to Backend to reject unsupported payout methods with validation errors and align affiliate attribution statuses with the documented enum, or update the accepted status contract explicitly before approval.
