# back-office-p5-tenant-seo-settings-pages-redirects-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted focused QA for `back-office-p5-tenant-affiliate-commission-typed-workflows` as PASS and promoted these rows to complete:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Official BO completion is now:

```text
51 / 56 complete = 91.1%
3 partial
2 api_gap
```

Coordinator opened the next BO implementation slice:

```text
back-office-p5-tenant-seo-settings-pages-redirects-workflows
```

Expected first owner:

```text
BO Develop
```

Scope:

```text
tenant:seo_settings
```

Source decision and handoff:

```text
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: 2b41518d427524fe0b88bb00ffa48afa87bdbd41
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
tenant:seo_settings
```

This row remains partial because BO exposes the tenant SEO settings route, but the full typed tenant SEO settings save plus SEO pages and redirects CRUD workflows have not been connected and workflow-tested from the real tenant BO menu. This task should make the row ready for focused QA. Do not mark the row complete; Coordinator will decide after QA.

## Required BO Direction

Implement BO only.

Required behavior:

```text
preserve the real tenant BO menu route /admin/tenant/seo
preserve tenant X-Tenant-Id behavior
preserve tenant scope headers
preserve idempotency behavior from the existing admin API flow
replace or supplement generic JSON payload workflows with typed controls
use safe local fixtures and avoid destructive production-like assumptions
do not change backend or OpenAPI contract
do not use Customer frontend
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Other `apps/back-office/**` files may be edited only if the typed workflows require existing shared form/action behavior to support the contracts cleanly.

## tenant:seo_settings Requirements

Current row status from coverage docs:

```text
route: /admin/tenant/seo
settings route connected
SEO pages and redirects CRUD APIs exist
BO currently exposes settings JSON editor only
pages/redirects workflows are not connected
workflow remains partial
```

Required typed settings workflow:

```text
typed settings save for PATCH /admin/tenant/seo
list/read from GET /admin/tenant/seo must remain intact
all settings write calls must include Idempotency-Key
tenant scope headers must remain intact
```

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

Contract notes:

```text
status accepts draft, active, inactive, archived
default_title cannot be blank when supplied
default_keywords must submit as an array
default_keywords may use a focused lines/tags control or another typed array control
canonical_base_url and og_image_url are nullable strings
the backend also accepts nested seo payloads, but a flat typed PATCH payload is acceptable
```

Do not use a whole-payload JSON editor as the primary settings workflow.

## SEO Pages Requirements

Required APIs:

```text
GET /admin/tenant/seo/pages
POST /admin/tenant/seo/pages
PATCH /admin/tenant/seo/pages/{page_id}
DELETE /admin/tenant/seo/pages/{page_id}
```

Required typed workflow:

```text
list SEO pages from the real tenant SEO menu experience
typed create for POST /admin/tenant/seo/pages
typed update for PATCH /admin/tenant/seo/pages/{page_id}
reason/context-confirmed delete for DELETE /admin/tenant/seo/pages/{page_id}
post-write list refresh or row evidence must be available for QA
```

Typed create/update fields:

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

Contract notes:

```text
path and title are required on create
path is normalized by the backend and must be unique per tenant
status accepts draft, active, inactive, archived
robots defaults to index,follow on create
metadata is stored as metadata_json
metadata must submit as an object/array; a focused JSON/object field is acceptable
DELETE hard-deletes and returns 204
```

List/filter behavior:

```text
backend supports status, path, cursor, and limit
surface status/cursor/limit behavior if the existing list pattern supports it
surface path filter if feasible without broad shared component changes
```

Important endpoint boundary:

```text
OpenAPI does not expose GET /admin/tenant/seo/pages/{page_id}
Do not invent a detail route for SEO pages.
Use list row/action context plus post-write list evidence for QA.
```

Do not use a whole-payload JSON editor as the primary create/update workflow.

## Redirects Requirements

Required APIs:

```text
GET /admin/tenant/redirects
POST /admin/tenant/redirects
PATCH /admin/tenant/redirects/{redirect_id}
DELETE /admin/tenant/redirects/{redirect_id}
```

Required typed workflow:

```text
list redirects from the real tenant SEO menu experience
typed create for POST /admin/tenant/redirects
typed update for PATCH /admin/tenant/redirects/{redirect_id}
reason/context-confirmed delete for DELETE /admin/tenant/redirects/{redirect_id}
post-write list refresh or row evidence must be available for QA
```

Typed create/update fields:

```text
source_path
target_url
status_code
status
metadata
```

Contract notes:

```text
source_path and target_url are required on create
source_path is normalized by the backend and must be unique per tenant
status_code accepts 301, 302, 307, 308 and defaults to 301 on create
status accepts draft, active, inactive, archived
metadata is stored as metadata_json
metadata must submit as an object/array; a focused JSON/object field is acceptable
DELETE hard-deletes and returns 204
```

List/filter behavior:

```text
backend supports status, cursor, and limit
backend does not support a source_path list filter
do not surface a source_path filter unless the backend contract changes through Coordinator
```

Important endpoint boundary:

```text
OpenAPI does not expose GET /admin/tenant/redirects/{redirect_id}
Do not invent a detail route for redirects.
Use list row/action context plus post-write list evidence for QA.
```

Do not use a whole-payload JSON editor as the primary create/update workflow.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantSeoController.php
apps/platform-api/app/Modules/AdminOperations/Services/TenantSeoService.php
apps/platform-api/tests/Feature/M10RemainingOpenApiRouteClosureTest.php
```

## Backend Contract References

Existing backend routes:

```text
GET /admin/tenant/seo
PATCH /admin/tenant/seo

GET /admin/tenant/seo/pages
POST /admin/tenant/seo/pages
PATCH /admin/tenant/seo/pages/{page_id}
DELETE /admin/tenant/seo/pages/{page_id}

GET /admin/tenant/redirects
POST /admin/tenant/redirects
PATCH /admin/tenant/redirects/{redirect_id}
DELETE /admin/tenant/redirects/{redirect_id}
```

Existing permissions:

```text
seo.view
seo.update
seo.redirect.manage
```

Route permission map:

```text
GET /admin/tenant/seo -> seo.view
PATCH /admin/tenant/seo -> seo.update
GET /admin/tenant/seo/pages -> seo.view
POST /admin/tenant/seo/pages -> seo.update
PATCH /admin/tenant/seo/pages/{page_id} -> seo.update
DELETE /admin/tenant/seo/pages/{page_id} -> seo.update
GET /admin/tenant/redirects -> seo.view
POST /admin/tenant/redirects -> seo.redirect.manage
PATCH /admin/tenant/redirects/{redirect_id} -> seo.redirect.manage
DELETE /admin/tenant/redirects/{redirect_id} -> seo.redirect.manage
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
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
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
docker compose run --rm platform-api php artisan test --filter=tenant_seo_redirects_and_public_content_use_tenant_sources
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
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
```

The handoff must include:

```text
implementation commit hash
files changed
exact typed fields/actions surfaced for tenant SEO settings
exact typed fields/actions surfaced for SEO pages
exact typed fields/actions surfaced for redirects
confirmation that no page/redirect detail GET endpoint was invented
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
real tenant BO menu route /admin/tenant/seo
settings GET/PATCH with tenant scope and X-Tenant-Id
settings PATCH includes Idempotency-Key
typed SEO settings save fields round-trip
SEO pages list/create/update/delete with typed fields
SEO pages delete shows row context and requires reason
redirects list/create/update/delete with typed fields
redirects delete shows row context and requires reason
all page and redirect write calls include Idempotency-Key
no detail endpoint assumptions for pages or redirects
filters/cursor behavior remains coherent
Customer frontend not used
```

Do not write seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets into artifacts or handoffs.

## Next Agent

After BO Develop completes and pushes:

```text
Orchestrator
```

Orchestrator will create the focused QA Tester task for `tenant:seo_settings`.
