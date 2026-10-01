# partner-bo-domain-auth-branding Handoff

## Agent

Orchestrator

## Task

Dispatch `partner-bo-domain-auth-branding` from Coordinator to Backend Develop.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: 7b6672a12f45c9c5a5048b3f74fc41b7806e0008
origin/develop at dispatch start: 7b6672a12f45c9c5a5048b3f74fc41b7806e0008
git status --short --branch: ## develop...origin/develop plus unrelated apps/platform-api/.phpunit.result.cache
```

Start gate completed:

```text
pwd: /Users/supakit/WorkSpace/www/newPaotang
git top-level: /Users/supakit/WorkSpace/www/newPaotang
git fetch origin: completed
git merge --ff-only origin/develop: Already up to date.
HEAD equals origin/develop.
```

Known unrelated dirty artifact:

```text
apps/platform-api/.phpunit.result.cache
```

This file is PHPUnit runtime noise from prior QA and was not staged.

## What Was Done

Read the Coordinator source of truth:

```text
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-coordinator-handoff.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-orchestrator.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-backend.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-bo.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-qa.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
```

Coordinator already authored detailed Backend, BO, and QA task files. I kept those task prompts as the active prompts and routed the first implementation step to Backend Develop.

Dispatch order:

```text
Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

Backend Develop owns the first implementation slice:

```text
bo.* admin host resolver
GET /api/v1/public/admin-site-config
partner-host tenant-only admin auth/session behavior
partner-host scope guard restrictions
1 Partner = 1 Tenant schema/provisioning guard
backend tests and OpenAPI/docs updates where needed
```

BO Develop must wait for:

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
```

QA Tester must wait for both backend and BO handoffs.

## Files Changed

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-orchestrator-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: only orchestration files plus unrelated apps/platform-api/.phpunit.result.cache before staging
```

## Known Risks

```text
apps/platform-api/.phpunit.result.cache remains dirty and unstaged.
Backend migration must not silently merge/delete duplicate partner tenants. If duplicate partner_tenants.partner_id rows block uniqueness, Backend must report a blocker.
This workflow must use bo.{storefront_host} and same-origin /api/v1. Do not introduce api.* support.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop
