# back-office-p1-money-stock-crud-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted the Back Office CRUD Coverage Audit baseline and opened:

```text
back-office-p1-money-stock-crud-workflows
```

Source decision and handoff:

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-review-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-review-coordinator-handoff.md
```

## Objective

Implement the first Back Office P1 money/stock CRUD/API workflows against the frozen backend contract.

This task must move the P1 rows from generic/partial operator coverage toward real BO workflows. Use typed domain forms/modals where practical, wire through the existing BO API layer, preserve tenant/security behavior, update the CRUD coverage matrix, then hand off to QA for real menu workflow testing.

## Current Baseline

Accepted BO planning baseline:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

Official corrected BO completion:

```text
0 / 56 complete = 0% verified complete
```

Rules:

```text
Do not use weighted partial credit.
Do not mark any row complete without real QA menu workflow evidence.
Route/catalog/menu/OpenAPI presence does not count as BO completion by itself.
```

Backend remains frozen:

```text
OpenAPI/app route parity: 279 / 279 / 0 / 0
Full backend Docker suite: 152 tests / 4140 assertions
Backend-only local/dev QA verdict: PASS
```

## P1 Scope

Implement these priority rows:

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

Keep out of completion scoring for this pass:

```text
central:master_stock
tenant:commission_transactions
```

These remain `api_gap` until Coordinator approves backend remediation or an explicit list/action-only acceptance rule.

Temporary Coordinator rule:

```text
tenant:reservations and tenant:payouts may be implemented as list/action-only workflows if the current API response contains enough context for a safe operator decision.
```

If current API response context is not safe enough, report the exact blocker to Coordinator instead of changing backend.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260509-back-office-crud-coverage-audit-review-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md
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
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminModal.vue
apps/back-office/components/AdminFormSection.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Stock*
apps/platform-api/tests/Feature/*Order*
apps/platform-api/tests/Feature/*Wallet*
apps/platform-api/tests/Feature/*Topup*
```

## Required Implementation Behavior

Use current Meno/admin BO patterns and existing composables.

For high-risk money and stock workflows:

```text
prefer typed domain forms/modals over raw JSON payload editors
keep action confirmations explicit and operator-readable
show enough record context before destructive or financial actions
use Idempotency-Key for write/action APIs where backend expects or supports it
preserve tenant scope and X-Tenant-Id behavior
preserve loading, error, empty, success, disabled, and validation states
avoid silently falling back to unrelated dashboard/settings/reports/partners/agents pages
```

Do not remove existing generic JSON/detail editor support if other menus still need it.

## Expected Workflow Coverage

Central routes:

```text
/admin/central/stock
- stock import/generate/export controls with typed operator input where needed
- stock recall action with explicit confirmation and row context
- keep central:master_stock as api_gap for missing detail inspection

/admin/central/allocations
- list/detail
- create allocation workflow
- cancel allocation workflow with explicit confirmation
```

Tenant routes:

```text
/admin/tenant/stock
- list/detail/export workflow

/admin/tenant/stock-sync
- list/detail
- create sync batch workflow with typed operator input

/admin/tenant/reservations
- list/action-only cancel workflow if list context is sufficient
- otherwise report exact backend/API context blocker

/admin/tenant/orders
- list/detail
- order update workflow where safe
- cancel/refund actions with explicit confirmations

/admin/tenant/wallets
- list/detail
- wallet adjustment typed workflow
- surface ledger if current endpoint shape supports it safely

/admin/tenant/topups
- list/detail
- approve/reject/cancel actions with explicit confirmations

/admin/tenant/growth/payouts
- list/action-only approve workflow if list context is sufficient
- create payout workflow if contract and UI context are sufficient
- otherwise report exact blocker

/admin/tenant/payment-settings
- settings read/update workflow
- payment channel list/detail/create/update/delete workflow if current contract exposes enough context
```

## Documentation Updates

Update:

```text
docs/back-office-crud-coverage.md
```

For the P1 rows, update UI/API/form/gap notes after implementation.

Do not mark a row `complete` unless QA has already provided real menu workflow evidence. In this implementation handoff, rows should generally remain `partial` with QA pending unless a row becomes an explicit Coordinator-level blocker.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
```

Do not:

```text
change backend API paths, methods, schemas, response semantics, permissions, or tenant behavior
start backend remediation without Coordinator approval
start customer frontend work
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
```

Avoid adding new dependencies unless absolutely necessary and justified in the handoff.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

Follow the Code Agent Commit Rule. Commit only scoped files after validation passes and record the commit hash in the handoff.

## Required Steps

1. Read the Source Of Truth files.
2. Confirm Docker runtime policy and Code Agent Commit Rule.
3. Inspect `git status --short` before editing and preserve unrelated dirty changes.
4. Inspect current P1 catalog definitions and generic operation/action behavior.
5. Implement P1 typed forms/modals/actions using existing BO patterns.
6. Ensure write/action requests use the BO API layer and idempotency keys where expected or supported.
7. Preserve tenant scope and `X-Tenant-Id` behavior.
8. Add or update guardrails in `apps/back-office/scripts/check.mjs` if needed so P1 routes cannot regress to generic/stale unsafe gaps.
9. Update `docs/back-office-crud-coverage.md` for the P1 rows.
10. Run Docker-only validation.
11. Capture browser evidence where tooling allows, especially non-destructive modal/form/open-route checks.
12. Commit scoped changes only.
13. Write BO handoff to:

```text
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

## Validation Commands

Use Docker only for application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

If backend route evidence is needed, use Docker only:

```sh
docker compose exec -T platform-api php artisan route:list
```

Allowed local static reads:

```text
git status --short
rg
sed
ls
git diff --check
```

## QA Routes To Prepare

Prepare these for QA real menu workflow testing:

```text
/admin/central/stock
/admin/central/allocations
/admin/tenant/stock
/admin/tenant/stock-sync
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/wallets
/admin/tenant/topups
/admin/tenant/growth/payouts
/admin/tenant/payment-settings
```

QA must verify access through actual menus, not only direct URLs.

## Acceptance Criteria

```text
P1 routes have safer operator workflows than raw generic JSON where practical.
P1 write/action APIs use idempotency keys where expected/supported.
Tenant scope and X-Tenant-Id behavior are preserved.
Loading/error/empty/success states are preserved or improved.
docs/back-office-crud-coverage.md is updated for P1 rows without premature complete statuses.
No backend/customer/OpenAPI files are edited.
Docker runtime policy is followed.
Scoped commit is created and recorded in the BO handoff.
Next agent is QA Tester unless BO reports Coordinator-level backend/API blockers.
```

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md
```

Must include:

```text
1. What P1 workflows were implemented
2. Files changed
3. Commit hash
4. P1 row status changes in docs/back-office-crud-coverage.md
5. Any P1 backend/API blockers that require Coordinator approval
6. Docker validation results
7. Browser evidence captured or intentionally deferred to QA
8. Known risks carried forward
9. Recommendation: QA Tester next for real menu workflow QA, unless blocked by backend/API gaps
```
