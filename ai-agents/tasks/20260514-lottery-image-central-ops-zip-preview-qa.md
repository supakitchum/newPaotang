# lottery-image-central-ops-zip-preview-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the completed Backend and BO delivery for:

```text
lottery-image-central-ops-usability-zip-preview
```

Coordinator requires QA coverage for central-only visibility/enforcement, Games/Partners deep links, game-name selection, PNG zip import, generated full/thumb readiness, central and partner preview modes, preview side-effect safety, pending/mix regressions, OpenAPI parse, and credential/artifact scan.

## QA Start Gate

Do not start QA until both implementation handoffs exist, include commit hashes, and are pushed:

```text
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md
```

If either handoff is missing, uncommitted, or does not include a commit hash, stop and report the blocker to Coordinator/Orchestrator.

## Objective

Run a focused release-gate QA pass for the central lottery image operations usability follow-up and report pass/fail with actionable defects.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
ai-agents/handoffs/20260514-lottery-image-central-ops-usability-zip-preview-coordinator-handoff.md
ai-agents/tasks/20260514-lottery-image-central-ops-zip-preview-backend.md
ai-agents/tasks/20260514-lottery-image-central-ops-zip-preview-bo.md
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md
docs/openapi.yaml
docs/lottery-image-generation.md
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
apps/back-office/scripts/check-lottery-image-operations.mjs
apps/back-office/scripts/check-lottery-branding.mjs
```

## Scope

Validate:

```text
central-only BO visibility for lottery-images and lottery-branding
backend central-only enforcement for lottery-images operations APIs
backend central-only enforcement for partner lottery-branding APIs
tenant/partner scope cannot see, open, or call these workflows
Games table action deep-links to /admin/central/lottery-images?game_id={game_id}
Partners table action deep-links to /admin/central/partners/{partner_id}/lottery-branding
game selector displays game names and submits game_id
query param game_id preselects the game
valid PNG zip import succeeds
invalid zip rejection
mixed file type/non-PNG rejection
bad count/name/dimension/size rejection where Backend rules apply
generated full/thumb WebP variants are ready/registered after import
readiness refresh after import
lottery-images central_unbranded manual-number preview
lottery-images partner selection still defaults to central_unbranded
lottery-images explicit partner_branded preview behavior
partner_branded actionable warning/fallback when partner assets are missing
lottery-branding preview uses route partner_id and exposes no partner selector
lottery-branding body partner_id mismatch cannot override route partner
preview actions do not create stock rows
preview actions do not create permanent lottery image rows
preview actions do not lock partner branding
mix behavior regression
pending_assets retry regression
OpenAPI YAML parse
credential/artifact scan
```

## Out Of Scope

```text
fixing implementation defects unless Coordinator explicitly assigns QA a fix
production S3/R2/CDN rollout
authenticated production UAT without provided credentials/env
customer frontend testing unless a regression is directly caused by this task
```

## File Ownership

Can edit:

```text
ai-agents/reports/20260514-lottery-image-central-ops-zip-preview-qa-report.md
ai-agents/reports/artifacts/20260514-lottery-image-central-ops-zip-preview-qa/**
tests/** only if a QA-owned test fixture/report helper is explicitly needed
apps/*/tests/** only if adding a QA-owned regression test is necessary and Coordinator permits it
```

Must not edit:

```text
apps/platform-api/app/**
apps/back-office/**
apps/customer/**
docs/openapi.yaml
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

The shared worktree contains unrelated dirty/untracked files from other agents, including generated lottery image assets.

Before QA:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. Record unrelated dirty files at a high level in the QA report.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Verify Backend and BO implementation commits are present locally and on `origin/develop`.
2. Start required Docker services.
3. Run Backend tests for lottery image operations, partner branding assets, central games, zip import, preview, side effects, mix, and pending_assets retry.
4. Run BO lint/test/build and lottery-image/branding structural checks.
5. Parse OpenAPI with an available Docker-compatible command.
6. Exercise or inspect central-only access behavior for BO routes/actions and backend APIs.
7. Validate zip import success/failure flows and generated variant readiness.
8. Validate preview modes and no side effects.
9. Run credential/artifact scan, excluding known safe binary/generated image assets as appropriate.
10. Write a QA report with PASS/FAIL and actionable defects.

## Acceptance Criteria

```text
all required Backend tests pass through Docker
all required BO validation commands pass through Docker
central users can access required workflows
tenant/partner users cannot see/open/call required workflows
deep links from Games and Partners work
game select behavior matches game-name display/game_id submit requirements
zip import accepts valid PNG zip and rejects invalid inputs
full/thumb generated variants are registered and readiness reflects them
preview APIs/UI support required modes and manual lottery_number
preview actions are side-effect free for stock rows, permanent image rows, and branding locks
OpenAPI parses
credential/artifact scan finds no committed secrets
QA report clearly states PASS or FAIL and next agent
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose build platform-api back-office
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralGameTest
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm back-office node scripts/check-lottery-image-operations.mjs
docker compose run --rm back-office node scripts/check-lottery-branding.mjs
```

Use additional Docker-backed checks for OpenAPI parsing and artifact credential scanning based on repo tooling. Record exact commands and outputs.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260514-lottery-image-central-ops-zip-preview-qa-report.md
```

Must include:

```text
result: PASS or FAIL
Backend commit hash under test
BO commit hash under test
current HEAD and origin/develop
files/artifacts created
validation commands and results
manual/API/route evidence
central-only visibility/enforcement evidence
zip import evidence
preview mode evidence
side-effect safety evidence
OpenAPI parse result
credential/artifact scan result
defects with owner recommendation
unrelated dirty files left untouched
next agent
```

## Next Agent

QA Tester
