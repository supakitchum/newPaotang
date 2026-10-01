# back-office-p5-tenant-seo-settings-pages-redirects-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened this P5 BO implementation slice after accepting `tenant:affiliate_programs`, `tenant:affiliate_accounts`, `tenant:affiliate_links`, and `tenant:commission_rules` typed workflow QA as PASS.

Coordinator source:

```text
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
```

## Objective

Perform focused QA for this row only:

```text
tenant:seo_settings
```

The retest must prove that the real tenant BO route now supports typed SEO settings save plus typed SEO pages and redirects CRUD workflows end to end, while preserving tenant scoping, idempotency, filters, cursor pagination, and the frozen backend contract.

If focused QA passes, Coordinator can decide whether to promote `tenant:seo_settings` to complete.

Customer frontend remains frozen. Do not enter the Customer frontend.

## BO Implementation Under Test

Implementation commit:

```text
f4a9d865700a2a0682f1c663bf7051fa21a7b647
```

BO handoff commit:

```text
475cbeab17ed71ecc1189ba8d7f40ad697df3e5b
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/openapi-admin-paths.snapshot.json
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
```

BO reports no backend, Customer frontend, docs, OpenAPI YAML, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/tasks/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantSeoController.php
apps/platform-api/app/Modules/AdminOperations/Services/TenantSeoService.php
apps/platform-api/tests/Feature/M10RemainingOpenApiRouteClosureTest.php
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
tenant:seo_settings
/admin/tenant/seo
```

Required shared checks:

```text
access the page from the real authenticated BO tenant menu
verify settings API loads with x-admin-scope: tenant and x-tenant-id
verify related SEO pages list API loads with x-admin-scope: tenant and x-tenant-id
verify related redirects list API loads with x-admin-scope: tenant and x-tenant-id
verify write requests include tenant scope and Idempotency-Key
verify typed forms expose expected controls
verify filters/cursor/loading/empty/error behavior remains coherent
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

## Safe Fixture Guidance

Use safe local fixture data only.

Recommended setup:

```text
update SEO settings using harmless QA title/description/keywords
create one SEO page with a unique path
update the same SEO page
delete the same SEO page after evidence is captured
create one redirect with a unique source path
update the same redirect
delete the same redirect after evidence is captured
```

Prefer unique values such as:

```text
/qa-seo-page-<short timestamp>
/qa-old-seo-page-<short timestamp>
QA Tenant SEO <short timestamp>
```

Do not use real customer data or enter the Customer frontend.

## Tenant SEO Settings QA Requirements

Required workflow:

```text
open /admin/tenant/seo from the real tenant menu
verify settings load uses GET /api/v1/admin/tenant/seo with tenant scope
verify the primary settings form is typed and not a whole-payload JSON editor
verify fields: status, default_title, title_template, default_description, default_keywords, robots_default, canonical_base_url, og_image_url
verify status options include draft, active, inactive, archived
verify default_keywords is a focused lines/tags/array control and submits an array
save a harmless settings update
verify save submits PATCH /api/v1/admin/tenant/seo with tenant scope and Idempotency-Key
verify settings response/list refresh reflects the updated values
verify blank default_keywords behavior is sane and does not break the form if tested
```

Evidence needed:

```text
request/response or browser evidence for GET /admin/tenant/seo
request evidence for PATCH /admin/tenant/seo including X-Tenant-Id and Idempotency-Key
UI evidence for typed settings fields
value round-trip evidence for at least default_title and default_keywords
```

## SEO Pages QA Requirements

Required workflow:

```text
stay inside /admin/tenant/seo
verify SEO Pages related list loads via GET /api/v1/admin/tenant/seo/pages with tenant scope
verify create modal/action is typed and exposes: path, title, description, canonical_url, robots, og_image_url, status, metadata
verify metadata accepts valid JSON object/array
create a safe local SEO page
verify create submits POST /api/v1/admin/tenant/seo/pages with tenant scope and Idempotency-Key
verify created row appears in the related list
open Update page from the real related-list row
verify update form exposes the same typed fields and pre-fills row context where applicable
update at least title, robots or status, and metadata
verify update submits PATCH /api/v1/admin/tenant/seo/pages/{page_id} with tenant scope and Idempotency-Key
verify related list refresh reflects updated values
open Delete page from the real related-list row
verify delete modal shows row context and requires reason
delete only the safe QA-created page
verify delete submits DELETE /api/v1/admin/tenant/seo/pages/{page_id} with tenant scope and Idempotency-Key
verify the row is absent from the refreshed related list after delete
```

Filter/pagination checks:

```text
verify status filter is surfaced and coherent
verify path filter is surfaced and coherent
verify cursor and limit controls or pagination remain coherent
```

Endpoint boundary:

```text
OpenAPI does not expose GET /admin/tenant/seo/pages/{page_id}
QA must not require or call a page detail endpoint.
Rows should use list row/action context plus post-write list refresh.
```

Evidence needed:

```text
UI evidence for SEO Pages related list inside /admin/tenant/seo
request evidence for GET/POST/PATCH/DELETE page APIs
tenant scope and Idempotency-Key evidence for writes
typed create/update field evidence
delete reason/context evidence
post-delete list absence evidence
```

## Redirects QA Requirements

Required workflow:

```text
stay inside /admin/tenant/seo
verify Redirects related list loads via GET /api/v1/admin/tenant/redirects with tenant scope
verify create modal/action is typed and exposes: source_path, target_url, status_code, status, metadata
verify status_code options include 301, 302, 307, 308
verify metadata accepts valid JSON object/array
create a safe local redirect
verify create submits POST /api/v1/admin/tenant/redirects with tenant scope and Idempotency-Key
verify created row appears in the related list
open Update redirect from the real related-list row
verify update form exposes the same typed fields and pre-fills row context where applicable
update at least target_url, status_code or status, and metadata
verify update submits PATCH /api/v1/admin/tenant/redirects/{redirect_id} with tenant scope and Idempotency-Key
verify related list refresh reflects updated values
open Delete redirect from the real related-list row
verify delete modal shows row context and requires reason
delete only the safe QA-created redirect
verify delete submits DELETE /api/v1/admin/tenant/redirects/{redirect_id} with tenant scope and Idempotency-Key
verify the row is absent from the refreshed related list after delete
```

Filter/pagination checks:

```text
verify status filter is surfaced and coherent
verify cursor and limit controls or pagination remain coherent
verify no source_path filter is required because the backend contract does not support it
```

Endpoint boundary:

```text
OpenAPI does not expose GET /admin/tenant/redirects/{redirect_id}
QA must not require or call a redirect detail endpoint.
Rows should use list row/action context plus post-write list refresh.
```

Evidence needed:

```text
UI evidence for Redirects related list inside /admin/tenant/seo
request evidence for GET/POST/PATCH/DELETE redirect APIs
tenant scope and Idempotency-Key evidence for writes
typed create/update field evidence
delete reason/context evidence
post-delete list absence evidence
```

## Validation

Use Docker-only application validation. Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations directly on the host.

Run:

```sh
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

Browser/real-menu QA should use the running Docker services. Do not write seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets into artifacts or handoffs.

## QA Report Required

Create:

```text
ai-agents/reports/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa/**
```

The report must include:

```text
PASS or FAIL
commit under test
files changed by QA
validation commands and results
any skipped command with blocker reason
real tenant menu route evidence
settings GET/PATCH evidence
SEO pages list/create/update/delete evidence
redirects list/create/update/delete evidence
tenant scope and X-Tenant-Id evidence
Idempotency-Key evidence for all write calls
confirmation that Customer frontend was not used
confirmation that no page/redirect detail endpoint was required
unrelated dirty files left untouched
```

If QA finds defects, report:

```text
severity
affected workflow
exact reproduction steps
expected versus actual behavior
likely owner
artifact paths
```

QA should not patch implementation. Route findings to Coordinator.

## Next Agent

After QA completes:

```text
Coordinator
```

Coordinator will decide whether to promote `tenant:seo_settings` to complete or route remediation.
