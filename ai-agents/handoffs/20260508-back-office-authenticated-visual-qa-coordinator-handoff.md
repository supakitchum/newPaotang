# Back-office Authenticated Visual QA Coordinator Handoff

Date: 2026-05-08
Agent: Coordinator
Next Agent: Orchestrator

## Task

Route a focused authenticated runtime/visual QA slice now that backend seeders provide usable admin credentials.

## Context

Coordinator approved:

```text
ai-agents/decisions/20260508-backend-bootstrap-seeders-approval-decision.md
```

The approved seeded accounts unblock the back-office visual QA risk carried from:

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
```

## What Orchestrator Should Do

Create a QA Tester task for:

```text
20260508-back-office-authenticated-visual-qa
```

The task should require QA to validate authenticated protected-page rendering using seeded credentials.

## Seeded Credentials For QA

Central:

```text
email: admin@newpaotang.test
password: NewPaotangAdmin!2026
scope: central
```

Tenant:

```text
tenant_id: ten_demo_alpha
host: alpha.newpaotang.test
email: owner@alpha.newpaotang.test
password: NewPaotangTenant!2026
scope: tenant
```

Other available tenants:

```text
ten_demo_beta / beta.newpaotang.test / owner@beta.newpaotang.test
ten_demo_gamma / gamma.newpaotang.test / owner@gamma.newpaotang.test
```

## QA Must Validate

```text
login succeeds for central and tenant seeded accounts
protected central and tenant shells render after login
central and tenant menus render usable navigation
tenant growth pages use frontend /admin/tenant/growth/* routes while API calls use documented /admin/tenant/* endpoints
Meno/Bootstrap CSS renders correctly on authenticated pages
desktop and mobile screenshots show no obvious broken layout, overlapping text, or missing template assets
sidebar/header/menu/sticky/simplebar/waves/dropdown behavior is acceptable where practical
Docker-only runtime policy is followed for package/build/test/runtime commands
```

## Suggested Docker Commands

QA should use Docker only for runtime and test/build commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

If QA uses browser automation, target:

```text
http://localhost:3100/login
```

## Expected Files

Orchestrator should create:

```text
ai-agents/tasks/20260508-back-office-authenticated-visual-qa.md
ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-orchestrator-handoff.md
```

QA should create:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
```

## Known Risks To Carry

```text
Meno license notice is still missing before staging, production, or client delivery.
npm audit still reports vulnerabilities and needs production-readiness triage.
Maintenance bypass list endpoint remains absent.
Backend menu category/icon fields remain absent.
```

## Next Agent

Orchestrator
