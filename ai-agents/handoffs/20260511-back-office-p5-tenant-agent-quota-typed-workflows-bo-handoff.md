# back-office-p5-tenant-agent-quota-typed-workflows - BO Handoff

## Summary

BO Develop implemented typed back-office workflows for:

```text
tenant:agents
tenant:agent_quotas
```

Implementation commit:

```text
4be4957083de80b9ef63395d1479b8a78be83f55
```

Next Agent:

```text
Orchestrator
```

## Files Changed

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

## tenant:agents Typed Workflows

Route:

```text
/admin/tenant/growth/agents
```

Preserved API connections:

```text
GET /admin/tenant/agents
GET /admin/tenant/agents/{agent_id}
```

Typed create action:

```text
POST /admin/tenant/agents
```

Create fields:

```text
code
name
phone
email
store_id
status
metadata
```

Typed update action:

```text
PATCH /admin/tenant/agents/{agent_id}
```

Update fields:

```text
code
name
phone
email
store_id
status
metadata
```

Typed quota action:

```text
PATCH /admin/tenant/agents/{agent_id}/quotas
```

Quota fields:

```text
game_id
quota_count
used_count
status
payload
reason
```

Quota action context:

```text
id
tenant_id
code
name
store_id
status
quotas.0.game_id
quotas.0.quota_count
quotas.0.used_count
quotas.0.status
updated_at
```

## tenant:agent_quotas Typed Workflow

Route:

```text
/admin/tenant/growth/agent-quotas
```

Preserved API connections:

```text
GET /admin/tenant/agents
GET /admin/tenant/agents/{agent_id}
```

Typed quota action:

```text
PATCH /admin/tenant/agents/{agent_id}/quotas
```

Quota fields:

```text
game_id
quota_count
used_count
status
payload
reason
```

The dedicated route keeps the agents list/detail backing API and exposes the same typed quota action with reason/context confirmation.

## Template And UI Behavior

Existing Meno/Bootstrap operation patterns were reused:

```text
AdminOperationsPage
AdminConfirmAction
AdminExportPanel
AdminDataTable
AdminStatusBadge
AdminModal
btn btn-primary / btn-warning btn-wave
form-control / form-select
```

No new design system was introduced.

Existing loading/error/empty states remain handled through:

```text
AdminApiState
AdminLoader
AdminDataTable
AdminPagination
AdminConfirmAction loading/error state
```

## Scope Confirmations

- Existing list/detail/filter/cursor behavior was preserved for both rows.
- Tenant scope and `X-Tenant-Id` behavior were preserved through the existing `useAdminApi` flow.
- Idempotency behavior was preserved through existing `api.idempotencyKey()` write action handling.
- `metadata` and `payload` use focused JSON fields and are parsed into object/array values before submit.
- No whole-payload JSON editor was added as the primary workflow.
- Backend, OpenAPI, Customer frontend, docs, compose, GitHub workflow, Board, decisions, tasks, and reports files were not edited.
- Customer frontend was not used.
- No seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets were written to this handoff.

## Validation

Commands run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AgentTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Results:

```text
git diff --check: PASS
docker compose up -d postgres valkey platform-api back-office: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed: PASS
docker compose run --rm platform-api php artisan test --filter=AgentTest: PASS, 1 passed / 16 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest: PASS, 5 passed / 26 assertions
docker compose run --rm back-office npm run lint: PASS
docker compose run --rm back-office npm run test: PASS
docker compose run --rm back-office npm run build: PASS
docker compose up -d --force-recreate back-office: PASS
```

Build warnings observed but non-blocking:

```text
[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated.
/admin-template/assets/images/media/media-33.jpg did not resolve at build time and remains runtime-resolved.
```

## Known Unrelated Dirty Files Left Untouched

These files existed or were runtime/test artifacts outside BO scope and were not staged or committed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Known Risks Or QA Notes

- `metadata` and `payload` must be valid JSON object/array values.
- Quota action can prefill from `quotas.0.*` only when detail response includes quotas; list rows may open with defaults because list response does not include quota detail.
- Backend accepts status as a string and defaults blank status to `active`; BO offers `active`, `inactive`, and `suspended` to match the existing tenant agent filters.
- QA should verify both real menu routes and confirm quota detail response shows updated `quotas`.

