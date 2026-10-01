# lottery-image-customer-ssr-error-serialization-remediation - QA Tester

## Target Agent

QA Tester

## Task

Focused QA retest for Customer SSR serialization remediation.

## Source

Coordinator rejection:

```text
ai-agents/decisions/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-expanded-delivery-launch-gate-remediation-coordinator-handoff.md
```

Previous failing QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
```

Customer remediation:

```text
Customer implementation: c351606c7924dfd85824dd442ef03be7a2d2f98d
Customer handoff commit: 212fa9d
ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
```

## Objective

Verify the Customer remediation fixes the launch-gate Nuxt SSR serialization crash:

```text
Cannot stringify arbitrary non-POJOs
```

Focus only on the Customer remediation and minimum integration smoke needed to unblock Coordinator review.

## Required Scope

QA must verify:

```text
/search does not render Nuxt 500
/checkout redirects or renders without Nuxt 500
/success redirects or renders without Nuxt 500
/tickets redirects or renders without Nuxt 500
customer service logs have no devalue/non-POJO serialization crash
customer source scan still has no central lottery image operations API calls
customer image field/source scan still shows lottery image integration paths
customer build still passes
remediation stores only serializable error state in inspected code paths
```

## Previous Failure To Recheck

Previous launch-gate failure:

```text
GET http://localhost:3000/search   -> final URL /result, body shows 500
GET http://localhost:3000/checkout -> final URL /login?redirect=/checkout, body shows 500
GET http://localhost:3000/success  -> final URL /login?redirect=/success, body shows 500
GET http://localhost:3000/tickets  -> final URL /login?redirect=/tickets, body shows 500
```

Expected after remediation:

```text
routes may redirect according to current auth/app-init behavior
routes must not show Nuxt 500
routes must not include Cannot stringify arbitrary non-POJOs
customer logs must not include devalue/non-POJO serialization crash
```

## Out Of Scope

```text
fixing defects without Coordinator routing
full BO operations workflow QA
full Backend/Ops launch-gate rerun unless needed to prove no regression
real production S3/R2/CDN credentials
authenticated checkout/ticket journey if no seeded customer session is available
adding customer lint/test tooling
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

Use Docker commands only. Do not run Node/npm/Nuxt on the host machine.

Required:

```sh
git diff --check c351606c7924dfd85824dd442ef03be7a2d2f98d..HEAD
docker compose build customer
docker compose up -d postgres valkey platform-api customer
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

Interpretation:

```text
central operations API scan should have no customer calls
image field scan should show expected image display integration
raw-error useState scan should not show raw caught Error assigned to SSR state
```

Required route smoke:

```text
GET http://localhost:3000/search
GET http://localhost:3000/checkout
GET http://localhost:3000/success
GET http://localhost:3000/tickets
```

Record:

```text
HTTP status
final URL
whether body includes 500/Internal Server Error/Cannot stringify/devalue/non-POJO
customer container logs after smoke
```

## Evidence Requirements

Write QA report:

```text
ai-agents/reports/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa-report.md
```

If artifacts are created, place them under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa/
```

Report must include:

```text
result: PASS or FAIL
commits under test
commands run with pass/fail results
route smoke result table
customer log serialization-crash scan result
central operations API scan result
image field/source scan result
raw-error state scan result
customer build result
credential/artifact scan result
findings with severity and file/route references
residual risks
recommendation for Coordinator
```

## Recommended Routing

If PASS:

```text
Next Agent: Coordinator
Reason: Coordinator should review focused remediation QA and decide whether to re-approve or rerun full launch gate.
```

If FAIL:

```text
Next Agent: Coordinator
Reason: Coordinator should review findings and route Customer remediation again.
```

## Next Agent

QA Tester
