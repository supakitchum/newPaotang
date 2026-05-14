# lottery-image-customer-ssr-error-serialization-remediation Handoff

## Agent

Customer Develop

## Task

Fix Customer Nuxt SSR serialization crashes on launch-gate routes caused by non-plain error objects being stored in Nuxt `useState`.

## Commit Hash

Customer remediation commit:

```text
c351606c7924dfd85824dd442ef03be7a2d2f98d
```

## Root Cause

`useSiteConfig.fetchSiteConfig()` and `useAppInit.fetchAppInit()` stored raw caught errors in SSR-backed Nuxt state:

```text
site_config_error
app_init_error
```

When the platform API bootstrap path failed in Docker SSR, those values could be `Error`, Axios/Fetch-style errors, or other class instances. Nuxt then attempted to serialize them with `devalue`, causing:

```text
Cannot stringify arbitrary non-POJOs
```

## Serialization Strategy

Added a minimal customer-local serializer that converts unknown errors to plain JSON-safe state:

```text
{ message: string, status?: number, code?: string, name?: string }
```

The serializer intentionally avoids copying request, response, headers, config, or credential-bearing payloads.

## What Was Done

- Added a serializable error helper in `apps/customer/utils/serializableError.ts`.
- Updated `apps/customer/composables/useSiteConfig.ts` to store `SerializableError | null` in `site_config_error`.
- Updated `apps/customer/composables/useAppInit.ts` to store `SerializableError | null` in `app_init_error`.
- Preserved site-config fallback behavior: failed public site config still clears config and returns `null`.
- Preserved app-init fallback behavior: failed app init still returns the current cached `data.value`.
- Preserved auth redirect behavior for protected routes.
- Preserved lottery image display/fallback code paths; no image display implementation was changed.

## Files Changed

```text
apps/customer/composables/useAppInit.ts
apps/customer/composables/useSiteConfig.ts
apps/customer/utils/serializableError.ts
ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md
```

## Routes Smoked

Docker services were running with:

```sh
docker compose up -d postgres valkey platform-api customer
```

HTTP smoke results:

```text
GET http://localhost:3000/search   -> 200, final http://localhost:3000/result
GET http://localhost:3000/checkout -> 200, final http://localhost:3000/login?redirect=/checkout
GET http://localhost:3000/success  -> 200, final http://localhost:3000/login?redirect=/success
GET http://localhost:3000/tickets  -> 200, final http://localhost:3000/login?redirect=/tickets
```

Browser plugin smoke results:

```text
/search   -> final /result, no serialization error, no internal server error
/checkout -> final /login?redirect=/checkout, no serialization error, no internal server error
/success  -> final /login?redirect=/success, no serialization error, no internal server error
/tickets  -> final /login?redirect=/tickets, no serialization error, no internal server error
```

Protected routes still redirected to login as expected.

## Validation

Required checks:

```text
git status --short --branch -> checked before work; unrelated dirty/untracked files existed outside scope
git rev-parse HEAD -> feb52908c83f0fec918e3d80cb0e4481f321c2d7
git rev-parse origin/develop -> feb52908c83f0fec918e3d80cb0e4481f321c2d7
git diff --check -- apps/customer ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md -> PASS
docker compose build customer -> PASS
docker compose up -d postgres valkey platform-api customer -> PASS
docker compose run --rm customer npm run build -> PASS
```

Customer lint/test:

```text
SKIPPED: apps/customer/package.json still has no lint or test scripts.
Existing scripts are dev, build, generate, preview.
```

Central operations API scan:

```sh
rg -n "/api/v1/admin/central/lottery-images|/admin/central/lottery-images|lottery-images|branding-assets" apps/customer -g '!node_modules'
```

Result:

```text
PASS: no matches in apps/customer.
```

Customer service log check after route smoke:

```text
PASS: no "Cannot stringify arbitrary non-POJOs", "devalue", or "non-POJO" entries.
Note: logs still show the pre-existing Node fs.Stats deprecation warning during Nuxt startup/build.
```

Body scan after route smoke:

```text
PASS: no "Cannot stringify arbitrary non-POJOs", "Nuxt 500", "Internal Server Error", "devalue", or "non-POJO" text in smoked route HTML.
```

## Lottery Image Display Regression Notes

No lottery image components, image field normalization, checkout/success ticket previews, or ticket list/detail image display logic were changed in this remediation. Build and route smoke continued to include the committed lottery image integration paths.

## Unrelated Dirty Files Left Untouched

The shared worktree still contains unrelated dirty/untracked files outside this Customer remediation scope, including `apps/back-office/**`, `apps/platform-api/**`, `docs/**`, `compose.yaml`, generated lottery image resources, and the credential-bearing local artifact:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not cleaned, reverted, staged, or committed by Customer Develop.

## Known Risks

- Customer authenticated checkout/ticket image journeys still need QA with a real authenticated session and test data.
- Customer package still lacks lint/test scripts; only Docker build and smoke coverage were available for this remediation.
- Local logs still include Node deprecation warnings unrelated to this serialization crash.

## Questions For Coordinator

None.

## Next Agent

QA Tester
