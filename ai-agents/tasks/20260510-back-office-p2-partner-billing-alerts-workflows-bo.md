# back-office-p2-partner-billing-alerts-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved the P1 money/stock CRUD/API workflow slice after focused topups customer-context QA passed.

Open the next BO priority:

```text
back-office-p2-partner-billing-alerts-workflows
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Official BO completion before this task:

```text
11 / 56 complete = 19.6% verified complete
```

Do not count any P2 row as complete until BO implementation is done and QA verifies the real menu workflow.

## Branch And Sync Rules

Use:

```text
branch: develop
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

If the worktree is dirty before BO edits, stop and report the exact files to Orchestrator. Do not recreate `codex/*` branches unless the user or Coordinator explicitly asks for per-agent branches again.

## Objective

Implement P2 Back Office central partner, billing, and alert workflows against the frozen backend contract.

Move the selected P2 rows from generic/partial coverage toward real operator workflows. Use typed forms/modals where practical, wire through the existing BO API layer, preserve central-scope authorization behavior, update the CRUD coverage matrix notes, and hand back to Orchestrator for QA dispatch.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/package.json
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminModal.vue
apps/back-office/components/AdminFormSection.vue
apps/back-office/pages/admin/central/[...slug].vue
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Partner*
apps/platform-api/tests/Feature/*Billing*
apps/platform-api/tests/Feature/*Alert*
```

## Scope

Implement these matrix rows:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:partner_monitoring
central:partner_usage
central:billing_plans
central:alert_policies
central:alert_events
```

Expected routes and endpoints:

```text
/admin/central/partners
- GET /admin/central/partners
- GET /admin/central/partners/{partner_id}
- POST /admin/central/partners
- PATCH /admin/central/partners/{partner_id}
- POST /admin/central/partners/{partner_id}/suspend

/admin/central/partner-provisioning
- GET /admin/central/partners
- GET /admin/central/partners/{partner_id}
- POST /admin/central/partners/{partner_id}/provision
- POST /admin/central/partners/{partner_id}/suspend

/admin/central/partner-quotas
- GET /admin/central/partner-quotas
- POST /admin/central/partner-quotas
- PATCH /admin/central/partner-quotas/{quota_id}

/admin/central/partner-monitoring
- GET /admin/central/partner-monitoring
- GET /admin/central/partner-monitoring/{monitoring_profile_id}
- PATCH /admin/central/partner-monitoring/{monitoring_profile_id}

/admin/central/partner-usage
- GET /admin/central/partner-usage
- GET /admin/central/partner-usage/{usage_meter_id}
- PATCH /admin/central/partner-usage/{usage_meter_id}

/admin/central/billing-plans
- GET /admin/central/billing-plans
- GET /admin/central/billing-plans/{billing_plan_id}
- POST /admin/central/billing-plans
- PATCH /admin/central/billing-plans/{billing_plan_id}

/admin/central/alert-policies
- GET /admin/central/alert-policies
- GET /admin/central/alert-policies/{alert_policy_id}
- POST /admin/central/alert-policies
- PATCH /admin/central/alert-policies/{alert_policy_id}

/admin/central/alert-events
- GET /admin/central/alert-events
- GET /admin/central/alert-events/{alert_event_id}
- POST /admin/central/alert-events/{alert_event_id}/acknowledge
- POST /admin/central/alert-events/{alert_event_id}/resolve
```

## Required Implementation Behavior

Use existing Meno/admin patterns and current BO composables.

Required behavior:

```text
replace raw JSON create/update where the matrix identifies typed workflow gaps
keep generic JSON support for unrelated menus that still rely on it
show record context before suspend/provision/acknowledge/resolve actions
require operator reason where the existing action pattern requires reason
use idempotency keys for writes/actions where backend expects or supports them
preserve central scope and permission behavior
handle loading/error/empty/success/disabled/validation states
avoid silently falling back to unrelated dashboard/settings/report pages
```

For `central:partner_monitoring` and `central:partner_usage`, the seeded permissions are view permissions while the backend exposes update APIs. Implement only safe update workflows if the current BO permission model and contract clearly support them. If the permission intent is ambiguous, report the exact ambiguity in the BO handoff and leave those rows partial instead of changing permission/security behavior.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

Do not change backend contracts, permission semantics, tenant/customer flows, production/Ops config, or API schemas.

Do not use Customer frontend for this task.

Do not mark BO percentage as complete yourself. Update `docs/back-office-crud-coverage.md` notes/status only to reflect implementation readiness or known blockers. Coordinator recalculates percentage after QA.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

## Required Steps

1. Read the source-of-truth files and current catalog/page patterns.
2. Map each P2 row to current BO route/catalog behavior and backend OpenAPI contract.
3. Implement typed forms/modals/actions for the selected rows where contract and permission intent are clear.
4. Preserve existing list/detail/action behavior for rows already wired.
5. Update `docs/back-office-crud-coverage.md` row notes to show BO implementation status and QA readiness, but leave completion as `partial` until QA passes.
6. Run required Docker validation.
7. Commit BO implementation changes with a task-prefixed commit message.
8. Write BO handoff and route back to Orchestrator, not directly to QA.

## Acceptance Criteria

- `central:partners` has list/detail/create/update/suspend operator workflows wired where supported by contract.
- `central:partner_provisioning` has provision/suspend confirmation workflows with clear partner context.
- `central:partner_quotas` has typed create/update quota workflows where supported by contract.
- `central:partner_monitoring` and `central:partner_usage` either expose safe update workflows or document the exact permission ambiguity/blocker.
- `central:billing_plans` has typed create/update workflows instead of operator-facing raw JSON-only create/update.
- `central:alert_policies` has typed create/update workflows instead of operator-facing raw JSON-only create/update.
- `central:alert_events` has acknowledge/resolve workflows with clear event context and reason guards where required.
- Loading/error/empty/success/disabled/validation states remain coherent.
- BO implementation does not edit backend, customer, OpenAPI, production/Ops, or permission source files.
- `docs/back-office-crud-coverage.md` reflects implementation readiness without marking rows complete before QA.
- BO handoff lists changed files, endpoints consumed, validation, blockers/risks, commit hash, and next agent.

## Validation Commands

Application commands must be Docker-only.

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

Must include:

```text
what was done
files changed
template/admin patterns used
API endpoints consumed
coverage matrix status per row
validation commands and results
implementation commit hash
known risks/blockers
next agent: Orchestrator
```
