# M8 Affiliate, Agent, Reports, Settlement Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-qa.md
ai-agents/reports/20260507-m8-affiliate-agent-reports-settlement-qa-report.md
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-qa-review-decision.md
ai-agents/tasks/20260507-m8-payout-attribution-status-revision-backend.md
ai-agents/handoffs/20260507-m8-payout-attribution-status-revision-backend-handoff.md
ai-agents/tasks/20260507-m8-payout-attribution-status-revision-qa.md
ai-agents/reports/20260507-m8-payout-attribution-status-revision-qa-report.md
```

Initial M8 QA result:

```text
FAIL
```

Coordinator requested a focused Backend Develop revision for:

```text
D1/P2 - Payout create accepts unsupported payout methods by silently coercing them.
D2/P2 - Documented pending affiliate attributions are ignored by commission calculation.
```

Focused revision QA result:

```text
PASS
```

Focused Docker validation evidence:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Affiliate: PASS, 1 test, 22 assertions
docker compose run --rm platform-api php artisan test --filter=Commission: PASS, 3 tests, 24 assertions
docker compose run --rm platform-api php artisan test --filter=Report: PASS, 3 tests, 31 assertions
docker compose run --rm platform-api php artisan test: PASS, 94 tests, 1565 assertions
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing: PASS
```

## Decision

Approve M8 Affiliate, Agent, Reports, Settlement.

The focused revision closed all blocking M8 findings. Unsupported payout methods now fail validation before mutation, and affiliate attribution status behavior now follows `docs/status-enums.md`: new attributions default to `pending`, pending attributions are commission-eligible, successful commission calculation converts the attribution, and expired/cancelled attributions are skipped.

## Approved Backend Scope

```text
tenant agents and agent quotas
tenant affiliate accounts, programs, links, and attributions
tenant commission rules and commission transactions
command/service-driven commission calculation
commission.calculated.v1 outbox persistence
commission reversal rows without deleting originals
tenant affiliate payout create/approve foundation
tenant reports and report export jobs
central reports and report export jobs
central partner settlement list/detail/approve foundation
audit redaction for payout/bank/account payload keys
focused Agent, Affiliate, Commission, Report, and Settlement tests
```

## Approved Endpoint Coverage

```text
GET /api/v1/admin/tenant/agents
POST /api/v1/admin/tenant/agents
GET /api/v1/admin/tenant/agents/{agent_id}
PATCH /api/v1/admin/tenant/agents/{agent_id}
PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas
GET /api/v1/admin/tenant/affiliate-programs
POST /api/v1/admin/tenant/affiliate-programs
GET /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
PATCH /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
DELETE /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}
GET /api/v1/admin/tenant/affiliate-links
POST /api/v1/admin/tenant/affiliate-links
GET /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
PATCH /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
DELETE /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}
GET /api/v1/admin/tenant/affiliate-attributions
GET /api/v1/admin/tenant/affiliate-attributions/{attribution_id}
GET /api/v1/admin/tenant/affiliates
POST /api/v1/admin/tenant/affiliates
GET /api/v1/admin/tenant/affiliates/{affiliate_id}
PATCH /api/v1/admin/tenant/affiliates/{affiliate_id}
GET /api/v1/admin/tenant/commission-rules
POST /api/v1/admin/tenant/commission-rules
GET /api/v1/admin/tenant/commission-rules/{commission_rule_id}
PATCH /api/v1/admin/tenant/commission-rules/{commission_rule_id}
DELETE /api/v1/admin/tenant/commission-rules/{commission_rule_id}
GET /api/v1/admin/tenant/commission-transactions
POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve
GET /api/v1/admin/tenant/payouts
POST /api/v1/admin/tenant/payouts
POST /api/v1/admin/tenant/payouts/{payout_id}/approve
GET /api/v1/admin/tenant/reports/{report_key}
POST /api/v1/admin/tenant/reports/{report_key}/exports
GET /api/v1/admin/tenant/export-jobs/{export_job_id}
GET /api/v1/admin/tenant/export-jobs/{export_job_id}/download
GET /api/v1/admin/central/reports/{report_key}
POST /api/v1/admin/central/reports/{report_key}/exports
GET /api/v1/admin/central/export-jobs/{export_job_id}
GET /api/v1/admin/central/export-jobs/{export_job_id}/download
GET /api/v1/admin/central/settlements
GET /api/v1/admin/central/settlements/{settlement_id}
POST /api/v1/admin/central/settlements/{settlement_id}/approve
```

## Approved Behavior

```text
Migrations run from an empty testing database.
Tenant M8 endpoints require admin auth, tenant scope, selected X-Tenant-Id, and mapped permissions.
Central report/settlement endpoints require central admin auth and mapped central permissions.
Tenant-owned reads/writes filter by selected tenant.
Write actions use Idempotency-Key where required and preserve replay/conflict behavior.
Agent and affiliate records are tenant-scoped and do not create tenant clones or new codebases.
Commission calculation runs through GrowthService and commission:calculate, not checkout controller.
Commission transactions reference order_id and commission_rule_id.
Retrying commission calculation does not duplicate commission transactions.
Commission reversals use reversal rows with original reference rather than deleting originals.
commission.calculated.v1 is persisted in sync_outbox.
Affiliate payout create validates positive amount and supported payout method.
Unsupported payout methods fail validation before payout, audit, or idempotency-success mutation.
affiliate_attributions.status defaults to pending and uses documented pending/converted/expired/cancelled values.
Pending attributions are commission-eligible and convert on successful commission calculation.
Expired and cancelled attributions are skipped.
Tenant and central reports enforce their scope.
Report export jobs are scoped and return placeholder signed URL contract behavior.
Central settlements summarize partner/tenant paid orders, commissions, and approved payouts.
Settlement approval is central-only, permission checked, audited, and idempotent.
```

## Accepted Residual Risks

These are accepted as non-blocking for M8 and should be handled in later slices or Coordinator contract clarification:

```text
Export jobs currently use placeholder signed URLs and do not generate physical CSV/XLSX/PDF files.
Real external payout/bank transfer provider integration remains out of scope.
Customer/browser affiliate attribution may need a later customer/frontend slice.
Internal commission_transactions.status = calculated remains accepted unless a later contract task changes it.
Additional commission rule types beyond fixed_per_order, percent_sales, and per_ticket are future business work.
Back-office UI is not part of M8 approval; M8 approves backend APIs/foundation for later UI work.
```

## Still Out Of Scope

```text
apps/customer changes
apps/back-office changes
back-office screens
public affiliate tracking UI
real bank transfer provider integration
real export file generation/storage/CDN delivery
billing plan/payment collection for platform subscriptions
M9 maintenance/support/security hardening
Laravel/PHP dependency upgrades
```

## Reason

M8 provides the tenant growth, commission, reporting, payout, and settlement backend foundation required before back-office UI and production hardening. The first QA run found two focused contract defects. The revision closed both, expanded regression coverage, and QA confirmed all required Docker validation commands pass.

## Impact

M8 is now approved:

```text
tenant agent and affiliate management foundation exists
commission calculation is worker/command-service driven and retry-safe
commission events support report/settlement consumers
reports and export job API contracts are available
settlement summaries and approval foundation exists
payout create/approve foundation validates supported methods and amount behavior
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
