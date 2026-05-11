# back-office-p5-tenant-price-rules-customers-typed-workflows - BO Handoff

## Summary

BO Develop implemented typed back-office workflows for:

```text
tenant:price_rules
tenant:customers
```

Implementation commit:

```text
10ce1bfb720d561e0fab6f886c45f04337a6e239
```

Next Agent:

```text
Orchestrator
```

## Changed Files

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

## UI Pages And Components Changed

- `tenant:price_rules` now uses typed create/update actions instead of whole-payload JSON as the primary workflow.
- `tenant:price_rules` now surfaces a destructive `Archive` action using `DELETE /admin/tenant/price-rules/{price_rule_id}` with reason and record context confirmation.
- `tenant:customers` now uses typed create/update/status actions instead of whole-payload JSON as the primary workflow.
- `tenant:customers` status action now shows member context, has selectable status values, and requires a reason.
- `AdminConfirmAction.vue` and `AdminOperationsPage.vue` now support a focused `json` form field type for object/array payload fields such as price rule `conditions`.
- `openapi-admin-paths.snapshot.json` was updated to include the already-documented price rule `DELETE` method so the BO catalog checker accepts the surfaced archive action.

## Template References Used

Existing Meno/Bootstrap back-office operation patterns were preserved:

```text
AdminOperationsPage
AdminConfirmAction
AdminExportPanel
AdminDataTable
AdminStatusBadge
AdminModal
btn btn-primary/btn-danger btn-wave
form-control/form-select/form-check
```

No new design system was introduced.

## API Endpoints Consumed

Price rules:

```text
GET /admin/tenant/price-rules
POST /admin/tenant/price-rules
GET /admin/tenant/price-rules/{price_rule_id}
PATCH /admin/tenant/price-rules/{price_rule_id}
DELETE /admin/tenant/price-rules/{price_rule_id}
```

Customers/members:

```text
GET /admin/tenant/members
POST /admin/tenant/members
GET /admin/tenant/members/{member_id}
PATCH /admin/tenant/members/{member_id}
POST /admin/tenant/members/{member_id}/status
```

## Typed Fields And Actions

Price rule create fields:

```text
code
name
game_id
rule_type
price_amount
currency
conditions
status
```

Price rule update fields:

```text
code
name
game_id
rule_type
price_amount
currency
conditions
status
```

Price rule archive/delete:

```text
method: DELETE
reason: required
context: id, tenant_id, code, name, game_id, rule_type, price, status, conditions, updated_at
```

Customer/member create fields:

```text
name
phone
email
password
status
send_invitation
```

Customer/member update fields:

```text
name
phone
email
admin_note
```

Member status action fields:

```text
status
notify_member
reason
```

Member status context:

```text
id, tenant_id, member_no, name, phone, email, status, order_count, lifetime_spend, updated_at
```

## Responsive/Error/Loading States

The workflows use the existing operation modal/table/loading/error states:

```text
AdminApiState
AdminLoader
AdminConfirmAction loading/error state
AdminDataTable empty/loading state
AdminPagination
```

The focused JSON field is rendered as a full-width textarea so long object/array values do not squeeze into compact columns.

## Scope Confirmations

- Existing list/detail/filter/cursor behavior was preserved for both rows.
- Existing `useAdminApi` tenant scope behavior was preserved.
- Tenant requests continue through the existing admin API flow with `X-Admin-Scope: tenant` and `X-Tenant-Id`.
- Existing idempotency behavior was preserved through `api.idempotencyKey()` in `AdminOperationsPage`.
- Customer frontend was not used.
- No real customer data or secrets were copied into artifacts.
- No `password_hash` is surfaced by the BO catalog.
- No backend, OpenAPI contract, Customer frontend, docs, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed.

## Validation

Commands run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
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
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest: PASS, 3 passed / 161 assertions
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

## Known Unrelated Dirty Files Left Untouched

These files existed or were runtime/test artifacts outside BO scope and were not staged or committed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Known Risks Or QA Notes

- `conditions` must be valid JSON and must parse to an object or array.
- `rule_type` is a typed text field with default `fixed_price` because the backend currently accepts a string/default rather than documenting a fixed enum for price rules.
- `admin_note` is included in the member update form per OpenAPI task requirements; current backend behavior records the submitted payload for audit context but does not echo `admin_note` on the member resource.
- QA should use safe local fixture members only and should not enter the Customer frontend.
