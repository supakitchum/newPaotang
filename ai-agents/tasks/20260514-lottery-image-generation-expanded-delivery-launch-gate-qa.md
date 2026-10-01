# lottery-image-generation-expanded-delivery-launch-gate - QA Tester

## Target Agent

QA Tester

## Lane

Lane D: End-to-end QA launch gate

## Status

Ready to execute.

## Required Preconditions

Orchestrator confirmed all relevant lane handoffs are present:

```text
ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
```

Lane commits under test:

```text
BO implementation: f853c82805ce9f589bc5f7e432a200d48088ba5e
BO handoff: e5fc5f4
Backend/Ops implementation: e5513c923dd91024238d175bb1de2a68bebb173f
Backend/Ops handoff: e41026cb08cb5f55acf9e2a34dcb167a0a57a781
Customer implementation: afd79933a5eb146a7880650144a91ff021430137
Customer handoff: 1f9abb6
QA dispatch: pending
```

## Objective

Validate the integrated lottery image generation journey across central BO, backend generation/ops, partner-branded images, and customer display.

## Scope

After lanes A-C are complete, validate:

```text
central background upload/commit/register workflow
central background readiness dashboard
mix setting workflow
central stock generation and image generation
pending_assets stays pending until required background set arrives
retry pending creates images after assets arrive
partner allocation/sync creates partner-branded images
customer stock list/search displays usable images
customer reservation/checkout/success/ticket surfaces preserve image display where supported
production readiness reports expected local/non-production state or configured production-like state without secrets
queue/worker commands and runbook match implementation
```

## Required Source

Read before execution:

```text
ai-agents/decisions/20260514-lottery-image-generation-remaining-closure-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-expanded-delivery-coordinator-handoff.md
ai-agents/tasks/20260514-lottery-image-operations-management-ui-bo.md
ai-agents/tasks/20260514-lottery-image-customer-display-integration-customer.md
ai-agents/tasks/20260514-lottery-image-production-ops-readiness-backend.md
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
```

## Out Of Scope

```text
fixing defects without Coordinator routing
using real production credentials
deploying live S3/R2/CDN infrastructure
marking launch approved without evidence
```

## Validation Expectations

Use Docker commands only for application runtime validation.

Expected baseline after lanes A-C:

```sh
git diff --check
docker compose build platform-api back-office customer
docker compose up -d postgres valkey platform-api back-office customer
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm customer npm run build
```

Customer package validation note:

```text
apps/customer/package.json currently has no lint or test scripts and no matching lint/test tooling dependencies.
Customer handoff documents this as unavailable.
Do not treat missing customer lint/test scripts alone as an implementation defect for this lane; record it as a residual tooling gap unless a separate functional issue is found.
```

If Customer lint/test scripts are added before QA starts, run them:

```sh
docker compose run --rm customer npm run lint
docker compose run --rm customer npm run test
```

Add route/manual workflow evidence for BO and Customer where practical.

## Evidence Requirements

Write QA report to:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
```

If artifacts are created, place them under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/
```

Report must include:

```text
result: PASS or FAIL
lane commits under test
commands run with pass/fail results
BO workflow evidence
Customer workflow evidence
backend runtime/readiness evidence
credential/artifact scan result
findings with severity and file/route/endpoint references
residual risks
recommendation for Coordinator approval or remediation routing
```

## Next Agent

QA Tester after lanes A-C are complete
