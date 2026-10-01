# Back Office P5 Tenant SEO Settings Pages Redirects Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO tenant SEO settings/pages/redirects workflow implementation to QA Tester.

## Source

Coordinator P5 tenant affiliate/commission typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
```

BO implementation task and handoff:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo.md
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: f4a9d865700a2a0682f1c663bf7051fa21a7b647
BO handoff commit: 475cbeab17ed71ecc1189ba8d7f40ad697df3e5b
```

BO added typed tenant workflows for:

```text
tenant:seo_settings
```

Tenant SEO settings workflow:

```text
typed settings save via PATCH /admin/tenant/seo
typed fields: status, default_title, title_template, default_description, default_keywords, robots_default, canonical_base_url, og_image_url
default_keywords uses a focused lines control and submits an array
```

SEO pages workflow:

```text
related list via GET /admin/tenant/seo/pages inside /admin/tenant/seo
typed create via POST /admin/tenant/seo/pages
typed update via PATCH /admin/tenant/seo/pages/{page_id}
reason-confirmed delete via DELETE /admin/tenant/seo/pages/{page_id}
status, path, cursor, and limit list behavior surfaced where supported
```

Redirects workflow:

```text
related list via GET /admin/tenant/redirects inside /admin/tenant/seo
typed create via POST /admin/tenant/redirects
typed update via PATCH /admin/tenant/redirects/{redirect_id}
reason-confirmed delete via DELETE /admin/tenant/redirects/{redirect_id}
status, cursor, and limit list behavior surfaced where supported
source_path filter not surfaced because backend does not support it
```

BO reports tenant scope, `X-Tenant-Id`, idempotency behavior, settings loading/error/save states, related list loading/error/empty states, backend freeze, and customer frontend freeze were preserved.

BO also reports no detail GET endpoint was invented for SEO pages or redirects.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
tenant:seo_settings
real authenticated tenant menu route /admin/tenant/seo
typed tenant SEO settings save
typed SEO pages list/create/update/delete workflows
typed redirects list/create/update/delete workflows
tenant scope and X-Tenant-Id evidence
idempotency evidence for all write calls
delete reason/context evidence
no page/redirect detail endpoint assumptions
```

QA must not enter the Customer frontend.

## Validation Plan Given To QA

Docker-only:

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

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected QA Output

```text
ai-agents/reports/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `tenant:seo_settings` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester
