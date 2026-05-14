# lottery-image-customer-ssr-error-serialization-remediation - Customer Develop

## Target Agent

Customer Develop

## Coordinator Decision

Expanded delivery launch gate was rejected because Customer Docker SSR browser smoke renders Nuxt 500 pages.

Decision:

```text
ai-agents/decisions/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-review-decision.md
```

Coordinator handoff:

```text
ai-agents/handoffs/20260514-lottery-image-expanded-delivery-launch-gate-remediation-coordinator-handoff.md
```

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
```

## Blocking Issue

Customer launch-gate routes return Nuxt 500 in Docker SSR:

```text
/search
/checkout
/success
/tickets
```

Visible error:

```text
Cannot stringify arbitrary non-POJOs
```

QA suspects raw caught `Error`, `FetchError`, `Response`, `Request`, or related class instances are being stored in Nuxt `useState` and then serialized by `devalue` during SSR.

Likely source locations:

```text
apps/customer/composables/useSiteConfig.ts:156-158
apps/customer/composables/useAppInit.ts:202-205
apps/customer/middleware/init.global.ts:6-16
```

Current observed risky assignments:

```text
useSiteConfig.fetchSiteConfig catch: error.value = e
useAppInit.fetchAppInit catch: error.value = e
```

## Objective

Fix Customer SSR serialization so failed site-config/app-init requests store only plain serializable state.

After remediation, `/search`, `/checkout`, `/success`, and `/tickets` must no longer render Nuxt 500 from non-POJO serialization in the Docker customer SSR environment.

## Required Scope

Customer Develop must:

```text
replace raw caught errors stored in Nuxt useState with plain serializable objects or strings
remove Error, FetchError, Response, Request, AxiosError, or other class instances from SSR state
preserve app-init fallback behavior when platform API init is unavailable
preserve site-config fallback behavior when public site config is unavailable
preserve auth redirect behavior for protected routes
preserve lottery image display integration and image fallback behavior
keep customer free of central lottery image operations API calls
document the existing customer lint/test script gap if still unavailable
write a remediation handoff with exact files changed and validation results
```

Suggested approach:

```text
add a small local serializer/helper that converts unknown errors into a plain object:
{ message: string, status?: number, code?: string, name?: string }
```

Keep the serialized shape minimal and avoid copying request/response/config headers or credential-bearing payloads.

## Out Of Scope

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
backend/BO remediation
new Customer feature work unrelated to SSR serialization
adding broad lint/test tooling unless already present and trivial
real production credentials
launch-gate approval
```

## File Ownership

Can edit:

```text
apps/customer/**
ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
docs/lottery-image-generation.md
ai-agents/decisions/**
```

## Shared Workspace Guardrail

The shared worktree contains unrelated dirty/untracked files from other agents.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If overlapping customer files contain current customer lane changes, work with them and stage only this remediation scope.

Do not touch this credential-bearing local artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Acceptance Criteria

```text
Nuxt useState values for site-config/app-init errors are plain serializable data
/search does not render Nuxt 500 in Docker SSR
/checkout redirects or renders without Nuxt 500 in Docker SSR
/success redirects or renders without Nuxt 500 in Docker SSR
/tickets redirects or renders without Nuxt 500 in Docker SSR
customer service logs have no devalue/non-POJO serialization crash
app-init and site-config fallback behavior still returns usable fallback state
auth redirect behavior remains intact
lottery image display/fallback integration remains intact
customer source still has no central lottery image operations API calls
customer build passes
```

## Validation

Use Docker commands only. Do not run Node/npm/Nuxt on the host machine.

Required:

```sh
git diff --check -- apps/customer ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
docker compose build customer
docker compose up -d postgres valkey platform-api customer
docker compose run --rm customer npm run build
```

Run lint/test only if scripts exist after remediation:

```sh
docker compose run --rm customer npm run lint
docker compose run --rm customer npm run test
```

Required source scan:

```sh
rg -n "/api/v1/admin/central/lottery-images|/admin/central/lottery-images|lottery-images|branding-assets" apps/customer -g '!node_modules'
```

Expected result: no customer call to central operations APIs. If benign text appears, explain it in the handoff.

Required route smoke:

```text
GET http://localhost:3000/search
GET http://localhost:3000/checkout
GET http://localhost:3000/success
GET http://localhost:3000/tickets
```

Record final URLs, status/body summary, and customer service log check. Protected routes may redirect to login; they must not show Nuxt 500.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
```

Must include:

```text
commit hash
files changed
root cause
serialization strategy
routes smoked and results
customer logs devalue/non-POJO result
build/lint/test status
central operations API scan result
lottery image display regression notes
unrelated dirty files left untouched
known risks/blockers
next recommended agent
```

## Next Agent

Customer Develop
