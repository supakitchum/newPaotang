# Partner BO Domain Auth Branding - Coordinator Handoff

## Date

2026-05-21

## From

Coordinator

## To

Orchestrator

## Worktree

```text
/Users/supakit/WorkSpace/www/newPaotang
```

## Task

```text
partner-bo-domain-auth-branding
```

## Coordinator Summary

User wants each Partner to have a dedicated Back Office domain derived from the storefront domain:

```text
Storefront/customer: partner-a.test
Back Office + same-origin API entrypoint: bo.partner-a.test
```

Partner BO login must be tenant-only, branded by tenant theme, and must not allow Central scope or cross-partner login. Central BO login must remain unchanged.

## Source Files

```text
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-orchestrator.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-backend.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-bo.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-qa.md
```

## Dispatch Order

```text
Orchestrator -> Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

## Key Constraints

```text
Do not use api.* in this workflow.
Do not implement custom BO host labels other than bo.* in v1.
Do not wipe runtime DB newpaotang.
Destructive QA/test DB setup must use APP_ENV=testing, DB_DATABASE=newpaotang_test, --env=testing.
Do not silently merge or delete duplicate partner tenants. Report blocker if duplicates prevent unique constraint.
All agents use canonical worktree /Users/supakit/WorkSpace/www/newPaotang.
```

## Next Agent

Orchestrator
