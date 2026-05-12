# Back Office P5 Tenant SEO Settings Pages Redirects Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-tenant-seo-settings-pages-redirects-workflows
```

## Source

Coordinator P5 tenant affiliate/commission typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-qa-report.md
```

## What Was Done

Created BO Develop implementation task:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused tenant affiliate/commission typed workflow QA passed. Coordinator promoted:

```text
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Official BO completion is now:

```text
51 / 56 menus = 91.1%
```

Remaining:

```text
3 partial
2 api_gap
```

Remaining partial rows:

```text
central:partner_monitoring
central:partner_usage
tenant:seo_settings
```

API-gap rows remain:

```text
central:master_stock
tenant:commission_transactions
```

Next implementation row:

```text
tenant:seo_settings
```

Reason it remains partial:

```text
BO exposes the tenant SEO settings route, but the full typed tenant SEO settings save plus SEO pages and redirects CRUD workflows have not been connected and workflow-tested from the real tenant BO menu.
```

## Implementation Direction Given To BO

BO Develop must:

```text
implement or surface typed tenant SEO settings save for PATCH /admin/tenant/seo
implement or surface typed SEO pages list/create/update/delete workflows
implement or surface typed redirects list/create/update/delete workflows
preserve tenant X-Tenant-Id behavior
preserve tenant scope and idempotency behavior from the existing admin API flow
use reason/context confirmation for destructive page and redirect deletes
avoid inventing detail GET endpoints for SEO pages or redirects
avoid Customer frontend usage
avoid backend, OpenAPI, docs, compose, GitHub workflow, Board, decision, task, and report edits
commit and push scoped changes
handoff back to Orchestrator
```

Backend remains frozen unless BO proves the current OpenAPI/backend contract is insufficient and Coordinator approves a backend exception.

Customer frontend remains frozen.

## Contract Notes Passed To BO

SEO settings typed fields should cover:

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

SEO pages typed fields should cover:

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

Redirects typed fields should cover:

```text
source_path
target_url
status_code
status
metadata
```

Status values:

```text
draft
active
inactive
archived
```

Redirect status code values:

```text
301
302
307
308
```

All write actions must preserve tenant scope headers and `Idempotency-Key`.

OpenAPI does not expose detail GET endpoints for SEO pages or redirects. BO must use list row/action context plus post-write list evidence instead of inventing detail routes.

## Validation Plan Given To BO

Docker-only application validation:

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

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes implementation without reporting a blocker, Orchestrator should create a focused QA Tester task for:

```text
tenant:seo_settings
```

The QA task should verify:

```text
real tenant BO menu route /admin/tenant/seo
settings GET/PATCH with tenant scope and X-Tenant-Id
typed SEO settings save fields round-trip
SEO pages list/create/update/delete with typed fields and delete reason/context
redirects list/create/update/delete with typed fields and delete reason/context
Idempotency-Key on all write calls
no detail endpoint assumptions for pages or redirects
filters/cursor behavior
Customer frontend not used
```

## Next Agent

```text
BO Develop
```
