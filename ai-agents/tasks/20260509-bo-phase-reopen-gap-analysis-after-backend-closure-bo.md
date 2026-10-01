# bo-phase-reopen-gap-analysis-after-backend-closure - BO Develop

## Superseded

This generic BO gap-analysis task is superseded by:

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
```

Do not execute this task. Orchestrator must instead dispatch:

```text
back-office-crud-coverage-audit
```

That task must produce `docs/back-office-crud-coverage.md` with a complete CRUD/API workflow matrix for every central and tenant menu.

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator closed backend engineering scope for BO unblock and opened:

```text
bo-phase-reopen-gap-analysis-after-backend-closure
```

Source decision and handoff:

```text
ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md
ai-agents/handoffs/20260509-m10-backend-complete-bo-unblock-coordinator-handoff.md
```

## Objective

Perform Back Office gap analysis against the frozen backend contract and current BO state.

This is an analysis/planning task first. Do not start broad BO implementation in this task. The handoff must identify the exact BO work needed, exact files likely involved, backend contract gaps if any, risks, and Docker-only validation commands for the next implementation task.

## Current Accepted Backend State

```text
Backend contract: frozen for BO consumption
OpenAPI/app route parity: 279 / 279 / 0 / 0
Full backend Docker suite: 152 tests / 4140 assertions
Backend-only local/dev QA verdict: PASS
Production/Ops evidence gates remain open but do not block BO development
```

Production/Ops evidence remains tracked separately:

```text
ops/m10/m10-production-evidence-request-list.md
```

Do not treat this BO work as staging, production, client delivery, Gate 5, or final release approval.

## Source Of Truth

Read these before analysis:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md
ai-agents/handoffs/20260509-m10-backend-complete-bo-unblock-coordinator-handoff.md
docs/openapi.yaml
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
docs/permissions.md
apps/back-office/package.json
apps/back-office/nuxt.config.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/layouts/admin.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminConfirmAction.vue
```

Prior BO context to review:

```text
ai-agents/tasks/20260508-m10-license-dependency-bo-production-readiness-bo.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
ai-agents/tasks/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
ai-agents/tasks/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md
ai-agents/tasks/20260509-m10-bo-menu-completion-backend-ready-wiring-bo.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md
```

## Scope

Analyze current BO completeness against the frozen backend contract:

```text
central admin pages and route coverage
tenant admin pages and route coverage
menu/navigation route overrides and fallback safety
auth/session restore and protected deep-link behavior
tenant context and X-Tenant-Id behavior
generic operations catalog/list/detail/action coverage
forms/write actions and idempotency header usage where BO writes are available
API-backed empty/loading/error states
mobile 390x844 admin shell overflow risk
guardrail coverage in apps/back-office/scripts/check.mjs
docs/back-office-menu-completion.md accuracy
npm/Meno/license/audit risks already known from prior BO QA
```

For every gap, classify it as one of:

```text
bo_implementation_needed
bo_validation_needed
backend_contract_gap_requires_coordinator
blocked_by_external_release_ops
already_complete
out_of_scope
```

## Required Output

Write BO handoff to:

```text
ai-agents/handoffs/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo-handoff.md
```

The handoff must include:

```text
1. BO completion map by central/tenant area
2. Exact gaps and classification
3. Exact files likely needed for the next BO implementation task
4. Any backend contract gaps that require Coordinator approval before backend changes
5. Validation commands to run in the next BO implementation/QA tasks
6. Browser routes that QA should inspect
7. Known risks carried forward
8. Recommendation for the next agent
```

## Out Of Scope

Do not edit implementation code in this task unless Coordinator explicitly re-scopes it later.

Do not edit:

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
```

Do not:

```text
change backend/API paths, methods, schemas, response semantics, permissions, or tenant behavior
start backend remediation without Coordinator approval
start customer frontend work
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit/Meno legal/license closure unless a later Coordinator-scoped task explicitly closes it
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
```

## File Ownership

Can write:

```text
ai-agents/handoffs/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo-handoff.md
```

Read-only for this task:

```text
apps/back-office/**
docs/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/**
apps/platform-api/**
```

If BO Develop determines that a small implementation change is truly required before a useful handoff can be produced, stop and report that as a gap instead of making the change.

## Required Steps

1. Read the Source Of Truth files.
2. Confirm Docker runtime policy and Code Agent Commit Rule.
3. Inspect `git status --short` before analysis and preserve unrelated dirty changes.
4. Inventory current BO routes/pages/catalog entries against `docs/openapi.yaml` and `docs/back-office-menu-completion.md`.
5. Review prior BO QA reports and carry forward unresolved risks accurately.
6. Identify whether any BO route still falls back to unrelated dashboard/settings/reports/partners/agents pages.
7. Identify whether any visible menu item is still a controlled API gap despite backend contract coverage.
8. Identify whether any BO implementation need would require a backend/API contract change; classify those as `backend_contract_gap_requires_coordinator`.
9. Do not change implementation files.
10. Run Docker-only analysis validation where useful.
11. Write the BO handoff with the required output sections.
12. Do not commit unless implementation code was changed by explicit later Coordinator re-scope. For this analysis-only task, no commit is expected.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

If browser/API-backed analysis needs seeded backend data, use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Optional static checks are allowed with local file-inspection commands such as `rg`, `sed`, and `git status` because they do not execute project runtime.

## Acceptance Criteria

```text
No implementation code is edited.
No backend/customer files are edited.
No backend contract change is proposed as direct BO work.
Every BO area reviewed has a clear status/classification.
Next BO implementation scope is concrete enough for Orchestrator to dispatch.
Docker runtime policy is followed for all application commands.
Handoff clearly recommends the next agent.
```
