# Backend Structure And Console Command Remediation Coordinator Handoff

## Agent

Coordinator

## Task

Open a focused follow-up after the user questioned missing root Http/Controllers and Console/Commands directories.

## What Was Done

Coordinator inspected the backend structure and confirmed:

```text
Controllers exist under apps/platform-api/app/Modules/Platform/Http/Controllers.
apps/platform-api/app/Http/Controllers does not exist.
apps/platform-api/app/Console/Commands does not exist.
Artisan commands are currently closure commands in apps/platform-api/routes/console.php.
```

Coordinator verified command registration through Docker:

```sh
docker compose run --rm platform-api php artisan list --raw
```

Registered commands found:

```text
platform:about
stock:reservations:expire
stock:sold:sync
reward:check
commission:calculate
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-structure-console-remediation-backend.md
```

After Backend Develop handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-structure-console-remediation-qa.md
```

## Important Direction

The missing root `apps/platform-api/app/Http/Controllers` directory is not itself a defect. The accepted controller convention for this modular monolith is:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

Do not ask Backend Develop to duplicate controllers into root `app/Http/Controllers`.

The missing `apps/platform-api/app/Console/Commands` command-class layer is a maintainability gap for production workflow commands. Backend Develop should convert the existing closure commands into command classes while preserving names, options, outputs, and service delegation.

## Validation

Coordinator ran one Docker-only runtime inspection:

```text
docker compose run --rm platform-api php artisan list --raw
```

No host PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration command was run.

## Next Agent

Orchestrator
