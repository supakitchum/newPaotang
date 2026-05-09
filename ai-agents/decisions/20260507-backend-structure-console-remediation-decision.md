# Backend Structure And Console Command Remediation Decision

## Context

After Backend Architecture Compliance Remediation was approved, the user raised two additional structure concerns:

```text
The root apps/platform-api/app/Http/Controllers directory is not visible.
The app/Console/Commands command-class directory is not visible.
```

Coordinator inspected the current backend and found:

```text
Controllers do exist under the modular monolith path apps/platform-api/app/Modules/Platform/Http/Controllers.
apps/platform-api/app/Http/Controllers does not exist.
apps/platform-api/app/Console/Commands does not exist.
Artisan commands currently exist as closure commands in apps/platform-api/routes/console.php.
```

Docker verification confirmed these commands are currently registered:

```text
platform:about
stock:reservations:expire
stock:sold:sync
reward:check
commission:calculate
```

The controller location is consistent with the task source of truth and `docs/workspace-app-structure.md` modular-monolith direction. However, the Backend handoff incorrectly listed controller files under `apps/platform-api/app/Http/Controllers/...`, which should be corrected or documented for traceability.

The missing command-class layer is not a runtime failure because Laravel loads `routes/console.php`. Still, production workflow commands for stock expiration, sold sync, reward checking, and commission calculation are important enough that they should be first-class command classes with focused tests and documentation instead of closure-only definitions.

## Decision

Open a focused Backend Structure And Console Command Remediation slice before M9.

This decision does not revoke the approved model/request validation remediation. It adds a follow-up compliance hardening gate for backend structure clarity and command maintainability.

## Orchestrator Instruction

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-structure-console-remediation-backend.md
```

After Backend Develop writes its handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-structure-console-remediation-qa.md
```

## Objective

Make backend controller and console-command structure explicit, maintainable, and testable without changing API contracts, command signatures, business rules, customer UI flow, or back-office UI scope.

## Source Of Truth

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/workspace-app-structure.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/backend-architecture-compliance.md
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/tests/**
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md
```

## Approved Scope

```text
apps/platform-api/app/Console/**
apps/platform-api/routes/console.php
apps/platform-api/bootstrap/app.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-console-commands.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

Backend Develop may update another backend-owned doc if that is clearer, but must not edit source-of-truth contract docs unless explicitly approved.

## Required Backend Work

### Controller Structure

Verify and document the accepted controller path convention:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

Do not create a duplicate root `apps/platform-api/app/Http/Controllers` layer just to satisfy a conventional Laravel skeleton path. This project is a modular monolith and the module controller path is the active convention.

Update backend compliance documentation to make this explicit and prevent future handoff confusion.

### Console Command Structure

Move production workflow commands out of closure-only definitions and into Laravel command classes.

Minimum required command classes:

```text
PlatformAboutCommand
ExpireStockReservationsCommand
ProcessSoldSyncCommand
ProcessRewardCheckCommand
CalculateCommissionsCommand
```

Keep existing command signatures and output intent:

```text
platform:about
stock:reservations:expire {--limit=100}
stock:sold:sync {--limit=100}
reward:check {reward_result_id?} {--chunk=100}
commission:calculate {order_id?} {--tenant_id=} {--limit=100}
```

Register commands using the Laravel-supported mechanism for the current `apps/platform-api` application. Keep `routes/console.php` only for lightweight bootstrapping or remove closure definitions if classes are registered elsewhere.

### Tests And Documentation

Add focused tests that prove:

```text
expected Artisan command names are registered
command signatures remain stable
commands call existing services and produce the same successful output shape for empty/seeded testing data
routes/console.php no longer owns production workflow closures unless explicitly justified
controller convention is documented as module-based
```

Add `docs/backend-console-commands.md` or equivalent documentation describing:

```text
command class location
registration convention
command list
service ownership for each command
Docker-only execution examples
why controllers live under the module path instead of app/Http/Controllers
```

## Out Of Scope

```text
No API route, response envelope, permission, tenant-scope, or business-rule changes.
No customer UI changes.
No back-office UI changes.
No new commands beyond the existing command set unless documented as required by tests.
No queue/Horizon/worker redesign.
No Laravel/PHP dependency upgrade.
No host PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration commands.
```

## Validation Required From Backend Develop

Use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan list --raw
docker compose run --rm platform-api php artisan platform:about
docker compose run --rm platform-api php artisan stock:reservations:expire --limit=1
docker compose run --rm platform-api php artisan stock:sold:sync --limit=1
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
docker compose run --rm platform-api php artisan test --filter=Command
docker compose run --rm platform-api php artisan test --filter=Console
docker compose run --rm platform-api php artisan test
```

If one of the filtered test names does not exist before the task, add focused tests so at least one command/console filtered suite is meaningful.

## QA Requirements

QA must verify:

```text
controller path convention is documented and no duplicate root controller layer was introduced unnecessarily
all existing command names and options still work
production workflow command logic moved from closure-only definitions into command classes
commands still delegate to existing services
Docker runtime policy was followed
no API contract, customer UI flow, back-office UI flow, permission, tenant-scope, or business-rule regression was introduced
full platform-api test suite passes
```

QA report path:

```text
ai-agents/reports/20260507-backend-structure-console-remediation-qa-report.md
```

## Next Agent

```text
Orchestrator
```
