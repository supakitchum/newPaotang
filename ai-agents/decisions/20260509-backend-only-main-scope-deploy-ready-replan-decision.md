# Backend-Only Main Scope Deploy-Ready Replan Decision

Date: 2026-05-09
Agent: Coordinator

## Context

The user explicitly changed the main plan:

```text
cancel Back Office work from the main plan
move Back Office to the next phase
finish the main plan by closing backend deploy-readiness according to the documents
```

The repository has already been cleaned by consolidation commit `f4f5b40` on branch `deverlop`.

## Decision

The current main plan is now backend-only.

Back Office work is removed from the active main plan and deferred to the next phase. This includes:

```text
BO page/menu completion
BO visual polish
BO template/CSS remediation
BO dependency/license remediation
BO npm audit remediation
BO production-readiness work
BO deployment/build release work
any implementation edit under apps/back-office/**
```

Customer frontend work is also frozen unless Coordinator explicitly opens a regression-only backend contract check.

## Active Closeout Target

The active target is:

```text
apps/platform-api backend deploy-readiness
```

Backend deploy-readiness must cover:

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

## Constraints

```text
Do not dispatch BO Develop for current main-plan work.
Do not edit apps/back-office/**.
Do not edit apps/customer/** unless Coordinator scopes a regression-only task.
Do not change API paths or response contracts without Coordinator approval.
Do not change customer UI flow.
Do not claim staging, production, or final release approval without external evidence.
All runtime, test, build, migration, queue, scheduler, and Artisan commands must run through Docker only.
If a blocker needs real external infrastructure, document it as an external blocker instead of fabricating readiness.
```

## Documents Updated

```text
document/08_IMPLEMENTATION_ROADMAP.md
document/15_EXECUTION_PLAN.md
document/README.md
document/09_AI_WORK_INSTRUCTIONS.md
document/11_DEPLOYMENT_WHITE_LABEL.md
docs/workspace-app-structure.md
docs/m10-deployment-monitoring-load-test.md
ai-agents/BOARD.md
```

## Next Agent

Orchestrator

## Next Task

```text
m10-backend-only-deploy-ready-closeout
```
