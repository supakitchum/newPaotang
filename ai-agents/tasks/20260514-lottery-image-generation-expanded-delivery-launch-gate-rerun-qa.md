# lottery-image-generation-expanded-delivery-launch-gate-rerun - QA Tester

## Target Agent

QA Tester

## Task

Rerun the expanded lottery image generation delivery launch gate after the focused Customer SSR serialization remediation passed QA.

## Coordinator Instruction

Coordinator approved the focused Customer SSR remediation and instructed Orchestrator to dispatch:

```text
lottery-image-generation-expanded-delivery-launch-gate-rerun
```

Coordinator handoff:

```text
ai-agents/handoffs/20260514-lottery-image-customer-ssr-remediation-qa-review-coordinator-handoff.md
```

Decision:

```text
ai-agents/decisions/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa-review-decision.md
```

Focused remediation QA report:

```text
ai-agents/reports/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa-report.md
```

## Commits Under Test

Expanded delivery lanes:

```text
BO implementation: f853c82805ce9f589bc5f7e432a200d48088ba5e
BO handoff: e5fc5f4b328c87f24eba1e62656affe8bf4aac13
Backend/Ops implementation: e5513c923dd91024238d175bb1de2a68bebb173f
Backend/Ops handoff: e41026cb08cb5f55acf9e2a34dcb167a0a57a781
Customer image integration: afd7993ee9aee0b7ad496172633911934e86eb1c
Customer image integration handoff: 1f9abb62310c3a2f58a2b6494d1af73a5697a02c
```

Customer SSR remediation:

```text
Customer remediation: c351606c7924dfd85824dd442ef03be7a2d2f98d
Customer remediation handoff: 212fa9d
Customer remediation QA dispatch: 450cec85b32e452e06968ad7271e2994a6a2a7ab
Customer remediation QA review: 37e88cd788f31fd3c2cc2f6858f0182c4aaa1e85
```

## Objective

Validate the final expanded delivery launch gate after the previous Customer SSR blocker was cleared.

The rerun should confirm:

```text
Customer SSR smoke remains fixed
Customer lottery image display integration remains present
Customer source remains free of central operations API calls
Backend/Ops lane remains healthy enough for launch gate
BO operations lane remains healthy enough for launch gate
OpenAPI and source-boundary checks remain clean
credential scan for new launch-gate artifacts passes
```

## Required Source

Read before execution:

```text
ai-agents/tasks/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa.md
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
ai-agents/reports/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa-report.md
ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
docs/openapi.yaml
```

## Required Scope

Rerun enough launch-gate coverage to prove the release gate is now healthy:

```text
Customer SSR smoke for /search, /checkout, /success, and /tickets remains passing
Customer logs have no serialization crash
Customer image integration fields and display fallbacks remain present
Customer source remains free of central lottery image operations API usage
Backend/Ops tests and readiness command remain passing
BO operations lint/test/build/structural check remain passing
OpenAPI YAML parse remains passing
credential scan for new rerun artifacts passes
authenticated checkout/ticket image journey is exercised if seeded credentials are available
```

If seeded authenticated customer credentials are not available, record that as residual risk rather than inventing credentials or changing code.

## Out Of Scope

```text
fixing defects without Coordinator routing
using real production credentials
deploying live S3/R2/CDN infrastructure
adding customer lint/test tooling
rewriting backend, BO, or customer implementation during QA
```

## Dirty Workspace Guardrail

The shared worktree may contain unrelated dirty/untracked files from other agents.

Before testing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files.

Important local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Validation

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt directly on the host machine.

Baseline:

```sh
git diff --check
docker compose build platform-api back-office customer
docker compose up -d postgres valkey platform-api back-office customer
```

Backend/Ops:

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
```

Back Office:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm back-office node scripts/check-lottery-image-operations.mjs
```

Customer:

```sh
docker compose run --rm customer npm run build
```

Customer package note:

```text
apps/customer/package.json currently has no lint/test scripts.
Do not fail this QA solely because npm run lint/test are unavailable; record it as a tooling gap unless separate functionality is broken.
```

Required source scans:

```sh
rg -n "/api/v1/admin/central/lottery-images|/admin/central/lottery-images|lottery-images|branding-assets" apps/customer -g '!node_modules'
rg -n "image_url|image_thumb_url|image_status|image_error|LotteryImage" apps/customer -g '!node_modules'
rg -n "error\\.value\\s*=\\s*e|error\\.value\\s*=\\s*error|useState<.*Error|useState\\(.*error" apps/customer/composables apps/customer/middleware apps/customer/utils -g '!node_modules'
```

OpenAPI:

```sh
ruby -e "require 'yaml'; YAML.load_file('docs/openapi.yaml'); puts 'openapi yaml ok'"
```

Customer route smoke:

```text
GET http://localhost:3000/search
GET http://localhost:3000/checkout
GET http://localhost:3000/success
GET http://localhost:3000/tickets
```

BO browser smoke:

```text
GET http://localhost:3100/admin/central/lottery-images
GET http://localhost:3100/admin/central/dashboard
```

Record final URLs, status/body summary, and service logs where relevant.

## Evidence Requirements

Write QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-rerun-qa-report.md
```

If artifacts are created, place them under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-rerun-qa/
```

Report must include:

```text
result: PASS or FAIL
commits under test
commands run with pass/fail results
Customer SSR route smoke result table
Customer logs serialization-crash scan
Customer image/central-API/raw-error scans
Backend/Ops validation summary
BO validation summary
OpenAPI validation summary
credential/artifact scan result
authenticated customer journey result or reason unavailable
findings with severity and file/route/endpoint references
residual risks
recommendation for Coordinator
```

## Recommended Routing

If PASS:

```text
Next Agent: Coordinator
Reason: Coordinator should review final launch-gate rerun for approval.
```

If FAIL:

```text
Next Agent: Coordinator
Reason: Coordinator should review findings and route the responsible agent.
```

## Next Agent

QA Tester
