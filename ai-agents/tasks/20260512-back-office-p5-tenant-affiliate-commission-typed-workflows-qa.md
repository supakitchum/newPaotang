# back-office-p5-tenant-affiliate-commission-typed-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened this P5 BO implementation slice after accepting `tenant:agents` and `tenant:agent_quotas` typed workflow QA as PASS.

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

## Objective

Perform focused QA for these rows only:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

The retest must prove that the real tenant BO workflows now support typed affiliate/commission CRUD actions end to end, while preserving existing list/detail/filter/cursor behavior and tenant scoping.

If focused QA passes, Coordinator can decide whether to promote any or all scoped rows to complete.

Customer frontend remains frozen. Do not enter the Customer frontend.

## BO Implementation Under Test

Implementation commit:

```text
fdd8ae946c52fb3ce7e4ffd71615cab546433cf2
```

BO handoff commit:

```text
2462ce91a94f676a4fb590ee2e84921aef5c6e66
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

BO reports no backend, OpenAPI contract, Customer frontend, docs, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/tasks/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/Growth/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/CommissionTest.php
```

Backend/OpenAPI files are read-only references. Do not edit them.

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential. Leave it untouched.

If these files are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Focused QA Scope

Test only:

```text
tenant:affiliate_programs
/admin/tenant/growth/affiliate-programs

tenant:affiliate_accounts
/admin/tenant/growth/affiliates

tenant:affiliate_links
/admin/tenant/growth/affiliate-links

tenant:commission_rules
/admin/tenant/growth/commission-rules
```

Required shared checks:

```text
access all four pages from the real authenticated BO tenant menu
verify list APIs load with x-admin-scope: tenant and x-tenant-id
verify detail opens from real rows
verify typed create/update/archive action modals expose expected controls
verify write requests include tenant scope and idempotency key where applicable
verify filter/cursor/loading/empty/error behavior remains coherent
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

## Safe Fixture Guidance

Use safe local fixture data only.

Recommended setup:

```text
create one affiliate program
create one affiliate account
use those IDs to create one affiliate link
use those IDs to create one commission rule
archive only safe QA-created rows
```

Prefer unique codes such as:

```text
p5_aff_program_<short timestamp>
p5_affiliate_<short timestamp>
p5_aff_link_<short timestamp>
p5_commission_rule_<short timestamp>
```

Do not use real customer data. `customer_id` for affiliate accounts is optional. If QA uses it, use only a safe same-tenant seeded or QA-created fixture and avoid entering the Customer frontend.

## tenant:affiliate_programs QA Requirements

Required workflow:

```text
open /admin/tenant/growth/affiliate-programs from the real tenant menu
verify list API uses GET /api/v1/admin/tenant/affiliate-programs with tenant scope
create a safe local affiliate program through the typed Create program modal
verify create fields: code, name, status, starts_at, ends_at, metadata JSON
verify metadata accepts valid JSON object/array
verify create submits POST /api/v1/admin/tenant/affiliate-programs with tenant scope and idempotency
verify created row appears in list and detail
update the same program through the typed Update program modal
verify update fields match create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id} with tenant scope and idempotency
verify list/detail reflect updated values
open Archive action from the real row/detail
verify archive modal shows program context and requires reason
execute archive on the safe QA-created program when it is no longer needed by other scoped workflows
verify DELETE /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id} carries tenant scope and idempotency
verify archived status/detail or archived filter evidence after archive
```

## tenant:affiliate_accounts QA Requirements

Required workflow:

```text
open /admin/tenant/growth/affiliates from the real tenant menu
verify list API uses GET /api/v1/admin/tenant/affiliates with tenant scope
create a safe local affiliate account through the typed Create affiliate modal
verify create fields: customer_id, code, name, phone, email, status, currency, payout_profile JSON, metadata JSON
verify payout_profile and metadata accept valid JSON object/array
verify create submits POST /api/v1/admin/tenant/affiliates with tenant scope and idempotency
verify created row appears in list and detail
update the same affiliate through the typed Update affiliate modal
verify update fields match create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/affiliates/{affiliate_id} with tenant scope and idempotency
verify list/detail reflect updated values
verify no archive/delete action is exposed for affiliate accounts
verify status and customer_id filters remain coherent when practical
```

## tenant:affiliate_links QA Requirements

Required workflow:

```text
open /admin/tenant/growth/affiliate-links from the real tenant menu
verify list API uses GET /api/v1/admin/tenant/affiliate-links with tenant scope
create a safe local affiliate link through the typed Create link modal
verify create fields: affiliate_account_id, affiliate_program_id, code, url, status, metadata JSON
use the safe QA-created affiliate account and, if practical, affiliate program IDs
verify metadata accepts valid JSON object/array
verify create submits POST /api/v1/admin/tenant/affiliate-links with tenant scope and idempotency
verify created row appears in list and detail
update the same link through the typed Update link modal
verify update fields match create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/affiliate-links/{affiliate_link_id} with tenant scope and idempotency
verify list/detail reflect updated values
open Archive action from the real row/detail
verify archive modal shows link context and requires reason
execute archive on the safe QA-created link when it is no longer needed
verify DELETE /api/v1/admin/tenant/affiliate-links/{affiliate_link_id} carries tenant scope and idempotency
verify archived status/detail or archived filter evidence after archive
verify affiliate_id filter remains coherent
```

## tenant:commission_rules QA Requirements

Required workflow:

```text
open /admin/tenant/growth/commission-rules from the real tenant menu
verify list API uses GET /api/v1/admin/tenant/commission-rules with tenant scope
create a safe local commission rule through the typed Create commission rule modal
verify create fields: affiliate_program_id, affiliate_account_id, code, name, rule_type, amount.amount, rate_bps, amount.currency, status, metadata JSON
use safe QA-created affiliate account/program IDs when testing relation-backed rules
verify metadata accepts valid JSON object/array
verify create submits POST /api/v1/admin/tenant/commission-rules with tenant scope and idempotency
verify amount is sent as an amount object with amount/currency, or equivalent backend-compatible payload
verify created row appears in list and detail
update the same rule through the typed Update rule modal
verify update fields match create fields and prefill from the record where applicable
verify update submits PATCH /api/v1/admin/tenant/commission-rules/{commission_rule_id} with tenant scope and idempotency
verify fixed_per_order or per_ticket rules use amount.amount greater than zero
verify percent_sales rules use rate_bps greater than zero if QA switches rule_type
verify list/detail reflect updated values
open Archive action from the real row/detail
verify archive modal shows commission rule context and requires reason
execute archive on the safe QA-created rule
verify DELETE /api/v1/admin/tenant/commission-rules/{commission_rule_id} carries tenant scope and idempotency
verify archived status/detail or archived filter evidence after archive
verify affiliate_account_id filter remains coherent
```

## Contract Notes To Respect

Affiliate programs:

```text
name is required on create
code defaults from name when omitted but BO surfaces it as editable
code must remain unique per tenant
status defaults to active
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

Affiliate accounts:

```text
name is required on create
customer_id is optional but must reference a same-tenant customer when supplied
code defaults from name when omitted but BO surfaces it as editable
code must remain unique per tenant
status defaults to active
currency defaults to THB
payout_profile is stored as payout_profile_json
metadata is stored as metadata_json
no current backend archive/delete route exists for affiliate accounts
```

Affiliate links:

```text
affiliate_account_id is required on create
affiliate_program_id is optional
relations must exist in the same tenant and must not be archived
code defaults to link but BO surfaces it as editable
code must remain unique per tenant
url defaults to https://newpaotang.local/a/{code} when omitted
status defaults to active
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

Commission rules:

```text
name is required on create
code defaults from name when omitted but BO surfaces it as editable
code must remain unique per tenant
rule_type accepts fixed_per_order, percent_sales, per_ticket
percent_sales requires rate_bps greater than zero
fixed_per_order and per_ticket require amount greater than zero
amount is stored in minor units
currency defaults to THB
affiliate_program_id and affiliate_account_id are optional but must reference same-tenant non-archived rows when supplied
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

Do not treat no affiliate-account delete/archive action as a defect. That action is out of backend contract for this row.

## Out Of Scope

Do not:

```text
edit implementation code
edit apps/back-office/**
edit apps/platform-api/**
edit apps/customer/**
edit docs/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/handoffs/**
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, real customer data, local credentials, or private keys into artifacts
use Customer frontend
change backend affiliate/commission logic
change API/OpenAPI contract
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/**
```

Must not edit:

```text
apps/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ops/**
scripts/**
load-tests/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md and ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `fdd8ae946c52fb3ce7e4ffd71615cab546433cf2`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Create or identify safe local fixtures for affiliate program, affiliate account, affiliate link, and commission rule workflows.
8. Capture API evidence for all scoped create/update/archive actions.
9. Test the real authenticated BO tenant menus and typed modals.
10. Capture screenshots/snapshots/text artifacts for typed fields, request payload keys, tenant scope, idempotency, detail routes, archive confirmations, filters, and final states.
11. Redact artifacts and verify no secrets/passwords/tokens are included.
12. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AffiliateTest
docker compose run --rm platform-api php artisan test --filter=CommissionTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, migrations, queues, or scheduler commands.

## Expected QA Output

Write:

```text
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
API evidence summary
browser evidence summary
typed affiliate program create/update/archive field and result evidence
typed affiliate account create/update field and result evidence
typed affiliate link create/update/archive field and result evidence
typed commission rule create/update/archive field and result evidence
tenant scope and X-Tenant-Id results
idempotency result for write calls
confirmation no Customer frontend was used
whether tenant:affiliate_programs is a completion candidate after implementation
whether tenant:affiliate_accounts is a completion candidate after implementation
whether tenant:affiliate_links is a completion candidate after implementation
whether tenant:commission_rules is a completion candidate after implementation
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
redaction summary
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether `tenant:affiliate_programs`, `tenant:affiliate_accounts`, `tenant:affiliate_links`, and/or `tenant:commission_rules` count toward BO completion. If QA finds defects, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
