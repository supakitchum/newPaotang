# Back-office Authenticated Visual QA Decision

Date: 2026-05-08
Agent: Coordinator

## Decision

Open a focused back-office authenticated runtime/visual QA slice.

The backend bootstrap seeder slice is approved and provides local admin credentials. This directly addresses the previously carried risk from:

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
```

That QA accepted the back-office remediation but carried forward:

```text
authenticated protected-page visual QA still needs seeded admin credentials
desktop/mobile screenshot QA should be performed when browser tooling and credentials are available
Meno JS strategy is PASS WITH RISK without authenticated visual coverage
```

## Objective

Use seeded admin credentials to verify that authenticated back-office protected routes render correctly with the restored Meno/Bootstrap template assets.

## Required Coverage

QA should validate at minimum:

```text
central login with admin@newpaotang.test / NewPaotangAdmin!2026
tenant login with owner@alpha.newpaotang.test / NewPaotangTenant!2026 / ten_demo_alpha
central dashboard/menu protected shell
central partners page or another central operations page
tenant dashboard/menu protected shell
tenant growth agents page
tenant orders or stock page
responsive desktop and mobile screenshots
sidebar/header/menu/sticky/simplebar/waves/dropdown behavior where practical
Bootstrap/Meno CSS order still correct at runtime
no obvious template CSS breakage, overlapping text, unusable layout, or redirect loop after login
```

## Constraints

- QA must not implement fixes.
- Use Docker only for package/build/test/runtime commands.
- Browser automation or manual browser checks may be used for local `localhost` runtime inspection if available.
- If visual/browser tooling is unavailable, QA must record the limitation and run the strongest static/runtime HTTP checks possible.
- Do not change API contracts, customer flow, backend business rules, or seeded credentials.

## Source Of Truth

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
ai-agents/decisions/20260508-backend-bootstrap-seeders-approval-decision.md
docs/back-office-admin-foundation.md
docs/backend-bootstrap-seeders.md
docs/docker-runtime-policy.md
apps/back-office/**
apps/platform-api/database/seeders/**
```

## Expected Output

Orchestrator should create a QA Tester task for this slice. QA should write:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
```

Verdict must be one of:

```text
PASS
PASS WITH RISKS
FAIL
```

## Next Agent

Orchestrator
