# Backend Architecture Compliance Remediation Coordinator Handoff

## Agent

Coordinator

## Task

Re-audit backend implementation against project rules and open a broader remediation slice after discovering the earlier model-only remediation was incomplete.

## What Was Done

Coordinator read additional governance files:

```text
ai-agents/prompts/open-chat-coordinator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
ai-agents/roles/coordinator.md
document/09_AI_WORK_INSTRUCTIONS.md
docs/api-conventions.md
```

Coordinator inspected backend structure and confirmed:

```text
No model layer exists under apps/platform-api/app.
No dedicated Requests/FormRequest-style validation layer exists.
Validation is scattered through controllers/services and RequestHeaderValidator.
Backend docs for model/request validation conventions are missing.
Query Builder is used heavily and needs an intentional exception inventory.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md
```

This supersedes:

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-architecture-compliance-remediation-backend.md
```

After Backend Develop handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-architecture-compliance-remediation-qa.md
```

Do not create or continue the older model-only task.

## Backend Task Summary

Backend Develop must:

```text
inventory all migration-created tables
add Eloquent model layer for required domain groups
add request validation layer for current write endpoints and representative report/query validation
preserve docs/api-conventions.md validation_failed envelope
refactor services to models where safe
document intentional Query Builder exceptions
add backend documentation files
add focused model and validation tests
run full Docker-only regression validation
write ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

## Validation Required From Backend Develop

Docker-only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Validation
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
```

## QA Requirements

QA must verify:

```text
required model coverage
request validation layer coverage
validation envelope preservation
validation before mutation/idempotency success
relationships and tenant scope helpers
safe service refactors
documented Query Builder exceptions
no endpoint/flow regression
Docker runtime policy compliance
no apps/customer or apps/back-office changes
```

QA report path:

```text
ai-agents/reports/20260507-backend-architecture-compliance-remediation-qa-report.md
```

## Known Risks

```text
This is broader than the model-only remediation and may touch many backend files.
Wholesale Query Builder conversion is explicitly not required and could be harmful.
Request validation must preserve current API error envelope; default Laravel validation responses may break contract if not customized.
Global tenant scopes are risky for central/report/settlement jobs; prefer explicit scopes.
```

## Next Agent

Orchestrator
