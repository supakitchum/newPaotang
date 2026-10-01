# BO Phase Reopen Gap Analysis Planning Orchestrator Handoff

## Superseded

This generic BO gap-analysis handoff is superseded by the Coordinator decision:

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
```

Do not dispatch this generic task. The active BO planning task is:

```text
back-office-crud-coverage-audit
```

The newer task requires `docs/back-office-crud-coverage.md` and a full CRUD/API workflow matrix for every central and tenant menu.

## Agent

Orchestrator

## Task

Dispatch:

```text
bo-phase-reopen-gap-analysis-after-backend-closure
```

## Coordinator Source

```text
ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md
ai-agents/handoffs/20260509-m10-backend-complete-bo-unblock-coordinator-handoff.md
```

## What Was Done

Created BO Develop task:

```text
ai-agents/tasks/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo.md
```

## Routing

Next agent:

```text
BO Develop
```

This is a gap-analysis task before broad implementation. BO Develop should inspect current Back Office state against the frozen backend contract and produce a handoff with exact gaps, likely files, validation plan, browser routes, and next-agent recommendation.

## Important Boundaries

Backend engineering is closed for BO unblock:

```text
OpenAPI/app route parity: 279 / 279 / 0 / 0
Full backend Docker suite: 152 tests / 4140 assertions
Backend-only local/dev QA verdict: PASS
Backend contract: frozen for BO consumption
```

Production/Ops evidence remains open and is not approved for release:

```text
ops/m10/m10-production-evidence-request-list.md
```

Those release/Ops blockers do not block BO development, but they still block staging, production, client delivery, Gate 5 final release, and final platform release.

## BO Task Intent

The BO task requires:

```text
read prior BO tasks, handoffs, QA reports, and known risks
verify current BO app state against the frozen backend contract
list the BO work needed for completion
avoid backend/API changes unless Coordinator approves a separate backend remediation task
keep customer frontend frozen
use Docker-only BO validation commands
```

## Guardrails

BO Develop must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/docker-runtime-policy.md
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
```

For this analysis-only pass, BO Develop should not edit implementation code. If implementation work is needed, it should be listed for the next Orchestrator-dispatched task.

## Expected BO Output

```text
ai-agents/handoffs/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo-handoff.md
```

The BO handoff should classify gaps as:

```text
bo_implementation_needed
bo_validation_needed
backend_contract_gap_requires_coordinator
blocked_by_external_release_ops
already_complete
out_of_scope
```

## Validation Plan Given To BO

Docker-only:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

The backend seed command is only for browser/API-backed analysis if needed and must not imply backend implementation changes.

## Next Step After BO Handoff

If BO reports implementation gaps only, Orchestrator should create a focused BO implementation task and route to BO Develop.

If BO reports backend contract gaps, Orchestrator should route back to Coordinator for approval before any backend remediation.

If BO reports analysis-only validation complete with no gaps, Orchestrator should create a QA task.

## Next Agent

BO Develop
