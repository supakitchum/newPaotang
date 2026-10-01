# Backend-Only Main Scope Deploy-Ready Replan Coordinator Handoff

## Agent

Coordinator

## Task

Replan the active main scope so it closes at backend deploy-readiness and defers Back Office to the next phase.

## What Changed

Back Office work is removed from the current main plan.

The current active closeout is now:

```text
apps/platform-api backend deploy-readiness only
```

Updated documents:

```text
document/08_IMPLEMENTATION_ROADMAP.md
document/15_EXECUTION_PLAN.md
document/README.md
document/09_AI_WORK_INSTRUCTIONS.md
document/11_DEPLOYMENT_WHITE_LABEL.md
docs/workspace-app-structure.md
docs/m10-deployment-monitoring-load-test.md
ai-agents/BOARD.md
ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md
```

## Frozen Scope

```text
Do not dispatch BO Develop.
Do not edit apps/back-office/**.
Do not edit apps/customer/** unless Coordinator scopes a regression-only backend contract check.
```

## Backend Closeout Scope

Orchestrator must open a backend-only task for Backend Develop covering:

```text
OpenAPI/app route parity
permission and tenant isolation compliance
model/service/controller/request/migration/seeder/test/doc compliance
Docker-only backend validation
queue, scheduler, Horizon, Reverb, idempotency, audit, outbox/inbox readiness
backend runtime/image/deployment template readiness
load-test scripts and backend execution evidence
Cloudflare/HTTPS/WAF/CDN/R2 backend readiness or exact external blocker evidence
mail, payment, LINE provider, production secret-manager, old-data migration, cutover, and rollback blocker matrix
backend release-gate ledger
```

## Validation

No application runtime command was required for this documentation/coordination update.

Latest accepted backend QA remains:

```text
OpenAPI/app route parity: 279/279/0/0
Full backend Docker suite: passed
route:list: passed
platform:smoke: passed after reseed
```

## Git Context

Previous cleanup commit:

```text
f4f5b40 20260509-m10-consolidate-backend-bo-customer-progress
```

Per the new rule, the next implementation agent must commit its own scoped changes after validation passes.

## Next Agent

Orchestrator

## Recommended Next Task

```text
m10-backend-only-deploy-ready-closeout
```
