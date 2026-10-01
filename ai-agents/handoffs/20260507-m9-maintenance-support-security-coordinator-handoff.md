# M9 Maintenance, Support Access, Security Hardening Coordinator Handoff

## Agent

Coordinator

## Task

Open the next main execution-plan slice after approved M8 and backend compliance/structure remediation.

## What Was Done

Coordinator reviewed:

```text
document/15_EXECUTION_PLAN.md
document/09_AI_WORK_INSTRUCTIONS.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/events.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
docs/docker-runtime-policy.md
apps/platform-api/routes/api.php
apps/platform-api/database/migrations/**
apps/platform-api/app/Shared/**
apps/platform-api/tests/**
```

Coordinator confirmed:

```text
M9 is the next roadmap milestone.
OpenAPI already contains tenant maintenance and support-access endpoint contracts.
permissions.md already contains maintenance.* and support_access.* permissions.
events.md already contains maintenance.changed.v1, support_impersonation.started.v1, and support_impersonation.action_blocked.v1.
public site-config already exposes basic maintenance state from existing tenant settings.
admin tenant maintenance/support-access routes are not yet implemented in routes/api.php.
M9 dedicated service/table/model/controller layer is not yet present.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md
```

After Backend Develop handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-m9-maintenance-support-security-qa.md
```

## Backend Task Summary

Backend Develop must implement:

```text
CentralStockTest deterministic audit lookup hardening
M9 maintenance/support migrations and Eloquent models
MaintenanceService
SupportAccessService
tenant admin maintenance endpoints
tenant admin support-access endpoints
maintenance route blocking behavior
maintenance.changed.v1 outbox/audit evidence
short-lived support impersonation session foundation
blocked sensitive action enforcement/evidence
request validation layer updates
backend maintenance/support documentation
focused tests and full Docker validation
```

## Important Constraints

```text
Do not edit customer UI.
Do not implement back-office UI yet.
Do not introduce global maintenance mode.
Do not expose real passwords, password hashes, token hashes, or support token material after initial issuance.
Do not create broad unsafe impersonation bypass.
Do not destructively remove existing tenant settings maintenance fields.
Do not run host PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration commands.
```

## Validation Required From Backend Develop

Docker-only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=SupportAccess
docker compose run --rm platform-api php artisan test --filter=Impersonation
docker compose run --rm platform-api php artisan test --filter=Security
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test
```

## Known Risks

```text
Existing partner_tenant_settings already contains maintenance fields. Backend must bridge/fallback carefully instead of destructive rewrites.
OpenAPI support-access schemas are intentionally compact; additive response fields may be acceptable only if they do not break existing envelopes.
Support impersonation token integration must be conservative. If safe endpoint-wide integration is too broad for this slice, Backend must document deferred integration and still prove blocked sensitive action behavior at service/middleware boundaries.
Back-office UI should wait until backend QA passes.
```

## Next Agent

Orchestrator
