# 20260507 M8 Affiliate Agent Reports Settlement - Orchestrator Handoff

## Role

Orchestrator Agent

## Coordinator Input

Coordinator issued Milestone 8 work through:

```text
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-decision.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-coordinator-handoff.md
```

## What Was Done

Created the Backend Develop task brief for M8:

```text
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
```

The task brief covers:

- tenant agent APIs and quotas
- tenant affiliate accounts, programs, links, and attributions
- commission rules and commission transactions
- service/command/worker-driven commission calculation from paid orders
- affiliate payout create/approve flow
- tenant and central reports
- report export job placeholders
- central settlement list/detail/approve foundation
- focused Docker-only validation expectations

## Source Context Read

- `ai-agents/prompts/open-chat-orchestrator.md`
- `ai-agents/prompts/orchestrator-task-template.md`
- `docs/docker-runtime-policy.md`
- `apps/platform-api/composer.json`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php`
- `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`
- `apps/platform-api/app/Shared/Audit/AuditLogger.php`
- `apps/platform-api/app/Shared/Rbac/PermissionService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php`
- `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
- `apps/platform-api/database/migrations/2026_05_07_000001_create_checkout_wallet_sold_sync_tables.php`
- `apps/platform-api/database/migrations/2026_05_07_000002_create_reward_result_engine_tables.php`
- `apps/platform-api/tests/Support/AdminAuthFixtures.php`
- `apps/platform-api/tests/Feature/PartnerProvisioningTest.php`
- `docs/permissions.md`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/erd.md`

## Files Changed

```text
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-orchestrator-handoff.md
```

## Validation

No application runtime commands were run by Orchestrator. Only file inspection commands were used.

Backend Develop must validate with Docker-only commands:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Affiliate
docker compose run --rm platform-api php artisan test --filter=Agent
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test --filter=Settlement
docker compose run --rm platform-api php artisan test
```

## Proposed Board Update

Orchestrator must not edit `ai-agents/BOARD.md` directly. Proposed update:

```text
Current task: 20260507-m8-affiliate-agent-reports-settlement-backend
Status: assigned_to_backend
Next Agent: Backend Develop
Task file: ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
Expected backend handoff: ai-agents/handoffs/20260507-m8-affiliate-agent-reports-settlement-backend-handoff.md
```

## Known Risks

- `docs/openapi.yaml` may use generic `AdminResource` shapes for some M8 responses; Backend Develop must document stable response fields in the backend handoff.
- Real bank transfer provider integration is out of scope.
- Real export file generation/storage/CDN delivery may be deferred behind export job contract placeholders.
- Public/browser affiliate attribution may require a later customer slice; this task still creates the backend foundation and safe service hooks.
- Back Office UI is not part of this slice.
- Docker-only runtime remains mandatory.

## Next Agent

```text
Backend Develop
```

Backend Develop should start from:

```text
ai-agents/tasks/20260507-m8-affiliate-agent-reports-settlement-backend.md
```
