# Back Office P4 Administration Security Settings Workflows QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO P4 administration/security/settings implementation to QA Tester.

## Source

Coordinator next-priority decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-review-coordinator-handoff.md
```

Orchestrator BO task and planning handoff:

```text
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-planning-orchestrator-handoff.md
```

BO Develop handoff:

```text
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 52e0f728594bdeda4ae0c6262c22c3cae8698a40
BO handoff commit: da664c6d59241165adc148765a5e1a218b5a6624
```

BO surfaced or strengthened P4 workflows for:

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

BO updated the coverage matrix to:

```text
implementation-ready; focused QA pending
```

for the P4 rows while preserving `partial` completion until QA and Coordinator review.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

QA must test real authenticated BO central and tenant menu workflows, not only build/lint/unit checks:

```text
central admin user list/detail/create/update/disable
central role list/create/update/archive with permission-code controls
central menu-management typed tree editor save/reset workflow
central system settings known-key save workflow
tenant admin user list/detail/create/update/disable with X-Tenant-Id preserved
tenant role list/create/update/archive with X-Tenant-Id preserved
tenant menu-management typed tree editor save/reset workflow
tenant maintenance save/create bypass/revoke bypass/events/bypasses workflows
tenant support access list/create/detail/approve/revoke/impersonate/elevated/end-session workflows
tenant settings/theme/domain list/detail/create/update/verify/delete workflows
```

Security-sensitive actions must prove:

```text
record context is clear before submit
operator reason guard is present where required
write/action submission is safe and scoped
tenant scope and X-Tenant-Id are correct
secrets, passwords, bearer tokens, local credentials, and one-time support tokens are not committed to artifacts
```

QA should submit safe local Docker fixture workflows where possible and capture before/after API evidence.

## Validation Plan Given To QA

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
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

If a test filter has no matching tests, QA should record the exact command/output and continue.

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected QA Output

```text
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p4-administration-security-settings-workflows-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes, Coordinator can decide whether to promote some or all P4 rows to complete. If QA finds implementation defects, report severity and likely owner. If QA finds frozen backend contract, permission, tenant isolation, or security blockers, route to Coordinator for decision rather than editing backend or permissions.

## Next Agent

QA Tester
