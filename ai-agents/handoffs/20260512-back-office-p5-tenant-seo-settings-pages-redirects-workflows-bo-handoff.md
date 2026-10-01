# back-office-p5-tenant-seo-settings-pages-redirects-workflows - BO Handoff

## Summary

BO Develop implemented typed back-office workflows for:

```text
tenant:seo_settings
```

Implementation commit:

```text
f4a9d865700a2a0682f1c663bf7051fa21a7b647
```

Next Agent:

```text
Orchestrator
```

## Files Changed

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

Handoff file:

```text
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
```

## Tenant SEO Settings Workflow

Real tenant BO route preserved:

```text
/admin/tenant/seo
```

Preserved API connections:

```text
GET /admin/tenant/seo
PATCH /admin/tenant/seo
```

Primary settings save is now typed instead of whole-payload JSON.

Typed settings fields:

```text
status
default_title
title_template
default_description
default_keywords
robots_default
canonical_base_url
og_image_url
```

Settings field behavior:

```text
status accepts draft, active, inactive, archived
default_keywords uses a focused lines control and submits an array
blank default_keywords submits an empty array instead of omitting the field
canonical_base_url and og_image_url remain nullable string controls
```

Write behavior:

```text
PATCH /admin/tenant/seo uses the existing settings form save path
Idempotency-Key is preserved through api.idempotencyKey()
X-Admin-Scope and X-Tenant-Id are preserved through useAdminApi/apiOptions
```

## SEO Pages Workflow

SEO pages are surfaced as a related workflow inside the real tenant SEO menu route:

```text
/admin/tenant/seo
```

Preserved API connections:

```text
GET /admin/tenant/seo/pages
POST /admin/tenant/seo/pages
PATCH /admin/tenant/seo/pages/{page_id}
DELETE /admin/tenant/seo/pages/{page_id}
```

Typed create action:

```text
POST /admin/tenant/seo/pages
```

Typed create fields:

```text
path
title
description
canonical_url
robots
og_image_url
status
metadata
```

Typed update action:

```text
PATCH /admin/tenant/seo/pages/{page_id}
```

Typed update fields:

```text
path
title
description
canonical_url
robots
og_image_url
status
metadata
```

Typed delete action:

```text
DELETE /admin/tenant/seo/pages/{page_id}
```

Delete behavior:

```text
delete requires reason
delete shows row context
post-write load refreshes settings and related lists
```

Delete/update context fields:

```text
id
tenant_id
path
title
status
robots
canonical_url
og_image_url
metadata
updated_at
```

List/filter behavior:

```text
GET /admin/tenant/seo/pages list is loaded from the SEO route related list
status filter is surfaced
path filter is surfaced
cursor and limit controls are surfaced
related list pagination is surfaced through AdminPagination
```

Endpoint boundary:

```text
No GET /admin/tenant/seo/pages/{page_id} detail endpoint was invented.
Rows use list row/action context plus post-write list refresh.
```

## Redirects Workflow

Redirects are surfaced as a related workflow inside the real tenant SEO menu route:

```text
/admin/tenant/seo
```

Preserved API connections:

```text
GET /admin/tenant/redirects
POST /admin/tenant/redirects
PATCH /admin/tenant/redirects/{redirect_id}
DELETE /admin/tenant/redirects/{redirect_id}
```

Typed create action:

```text
POST /admin/tenant/redirects
```

Typed create fields:

```text
source_path
target_url
status_code
status
metadata
```

Typed update action:

```text
PATCH /admin/tenant/redirects/{redirect_id}
```

Typed update fields:

```text
source_path
target_url
status_code
status
metadata
```

Typed delete action:

```text
DELETE /admin/tenant/redirects/{redirect_id}
```

Delete behavior:

```text
delete requires reason
delete shows row context
post-write load refreshes settings and related lists
```

Delete/update context fields:

```text
id
tenant_id
source_path
target_url
status_code
status
metadata
updated_at
```

List/filter behavior:

```text
GET /admin/tenant/redirects list is loaded from the SEO route related list
status filter is surfaced
cursor and limit controls are surfaced
related list pagination is surfaced through AdminPagination
source_path filter was not surfaced because the backend contract does not support it
```

Endpoint boundary:

```text
No GET /admin/tenant/redirects/{redirect_id} detail endpoint was invented.
Rows use list row/action context plus post-write list refresh.
```

## Shared BO Support Added

`AdminOperationsPage` now supports filters and cursor pagination for related lists. Existing related list create/update/delete flows still use:

```text
AdminFilterBar
AdminExportPanel
AdminDataTable
AdminConfirmAction
AdminPagination
```

`OperationFormField.emptyValue = array` was added for focused lines controls that must submit an empty array instead of omitting the field. This is used by `default_keywords`.

The back-office OpenAPI snapshot was refreshed for already-approved SEO pages and redirects admin paths so the BO lint guard can validate the new catalog endpoints against the frozen contract.

## Scope Confirmations

- Existing tenant route `/admin/tenant/seo` was preserved.
- Tenant scope and `X-Tenant-Id` behavior were preserved through the existing `useAdminApi` flow.
- Idempotency behavior was preserved for all write actions through existing `api.idempotencyKey()` handling.
- Existing settings loading/error/save states were reused.
- Existing related list loading/error/empty states were reused.
- No Customer frontend was used.
- Backend, Customer frontend, docs, OpenAPI YAML, compose, GitHub workflow, Board, decisions, tasks, and reports files were not edited.
- No seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets were written to this handoff.

## Local Dirty Files Left Untouched

These pre-existing local files were not staged or committed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` contains a local QA credential and remains uncommitted.

## Validation

Commands run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=tenant_seo_redirects_and_public_content_use_tenant_sources
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Results:

```text
git fetch --all --prune: PASS
git status --short --branch: expected unrelated dirty files only outside BO scope
git rev-parse HEAD before implementation: 8b74aae50598460d1c693b31e05f17693824ce2d
git diff --check: PASS
docker compose up -d postgres valkey platform-api back-office: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed: PASS
docker compose run --rm platform-api php artisan test --filter=tenant_seo_redirects_and_public_content_use_tenant_sources: PASS, 1 passed / 24 assertions
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

Browser smoke check:

```text
http://localhost:3100/admin/tenant/seo redirected to /login?redirect=/admin/tenant/seo with the login guard visible.
No authenticated customer or BO credential was used.
```

Lint note:

```text
An initial lint run flagged the stale back-office OpenAPI snapshot for SEO pages and redirects.
The snapshot was refreshed from the already-approved docs/openapi.yaml paths inside apps/back-office, then final lint/test/build passed.
```
