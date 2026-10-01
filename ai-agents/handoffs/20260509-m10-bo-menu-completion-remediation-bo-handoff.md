# BO Menu Completion Remediation Handoff

Date: 2026-05-09
Agent: BO Develop
Next Agent: Orchestrator

## What Was Done

- Added scoped BO navigation overrides so seeded RBAC menu items that currently point to unrelated backend fallback routes resolve to specific BO routes first.
- Expanded the BO operations catalog for API-backed menu coverage:
  - central admin users, roles, menu management, partner provisioning, partner quotas
  - tenant admin users, roles, menu management, agent quotas
- Added controlled `apiGap` handling in `AdminOperationsPage.vue` so known backend route gaps render an explicit message and do not issue failing fetches.
- Added PUT support for settings-style operations so central/tenant menu management can use documented `GET`/`PUT` APIs.
- Updated the OpenAPI admin path snapshot for the newly cataloged API-backed endpoints.
- Created full inventory doc at `docs/back-office-menu-completion.md`.
- Updated `docs/back-office-admin-foundation.md` with menu completion route contract and new route coverage.
- Strengthened `apps/back-office/scripts/check.mjs` to catch known unapproved fallback route regressions and ensure new catalog/gap handling remains present.

## Files Changed

- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `docs/back-office-admin-foundation.md`
- `docs/back-office-menu-completion.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md`

## Full Menu Inventory Summary

Full row-level inventory is in `docs/back-office-menu-completion.md`.

- Central menus: 24 total.
- Central complete/API-backed: 13.
- Central shared accepted generic pages: 4 (`prize_checking`, `master_stock`, `stock_generation`, `stock_recall`).
- Central controlled gap pages: 7 (`partner_monitoring`, `partner_usage`, `billing_plans`, `alert_policies`, `alert_events`, `webhook_logs`, `system_settings`).
- Tenant menus: 32 total.
- Tenant complete/API-backed: 28.
- Tenant controlled gap pages: 4 (`price_rules`, `customers`, `monitoring`, `usage`).

## Implemented Menu/Page Coverage

- `central:admin_users` -> `/admin/central/admin-users` -> `/admin/central/admin-users`
- `central:roles_permissions` -> `/admin/central/roles` -> `/admin/central/roles`
- `central:menu_management` -> `/admin/central/menu-management` -> `GET/PUT /admin/central/menu-management`
- `central:partner_provisioning` -> `/admin/central/partner-provisioning` -> partners API with provision/suspend actions
- `central:partner_quotas` -> `/admin/central/partner-quotas` -> `/admin/central/partner-quotas`
- `tenant:admin_users` -> `/admin/tenant/admin-users` -> `/admin/tenant/admin-users`
- `tenant:roles_permissions` -> `/admin/tenant/roles` -> `/admin/tenant/roles`
- `tenant:menu_management` -> `/admin/tenant/menu-management` -> `GET/PUT /admin/tenant/menu-management`
- `tenant:agent_quotas` -> `/admin/tenant/growth/agent-quotas` -> `/admin/tenant/agents` plus quota action

## Generic Catalog Pages Retained

- Central `prize_checking` remains on `/admin/central/rewards` because prize verification is a rewards workflow.
- Central `master_stock`, `stock_generation`, and `stock_recall` remain on `/admin/central/stock` because the stock page exposes the relevant list/actions.
- Tenant growth routes remain grouped under `/admin/tenant/growth/*` while API calls use documented `/admin/tenant/*` paths.
- Central/tenant report indexes remain generic report route groups with documented detail/export APIs.

## Controlled Gaps And Backend/API Decisions

These menu items now land on dedicated BO gap pages instead of unrelated fallback pages. Backend Develop should either register the documented route/controller or update the OpenAPI contract and ask BO to wire the resulting API.

| Menu code | Previous seeded route | BO route | Missing backend route/API gap | User impact |
| --- | --- | --- | --- | --- |
| central:partner_monitoring | /admin/central/partners | /admin/central/partner-monitoring | OpenAPI has `/admin/central/partner-monitoring`; `routes/api.php` lacks it. | Page explains the gap, no partner fallback. |
| central:partner_usage | /admin/central/partners | /admin/central/partner-usage | OpenAPI has `/admin/central/partner-usage`; `routes/api.php` lacks it. | Page explains the gap, no partner fallback. |
| central:billing_plans | /admin/central/partners | /admin/central/billing-plans | OpenAPI has `/admin/central/billing-plans`; `routes/api.php` lacks it. | Page explains the gap, no partner fallback. |
| central:alert_policies | /admin/central/partners | /admin/central/alert-policies | OpenAPI has `/admin/central/alert-policies`; `routes/api.php` lacks it. | Page explains the gap, no partner fallback. |
| central:alert_events | /admin/central/partners | /admin/central/alert-events | OpenAPI has `/admin/central/alert-events`; `routes/api.php` lacks it. | Page explains the gap, no partner fallback. |
| central:webhook_logs | /admin/central/audit-logs | /admin/central/webhook-logs | OpenAPI has `/admin/central/webhook-logs`; `routes/api.php` lacks it. | Page explains the gap, no audit fallback. |
| central:system_settings | /admin/central/dashboard | /admin/central/system-settings | OpenAPI has `/admin/central/system-settings`; `routes/api.php` lacks it. | Page explains the gap, no dashboard fallback. |
| tenant:price_rules | /admin/tenant/settings | /admin/tenant/price-rules | OpenAPI has `/admin/tenant/price-rules`; `routes/api.php` lacks it. | Page explains the gap, no settings fallback. |
| tenant:customers | /admin/tenant/settings | /admin/tenant/customers | OpenAPI has `/admin/tenant/members`; `routes/api.php` lacks it. | Page explains the gap, no settings fallback. |
| tenant:monitoring | /admin/tenant/reports | /admin/tenant/monitoring | OpenAPI has `/admin/tenant/monitoring`; `routes/api.php` lacks it. | Page explains the gap, no reports fallback. |
| tenant:usage | /admin/tenant/reports | /admin/tenant/usage | OpenAPI has `/admin/tenant/usage`; `routes/api.php` lacks it. | Page explains the gap, no reports fallback. |

## Static Guardrails Added

- `check.mjs` verifies scoped overrides for all known unapproved backend fallback mappings.
- `check.mjs` verifies new catalog routes/gap resources are present.
- `check.mjs` verifies `AdminOperationsPage.vue` renders and load-guards `resource.apiGap`.
- `check.mjs` verifies PUT-capable menu management resources remain wired.
- Existing endpoint snapshot validation now covers admin users, roles, menu management, and partner quotas.

## Validation

Docker-only commands run:

- `docker compose up -d postgres valkey platform-api back-office` -> pass.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` -> pass.
- `docker compose run --rm back-office npm run lint` -> pass.
- `docker compose run --rm back-office npm run test` -> pass.
- `docker compose run --rm back-office npm run build` -> pass, with existing Nuxt warning for `/admin-template/assets/images/media/media-33.jpg` remaining runtime-resolved.
- `docker compose up -d --force-recreate back-office` -> pass.
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` -> pass after rerunning sequentially.
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` -> pass after rerunning sequentially.
- Final `docker compose run --rm platform-api php artisan migrate:fresh --seed` -> pass, restores local DB after backend tests.
- Final `docker compose up -d --force-recreate back-office` -> pass.

Note: the first attempt to run `AdminMenuTest` and `AdminAuthTest` in parallel failed because both suites tried to migrate the same Docker Postgres database at the same time. Sequential rerun passed.

Focused route-list checks:

- central admin users: 5 routes found.
- central roles: 4 routes found.
- central menu management: GET/PUT found.
- tenant admin users: 5 routes found.
- tenant roles: 4 routes found.
- tenant menu management: GET/PUT found.
- central partner quotas: 3 routes found.
- tenant price rules: no route found, matching controlled-gap classification.

## Runtime Evidence

- Browser plugin opened `http://localhost:3100/login`; authenticated login interaction was blocked by the browser runtime failing to type into the email input (`setRangeText` on `type=email`). No app code change was made for that tooling issue.
- SSR/deep-link curl checks with the non-sensitive restore marker returned 200 and preserved protected paths:
  - `/tmp/bo-central-partner-monitoring.html` from `/admin/central/partner-monitoring`
  - `/tmp/bo-central-partners.html` from `/admin/central/partners`
  - `/tmp/bo-tenant-maintenance.html` from `/admin/tenant/maintenance`
  - `/tmp/bo-login.html` from `/login`
- Static lint/test guardrails still include protected restore shell checks and mobile no-overflow CSS checks for the 390x844 remediation.

## Known Risks

- Gap pages are intentional until backend routes/controllers are registered. They prevent misleading navigation but are not operational data pages yet.
- Back-office Docker service mounts only `apps/back-office`, so `check.mjs` cannot always read root-level `docs/back-office-menu-completion.md` inside the container. It checks the route/catalog/gap guardrails in Docker; the full root doc is maintained separately.
- Meno license/legal confirmation and npm audit/release-gate decisions remain outside this BO task.

## Next Agent

Orchestrator
