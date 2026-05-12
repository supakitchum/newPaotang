# back-office-p5-tenant-affiliate-commission-typed-workflows - BO Handoff

## Summary

BO Develop implemented typed back-office workflows for:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Implementation commit:

```text
fdd8ae946c52fb3ce7e4ffd71615cab546433cf2
```

Next Agent:

```text
Orchestrator
```

## Files Changed

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Handoff file:

```text
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo-handoff.md
```

## tenant:affiliate_programs Typed Workflow

Route:

```text
/admin/tenant/growth/affiliate-programs
```

Preserved API connections:

```text
GET /admin/tenant/affiliate-programs
GET /admin/tenant/affiliate-programs/{affiliate_program_id}
```

Typed create action:

```text
POST /admin/tenant/affiliate-programs
```

Create fields:

```text
code
name
status
starts_at
ends_at
metadata
```

Typed update action:

```text
PATCH /admin/tenant/affiliate-programs/{affiliate_program_id}
```

Update fields:

```text
code
name
status
starts_at
ends_at
metadata
```

Typed archive action:

```text
DELETE /admin/tenant/affiliate-programs/{affiliate_program_id}
```

Archive action requires reason and shows context:

```text
id
tenant_id
code
name
status
starts_at
ends_at
metadata
updated_at
```

## tenant:affiliate_accounts Typed Workflow

Route:

```text
/admin/tenant/growth/affiliates
```

Preserved API connections:

```text
GET /admin/tenant/affiliates
GET /admin/tenant/affiliates/{affiliate_id}
```

Typed create action:

```text
POST /admin/tenant/affiliates
```

Create fields:

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

Typed update action:

```text
PATCH /admin/tenant/affiliates/{affiliate_id}
```

Update fields:

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

Update context:

```text
id
tenant_id
customer_id
code
name
phone
email
status
wallet_balance.amount
wallet_balance.currency
payout_profile
metadata
updated_at
```

No archive/delete action was added for affiliate accounts because the backend task scope only required typed create/update for this row.

## tenant:affiliate_links Typed Workflow

Route:

```text
/admin/tenant/growth/affiliate-links
```

Preserved API connections:

```text
GET /admin/tenant/affiliate-links
GET /admin/tenant/affiliate-links/{affiliate_link_id}
```

Typed create action:

```text
POST /admin/tenant/affiliate-links
```

Create fields:

```text
affiliate_account_id
affiliate_program_id
code
url
status
metadata
```

Typed update action:

```text
PATCH /admin/tenant/affiliate-links/{affiliate_link_id}
```

Update fields:

```text
affiliate_account_id
affiliate_program_id
code
url
status
metadata
```

Typed archive action:

```text
DELETE /admin/tenant/affiliate-links/{affiliate_link_id}
```

Archive action requires reason and shows context:

```text
id
tenant_id
affiliate_account_id
affiliate_program_id
code
url
status
metadata
updated_at
```

## tenant:commission_rules Typed Workflow

Route:

```text
/admin/tenant/growth/commission-rules
```

Preserved API connections:

```text
GET /admin/tenant/commission-rules
GET /admin/tenant/commission-rules/{commission_rule_id}
```

Typed create action:

```text
POST /admin/tenant/commission-rules
```

Create fields:

```text
affiliate_program_id
affiliate_account_id
code
name
rule_type
amount.amount
rate_bps
amount.currency
status
metadata
```

Typed update action:

```text
PATCH /admin/tenant/commission-rules/{commission_rule_id}
```

Update fields:

```text
affiliate_program_id
affiliate_account_id
code
name
rule_type
amount.amount
rate_bps
amount.currency
status
metadata
```

Typed archive action:

```text
DELETE /admin/tenant/commission-rules/{commission_rule_id}
```

Archive action requires reason and shows context:

```text
id
tenant_id
affiliate_program_id
affiliate_account_id
code
name
rule_type
amount.amount
amount.currency
rate_bps
status
metadata
updated_at
```

Commission rule notes for QA:

```text
fixed_per_order and per_ticket require amount.amount > 0.
percent_sales requires rate_bps > 0.
amount.currency defaults to THB in BO.
```

## Template And UI Behavior

Existing Meno/Bootstrap operation patterns were reused:

```text
AdminOperationsPage
AdminConfirmAction
AdminExportPanel
AdminDataTable
AdminStatusBadge
AdminModal
btn btn-primary / btn-danger btn-wave
form-control / form-select
```

No new design system was introduced.

Existing loading/error/empty states remain handled through:

```text
AdminApiState
AdminLoader
AdminDataTable
AdminPagination
AdminConfirmAction loading/error state
```

## Scope Confirmations

- Existing list/detail/filter/cursor behavior was preserved for all four rows.
- Tenant scope and `X-Tenant-Id` behavior were preserved through the existing `useAdminApi` flow.
- Idempotency behavior was preserved through existing `api.idempotencyKey()` write action handling.
- `metadata` and `payout_profile` use focused JSON fields and are parsed into object/array values before submit.
- No whole-payload JSON editor was added as the primary workflow.
- Backend, OpenAPI, Customer frontend, docs, compose, GitHub workflow, Board, decisions, tasks, and reports files were not edited.
- Customer frontend was not used.
- No seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets were written to this handoff.

## Local Dirty Files Left Untouched

These pre-existing local files were not staged or committed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Validation

Commands run:

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

Results:

```text
git diff --check: PASS
docker compose up -d postgres valkey platform-api back-office: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed: PASS
docker compose run --rm platform-api php artisan test --filter=AffiliateTest: PASS, 1 passed / 22 assertions
docker compose run --rm platform-api php artisan test --filter=CommissionTest: PASS, 3 passed / 24 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest: PASS, 5 passed / 26 assertions
docker compose run --rm back-office npm run lint: PASS
docker compose run --rm back-office npm run test: PASS
docker compose run --rm back-office npm run build: PASS
docker compose up -d --force-recreate back-office: PASS
```

Build warnings observed but non-blocking:

```text
[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```
