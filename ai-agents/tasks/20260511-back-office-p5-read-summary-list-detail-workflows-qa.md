# back-office-p5-read-summary-list-detail-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted P4 remaining admin/security/settings closure QA as PASS and opened P5 remaining partial workflow closure planning.

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-report.md
docs/back-office-crud-coverage.md
```

Official BO completion before this task:

```text
36 / 56 complete = 64.3% verified complete
```

Remaining coverage:

```text
18 partial
2 api_gap
```

This is the first P5 QA-only slice for remaining read/summary/list/detail workflows that do not require new typed create/update/delete implementation before QA.

## Objective

Verify real authenticated BO menu workflows for read-only or read-mostly remaining partial rows.

Do not count route/catalog/menu presence alone. A row should only be recommended for Coordinator completion if QA verifies the real BO menu workflow, API-backed data loading, useful operator-visible content, loading/error/empty behavior where practical, scope headers where applicable, and no missing workflow requirement in the current frozen backend contract.

Do not mark rows complete directly; report evidence to Coordinator.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/pages/admin/central/dashboard.vue
apps/back-office/pages/admin/tenant/dashboard.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Dashboard*
apps/platform-api/tests/Feature/*Affiliate*
```

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

Test these rows:

```text
central:dashboard
tenant:dashboard
tenant:tickets
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

Browser routes:

```text
/admin/central/dashboard
/admin/tenant/dashboard
/admin/tenant/tickets
/admin/tenant/growth/attributions
/admin/tenant/monitoring
/admin/tenant/usage
```

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

### central:dashboard

Verify:

```text
real central menu opens dashboard
summary API loads successfully
cards/charts/tables show useful operator data or coherent empty state
refresh/reload path works
hard refresh does not render login with authenticated central session
central scope header is correct where API requests are captured
```

Capture browser and API evidence. If dashboard has no write workflow, completion can be recommended as read-summary workflow only if the page is useful and API-backed.

### tenant:dashboard

Verify:

```text
real tenant menu opens dashboard
summary API loads successfully with tenant scope
cards/charts/tables show useful tenant operator data or coherent empty state
refresh/reload path works
hard refresh does not render login with authenticated tenant session
x-admin-scope is tenant and x-tenant-id is ten_demo_alpha where requests are captured
```

Capture browser and API evidence.

### tenant:tickets

Verify:

```text
real tenant menu opens tickets route
list loads from GET /admin/tenant/tickets
safe fixture ticket exists or is created through Docker/API fixture setup
detail opens from a real row using GET /admin/tenant/tickets/{ticket_id}
operator-visible ticket/customer/order/status context is useful
filters/search/cursor/loading/empty/error behavior is coherent where supported
no Customer frontend is used
x-admin-scope is tenant and x-tenant-id is ten_demo_alpha
```

If the seeded page has no links, create safe local fixture data or use API evidence to seed a row, then verify real BO list/detail. Do not enter Customer UI.

### tenant:affiliate_attributions

Verify:

```text
real tenant menu opens affiliate attributions route
list loads from GET /admin/tenant/affiliate-attributions
safe fixture attribution exists or is created through Docker/API fixture setup
detail opens from a real row using GET /admin/tenant/affiliate-attributions/{attribution_id}
operator-visible affiliate/link/order/customer/commission/status context is useful
filters/search/cursor/loading/empty/error behavior is coherent where supported
x-admin-scope is tenant and x-tenant-id is ten_demo_alpha
```

This row is read-only by current contract. Do not invent write requirements.

### tenant:monitoring

Verify:

```text
real tenant menu opens monitoring route
summary API loads from GET /admin/tenant/monitoring
operator-visible runtime/health/alert context is useful or empty state is coherent
filters/refresh/loading/error behavior is coherent where supported
x-admin-scope is tenant and x-tenant-id is ten_demo_alpha
```

This row is read-summary by current contract. Do not invent write requirements.

### tenant:usage

Verify:

```text
real tenant menu opens usage route
summary API loads from GET /admin/tenant/usage
operator-visible usage/meter/quota context is useful or empty state is coherent
filters/refresh/loading/error behavior is coherent where supported
x-admin-scope is tenant and x-tenant-id is ten_demo_alpha
```

This row is read-summary by current contract. Do not invent write requirements.

## Explicitly Out Of This QA Slice

Do not test or decide these rows in this task:

```text
central:games
central:partner_monitoring
central:partner_usage
tenant:price_rules
tenant:customers
tenant:agents
tenant:agent_quotas
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
tenant:seo_settings
```

Planning notes for those rows are in:

```text
ai-agents/handoffs/20260511-back-office-p5-remaining-partial-workflow-closure-planning-orchestrator-handoff.md
```

## Cross-Cutting QA Requirements

Verify:

```text
real menu navigation, not route/catalog presence alone
API-backed data loading, not static shell only
central/tenant scope headers where applicable
hard refresh keeps authenticated route and does not render login
loading/error/empty states are coherent where practical
no Customer frontend usage
no seeded passwords, bearer tokens, local credentials, private keys, or one-time tokens in artifacts
mobile sanity at 390x844 for at least one dashboard/summary route and one list/detail route
known carry-forward Vue hydration warnings, Node DEP0180, Meno media-33.jpg, or git gc warnings are recorded only if observed and not treated as new blockers unless behavior regresses
```

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
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, or scheduler commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, local credentials, private keys, seeded passwords, or unredacted one-time tokens into artifacts
use Customer frontend
change backend validation, tenant isolation, permission, or security semantics
mark rows complete
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Run Docker-only validation commands.
5. Seed local backend data before API/browser QA.
6. Create only safe local Docker/API fixture data needed for list/detail evidence.
7. Capture API evidence before browser workflow submission.
8. Test real authenticated BO central and tenant menus for all scoped rows.
9. Capture screenshots/snapshots/text artifacts for real-menu navigation, API-backed content, detail routes, scope evidence, empty/loading states where practical, and mobile sanity.
10. Redact secrets/tokens/local credentials from artifacts before committing.
11. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

If a test filter has no matching tests, record the exact command/output in the QA report and continue with the remaining validation and browser/API evidence.

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
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/**
```

Report must include:

```text
HEAD under test
Docker validation command results
API evidence summary
browser evidence summary
per-row PASS/FAIL/HOLD status for all scoped rows
dashboard/summary workflow results
ticket and attribution list/detail results
tenant monitoring/usage results
central/tenant scope and X-Tenant-Id results
mobile sanity results
secret/token redaction statement
defects with severity, owner recommendation, and evidence path
rows recommended for Coordinator completion promotion, if any
rows that must remain partial, if any
unrelated dirty workspace files observed
```

Artifacts should include:

```text
validation command logs
API evidence for list/detail/summary endpoints
browser screenshots and text snapshots for real-menu navigation
detail page/list row evidence
scope/header evidence where practical
mobile screenshots for selected summary and list/detail workflows
```

## Routing After QA

Route back to:

```text
Coordinator
```

If QA passes, Coordinator can decide whether to promote scoped rows. If QA finds defects, report severity and likely owner. If QA finds frozen contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing implementation.
