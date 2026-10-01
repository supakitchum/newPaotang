# 20260507 Back-office Admin Foundation - Orchestrator Handoff

## Agent

Orchestrator

## Task

Route the latest Coordinator Back-office Admin Foundation decision to BO Develop.

## What Was Done

- Read current Board and latest agent files.
- Confirmed latest Coordinator decision:
  - `ai-agents/decisions/20260507-back-office-admin-foundation-decision.md`
- Confirmed Coordinator handoff:
  - `ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md`
- Read the preceding approved M9 QA report:
  - `ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md`
- Read Orchestrator task template and inspected relevant back-office/Meno/template/Docker references:
  - `docs/admin-dashboard-template-guidelines.md`
  - `compose.yaml`
  - `admin_dashboard_template/Meno_esbuild/**`
  - `admin_dashboard_template/Dependencies.txt`
  - `apps/customer/Dockerfile`
  - `apps/customer/package.json`
- Confirmed `apps/back-office` does not currently exist.
- Confirmed expected BO task and Orchestrator handoff did not already exist.
- Created BO Develop task:
  - `ai-agents/tasks/20260507-back-office-admin-foundation-bo.md`

## Files Changed

```text
ai-agents/tasks/20260507-back-office-admin-foundation-bo.md
ai-agents/handoffs/20260507-back-office-admin-foundation-orchestrator-handoff.md
```

## Validation

Only read/file inspection commands were run by Orchestrator. No application runtime commands were run.

BO Develop must validate with Docker-only commands:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Recommended runtime check:

```sh
docker compose up -d platform-api back-office
```

## Coordinator Decision Summary

Start the first real back-office frontend implementation slice before M10.

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
```

## Important Observation

The decision references:

```text
admin_dashboard_template/Legal Agreement & Copyright Notice.txt
```

During Orchestrator inspection, that exact file was not present under `admin_dashboard_template`. BO Develop must verify the template package again. If it is still missing, document the missing license notice risk in the BO handoff and `docs/back-office-admin-foundation.md`, and preserve any notices available in the copied template assets/source.

## Proposed Board Update

Orchestrator must not edit `ai-agents/BOARD.md` directly. Proposed update:

```text
Active Task: 20260507-back-office-admin-foundation-bo
Coordinator: handoff_sent
Orchestrator: handoff_sent
BO Develop: ready
QA Tester: waiting_for_back_office_handoff
Expected BO handoff: ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
Expected QA task after BO handoff: ai-agents/tasks/20260507-back-office-admin-foundation-qa.md
```

## Known Risks

```text
apps/back-office does not exist yet, so this is a scaffold-plus-feature slice.
Template license notice file referenced by Coordinator was not found during Orchestrator inspection.
The app must use Meno patterns and avoid creating a separate admin design system.
Back-office must call platform-api only and must not bypass backend permission checks.
Support impersonation token material must never be persisted or redisplayed after initial response state.
Docker-only runtime remains mandatory.
Workspace has unrelated dirty/untracked files from multi-agent workflow; BO should avoid touching unrelated files.
```

## Next Agent

BO Develop
