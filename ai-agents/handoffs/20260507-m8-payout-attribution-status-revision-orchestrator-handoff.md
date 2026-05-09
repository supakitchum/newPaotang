# 20260507 M8 Payout Attribution Status Revision - Orchestrator Handoff

## Agent

Orchestrator

## Task

Route focused Backend Develop revision after Coordinator reviewed the M8 QA failure.

## What Was Done

- Read current Board and latest agent files.
- Confirmed latest Coordinator decision:
  - `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md`
- Confirmed Coordinator handoff:
  - `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-review-coordinator-handoff.md`
- Read QA report:
  - `ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md`
- Read Orchestrator task template and Docker runtime policy.
- Inspected focused evidence in:
  - `docs/status-enums.md`
  - `apps/platform-api/app/Shared/Growth/GrowthService.php`
  - `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php`
  - `apps/platform-api/tests/Feature/AffiliateTest.php`
  - `apps/platform-api/tests/Feature/CommissionTest.php`
  - `apps/platform-api/tests/Support/M8GrowthFixtures.php`
- Created focused Backend Develop task:
  - `ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md`

## Files Changed

```text
ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-orchestrator-handoff.md
```

## Validation

Only read/file inspection commands were run by Orchestrator. No application runtime commands were run.

Backend Develop must validate with Docker-only commands:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
```

## Coordinator Decision Summary

M8 is not approved yet. Backend must close:

```text
D1/P2 - Reject unsupported payout methods instead of coercing them to bank_transfer.
D2/P2 - Align affiliate attribution statuses with docs/status-enums.md and make pending attributions commission-eligible.
```

Approved revision files are limited to:

```text
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Support/M8GrowthFixtures.php only if needed
```

## Proposed Board Update

Orchestrator must not edit `ai-agents/BOARD.md` directly. Proposed update:

```text
Active Task: 20260507-m8-payout-attribution-status-revision-backend
Coordinator: handoff_sent
Orchestrator: handoff_sent
Backend Develop: ready
QA Tester: waiting_for_backend_revision
Expected backend handoff: ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

## Known Risks

```text
Revision is intentionally narrow; broader M8 risks remain as accepted/non-blocking by Coordinator unless QA finds regression.
Export jobs remain placeholder signed URL contracts.
Real external payout/bank transfer provider integration remains out of scope.
Customer/browser affiliate attribution may need a later customer/frontend slice.
Docker-only runtime remains mandatory.
Workspace has unrelated dirty/untracked files from multi-agent workflow; Backend should avoid touching unrelated files.
```

## Next Agent

Backend Develop
