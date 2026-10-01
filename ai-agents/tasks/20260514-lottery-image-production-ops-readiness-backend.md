# lottery-image-production-ops-readiness - Backend Develop

## Target Agent

Backend Develop

## Lane

Lane C: Production storage, queue, and deployment readiness closure

## Coordinator Instruction

Close the non-secret production operations readiness surface for lottery image generation.

This is part of:

```text
lottery-image-generation-expanded-delivery
```

## Objective

Provide production-readiness closure without committing secrets:

```text
S3/R2/CDN config checklist
queue worker runbook
readiness endpoint expected production_ready=true criteria
failure/retry recovery runbook
redaction verification
object key/cache-control/CDN base URL verification
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/backend-console-commands.md
docs/lottery-image-generation.md
docs/deployment-monitoring.md
ai-agents/decisions/20260514-lottery-image-generation-remaining-closure-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-expanded-delivery-coordinator-handoff.md
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
apps/platform-api/config/lottery_images.php
apps/platform-api/app/Console/Commands/LotteryImageReadinessCommand.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageOperationsService.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
```

If a referenced docs file does not exist, use the closest existing deployment/operations document and record it in the handoff.

## Required Scope

Implement or document production ops closure for:

```text
environment variable checklist for S3/R2-compatible lottery image disk
CDN/base URL requirements and cache-control expectations
object key layout verification for central and partner outputs
production_ready=true criteria for readiness endpoint/command
queue worker commands for stock-image-generation and stock-partner-image-generation
scheduler/supervisor/container runbook guidance where repo conventions exist
failure/retry recovery runbook for pending_assets and failed generation
safe redaction verification for all readiness output
operator checklist for launch gate QA
focused tests or command checks for readiness criteria and redaction where implementation needs strengthening
```

Prefer documentation plus focused backend tests/config examples. Do not broaden app behavior unless needed to make readiness criteria verifiable.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
real production credentials
deploying live S3/R2/CDN infrastructure
changing BO or customer UI
new central operations API features unrelated to production readiness
marking launch gate complete
```

## File Ownership

Can edit:

```text
apps/platform-api/config/**
apps/platform-api/app/Console/Commands/**
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/tests/**
docs/backend-console-commands.md
docs/lottery-image-generation.md
docs/deployment-monitoring.md
docs/docker-runtime-policy.md only if runtime policy needs a small ops note
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml unless a readiness response contract is actually changed
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

The shared worktree contains unrelated dirty/untracked files from other agents.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If an overlapping backend/docs file has unrelated local changes, inspect it and work with it. Stage only files in this task scope.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Acceptance Criteria

```text
production S3/R2/CDN readiness checklist is explicit and actionable
readiness endpoint/command criteria for production_ready=true are documented
all secret-bearing config fields remain redacted in output and artifacts
queue worker commands and required queues are documented
pending_assets and failed-generation recovery runbook is documented
object key/cache-control/CDN behavior is verified or documented from tests
no real credentials are committed
Docker-only validation passes
```

## Validation

Use Docker commands only. Do not run PHP/Composer/Artisan on the host machine.

Required baseline:

```sh
git diff --check
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
```

Add focused tests if readiness/redaction criteria are changed or expanded.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
```

Must include:

```text
commit hash
files changed
production env/config checklist
production_ready=true criteria
queue/worker runbook summary
retry/recovery runbook summary
redaction verification
object key/cache-control/CDN verification
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Backend Develop
