# M8 Affiliate, Agent, Reports, Settlement QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-qa.md
ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md
```

QA result:

```text
FAIL
```

Docker validation evidence passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Affiliate: PASS, 1 test, 16 assertions
docker compose run --rm platform-api php artisan test --filter=Agent: PASS, 1 test, 16 assertions
docker compose run --rm platform-api php artisan test --filter=Commission: PASS, 2 tests, 16 assertions
docker compose run --rm platform-api php artisan test --filter=Report: PASS, 3 tests, 31 assertions
docker compose run --rm platform-api php artisan test --filter=Settlement: PASS, 1 test, 17 assertions
docker compose run --rm platform-api php artisan test: PASS, 93 tests, 1551 assertions
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing: PASS
```

QA confirmed broad M8 implementation coverage, including schema, tenant agent/affiliate/commission/payout APIs, commission command/service path, reports/export jobs, central settlement APIs, tenant isolation, RBAC checks, idempotency, audit redaction, and no checkout inline commission calculation.

QA found two acceptance-relevant defects:

```text
D1/P2 - Payout create accepts unsupported payout methods by silently coercing them.
D2/P2 - Documented pending affiliate attributions are ignored by commission calculation.
```

## Decision

Do not approve M8 yet.

Route a focused Backend Develop revision through Orchestrator to close D1/P2 and D2/P2 before M8 approval. The main implementation and Docker validation are healthy, but payout validation and attribution status contract alignment must be corrected.

## Orchestrator Instruction

Create one focused Backend Develop task:

```text
ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Revision Objective

Close the two QA defects blocking M8 approval:

```text
1. Reject unsupported affiliate payout methods instead of coercing them to bank_transfer.
2. Align affiliate attribution status defaults and commission calculation with docs/status-enums.md.
```

## Approved Scope

Backend Develop may edit only the platform-api M8 validation/status files and tests needed for these defects:

```text
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Support/M8GrowthFixtures.php only if needed for setup
```

## Required Fixes

Payout method validation:

```text
Validate payout_method for affiliate payout create against the supported allow-list.
Reject unsupported values such as crypto with the existing validation_failed error envelope.
Do not coerce unsupported methods to bank_transfer.
Do not create affiliate_payouts, audit logs, or idempotent success responses when payout_method validation fails.
Keep valid supported methods working.
```

Affiliate attribution status alignment:

```text
Use documented affiliate_attributions.status values: pending, converted, expired, cancelled.
Change the attribution default away from active and align it to pending unless a clearer documented status is already approved.
Update commission calculation to consider eligible pending attributions for paid orders.
On successful commission calculation, transition the attribution to converted as appropriate.
Ensure expired/cancelled attributions are not used for new commission calculation.
Avoid accepting or depending on undocumented active status for new attribution records.
```

Regression tests:

```text
Add a test that unsupported payout_method is rejected without mutation.
Add a test that valid payout methods still create payouts correctly.
Add a test that pending attributions are picked up by commission:calculate or GrowthService commission calculation.
Add a test that expired/cancelled attributions are skipped.
Keep existing M8 happy path and idempotency tests passing.
```

## Out Of Scope

```text
Do not redesign M8 schema beyond the attribution status correction.
Do not change checkout controller behavior.
Do not change commission rule algorithms except where needed to select eligible attributions.
Do not edit apps/customer.
Do not edit apps/back-office.
Do not implement real bank transfer provider integration.
Do not implement real export file generation.
Do not change docs/openapi.yaml or docs/status-enums.md unless Coordinator explicitly approves a contract correction.
```

## Validation Requirements

Backend Develop must run Docker-only validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
```

Backend Develop must also document evidence that no host PHP/Composer/Artisan commands were run.

## QA Follow-Up Instruction

After Backend Develop handoff, Orchestrator must create a focused QA task for D1/D2 closure. QA should rerun Docker validation and inspect that invalid payout methods do not mutate state, while pending attributions are commission-eligible and converted after calculation.

## Accepted Non-Blocking Risks

```text
Export jobs remain placeholder signed URL contracts.
Real external payout/bank transfer provider integration remains out of scope.
Customer/browser affiliate attribution may need a later customer/frontend slice.
Internal commission transaction status names remain a Coordinator review caveat unless they break tests or documented API behavior.
```

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```
