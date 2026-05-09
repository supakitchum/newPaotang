# Backend Laravel Eloquent Standardization Approval Decision

## Context

Coordinator reviewed the completed combined backend gate:

```text
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-qa.md
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

QA verdict:

```text
PASS
```

## Decision

Approve Backend Laravel Eloquent Standardization and Backend Eloquent Call Style Revision.

This closes the backend model adoption remediation gate that previously blocked continued back-office work.

## Approved Standard

The approved backend standard is:

```text
No DB::table() in apps/platform-api/app/**
No DB::raw or ->from() table shortcuts in apps/platform-api/app/**
No fully qualified \App\Models\... calls in app source
All app data access goes through Eloquent models, relationships, scopes, or model query builders
All concrete Eloquent models define explicit protected $fillable or a Laravel Fillable attribute
BaseModel and BasePivotModel do not globally unguard with protected $guarded = []
Eloquent strict discarded-attribute diagnostics are enabled outside production
Short direct queries prefer Model::where(), whereKey(), find(), firstWhere(), count(), and sum()
Model::query() remains allowed for complex/conditional/scoped/paginated/locked/joined/bulk/query-factory builder paths
```

## QA Evidence Reviewed

QA static checks:

```text
fully qualified \App\Models\... calls: PASS, no matches
DB::table() in apps/platform-api/app/**: PASS, no matches
DB::raw / ->from() shortcuts: PASS, no matches
protected $guarded = [] under app/Models: PASS, no matches
missing fillable: PASS, only non-model concern files reported
preventSilentlyDiscardingAttributes: PASS
remaining Model::query() calls: reviewed and accepted under allowed categories
```

QA Docker validation:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
BackendModelComplianceTest: PASS, 7 tests / 1052 assertions
Model filter: PASS, 7 tests / 1052 assertions
Tenant filter: PASS, 36 tests / 630 assertions
Admin filter: PASS, 42 tests / 472 assertions
Rbac filter: PASS, 6 tests / 18 assertions
Checkout filter: PASS, 1 test / 30 assertions
Reward filter: PASS, 7 tests / 321 assertions
Growth filter: PASS, 1 test / 10 assertions
CentralStock filter: PASS, 1 test / 32 assertions
full platform-api suite: PASS, 111 tests / 2766 assertions
```

Coordinator read-only spot checks also matched QA for:

```text
no \App\Models\... calls
no DB::table()
no DB::raw / ->from()
no protected $guarded = []
missing fillable only reports Concerns/BelongsToTenant.php and Concerns/HasStringPrimaryKey.php
docs reflect the no DB::table exception policy and the preferred Eloquent call style
```

## Accepted Residual Notes

The following are accepted for this gate:

```text
Remaining Model::query() calls are not expected to be zero.
Remaining Model::query() calls are accepted for explicit builders, tenant scopes, pagination/cursor flows, joins, locks, bulk writes, idempotency, audit/outbox/inbox, reports, and model-class maps.
Workspace remains broadly dirty/untracked from the multi-agent workflow; QA did not attribute unrelated customer/back-office state to this backend gate.
```

## Out Of Scope

This approval does not approve:

```text
new API contracts
business rule changes
customer flow changes
apps/customer changes
apps/back-office changes
dependency upgrades
staging/production/client delivery
```

## Next Plan

Resume the paused back-office work:

```text
20260507-back-office-operations-page-slice-1
```

Back-office risk tracking from the prior gate remains active:

```text
Meno license notice must be confirmed/restored before staging/production/client delivery.
npm audit vulnerabilities must be triaged before production readiness.
desktop/mobile screenshot QA and authenticated admin runtime QA are still required before delivery.
```

## Date

```text
2026-05-08
```

## Next Agent

```text
Orchestrator
```
