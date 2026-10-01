# Back-office Admin Foundation Coordinator Handoff

## Agent

Coordinator

## Task

Open the first back-office frontend implementation slice after M9 backend approval.

## What Was Done

Coordinator reviewed:

```text
docs/workspace-app-structure.md
docs/admin-dashboard-template-guidelines.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/permissions.md
docs/openapi.yaml
docs/site-config-contract.md
docs/backend-maintenance-support.md
compose.yaml
admin_dashboard_template/Meno_esbuild/**
apps/customer/Dockerfile
apps/customer/package.json
```

Coordinator confirmed:

```text
apps/back-office does not exist yet.
compose.yaml already defines back-office on port 3100.
docs require back-office to use admin_dashboard_template/Meno_esbuild.
backend M9 APIs are approved and ready for admin UI integration.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-back-office-admin-foundation-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-back-office-admin-foundation-decision.md
ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one BO Develop task:

```text
ai-agents/tasks/20260507-back-office-admin-foundation-bo.md
```

After BO Develop handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-back-office-admin-foundation-qa.md
```

## BO Task Summary

BO Develop must:

```text
scaffold apps/back-office
create Docker-compatible Nuxt admin app on port 3100
copy/reuse selected Meno_esbuild compiled assets
build Meno-based admin layout/components
implement admin login/session/scope/API client
render central/tenant dynamic RBAC menu from backend
implement central dashboard, tenant dashboard, maintenance, support access, and support access detail pages
add 403/404/500 states
document app structure and API conventions
run Docker-only build/lint/test validation
write ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

## Important Constraints

```text
Do not edit apps/platform-api.
Do not edit apps/customer.
Do not hardcode authorization in frontend.
Do not build a new admin visual language outside Meno.
Do not run host Node/npm/Nuxt/Vite commands.
Do not expose or persist support impersonation token material beyond the initial response state.
```

## Validation Required From BO Develop

Docker-only:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

At minimum, build must pass. If lint/test scripts are missing before scaffold, BO Develop must add meaningful lightweight scripts or document the limitation.

## Known Risks

```text
apps/back-office does not yet exist, so the first slice must scaffold before validation can run.
Template license must be preserved and project license should be confirmed before production/staging delivery.
Not every admin API screen should be implemented in this first slice; later slices should cover stock, commerce, reward, growth, reports, settings, SEO, domains, and audit pages.
```

## Next Agent

Orchestrator
