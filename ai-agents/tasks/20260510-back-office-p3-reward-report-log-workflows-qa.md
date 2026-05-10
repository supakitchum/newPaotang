# back-office-p3-reward-report-log-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator approved P2 write-submission QA and opened the next BO priority:

```text
back-office-p3-reward-report-log-workflows
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260510-back-office-p3-reward-report-log-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
```

## Objective

Perform real Back Office P3 reward, prize-checking, settlement, report/export, webhook log, audit log, and sync log workflow QA.

QA must test authenticated central and tenant menus, not only direct URLs or build/lint/unit checks. Verify typed forms/modals, related lists, report drill-down/export flows, read-only log inspection, action safety, central/tenant scope behavior, loading/error/empty states, and mobile sanity where the UI is dense.

For rows with create/update/action/export mutations, use safe local Docker QA fixture data and submit the workflow when it is safe. Capture before/after API evidence and browser evidence for submitted writes/actions/exports where applicable. Do not mark a row complete unless the workflow is verified from the real menu with evidence.

## BO Implementation Under Test

Implementation commit:

```text
10d6fd2028014635502e92adb04c3d8e78650fe0
```

BO handoff commit:

```text
3f094a4e0aafbe309939e4fac581769903954506
```

Files BO reports changed:

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminReportPanel.vue
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
```

Backend, customer, OpenAPI, compose, GitHub workflow, Board, decision, and task files were reported untouched by BO implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/tasks/20260510-back-office-p3-reward-report-log-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminReportPanel.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
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

## QA Scope

Test these P3 rows:

```text
central:rewards
central:prize_checking
central:settlement
central:reports
central:webhook_logs
central:audit_logs
tenant:reports
tenant:sync_logs
tenant:audit_logs
```

## Browser Routes To Test

Central:

```text
/admin/central/rewards
/admin/central/settlements
/admin/central/reports
/admin/central/webhook-logs
/admin/central/audit-logs
```

Tenant:

```text
/admin/tenant/reports
/admin/tenant/sync-logs
/admin/tenant/audit-logs
```

`central:prize_checking` shares `/admin/central/rewards` by current menu/contract. QA should capture reward detail check-batch related-list evidence as the prize-checking workflow.

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

### central:rewards

Use safe local QA fixture data and test from the real central menu:

```text
list renders from real API
detail opens for a reward row
check-batches related list appears on detail when fixture data provides it
typed create reward result workflow renders prize-line fields
typed update reward result workflow renders prefilled prize-line fields
verify confirmation shows reward/game/draw/prize/status context and reason guard
correct confirmation shows reward/game/draw/prize/status context and reason guard
publish confirmation shows reward/game/draw/prize/status context and reason guard
```

Submit create/update and safe actions if the fixture state supports them. Capture before/after API evidence. If an action cannot be safely submitted because of state constraints, capture modal evidence and exact API/state reason.

### central:prize_checking

Use the shared rewards route and verify:

```text
reward detail surfaces check-batch related-list evidence
check-batch data is readable and connected to reward/prize context
verify/correct/publish actions remain available with sufficient prize-checking context
```

If no seeded check-batch data exists, create safe local fixture data or record the exact fixture gap.

### central:settlement

Use safe local QA fixture data and test:

```text
list renders from real API
detail opens for a settlement row
approve confirmation shows settlement/partner/tenant/amount/status/period context
approve reason guard remains required
safe approve submission persists expected state when fixture is approvable
```

Capture before/after API evidence for any submitted approval.

### central:reports

Test from the real central reports menu:

```text
report index/drill-down opens a concrete central report key
summary cards render where data exists
report rows table renders
filters/date range/group controls are coherent where supported
export modal includes format, tenant drill-down, date range, group filter, current report/filter context, and reason
safe export submission returns expected response or queued/export artifact state
```

Capture API/browser evidence for export submit. If export cannot be submitted safely, record exact API/UI blocker.

### central:webhook_logs

Test read-only workflow:

```text
list renders from real API
detail opens for a webhook log row
delivery/status/event/payload metadata are useful
secret material is not exposed in screenshots/snapshots/artifacts
filters/cursor states are coherent where supported
```

### central:audit_logs

Test read-only workflow:

```text
list renders from real API
action/actor/target/request columns are useful
filters/cursor states are coherent where supported
no detail action is expected because the frozen contract has no detail endpoint
```

### tenant:reports

Test from the real tenant reports menu:

```text
tenant-scoped report drill-down opens a concrete tenant report key
summary cards and rows table render where data exists
tenant scope and X-Tenant-Id behavior are preserved
export modal includes format, date range, group filter, current tenant/report context, and reason
safe export submission returns expected response or queued/export artifact state
```

Capture API/browser evidence for export submit.

### tenant:sync_logs

Test read-only tenant workflow:

```text
list renders from real API
tenant scope and X-Tenant-Id behavior are preserved
status/cursor filters render where supported
direction/event metadata columns are useful
no detail action is expected because the frozen contract has no detail endpoint
```

### tenant:audit_logs

Test read-only tenant workflow:

```text
list renders from real API
tenant scope and X-Tenant-Id behavior are preserved
action/target/request columns are useful
filters/cursor states are coherent where supported
no detail action is expected because the frozen contract has no detail endpoint
```

## Mobile Sanity

Verify mobile sanity at `390x844` on at least:

```text
/admin/central/rewards
/admin/central/reports
/admin/tenant/reports
```

Use screenshots/snapshots to confirm dense tables, report cards, and modals do not overlap incoherently.

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
copy real secrets, tokens, bearer tokens, customer data, local credentials, or private keys into artifacts
use Customer frontend
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `10d6fd2028014635502e92adb04c3d8e78650fe0`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Prepare safe local QA fixtures for submitted reward, settlement, and export workflows where needed.
8. Capture before API evidence for rows with submitted mutations/actions/exports.
9. Test authenticated central and tenant workflows from actual BO menus.
10. Submit safe writes/actions/exports where specified and capture browser success/error evidence.
11. Capture after API evidence for submitted mutations/actions/exports.
12. Capture screenshots/JSON/text artifacts for each P3 route and modal/action/export class.
13. Verify mobile sanity for required routes.
14. Verify no route falls back to unrelated dashboard/settings/report pages.
15. Write the QA report.

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
docker compose run --rm platform-api php artisan test --filter=RewardEngineTest
docker compose run --rm platform-api php artisan test --filter=ReportTest
docker compose run --rm platform-api php artisan test --filter=SettlementTest
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
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
browser evidence summary
before/after API evidence summary for submitted writes/actions/exports
row-by-row result for all nine P3 rows
which rows are complete candidates and which remain partial
read-only list-only contract boundaries for audit/sync logs
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide which P3 rows count toward BO completion. If QA finds defects, permission mismatches, fixture gaps, or backend contract blockers, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.
