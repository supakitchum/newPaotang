# back-office-p5-tenant-affiliate-commission-typed-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted focused QA for `back-office-p5-tenant-agent-quota-typed-workflows` as PASS and promoted these rows to complete:

```text
tenant:agents
tenant:agent_quotas
```

Official BO completion is now:

```text
47 / 56 complete = 83.9%
7 partial
2 api_gap
```

Coordinator opened the next BO implementation slice:

```text
back-office-p5-tenant-affiliate-commission-typed-workflows
```

Expected first owner:

```text
BO Develop
```

Scope:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: d4f026896b7d49e49477696685aaa1592d9dd667
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, clean, or overwrite them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from the current shared workspace:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential used to generate evidence.

## Objective

Implement or surface typed BO workflows for:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

These rows remain partial because BO still lacks complete typed create/update/delete workflows and real tenant BO menu QA for the affiliate/commission CRUD group. This task should make all four rows ready for focused real-menu QA. Do not mark any row complete; Coordinator will decide after QA.

## Required BO Direction

Implement BO only.

Required behavior for all scoped rows:

```text
preserve existing list/detail API connections
preserve tenant X-Tenant-Id behavior
preserve tenant scope headers
preserve idempotency behavior from the existing admin API flow
replace or supplement generic JSON payload/detail workflows with typed controls
use safe local fixtures and avoid destructive production-like assumptions
do not change backend or OpenAPI contract
do not use Customer frontend
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Other `apps/back-office/**` files may be edited only if the typed workflows require existing shared form/action behavior to support the contracts cleanly.

## tenant:affiliate_programs Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/affiliate-programs
list/detail/delete connected
create/update APIs exist but are not surfaced as typed workflows
delete is reason-confirmed but lacks focused workflow QA
workflow remains partial
```

Required typed workflow:

```text
typed create for POST /admin/tenant/affiliate-programs
typed update for PATCH /admin/tenant/affiliate-programs/{affiliate_program_id}
reason-confirmed archive/delete for DELETE /admin/tenant/affiliate-programs/{affiliate_program_id}
list/detail/filter/cursor behavior must remain intact
```

Typed create/update fields from backend behavior:

```text
code
name
status
starts_at
ends_at
metadata
```

Contract notes:

```text
name is required on create
code defaults from name when omitted but should be surfaced as editable
code must remain unique per tenant
status defaults to active
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

If `metadata` cannot reasonably be represented as granular controls, a focused JSON/object field for `metadata` is acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## tenant:affiliate_accounts Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/affiliates
menu row: tenant:affiliate_accounts
list/detail connected
create/update APIs exist but are not surfaced as typed workflows
no delete API exists for affiliate accounts
workflow remains partial
```

Required typed workflow:

```text
typed create for POST /admin/tenant/affiliates
typed update for PATCH /admin/tenant/affiliates/{affiliate_id}
list/detail/filter/cursor behavior must remain intact
do not invent a delete/archive action because the current backend does not expose one
```

Typed create/update fields from backend behavior:

```text
customer_id
code
name
phone
email
status
currency
payout_profile
metadata
```

Contract notes:

```text
name is required on create
customer_id is optional but must reference an existing same-tenant customer when supplied
code defaults from name when omitted but should be surfaced as editable
code must remain unique per tenant
status defaults to active
currency defaults to THB
payout_profile is stored as payout_profile_json
metadata is stored as metadata_json
```

If `payout_profile` or `metadata` cannot reasonably be represented as granular controls, focused JSON/object fields are acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## tenant:affiliate_links Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/affiliate-links
list/detail/delete connected
create/update APIs exist but are not surfaced as typed workflows
delete is reason-confirmed but lacks focused workflow QA
workflow remains partial
```

Required typed workflow:

```text
typed create for POST /admin/tenant/affiliate-links
typed update for PATCH /admin/tenant/affiliate-links/{affiliate_link_id}
reason-confirmed archive/delete for DELETE /admin/tenant/affiliate-links/{affiliate_link_id}
list/detail/filter/cursor behavior must remain intact
```

Typed create/update fields from backend behavior:

```text
affiliate_account_id
affiliate_program_id
code
url
status
metadata
```

Contract notes:

```text
affiliate_account_id is required on create and may also be sent as affiliate_id
affiliate_program_id is optional and may also be sent as program_id
affiliate account and program relations must exist in the same tenant and not be archived
code defaults to link but should be surfaced as editable
code must remain unique per tenant
url defaults to https://newpaotang.local/a/{code} when omitted
status defaults to active
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

If `metadata` cannot reasonably be represented as granular controls, a focused JSON/object field for `metadata` is acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## tenant:commission_rules Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/growth/commission-rules
list/detail/delete connected
create/update APIs exist but are not surfaced as typed workflows
delete is reason-confirmed but lacks focused workflow QA
workflow remains partial
```

Required typed workflow:

```text
typed create for POST /admin/tenant/commission-rules
typed update for PATCH /admin/tenant/commission-rules/{commission_rule_id}
reason-confirmed archive/delete for DELETE /admin/tenant/commission-rules/{commission_rule_id}
list/detail/filter/cursor behavior must remain intact
```

Typed create/update fields from backend behavior:

```text
affiliate_program_id
affiliate_account_id
code
name
rule_type
amount
rate_bps
currency
status
metadata
```

Contract notes:

```text
name is required on create
code defaults from name when omitted but should be surfaced as editable
code must remain unique per tenant
rule_type accepts fixed_per_order, percent_sales, per_ticket
percent_sales requires rate_bps greater than zero
fixed_per_order and per_ticket require amount greater than zero
amount is stored in minor units; the existing BO money field pattern may submit amount.amount and amount.currency
currency defaults to THB
affiliate_program_id and affiliate_account_id are optional but must reference existing same-tenant non-archived rows when supplied
metadata is stored as metadata_json
DELETE archives by setting status=archived and returns 204
```

If `metadata` cannot reasonably be represented as granular controls, a focused JSON/object field for `metadata` is acceptable. Do not use a whole-payload JSON editor as the primary create/update workflow.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
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

## Backend Contract References

Existing backend routes:

```text
GET /admin/tenant/affiliate-programs
POST /admin/tenant/affiliate-programs
GET /admin/tenant/affiliate-programs/{affiliate_program_id}
PATCH /admin/tenant/affiliate-programs/{affiliate_program_id}
DELETE /admin/tenant/affiliate-programs/{affiliate_program_id}

GET /admin/tenant/affiliates
POST /admin/tenant/affiliates
GET /admin/tenant/affiliates/{affiliate_id}
PATCH /admin/tenant/affiliates/{affiliate_id}

GET /admin/tenant/affiliate-links
POST /admin/tenant/affiliate-links
GET /admin/tenant/affiliate-links/{affiliate_link_id}
PATCH /admin/tenant/affiliate-links/{affiliate_link_id}
DELETE /admin/tenant/affiliate-links/{affiliate_link_id}

GET /admin/tenant/commission-rules
POST /admin/tenant/commission-rules
GET /admin/tenant/commission-rules/{commission_rule_id}
PATCH /admin/tenant/commission-rules/{commission_rule_id}
DELETE /admin/tenant/commission-rules/{commission_rule_id}
```

Existing permissions:

```text
affiliate_program.view
affiliate_program.manage
affiliate.view
affiliate.create
affiliate.update
affiliate_link.view
affiliate_link.manage
commission_rule.view
commission_rule.manage
```

All write APIs require:

```text
X-Admin-Scope: tenant
X-Tenant-Id
Idempotency-Key
```

## Allowed Files

BO Develop may edit:

```text
apps/back-office/**
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Backend remains frozen unless BO proves the current OpenAPI/backend contract is insufficient and Coordinator approves a backend exception first.

## Required Validation

Use Docker-only application validation. Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations directly on the host.

Run:

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

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Handoff Required

When complete, create:

```text
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

The handoff must include:

```text
implementation commit hash
files changed
exact typed fields/actions surfaced for tenant:affiliate_programs
exact typed fields/actions surfaced for tenant:affiliate_accounts
exact typed fields/actions surfaced for tenant:affiliate_links
exact typed fields/actions surfaced for tenant:commission_rules
tenant scope and X-Tenant-Id behavior preserved
idempotency behavior preserved for all write actions
validation commands and results
any skipped command with blocker reason
confirmation that no forbidden files were edited
confirmation that known unrelated dirty files were left untouched
```

Commit and push scoped BO changes before returning the handoff, following the project commit rule.

## Evidence Needed For QA

Make QA able to verify:

```text
real tenant BO menu route /admin/tenant/growth/affiliate-programs
real tenant BO menu route /admin/tenant/growth/affiliates
real tenant BO menu route /admin/tenant/growth/affiliate-links
real tenant BO menu route /admin/tenant/growth/commission-rules
all list/detail API calls include tenant scope and X-Tenant-Id
typed affiliate program create/update/archive writes include Idempotency-Key
typed affiliate account create/update writes include Idempotency-Key
typed affiliate link create/update/archive writes include Idempotency-Key
typed commission rule create/update/archive writes include Idempotency-Key
safe created rows appear in list and detail
archive/delete actions show row context and require reason
filters/cursor behavior remains coherent
```

Do not write seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets into artifacts or handoffs.

## Next Agent

After BO Develop completes and pushes:

```text
Orchestrator
```

Orchestrator will create the focused QA Tester task for these rows.
