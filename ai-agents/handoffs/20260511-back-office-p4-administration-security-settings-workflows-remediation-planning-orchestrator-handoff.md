# Back Office P4 Administration Security Settings Workflows Remediation Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO remediation for:

```text
back-office-p4-administration-security-settings-workflows-remediation
```

## Source

Coordinator QA review:

```text
ai-agents/decisions/20260510-back-office-p4-administration-security-settings-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p4-administration-security-settings-workflows-qa-report.md
```

Prior BO and QA task context:

```text
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-bo-handoff.md
ai-agents/tasks/20260510-back-office-p4-administration-security-settings-workflows-qa.md
ai-agents/handoffs/20260510-back-office-p4-administration-security-settings-workflows-qa-task-orchestrator-handoff.md
```

## What Was Done

Created BO Develop remediation task:

```text
ai-agents/tasks/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Coordinator accepted P4 QA as FAIL and did not promote any P4 row.

Official BO completion remains:

```text
26 / 56 complete = 46.4%
```

## Remediation Scope Passed To BO

Affected rows:

```text
central:menu_management
tenant:menu_management
tenant:maintenance
```

Required fixes:

```text
tenant maintenance bypass create must require Ticket ID before submission
central and tenant menu-management tree saves must add a confirmation step with scope and changed-item context
```

## Guardrails Passed To BO

```text
Backend remains frozen unless Coordinator explicitly approves API validation work.
Customer frontend remains frozen.
Do not edit docs/openapi.yaml.
Do not change permission/security semantics.
Do not change unrelated P4 rows.
Do not mark P4 rows complete.
Keep completion decisions for focused QA and Coordinator review.
Use Docker-only validation for all application commands.
Do not touch unrelated dirty files.
```

## Validation Plan Given To BO

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected BO Output

```text
ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md
```

BO should commit and push implementation plus handoff when validation passes.

## Next Step After BO

Route back to:

```text
Orchestrator
```

Then Orchestrator should dispatch focused QA for:

```text
central:menu_management
tenant:menu_management
tenant:maintenance
```

## Next Agent

BO Develop
