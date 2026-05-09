# 20260509-m10-bo-menu-completion-backend-ready-wiring - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator opened:

```text
20260509-m10-bo-menu-completion-remediation
```

BO Develop completed the first BO-side menu remediation and Backend Develop completed:

```text
20260509-m10-bo-menu-completion-backend-gap-remediation
```

Backend now reports the previously controlled backend gaps are registered, tested, and backend-ready.

Open focused BO follow-up:

```text
20260509-m10-bo-menu-completion-backend-ready-wiring
```

Do not trigger Gate 5 or move to a new milestone. This remains inside M10 release-gate follow-up work.

## Objective

Replace BO controlled `apiGap` pages with API-backed BO rendering for the routes Backend just implemented.

The user-facing outcome:

```text
Visible BO menu items that were converted from misleading fallback pages to controlled gap pages should now become operational API-backed pages where Backend has route coverage.
```

## Source Of Truth

- `ai-agents/tasks/20260509-m10-bo-menu-completion-remediation-bo.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md`
- `ai-agents/tasks/20260509-m10-bo-menu-completion-backend-gap-remediation-backend.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/back-office-menu-completion.md`
- `docs/back-office-admin-foundation.md`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/components/AdminDataTable.vue`
- `apps/back-office/components/AdminFilterBar.vue`
- `apps/back-office/components/AdminExportPanel.vue`
- `apps/back-office/components/AdminConfirmAction.vue`
- `apps/back-office/components/AdminDefinitionList.vue`
- `apps/back-office/components/AdminDetailSection.vue`
- `apps/back-office/components/AdminReportPanel.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/BoMenuCompletionBackendGapTest.php`

## Scope

Wire BO catalog/pages to the backend-ready endpoints.

Central routes to convert from `apiGap` to API-backed resources:

```text
/admin/central/partner-monitoring
/admin/central/partner-monitoring/{monitoring_profile_id}
/admin/central/partner-usage
/admin/central/partner-usage/{usage_meter_id}
/admin/central/billing-plans
/admin/central/billing-plans/{billing_plan_id}
/admin/central/alert-policies
/admin/central/alert-policies/{alert_policy_id}
/admin/central/alert-events
/admin/central/alert-events/{alert_event_id}
/admin/central/system-settings
/admin/central/webhook-logs
/admin/central/webhook-logs/{webhook_log_id}
```

Tenant routes to convert from `apiGap` to API-backed resources:

```text
/admin/tenant/price-rules
/admin/tenant/price-rules/{price_rule_id}
/admin/tenant/members
/admin/tenant/members/{member_id}
/admin/tenant/monitoring
/admin/tenant/usage
```

Include supported actions where safe and already covered by Backend:

```text
POST/PATCH billing plans with idempotency
POST/PATCH alert policies with idempotency
POST acknowledge/resolve alert events with idempotency
PATCH system settings with idempotency
POST/PATCH price rules with idempotency
POST/PATCH members and member status action with idempotency
```

Expected implementation areas:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue if the generic page needs small support for these response shapes/actions
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md only if the contract changes
```

## Out Of Scope

- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not change backend API paths, OpenAPI contracts, permissions, business rules, or RBAC semantics.
- Do not implement backend routes intentionally left outside the previous backend scope, such as central monitoring/usage PATCH routes or tenant price-rule DELETE, unless they are already present and needed only as read-safe catalog metadata.
- Do not remove the generic `apiGap` support entirely if it remains useful for future controlled gaps; remove or replace only stale gap resources that Backend now made operational.
- Do not approve or claim Meno legal/license compliance.
- Do not approve or claim npm audit remediation/deferral.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not reopen the already approved protected deep-link/mobile overflow remediation except for regression validation.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/docker-runtime-policy.md
docs/permissions.md
docs/api-conventions.md
docs/status-enums.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Compare Backend handoff endpoint list with current `useAdminOperationsCatalog.ts` `apiGapResource(...)` entries.
5. Replace stale `apiGapResource(...)` entries for backend-ready routes with proper `OperationResource` definitions:

```text
columns
filters
listEndpoint
detailEndpoint where available
idParam
idKey
actions and collectionActions where Backend implemented safe writes
accurate titles/groups
```

6. Ensure BO calls documented `/admin/...` API paths through `useAdminApi`, not raw `/api/v1/...` URLs.
7. For response shapes that are summaries rather than rows, use an existing report/settings/detail pattern or make a small generic enhancement in `AdminOperationsPage.vue` rather than a one-off hardcoded page.
8. Update `apps/back-office/scripts/check.mjs`:

```text
fail if backend-ready routes still use apiGapResource messages saying routes are not registered
verify catalog entries for every backend-ready route
keep route override guardrails against dashboard/settings/reports/partners/agents fallback regressions
keep protected deep-link and mobile no-overflow guardrails
```

9. Update `apps/back-office/scripts/openapi-admin-paths.snapshot.json` if the BO snapshot must include newly consumed admin paths.
10. Update `docs/back-office-menu-completion.md` so Backend-ready items become `Complete` or otherwise accurately reflect BO wiring.
11. Update `docs/back-office-admin-foundation.md` only if the menu/page contract changes.
12. Preserve:

```text
protected hard-refresh/deep-link behavior
mobile 390x844 admin shell no-overflow behavior
sessionStorage auth restore and stale marker safety
tenant X-Tenant-Id behavior
menu route overrides that prevent unrelated fallback pages
```

13. Run Docker-only validation commands.
14. Capture browser/runtime evidence where tooling allows.
15. Write BO handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Stale gap messages saying Laravel routes are not registered are removed for Backend-ready routes.
- Backend-ready central partner monitoring/usage, billing plans, alert policies/events, system settings, and webhook logs render API-backed BO pages.
- Backend-ready tenant price rules, customers/members, monitoring, and usage render API-backed BO pages.
- Detail pages work where Backend provides detail endpoints.
- Supported idempotent actions are wired only where Backend implemented them and with existing confirmation/idempotency behavior.
- BO route override guardrails remain intact and no visible menu item silently returns to unrelated fallback pages.
- `docs/back-office-menu-completion.md` accurately marks fully wired routes as complete and documents any remaining limitations.
- Protected central/tenant hard refresh and deep-link behavior remains fixed.
- Mobile `390x844` tenant maintenance remains free of horizontal overflow.
- BO lint, test, and build pass through Docker.
- Backend route-list and focused backend gap tests pass through Docker as integration guardrails.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup and BO checks:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Required backend guardrails:

```sh
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/partner-monitoring
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/billing-plans
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/alert-events
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/price-rules
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/members
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/monitoring
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "apiGapResource|not registered in routes/api.php|partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|system-settings|webhook-logs|price-rules|customers|members|monitoring|usage" apps/back-office/composables/useAdminOperationsCatalog.ts apps/back-office/components/AdminOperationsPage.vue apps/back-office/scripts/check.mjs docs/back-office-menu-completion.md docs/back-office-admin-foundation.md
rg -n "newpaotang_bo_session|AdminProtectedContent|restore shell|hard refresh|sessionStorage|max-width: 100vw|app-sidebar" apps/back-office/middleware/admin.global.ts apps/back-office/components/AdminProtectedContent.vue apps/back-office/assets/css/admin-foundation.css apps/back-office/scripts/check.mjs
```

Browser/runtime evidence should cover at least:

```text
central partner monitoring route loads API-backed content
central partner usage route loads API-backed content
central billing plans route loads API-backed content
central alert events route loads API-backed content
central system settings route loads API-backed content
central webhook logs route loads API-backed content
tenant price rules route loads API-backed content
tenant customers route loads API-backed members content
tenant monitoring route loads API-backed content
tenant usage route loads API-backed content
central /admin/central/partners hard refresh still works
tenant /admin/tenant/maintenance hard refresh still works
mobile 390x844 /admin/tenant/maintenance remains no-overflow
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
```

Must include:

```text
what was done
files changed
backend-ready routes wired
remaining apiGap resources, if any, and why
actions enabled/withheld and why
static guardrails added/updated
docs updated
protected deep-link and mobile no-overflow regression evidence
Docker validation commands and results
browser/runtime evidence and artifact paths if captured
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```
