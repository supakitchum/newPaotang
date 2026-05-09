# 20260507-backend-structure-console-remediation Handoff

## Agent

Backend Develop

## Task

20260507-backend-structure-console-remediation

## What Was Done

- Converted the five existing production workflow closure commands from `apps/platform-api/routes/console.php` into first-class Laravel command classes.
- Registered command classes in `apps/platform-api/bootstrap/app.php` through Laravel `withCommands([...])`.
- Kept `apps/platform-api/routes/console.php` as lightweight console bootstrapping only.
- Confirmed the active controller convention is module-based under `apps/platform-api/app/Modules/Platform/Http/Controllers/**`.
- Did not create a duplicate root `apps/platform-api/app/Http/Controllers` directory.
- Added focused console/command tests for registration, stable signatures/options, service delegation, output shape, closure removal, and controller convention.
- Added backend console command documentation and updated backend architecture compliance documentation.

## Files Changed

```text
apps/platform-api/app/Console/README.md
apps/platform-api/app/Console/Commands/PlatformAboutCommand.php
apps/platform-api/app/Console/Commands/ExpireStockReservationsCommand.php
apps/platform-api/app/Console/Commands/ProcessSoldSyncCommand.php
apps/platform-api/app/Console/Commands/ProcessRewardCheckCommand.php
apps/platform-api/app/Console/Commands/CalculateCommissionsCommand.php
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/console.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

## Controller Convention Confirmation

The accepted controller path is:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

The root path remains absent:

```text
apps/platform-api/app/Http/Controllers
```

This is intentional for the Laravel modular monolith. Controllers were not moved or duplicated.

## Command Class List And Registration Method

Command classes added:

```text
App\Console\Commands\PlatformAboutCommand
App\Console\Commands\ExpireStockReservationsCommand
App\Console\Commands\ProcessSoldSyncCommand
App\Console\Commands\ProcessRewardCheckCommand
App\Console\Commands\CalculateCommissionsCommand
```

Registration:

```text
apps/platform-api/bootstrap/app.php -> withCommands([...])
```

`apps/platform-api/routes/console.php` no longer owns production workflow `Artisan::command(...)` closures.

## Command Signatures Preserved

```text
platform:about
stock:reservations:expire {--limit=100}
stock:sold:sync {--limit=100}
reward:check {reward_result_id?} {--chunk=100}
commission:calculate {order_id?} {--tenant_id=} {--limit=100}
```

## Service Delegation Preserved

```text
platform:about -> command-only platform identity output
stock:reservations:expire -> App\Shared\PartnerStore\PartnerStoreService::expireReservations()
stock:sold:sync -> App\Shared\Commerce\CommerceService::processSoldSync()
reward:check -> App\Shared\Reward\RewardService::processRewardCheck()
commission:calculate -> App\Shared\Growth\GrowthService::calculateCommissions()
```

## API Endpoints Implemented

No API endpoints were added or changed.

No API routes, endpoint URLs, response envelopes, OpenAPI contracts, permissions, tenant-scope semantics, customer UI flow, back-office UI flow, or business rules were changed.

## Permissions And Tenant Checks Enforced

- Existing command service delegation is preserved, so tenant isolation, permission, idempotency, audit, wallet, reward, stock, sold-sync, and commission behavior remain owned by existing services.
- No permission middleware or tenant-scope logic was bypassed.
- No controller or route-level auth behavior was changed.

## Documentation Updated

- `docs/backend-console-commands.md` documents command class location, registration convention, command list/signatures, service ownership, Docker examples, and module controller convention.
- `docs/backend-architecture-compliance.md` now references the command-class layer and module controller convention.
- `apps/platform-api/app/Console/README.md` provides app-local structure documentation that is visible inside the `platform-api` container for focused tests.

## Validation

All application commands were run through Docker only.

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS
```

```text
docker compose run --rm platform-api php artisan list --raw
PASS
Confirmed registered commands:
platform:about
stock:reservations:expire
stock:sold:sync
reward:check
commission:calculate
```

```text
docker compose run --rm platform-api php artisan platform:about
PASS
Output: NewPaotang Platform API
```

```text
docker compose run --rm platform-api php artisan stock:reservations:expire --limit=1
PASS
Output: Expired reservations: 0
```

```text
docker compose run --rm platform-api php artisan stock:sold:sync --limit=1
PASS
Output: Processed sold events: 0
```

```text
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10
PASS
Output: Processed reward tickets: 0
```

```text
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
PASS
Output: Calculated commission transactions: 0
```

```text
docker compose run --rm platform-api php artisan test --filter=Command
Initial run failed because the new test attempted to read root workspace docs from inside the platform-api container.
Fixed by adding app-local `apps/platform-api/app/Console/README.md` and reading that container-visible structure doc.
Final PASS: 5 tests, 74 assertions.
```

```text
docker compose run --rm platform-api php artisan test --filter=Console
PASS: 3 tests, 42 assertions.
```

```text
docker compose run --rm platform-api php artisan test
PASS: 103 tests, 1787 assertions.
```

## Known Risks

- The `platform-api` container test runtime does not see root workspace `docs/**`, so focused tests validate the controller convention through app-local `apps/platform-api/app/Console/README.md`. Root docs were still updated for Coordinator/QA workspace review.
- The broader git worktree remains dirty with unrelated `apps/customer/**` changes from other agent work. Backend Develop did not edit those files in this task.
- No scheduling, queue worker, Horizon, or async architecture redesign was attempted; command classes only preserve the current command behavior.

## Questions For Coordinator

- None blocking.
- Coordinator/QA may decide whether the app-local `apps/platform-api/app/Console/README.md` should remain as container-visible structure documentation or be removed after QA. It is currently inside approved `apps/platform-api/app/Console/**` scope and supports the focused test evidence.

## Next Agent

Orchestrator
