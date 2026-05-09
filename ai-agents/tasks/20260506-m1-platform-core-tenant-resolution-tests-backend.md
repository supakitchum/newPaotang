# m1-platform-core-tenant-resolution-tests - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Revise Milestone 1 platform core foundation before approval. Add the missing automated coverage identified by QA defect D1 for inactive tenant and inactive partner host resolution.

This revision is authorized by:

```text
ai-agents/decisions/20260506-m1-platform-core-qa-review-decision.md
ai-agents/handoffs/20260506-m1-platform-core-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m1-platform-core-qa-report.md
```

## Objective

Add focused automated tests proving that `ResolveTenantByHost` returns safe `tenant_inactive` behavior when either the matched tenant or partner is inactive.

## Source Of Truth

- ai-agents/tasks/20260506-m1-platform-core-backend.md
- ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
- ai-agents/reports/20260506-m1-platform-core-qa-report.md
- ai-agents/decisions/20260506-m1-platform-core-qa-review-decision.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/erd.md
- docs/status-enums.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Add automated coverage in `apps/platform-api/tests/Feature/TenantResolutionTest.php` for:
  - inactive `partner_tenants.status` returns `tenant_inactive`
  - inactive `partners.status` returns `tenant_inactive`
- Keep the revision focused on tenant resolution regression tests.
- Change implementation logic only if the new tests reveal a real behavior bug.

Optional scope only if tests reveal a behavior bug:

```text
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
```

## Out Of Scope

- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not modify business flows.
- Do not alter source-of-truth docs.
- Do not add default permission/menu seeders in this revision.
- Do not change `admin_menus.parent_id` schema in this revision.
- Do not implement new tenant, RBAC, menu, audit, stock, booking, checkout, wallet, reward, payment, support impersonation, or notification behavior.

## File Ownership

Can edit:

```text
apps/platform-api/tests/Feature/TenantResolutionTest.php
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php only if the new tests reveal a behavior bug
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
apps/platform-api/database/migrations/**
apps/platform-api/app/Shared/Rbac/**
apps/platform-api/app/Shared/Audit/**
apps/platform-api/routes/**
docs/**
document/**
ai-agents/decisions/**
```

If a broader issue is discovered, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `apps/platform-api/tests/Feature/TenantResolutionTest.php`.
3. Read `apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php`.
4. Add a test for inactive tenant status returning HTTP `409` with error code `tenant_inactive`.
5. Add a test for inactive partner status returning HTTP `409` with error code `tenant_inactive`.
6. Prefer adapting the existing `seedTenant` test helper to support tenant and partner status setup.
7. Run the focused tenant resolution test through Docker.
8. Run the full platform API test suite through Docker.
9. Write the required backend handoff.

## Acceptance Criteria

- `TenantResolutionTest` includes automated coverage for inactive tenant status returning `tenant_inactive`.
- `TenantResolutionTest` includes automated coverage for inactive partner status returning `tenant_inactive`.
- Focused `TenantResolutionTest` passes through Docker.
- Full `platform-api` test suite passes through Docker.
- No business logic changes are made unless the new tests expose an actual behavior bug.
- No files outside the approved scope are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Coordinator instructed Orchestrator to create a focused QA task after Backend Develop completes this revision handoff.
