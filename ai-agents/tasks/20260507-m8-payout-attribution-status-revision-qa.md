# 20260507-m8-payout-attribution-status-revision - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused M8 revision for the two QA-blocking defects:

```text
D1/P2 - Unsupported affiliate payout methods were silently coerced to bank_transfer.
D2/P2 - Documented pending affiliate attributions were ignored by commission calculation.
```

Validate that the focused Backend revision closes D1/D2 without regressing M8.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-review-coordinator-handoff.md
ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

## Objective

Validate focused D1/D2 closure:

```text
unsupported payout_method validation rejects bad values without mutation
supported payout methods still create payouts correctly
affiliate_attributions.status default aligns with docs/status-enums.md
pending attributions are commission-eligible for paid orders
successful commission calculation converts pending attributions
expired/cancelled attributions are skipped
Docker-only validation remains green
```

## Source Of Truth

- `docs/docker-runtime-policy.md`
- `docs/status-enums.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md`
- `ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md`
- `ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-qa-review-coordinator-handoff.md`
- `ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md`
- `ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md`
- `apps/platform-api/composer.json`

Documented attribution statuses:

```text
pending
converted
expired
cancelled
```

## Scope

Validate only the focused Backend revision and its regression safety.

Inspect changed files reported by Backend:

```text
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Support/M8GrowthFixtures.php
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
```

Validate behavior:

- Invalid `payout_method`, for example `crypto`, returns the existing `validation_failed` envelope.
- Invalid `payout_method` does not create `affiliate_payouts`.
- Invalid `payout_method` does not create audit logs for payout creation.
- Invalid `payout_method` does not store idempotent success responses.
- Valid supported payout methods still create payouts.
- `affiliate_attributions.status` migration default is `pending`.
- New fixtures/tests do not depend on undocumented `active` attribution status.
- Commission calculation selects eligible `pending` attributions.
- Successful commission calculation updates attribution to `converted`, sets `order_id`, and sets `converted_at`.
- `expired` and `cancelled` attributions are skipped and remain unchanged.
- Existing M8 report and full-suite tests still pass.
- Backend stayed inside the approved revision file list.
- Backend handoff explicitly reports no host PHP/Composer/Artisan commands were run.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates another implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not re-review all broad M8 behavior except where needed to verify no regression from this focused revision.
- Do not implement real bank transfer provider integration.
- Do not implement real export file generation.
- Do not change checkout controller behavior.
- Do not change commission rule algorithms.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend revision handoff against the focused Backend task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm Backend changed only approved revision files plus its backend handoff, or document scope drift.
5. Inspect the migration default for `affiliate_attributions.status`.
6. Inspect `GrowthService::createPayout()` for payout method validation before idempotent write/mutation.
7. Inspect commission attribution selection and conversion behavior in `GrowthService`.
8. Inspect `AffiliateTest`, `CommissionTest`, and fixtures for D1/D2 regression coverage.
9. Run all required validation commands through Docker only.
10. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m8-payout-attribution-status-revision-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report confirms Docker validation results for migration, Affiliate tests, Commission tests, Report tests, full suite, and `commission:calculate`.
- QA report confirms QA did not modify app code, docs, decisions, tasks, handoffs, or Board.
- QA report confirms Backend stayed within approved focused revision scope or lists scope drift defects.
- QA report confirms invalid payout methods are rejected without payout/audit/idempotency success mutation.
- QA report confirms valid payout methods still create payouts.
- QA report confirms attribution default/status values align with `docs/status-enums.md`.
- QA report confirms pending attribution commission behavior.
- QA report confirms expired/cancelled attribution skip behavior.
- QA report confirms no checkout inline commission calculation was introduced.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
git diff --stat -- apps/platform-api/app/Shared/Growth/GrowthService.php apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php apps/platform-api/tests/Feature/AffiliateTest.php apps/platform-api/tests/Feature/CommissionTest.php apps/platform-api/tests/Support/M8GrowthFixtures.php
rg -n "(PAYOUT_METHODS|payout_method|affiliate_attributions|pending|converted|expired|cancelled|tenantIdempotentWrite|commission:calculate)" apps/platform-api/app/Shared/Growth/GrowthService.php apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php apps/platform-api/tests/Feature/AffiliateTest.php apps/platform-api/tests/Feature/CommissionTest.php apps/platform-api/tests/Support/M8GrowthFixtures.php
sed -n '820,880p' apps/platform-api/app/Shared/Growth/GrowthService.php
sed -n '1240,1310p' apps/platform-api/app/Shared/Growth/GrowthService.php
sed -n '115,130p' apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php
sed -n '1,220p' apps/platform-api/tests/Feature/AffiliateTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/CommissionTest.php
sed -n '230,265p' apps/platform-api/tests/Support/M8GrowthFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m8-payout-attribution-status-revision-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
scope drift findings
payout method validation findings
payout mutation/idempotency/audit findings
valid payout method findings
attribution status/default findings
pending attribution commission findings
expired/cancelled attribution skip findings
checkout separation findings
test coverage findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
