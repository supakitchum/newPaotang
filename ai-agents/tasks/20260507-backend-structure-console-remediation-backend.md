# 20260507-backend-structure-console-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator opened a focused follow-up after the user questioned missing backend structure:

```text
root apps/platform-api/app/Http/Controllers is absent
apps/platform-api/app/Console/Commands is absent
```

Act on:

```text
ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-coordinator-handoff.md
```

The missing root controller directory is not itself a defect. Controllers intentionally live under the modular monolith path:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

Do not create duplicate controllers under root `apps/platform-api/app/Http/Controllers`.

The missing console command-class layer is a maintainability gap. Convert the existing production workflow closure commands from `routes/console.php` into first-class Laravel command classes while preserving behavior.

## Objective

Make backend controller and console-command structure explicit, maintainable, documented, and testable before M9.

Preserve current API contracts, command signatures, command output intent, service delegation, customer UI flow, back-office UI scope, permission behavior, tenant scoping, and business rules.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-structure-console-remediation-coordinator-handoff.md`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Approved implementation scope:

```text
apps/platform-api/app/Console/**
apps/platform-api/routes/console.php
apps/platform-api/bootstrap/app.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-console-commands.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

Backend Develop may update another backend-owned `docs/backend-*.md` file only if it is directly needed for clear cross-linking. If so, document why in the backend handoff.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit API routes, endpoint URLs, response envelopes, OpenAPI contracts, permissions, tenant-scope semantics, or business rules.
- Do not move or duplicate controller classes into root `apps/platform-api/app/Http/Controllers`.
- Do not change customer UI flow.
- Do not change back-office UI flow.
- Do not add new production workflow commands beyond the existing command set unless a test requires a tiny support command and the handoff justifies it.
- Do not redesign queues, Horizon, workers, scheduling, or async architecture.
- Do not upgrade Laravel, PHP, Composer, or package dependencies.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, migrations, tests, or builds on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/Console/**
apps/platform-api/routes/console.php
apps/platform-api/bootstrap/app.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-console-commands.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Http/Controllers/**
docs/openapi.yaml
docs/status-enums.md
docs/permissions.md
docs/erd.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/workspace-app-structure.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

If a source-of-truth contract appears wrong, document the issue in the backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `docs/docker-runtime-policy.md` and confirm all runtime/test/migration commands use Docker only.
3. Inspect the active controller directory and document that this project uses the module controller convention:
   - `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
   - no duplicate root `apps/platform-api/app/Http/Controllers` layer
4. Inspect the current closure commands in `apps/platform-api/routes/console.php`.
5. Create first-class Laravel command classes under the approved console namespace/directory.
6. Minimum required command classes:
   - `PlatformAboutCommand`
   - `ExpireStockReservationsCommand`
   - `ProcessSoldSyncCommand`
   - `ProcessRewardCheckCommand`
   - `CalculateCommissionsCommand`
7. Preserve these command signatures exactly:

```text
platform:about
stock:reservations:expire {--limit=100}
stock:sold:sync {--limit=100}
reward:check {reward_result_id?} {--chunk=100}
commission:calculate {order_id?} {--tenant_id=} {--limit=100}
```

8. Preserve output intent:

```text
platform:about -> NewPaotang Platform API
stock:reservations:expire -> Expired reservations: <count>
stock:sold:sync -> Processed sold events: <count>
reward:check -> Processed reward tickets: <count>
commission:calculate -> Calculated commission transactions: <count>
```

9. Preserve service delegation:

```text
stock:reservations:expire -> App\Shared\PartnerStore\PartnerStoreService::expireReservations()
stock:sold:sync -> App\Shared\Commerce\CommerceService::processSoldSync()
reward:check -> App\Shared\Reward\RewardService::processRewardCheck()
commission:calculate -> App\Shared\Growth\GrowthService::calculateCommissions()
```

10. Register command classes using the Laravel-supported mechanism for the current `apps/platform-api` app. Keep `routes/console.php` only for lightweight bootstrapping, or leave it without production workflow closure definitions if class registration replaces them.
11. Add focused tests proving:
    - expected Artisan command names are registered
    - command signatures/options remain stable
    - commands delegate to the existing services
    - commands keep the same successful output shape for empty or seeded testing data
    - `routes/console.php` no longer owns production workflow closures unless explicitly justified
    - controller convention is documented as module-based
12. Add `docs/backend-console-commands.md` documenting:
    - command class location
    - registration convention
    - command list and signatures
    - service ownership for each command
    - Docker-only execution examples
    - why controllers live under `apps/platform-api/app/Modules/Platform/Http/Controllers` instead of root `apps/platform-api/app/Http/Controllers`
13. Update `docs/backend-architecture-compliance.md` to reference the command-class layer and controller convention.
14. Run Docker-only validation commands.
15. Write the Backend handoff with complete evidence, validation output, changed files, residual risks/questions, and next agent.

## Acceptance Criteria

- `apps/platform-api/app/Console/Commands` or the documented approved command-class directory exists.
- The five required command classes exist and are registered.
- `php artisan list --raw` still shows:

```text
platform:about
stock:reservations:expire
stock:sold:sync
reward:check
commission:calculate
```

- Existing command signatures/options remain stable.
- Existing output intent remains stable.
- Production workflow command logic is no longer closure-only in `routes/console.php`.
- Command classes delegate to the existing services instead of duplicating business logic.
- Controller path convention is documented as module-based.
- No duplicate root `apps/platform-api/app/Http/Controllers` layer is introduced.
- No API contract, customer UI, back-office UI, permission, tenant-scope, or business-rule change is introduced.
- Focused Command/Console tests exist and pass.
- Full platform-api test suite passes through Docker.

## Validation Commands

Use Docker commands only. Do not write or run local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration commands.

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

If one of the filtered test names did not exist before this task, add focused tests so at least one command/console filtered suite is meaningful.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
controller convention confirmation
command class list and registration method
validation commands and results
known risks
next agent
```

Recommended next agent:

```text
Orchestrator
```
