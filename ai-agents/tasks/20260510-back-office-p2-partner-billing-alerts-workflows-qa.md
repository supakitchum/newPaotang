# back-office-p2-partner-billing-alerts-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator approved the P1 money/stock CRUD/API workflow slice and opened the next BO priority:

```text
back-office-p2-partner-billing-alerts-workflows
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

## Objective

Perform real Back Office P2 partner, billing, and alert menu workflow QA.

QA must test authenticated central menus, not only direct URLs or build/lint/unit checks. Verify typed forms/modals, list/detail views, action safety, central-scope permission behavior, loading/error/empty states, and mobile sanity where the UI is dense.

Do not mark a row complete unless the workflow is verified from the real menu with evidence.

## BO Implementation Under Test

Implementation commit:

```text
3c6750af9448cc72e56167231b750046ee6e6c19
```

BO handoff commit:

```text
3c33e44b515a1ddb118061e1dcd7c828f4e256e0
```

Files BO reports changed:

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

Backend, customer, OpenAPI, compose, GitHub workflow, Board, decision, and task files were reported untouched by BO implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, this unrelated local file was dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
```

If it is still dirty in QA's worktree, record it as unrelated existing change in the QA report and leave it untouched.

## QA Scope

Test these P2 rows:

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

Rows with explicit permission ambiguity:

```text
central:partner_monitoring
central:partner_usage
```

BO intentionally did not expose update buttons for monitoring/usage because seeded menu permissions are view-only while backend PATCH endpoints require manage permissions. QA should verify list/detail behavior and record this as a Coordinator permission/UX decision item, not patch it and not treat the absence of update buttons as a BO defect unless the task contract says otherwise.

## Browser Routes To Test

Central:

```text
/admin/central/partners
/admin/central/partner-provisioning
/admin/central/partner-quotas
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/alert-policies
/admin/central/alert-events
```

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

Central partners:

```text
list renders from real API
detail opens for seeded rows
create partner workflow exposes typed fields
update partner workflow exposes typed fields and prefilled data
suspend confirmation shows partner/tenant/domain context and requires reason
```

Central partner provisioning:

```text
list/detail render through real central menu
provision workflow exposes typed tenant/domain/owner/site/billing/deployment/feature fields
provision confirmation shows partner context and requires reason where applicable
suspend confirmation shows partner context and reason guard
```

Central partner quotas:

```text
list renders
typed create quota workflow renders expected quota fields
typed update quota workflow renders expected quota context and prefilled data
validation/disabled states are coherent
```

Central partner monitoring:

```text
list renders
detail opens for seeded monitoring profiles
no update action is exposed under view-only menu permission
record permission ambiguity for Coordinator: backend has PATCH requiring partner.monitoring.manage while menu is partner.monitoring.view
```

Central partner usage:

```text
list renders
detail opens for seeded usage meters
no limit update action is exposed under view-only menu permission
record permission ambiguity for Coordinator: backend has PATCH requiring partner.usage.manage while menu is partner.usage.view
```

Central billing plans:

```text
list/detail render
typed create billing plan workflow replaces operator-facing raw JSON create
typed update billing plan workflow replaces operator-facing raw JSON update
fee/currency/status/features/limits fields render coherently
```

Central alert policies:

```text
list/detail render
typed create alert policy workflow replaces operator-facing raw JSON create
typed update alert policy workflow replaces operator-facing raw JSON update
partner/policy/severity/status/config fields render coherently
```

Central alert events:

```text
list/detail render
acknowledge confirmation shows event context and requires reason where applicable
resolve confirmation shows event context and requires reason where applicable
status/context remains clear before action
```

For write/action checks, use freshly seeded local data or QA-created local fixtures only. If executing the action is unsafe, irreversible, or not possible with seeded data, capture non-destructive modal/form evidence and report the row as QA-pending or partial rather than complete.

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
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, or private keys into artifacts
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `3c6750af9448cc72e56167231b750046ee6e6c19`.
5. Run Docker-only validation commands.
6. Seed local backend data before browser QA.
7. Start/recreate the BO container after build.
8. Test authenticated central workflows from actual BO menus.
9. Capture screenshots/JSON/text artifacts for each P2 route and each modal/action class.
10. Verify mobile sanity for dense tables/modals at `390x844` on at least:

```text
/admin/central/partners
/admin/central/billing-plans
/admin/central/alert-events
```

11. Verify no stale generic JSON-only workflow remains for P2 create/update workflows where BO claims typed support.
12. Verify no route falls back to unrelated dashboard/settings/reports pages.
13. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

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
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
browser evidence summary
row-by-row result for all eight P2 rows
which rows are complete candidates and which remain partial
monitoring/usage permission ambiguity evidence
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether these P2 rows count toward BO completion. If QA finds defects or permission/contract blockers, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
