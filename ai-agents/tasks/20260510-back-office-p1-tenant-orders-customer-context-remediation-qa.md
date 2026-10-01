# Back Office P1 Tenant Orders Customer Context Remediation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator reviewed the P1 money/stock BO workflow QA report and routed one blocking defect to BO Develop:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

Orchestrator dispatched BO:

```text
ai-agents/tasks/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-planning-orchestrator-handoff.md
```

BO Develop completed remediation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
```

## Objective

Perform focused QA retest for the tenant orders customer context blocker.

The retest must prove that BO now reads nested tenant order `customer` data from the admin order API response and shows enough customer/member context for safe Update, Cancel, and Refund decisions.

This is not a full P1 retest. Reuse already-passing P1 evidence from:

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

unless this BO remediation changed shared code that creates a targeted regression risk.

## BO Remediation Under Test

Implementation commit:

```text
126a2ee94d609233e99be8099671300bf54c75f9
```

BO handoff commit:

```text
9079fd6ae9650639fd0dd092001555eb83851cae
```

Files BO reports changed:

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
```

BO reports no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, or report files were edited for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
ai-agents/tasks/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p1-tenant-orders-customer-context-remediation-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/scripts/check.mjs
```

Prior QA evidence for the defect:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-from-menu.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-update-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-cancel-modal.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/browser/tenant-orders-refund-modal.snapshot.txt
```

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
```

If they are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Required API-First Policy

Coordinator recorded the user's new rule:

```text
For customer/member/customer-facing CRUD and workflows, QA must validate with API requests first before entering the Customer frontend.
```

For this retest:

```text
send API requests first against Docker/local platform API data
verify tenant order API response includes nested customer context
capture sanitized API evidence before opening BO browser workflow
do not enter the Customer frontend before API validation
do not use Customer UI for this remediation unless Coordinator explicitly adds that scope later
```

API-first evidence must cover:

```text
GET /admin/tenant/orders
GET /admin/tenant/orders/{order_id}
nested customer.id/name/phone/email presence where seeded data provides it
fallback behavior notes if any customer field is absent
tenant scope for the authenticated tenant session
```

Use local Docker test data only. Do not copy real customer data, secrets, bearer tokens, private keys, or raw session credentials into artifacts.

## Focused QA Scope

Retest tenant orders only:

```text
/admin/tenant/orders
```

Required BO browser checks:

```text
access tenant orders from the real authenticated BO tenant menu
list Customer column no longer renders "-" when nested customer data is available
order detail exposes enough customer/member context for safe operator review
Update modal includes customer/member context plus order id/status/payment/amount/tenant context
Cancel modal includes customer/member context plus order id/status/payment/amount/tenant context
Refund modal includes customer/member context plus order id/status/payment/amount/tenant context
Update, Cancel, and Refund reason guards remain required
typed controls remain intact
no action falls back to a raw generic JSON-only workflow for these operator-critical modals
no route falls back to unrelated dashboard/settings/reports/partners/agents pages
```

Because BO touched shared confirmation/page components, also perform a small regression smoke on representative already-passing workflows:

```text
tenant:wallets adjust modal still shows customer/money context and reason guard
tenant:topups approve or cancel modal still shows context and reason guard
tenant:reservations cancel modal still shows reservation/customer context and reason guard
```

Do not rerun full P1 evidence unless the focused smoke reveals a shared regression.

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
submit real destructive or financial actions outside local seeded data
copy real secrets, tokens, bearer tokens, customer data, or private keys into artifacts
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `126a2ee94d609233e99be8099671300bf54c75f9`.
5. Run focused Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Perform API-first tenant order/customer validation before opening BO browser workflow.
8. Start/recreate the BO container after build.
9. Test the real authenticated BO tenant orders menu and required modals.
10. Capture sanitized API/browser/text artifacts for the API response, list, detail, Update modal, Cancel modal, Refund modal, and reason guards.
11. Run the shared-component smoke checks listed above.
12. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
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
ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
API-first validation evidence summary
browser evidence summary
tenant orders list/detail/update/cancel/refund result
reason guard result
shared-component smoke result
whether the original P1 blocker is resolved
any new defects with severity, likely owner, and evidence
Docker validation command results
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If this focused QA passes, Coordinator can decide whether the P1 BO workflow slice is approved or whether any remaining Gate/production risks still block release.

If QA finds defects, report them to Coordinator with severity and likely owner. Do not route directly to BO or Backend.
