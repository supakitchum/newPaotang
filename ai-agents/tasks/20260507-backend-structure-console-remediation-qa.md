# 20260507-backend-structure-console-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Backend Structure And Console Command Remediation slice.

Validate the completed remediation against:

```text
ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-coordinator-handoff.md
ai-agents/tasks/20260507-backend-structure-console-remediation-backend.md
ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md
```

This is a focused follow-up after Backend Architecture Compliance Remediation approval. It does not reopen model/request-validation remediation except where command/controller documentation references that approved work.

## Objective

Validate that backend controller and console-command structure is now explicit, maintainable, documented, and testable without changing:

```text
API contracts
command signatures
command output intent
service delegation
business rules
permission behavior
tenant-scope semantics
customer UI flow
back-office UI flow
```

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/workspace-app-structure.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-console-commands.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-backend-structure-console-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-structure-console-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-structure-console-remediation-backend.md`
- `ai-agents/handoffs/20260507-backend-structure-console-remediation-backend-handoff.md`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/app/Console/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Validate Backend Develop changes within approved implementation scope:

```text
apps/platform-api/app/Console/**
apps/platform-api/routes/console.php
apps/platform-api/bootstrap/app.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-console-commands.md
```

Inspect at least:

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
```

Also inspect current backend structure to confirm:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/** exists
apps/platform-api/app/Http/Controllers was not introduced unnecessarily
```

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not change command signatures, command behavior, service code, routes, controllers, OpenAPI, permissions, tenant logic, customer flow, or back-office flow.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, migrations, tests, builds, or package commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-backend-structure-console-remediation-qa-report.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
ai-agents/reports/** except ai-agents/reports/20260507-backend-structure-console-remediation-qa-report.md
```

If a defect requires code, docs, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm Backend did not edit `apps/customer/**`, `apps/back-office/**`, forbidden docs, decisions, reports, tasks, or Board as part of this slice. Note unrelated dirty workspace files separately.
5. Verify the active controller convention is documented as:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

6. Verify no duplicate root controller layer was introduced unnecessarily:

```text
apps/platform-api/app/Http/Controllers
```

7. Verify required command classes exist:
   - `PlatformAboutCommand`
   - `ExpireStockReservationsCommand`
   - `ProcessSoldSyncCommand`
   - `ProcessRewardCheckCommand`
   - `CalculateCommissionsCommand`
8. Verify command classes are registered through the Laravel-supported mechanism used by this application, reported by Backend as:

```text
apps/platform-api/bootstrap/app.php -> withCommands([...])
```

9. Verify `apps/platform-api/routes/console.php` no longer owns production workflow `Artisan::command(...)` closures unless the Backend handoff explicitly justified a remaining closure.
10. Verify command signatures/options remain stable:

```text
platform:about
stock:reservations:expire {--limit=100}
stock:sold:sync {--limit=100}
reward:check {reward_result_id?} {--chunk=100}
commission:calculate {order_id?} {--tenant_id=} {--limit=100}
```

11. Verify command output intent remains stable:

```text
platform:about -> NewPaotang Platform API
stock:reservations:expire -> Expired reservations: <count>
stock:sold:sync -> Processed sold events: <count>
reward:check -> Processed reward tickets: <count>
commission:calculate -> Calculated commission transactions: <count>
```

12. Verify command classes delegate to existing services instead of duplicating business logic:

```text
stock:reservations:expire -> App\Shared\PartnerStore\PartnerStoreService::expireReservations()
stock:sold:sync -> App\Shared\Commerce\CommerceService::processSoldSync()
reward:check -> App\Shared\Reward\RewardService::processRewardCheck()
commission:calculate -> App\Shared\Growth\GrowthService::calculateCommissions()
```

13. Verify focused command/console tests cover registration, stable signatures/options, service delegation, output shape, closure removal, and controller convention.
14. Verify `docs/backend-console-commands.md` documents command class location, registration convention, command list/signatures, service ownership, Docker examples, and module controller convention.
15. Verify `docs/backend-architecture-compliance.md` references the command-class layer and module controller convention.
16. Evaluate Backend's question about `apps/platform-api/app/Console/README.md`: confirm whether it is within approved scope and useful as container-visible structure documentation, or flag it as unnecessary documentation drift.
17. Run all required validation commands through Docker only.
18. Write QA report with pass/fail status, validation evidence, defects, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-backend-structure-console-remediation-qa-report.md`.
- QA report states whether Backend Structure And Console Command Remediation passes, conditionally passes, or fails.
- QA report confirms controller path convention is documented and module-based.
- QA report confirms no duplicate root `apps/platform-api/app/Http/Controllers` layer was introduced unnecessarily.
- QA report confirms all required command classes exist and are registered.
- QA report confirms command names, signatures/options, and output intent remain stable.
- QA report confirms production workflow command logic moved from closure-only definitions into command classes.
- QA report confirms commands still delegate to existing services.
- QA report confirms focused Command/Console tests are meaningful and pass.
- QA report confirms Docker runtime policy was followed.
- QA report confirms no API contract, customer UI flow, back-office UI flow, permission, tenant-scope, or business-rule regression was introduced.
- QA report confirms full platform-api test suite passes.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan list --raw
docker compose run --rm platform-api php artisan help platform:about
docker compose run --rm platform-api php artisan help stock:reservations:expire
docker compose run --rm platform-api php artisan help stock:sold:sync
docker compose run --rm platform-api php artisan help reward:check
docker compose run --rm platform-api php artisan help commission:calculate
docker compose run --rm platform-api php artisan platform:about
docker compose run --rm platform-api php artisan stock:reservations:expire --limit=1
docker compose run --rm platform-api php artisan stock:sold:sync --limit=1
docker compose run --rm platform-api php artisan reward:check --env=testing --chunk=10
docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test --filter=Command
docker compose run --rm platform-api php artisan test --filter=Console
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
find apps/platform-api/app/Console -maxdepth 3 -type f | sort
find apps/platform-api/app/Modules/Platform/Http/Controllers -maxdepth 1 -type f | sort
test ! -d apps/platform-api/app/Http/Controllers
rg -n "Artisan::command|withCommands|platform:about|stock:reservations:expire|stock:sold:sync|reward:check|commission:calculate|PartnerStoreService|CommerceService|RewardService|GrowthService|Modules/Platform/Http/Controllers|app/Http/Controllers" apps/platform-api/bootstrap/app.php apps/platform-api/routes/console.php apps/platform-api/app/Console apps/platform-api/tests docs/backend-console-commands.md docs/backend-architecture-compliance.md
sed -n '1,220p' apps/platform-api/bootstrap/app.php
sed -n '1,220p' apps/platform-api/routes/console.php
sed -n '1,260p' apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
sed -n '1,260p' docs/backend-console-commands.md
sed -n '1,220p' docs/backend-architecture-compliance.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-backend-structure-console-remediation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
scope drift findings
controller convention findings
command class and registration findings
command signature and output findings
service delegation findings
routes/console.php closure findings
documentation findings
test coverage findings
Docker policy findings
API contract and business rule regression findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```
