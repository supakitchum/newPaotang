# Runtime DB Initial Data Update Decision

## Decision Type

```text
User-requested local runtime DB update
```

## Task Key

```text
runtime-db-initial-data-update
```

## Date

```text
2026-06-26T13:40:52+0700
```

## Execution Mode

```text
AUTO
```

Fallback:

```text
MANUAL if Codex native runner / multi_agent_v1.spawn_agent is unavailable
```

## User Requirement

```text
migrate ข้อมูลเริ่มต้นบน runtimeDB ที
```

## Coordinator Interpretation

Apply the current pending platform-api schema and idempotent bootstrap/initial data to the local runtime DB.

This is a runtime DB operation. Coordinator must not run the commands directly. GitOps is the only allowed executor.

## Current Evidence

```text
branch: develop
worktree: dirty
runtime DB target requested by user: local runtime DB
```

Relevant dirty/runtime files observed at intake:

```text
apps/platform-api/database/migrations/2026_06_25_000001_create_customer_biometric_and_social_auth_tables.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/database/seeders/InitialSystemSeeder.php
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/Auth/**
apps/back-office/pages/admin/tenant/social-login.vue
apps/customer_flutter/**
```

Source inspection:

```text
DatabaseSeeder calls InitialSystemSeeder.
InitialSystemSeeder calls DefaultRbacMenuSeeder and BootstrapAdminSeeder, conditionally BaseLotteryNumberSeeder only when config enables it, and syncs the translation catalog.
DefaultRbacMenuSeeder includes tenant social-login permissions/menu and uses upsert-style idempotent writes.
```

## Task Classification

```text
Task Size: STANDARD
Flow Mode: STANDARD
Primary Owner: GitOps
Conditional Agents: None
Fast Path Eligibility: No
Reason: runtime DB update must be executed only by GitOps and must use non-destructive commands.
```

## Approval

```text
Coordinator approval for local runtime DB update: Yes
Basis: direct user request in chat on 2026-06-26.
QA PASS available for this DB update task: No formal QA report for this standalone runtime operation.
Scope limited to local runtime DB only.
```

This approval does not authorize staging, committing, pushing, implementation changes, destructive DB commands, or staging/production migration.

## Scope

GitOps may:

- Run worktree start gate and record current dirty files.
- Identify the actual runtime DB target from Docker/env before DB mutation.
- Run non-destructive Laravel migration on local runtime DB.
- Run idempotent initial system seed on local runtime DB.
- Run smoke check after migrate/seed.
- Write a GitOps report.

Approved command family:

```sh
docker compose -p newpaotang exec -T platform-api php artisan migrate:status
docker compose -p newpaotang exec -T platform-api php artisan migrate --force
docker compose -p newpaotang exec -T platform-api php artisan db:seed --class=InitialSystemSeeder --force --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

If `InitialSystemSeeder` cannot resolve from short class name, GitOps may retry with the fully qualified class:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --class='Database\\Seeders\\InitialSystemSeeder' --force --no-interaction
```

## Out Of Scope

- `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe`, truncate/drop/reset commands against runtime DB.
- `runtime:mock-data:seed` or other mock/sample data seeders.
- Stage, commit, push.
- Implementation edits.
- Production/staging DB migration.
- Any destructive operation against local runtime DB.

## Acceptance Criteria

- GitOps proves the runtime DB target before mutation, including `APP_ENV` and `DB_DATABASE`.
- GitOps runs only non-destructive commands.
- Pending migrations are applied with `php artisan migrate --force`.
- Initial/bootstrap data is applied with idempotent seeder command.
- Smoke check runs after migration/seed.
- GitOps report records all commands, exit status, DB target, and final worktree status.
- If any command fails, GitOps stops and reports BLOCKED without retrying destructive alternatives.

## Required Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/roles/gitops.md
ai-sub-agents/memory/gitops/memory.md
docs/docker-runtime-policy.md
docs/backend-bootstrap-seeders.md
docs/backend-console-commands.md
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/database/seeders/InitialSystemSeeder.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/database/migrations/2026_06_25_000001_create_customer_biometric_and_social_auth_tables.php
```

## DB Change Declaration

```text
Runtime DB update required: Yes
Runtime DB update type: non-destructive migrate + idempotent initial seed
Target: local runtime DB only
Expected DB_DATABASE: GitOps must detect and report actual value before running commands.
```

## Required Output

```text
ai-sub-agents/gitops/20260626-runtime-db-initial-data-update-gitops-report.md
```

## Next Agent

```text
GitOps
```

## Trigger

```text
ai-sub-agents/triggers/20260626-runtime-db-initial-data-update-gitops-trigger.md
```
