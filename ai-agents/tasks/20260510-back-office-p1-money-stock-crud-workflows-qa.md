# back-office-p1-money-stock-crud-workflows - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator restarted the BO P1 implementation on `develop`:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260510-back-office-p1-money-stock-crud-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

## Objective

Perform real Back Office P1 money/stock menu workflow QA.

QA must test authenticated central and tenant menus, not only direct URLs or build/lint/unit checks. Verify typed forms/modals, list/detail views, write/action safety, idempotency behavior where observable, tenant scope, loading/error/empty states, and mobile sanity.

Do not mark a row complete unless the workflow is verified from the real menu with evidence.

## BO Implementation Under Test

Implementation commit:

```text
8a245b2a4244171bff786d1586570822e69671f0
```

BO handoff commit:

```text
3a211e8c56222e8f5c1ec0249d7ca34f5b854c2c
```

Route-to-Orchestrator commit:

```text
15c94717912d810281576818ccfd9196a65c5db6
```

Files BO reports changed:

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

Backend, customer, OpenAPI, compose, GitHub workflow, Board, decision, and task files were reported untouched by BO implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md
ai-agents/tasks/20260510-back-office-p1-money-stock-crud-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
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

At Orchestrator dispatch time, these unrelated local files were dirty and must not be edited or staged by QA:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
```

If they are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## QA Scope

Test these P1 rows:

```text
central:stock_generation
central:allocations
central:stock_recall
tenant:local_stock
tenant:stock_sync
tenant:reservations
tenant:orders
tenant:wallets
tenant:topups
tenant:payouts
tenant:payment_settings
```

Out of scoring for this pass:

```text
central:master_stock
tenant:commission_transactions
```

These remain `api_gap` unless Coordinator later approves remediation or a list/action-only acceptance rule.

## Browser Routes To Test

Central:

```text
/admin/central/stock
/admin/central/allocations
```

Tenant:

```text
/admin/tenant/stock
/admin/tenant/stock-sync
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/wallets
/admin/tenant/topups
/admin/tenant/growth/payouts
/admin/tenant/payment-settings
```

QA must access routes through actual BO menus where possible, then may hard-refresh/direct-open the same routes for regression coverage.

## Required Workflow Checks

Central stock:

```text
list renders from real API
typed import/generate/export controls are present
recall modal shows stock row context and requires explicit reason
central:master_stock missing detail remains api_gap and is not counted complete
```

Central allocations:

```text
list renders
detail view opens where seeded rows exist
create allocation workflow exposes typed fields
cancel allocation confirmation shows row context and reason
```

Tenant stock and sync:

```text
tenant stock list/detail/export workflow renders under tenant session
stock sync list/detail renders
create sync batch workflow exposes typed operator input
X-Tenant-Id behavior is preserved
```

Tenant reservations, orders, wallets, topups, payouts, payment settings:

```text
reservation cancel list/action-only workflow has enough row context for safe operator decision
order detail/update/cancel/refund workflows expose typed fields and confirmation context
wallet detail/adjust workflow exposes typed money fields and ledger related list
topup approve/reject/cancel workflows expose typed amount/bonus/reason/notify controls where applicable
payout create/approve workflows work under the Coordinator list/action-only temporary rule when context is sufficient
payment settings save and payment channel list/detail/create/update/archive workflows are present and typed where practical
```

For destructive or financial actions, use freshly seeded local data only. If executing the action is unsafe or not possible with seeded data, capture non-destructive modal evidence and report the row as QA-pending or partial rather than complete.

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
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `8a245b2a4244171bff786d1586570822e69671f0`.
5. Run Docker-only validation commands.
6. Seed local backend data before browser QA.
7. Start/recreate the BO container after build.
8. Test authenticated central and tenant workflows from actual BO menus.
9. Capture screenshots/JSON/text artifacts for each P1 route and modal/action class.
10. Verify mobile sanity for dense tables/modals at `390x844` on at least:

```text
/admin/central/stock
/admin/tenant/wallets
/admin/tenant/payment-settings
```

11. Verify no stale generic JSON-only workflow remains for P1 operator-critical actions where BO claims typed support.
12. Verify no route falls back to unrelated dashboard/settings/reports/partners/agents pages.
13. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
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

Host-side `git`, `rg`, `sed`, screenshots/artifact writes, and browser automation are allowed. Do not run project runtime commands on the host.

## Acceptance Criteria

QA report clearly states PASS or FAIL for the P1 implementation.

For PASS:

```text
Docker validation passes
actual menu navigation works for central and tenant P1 routes
typed forms/modals render for P1 operator-critical flows where BO claims typed support
write/action safety and idempotency behavior are verified or safely deferred with evidence
tenant scope and X-Tenant-Id behavior are verified
loading/error/empty states do not block workflows
mobile sanity passes for selected dense routes
no backend/customer/OpenAPI files were edited by QA
P1 rows that lack executed workflow evidence remain partial and are not marked complete
```

For FAIL:

```text
list defects by severity
include exact route/workflow
include evidence and likely owner
state whether next agent should be BO Develop, Backend Develop through Coordinator approval, or Coordinator
```

## Report Requirements

Write:

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

Include:

```text
Verdict
Docker runtime policy result
Workspace state and unrelated dirty files
Validation command results
Static review summary
Browser/menu workflow evidence
Mobile sanity evidence
P1 row status evidence
Defects by severity
Known risks carried forward
Recommendation
Next Agent
```

Recommended next agent after QA:

```text
Coordinator
```
