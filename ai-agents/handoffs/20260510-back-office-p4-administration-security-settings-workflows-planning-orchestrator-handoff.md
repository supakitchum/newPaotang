# Back Office P4 Administration Security Settings Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p4-administration-security-settings-workflows
```

## Source

Coordinator P3 sync-log remediation QA review and next-priority handoff:

```text
ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

## What Was Done

Created BO Develop task:

```text
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused tenant sync logs remediation QA passed and Coordinator promoted:

```text
tenant:sync_logs
```

Official BO completion is now:

```text
26 / 56 menus = 46.4%
```

Remaining:

```text
28 partial menus
2 API-gap menus: central:master_stock, tenant:commission_transactions
```

## BO Scope Dispatched

P4 matrix rows:

```text
central:admin_users
central:roles_permissions
central:menu_management
central:system_settings
tenant:admin_users
tenant:roles_permissions
tenant:menu_management
tenant:maintenance
tenant:support_access_logs
tenant:settings
```

BO Develop is instructed to implement typed/security-appropriate workflows where the frozen backend contract supports them, update matrix notes without marking rows complete before QA, commit implementation changes, and hand back to Orchestrator.

## Guardrails Passed To BO

```text
Backend remains frozen.
Customer frontend remains frozen.
Do not edit docs/openapi.yaml.
Do not change permission/security semantics.
Use Docker-only application/runtime/test commands.
Do not count route/catalog/menu presence as BO completion.
Do not mark rows complete before QA verifies real menu workflows.
Do not commit QA helper scripts that contain local credentials.
```

Security-sensitive flows requiring focused QA evidence:

```text
admin users
roles and permissions
maintenance
support access
settings/menu saves
```

Special dirty workspace warning:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/*.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

The QA helper file `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential.

## Validation Plan Given To BO

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=Support
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Expected BO Output

```text
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

BO handoff must include commit hash, files changed, validation, known risks/blockers, security-sensitive workflow notes, and next agent.

## Next Agent

BO Develop
