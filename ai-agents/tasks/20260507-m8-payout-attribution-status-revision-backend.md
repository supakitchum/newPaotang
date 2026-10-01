# 20260507-m8-payout-attribution-status-revision - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

M8 Affiliate, Agent, Reports, Settlement is not approved yet. QA result was `FAIL` because two acceptance-relevant defects remain:

```text
D1/P2 - Payout create accepts unsupported payout methods by silently coercing them.
D2/P2 - Documented pending affiliate attributions are ignored by commission calculation.
```

This focused revision is authorized by:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-review-coordinator-handoff.md
ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md
```

## Objective

Close the two QA defects blocking M8 approval:

1. Reject unsupported affiliate payout methods instead of coercing them to `bank_transfer`.
2. Align affiliate attribution status defaults and commission calculation with `docs/status-enums.md`.

## Source Of Truth

- `docs/docker-runtime-policy.md`
- `docs/status-enums.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md`
- `ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md`
- `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md`
- `ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-qa.md`
- `ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md`
- `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-review-coordinator-handoff.md`

Relevant documented enum:

```text
affiliate_attributions.status: pending, converted, expired, cancelled
```

## Scope

Fix only:

- affiliate payout method validation
- affiliate attribution status default/alignment
- commission calculation eligibility for pending attributions
- tests proving these fixes

Evidence from QA:

```text
apps/platform-api/app/Shared/Growth/GrowthService.php around createPayout() coerces unsupported payout_method to bank_transfer.
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php defaults affiliate_attributions.status to active.
apps/platform-api/app/Shared/Growth/GrowthService.php commission calculation searches customer attributions with status = active.
```

## Out Of Scope

- Do not redesign M8 schema beyond the attribution status correction.
- Do not change checkout controller behavior.
- Do not change commission rule algorithms except where needed to select eligible attributions.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement real bank transfer provider integration.
- Do not implement real export file generation.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/status-enums.md`.
- Do not edit other source-of-truth docs unless Coordinator explicitly approves a contract correction.
- Do not upgrade Laravel/PHP dependencies.

## File Ownership

Can edit:

```text
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Support/M8GrowthFixtures.php
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
apps/platform-api/app/Modules/**
apps/platform-api/routes/**
apps/platform-api/config/**
apps/platform-api/database/migrations/* except apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/tests/** except apps/platform-api/tests/Feature/AffiliateTest.php, apps/platform-api/tests/Feature/CommissionTest.php, apps/platform-api/tests/Support/M8GrowthFixtures.php
docs/**
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

## Required Steps

1. Read the Coordinator QA review decision, Coordinator handoff, QA report, this task, and Docker runtime policy.
2. Inspect the current implementation in `GrowthService::createPayout()`.
3. Add validation so unsupported `payout_method` values, for example `crypto`, return the existing `validation_failed` error envelope.
4. Ensure invalid payout method requests do not create:
   - `affiliate_payouts`
   - audit log rows
   - idempotency success responses.
5. Keep valid supported payout methods working. Use the existing supported allow-list in `GrowthService` unless the code already has a clearer supported source.
6. Change `affiliate_attributions.status` default from undocumented `active` to documented `pending`.
7. Update commission calculation to consider eligible `pending` attributions for paid orders.
8. On successful commission calculation, transition the attribution to `converted` as appropriate and set `converted_at` where current conventions support it.
9. Ensure `expired` and `cancelled` attributions are skipped for new commission calculation.
10. Avoid accepting or depending on undocumented `active` status for new attribution records.
11. Add or update tests:
    - unsupported payout method is rejected with no mutation
    - valid payout method still creates payout
    - pending attribution is picked up by `commission:calculate` or `GrowthService` commission calculation
    - successful calculation converts the attribution
    - expired/cancelled attributions are skipped
12. Keep existing M8 happy path, idempotency, report, and full suite tests passing.
13. Run Docker-only validation and record exact results in the backend handoff.
14. Explicitly document that no host PHP/Composer/Artisan commands were run.

## Acceptance Criteria

- Unsupported payout methods are rejected with `validation_failed`.
- Unsupported payout method requests do not persist payouts, audit logs, or idempotent success responses.
- Valid supported payout methods still create payouts correctly.
- `affiliate_attributions.status` defaults to `pending`.
- New attribution behavior does not depend on undocumented `active`.
- Pending attributions are eligible for commission calculation on paid orders.
- Successful commission calculation transitions eligible attribution to `converted`.
- Expired and cancelled attributions are not used for new commission calculation.
- Existing M8 commission retry/idempotency behavior remains intact.
- Existing M8 report and settlement behavior remains intact.
- Docker validation passes.
- Backend handoff exists and includes the requested evidence.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation commands and results
invalid payout_method rejection behavior
valid payout method behavior
affiliate_attributions default/status values
pending attribution commission behavior
expired/cancelled attribution skip behavior
evidence that no host PHP/Composer/Artisan commands were run
known risks
next agent
```

Next agent after backend handoff:

```text
Orchestrator
```

Do not create a QA task directly. Orchestrator will create the focused QA task after this backend handoff exists.
