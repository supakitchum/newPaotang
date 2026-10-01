# New Chat Coordinator Transfer

Date: 2026-05-09
Workspace: `/Users/supakit/WorkSpace/www/newPaotang`
Branch: `deverlop`
Remote: `origin/deverlop`

## Purpose

Use this file to transfer the current Coordinator context into a new chat without losing the latest scope decision, git status, or next-agent routing.

## Current Identity

```text
You are the Coordinator Agent for NewPaotang.
You do not act as Backend Develop, BO Develop, Customer Develop, Orchestrator, or QA Tester unless the user explicitly changes the role.
Your job is to control the plan, read handoffs/reports, approve or reject QA, write decisions, and tell Orchestrator what to dispatch next.
```

## Latest Main Scope Decision

The active main plan is now backend-only.

```text
Back Office work is removed from the current main plan and deferred to the next phase.
The current phase closes only when apps/platform-api is backend deploy-ready according to the project docs.
```

Frozen scope:

```text
Do not dispatch BO Develop.
Do not edit apps/back-office/**.
Do not edit apps/customer/** unless Coordinator scopes a regression-only backend contract check.
Do not change API paths or response contracts without Coordinator approval.
Do not claim staging, production, or final release approval without external evidence.
All runtime, test, build, migration, queue, scheduler, and Artisan commands must run through Docker only.
```

## Current Progress Estimate

```text
Current backend-only phase progress: about 82% complete.
Remaining: about 18%.
```

What is mostly complete:

```text
Backend implementation and API surface
OpenAPI/app route parity: 279/279/0/0
Latest full backend Docker suite: passed
route:list: passed
platform:smoke: passed after reseed
Model/service/controller/request/migration/seeder/test/doc foundation
Git worktree cleanup and latest scope replan commits
```

What remains:

```text
Orchestrator must open m10-backend-only-deploy-ready-closeout.
Backend Develop must perform the final backend-only deploy-readiness audit.
Backend Develop must close safe backend gaps or document exact external blockers.
Backend Develop must produce the blocker matrix and release-gate ledger.
QA Tester must verify the backend-only closeout through Docker only.
Coordinator must review QA before approving backend phase completion.
```

## Latest Important Commits

```text
f4f5b40 20260509-m10-consolidate-backend-bo-customer-progress
9eb703a 20260509-backend-only-main-scope-replan
```

The worktree was clean after commit `9eb703a` was pushed to `origin/deverlop`.

## Files To Read First In The New Chat

Read these in order:

```text
ai-agents/README.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/roles/coordinator.md
ai-agents/BOARD.md
ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md
ai-agents/handoffs/20260509-backend-only-main-scope-deploy-ready-replan-coordinator-handoff.md
document/08_IMPLEMENTATION_ROADMAP.md
document/15_EXECUTION_PLAN.md
document/11_DEPLOYMENT_WHITE_LABEL.md
docs/m10-deployment-monitoring-load-test.md
docs/m10-backend-completion-and-release-gate-closure.md
ops/m10/backend-release-gate-ledger.md
```

## Active Board State

```text
Active Task: m10-backend-only-deploy-ready-closeout
Coordinator: completed latest replan
Orchestrator: pending dispatch
Backend Develop: pending backend-only closeout
BO Develop: deferred to next phase
Customer Develop: frozen unless regression-only task is scoped
QA Tester: pending after Backend Develop handoff
```

## Next Agent

```text
Orchestrator
```

## Next Task To Dispatch

```text
m10-backend-only-deploy-ready-closeout
```

## Required Orchestrator Instruction

Tell Orchestrator to create a backend-only task for Backend Develop.

The task must include:

```text
OpenAPI/app route parity recheck
permission and tenant isolation compliance
model/service/controller/request/migration/seeder/test/doc compliance
Docker-only backend validation plan
queue, scheduler, Horizon, Reverb, idempotency, audit, outbox/inbox readiness
backend runtime/image/deployment template readiness
load-test scripts and backend execution evidence
Cloudflare/HTTPS/WAF/CDN/R2 backend readiness or exact external blocker evidence
mail, payment, LINE provider, production secret-manager, old-data migration, cutover, and rollback blocker matrix
backend release-gate ledger
```

Acceptance for Backend Develop:

```text
No edits under apps/back-office/**
No edits under apps/customer/** unless Coordinator explicitly scopes a regression-only check
No API contract changes unless approved by Coordinator
All validation commands must be Docker commands
Handoff must include changed files, Docker validation commands/results, route parity evidence, blocker matrix, and commit hash
Implementation agent must commit its own task scope after validation passes
```

## Coordinator Reminder

After QA passes the backend-only closeout:

```text
Review QA report before approval.
Do not approve staging, production, or final release unless external evidence exists.
If backend deploy-ready is approved and the project is about to move to the next phase, stop and commit/push first.
```
