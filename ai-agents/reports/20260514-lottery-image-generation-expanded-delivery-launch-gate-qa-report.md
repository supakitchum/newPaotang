# Lottery Image Generation Expanded Delivery Launch Gate QA Report

## Summary

Result: FAIL

Task key: `lottery-image-generation-expanded-delivery-launch-gate`

QA date: 2026-05-14

Current commit under QA:

```text
b2c0893734ccd94e3af92fcafd559693c99fb295
```

Lane commits under test:

```text
BO implementation: f853c82805ce9f589bc5f7e432a200d48088ba5e
BO handoff: e5fc5f4b328c87f24eba1e62656affe8bf4aac13
Backend/Ops implementation: e5513c923dd91024238d175bb1de2a68bebb173f
Backend/Ops handoff: e41026cb08cb5f55acf9e2a34dcb167a0a57a781
Customer implementation resolved in git: afd7993ee9aee0b7ad496172633911934e86eb1c
Customer handoff: 1f9abb62310c3a2f58a2b6494d1af73a5697a02c
```

Note: the QA task/handoff listed the customer implementation as `afd79933a5eb146a7880650144a91ff021430137`, but that full object was not present in the local git history. The short commit `afd7993` resolves to `afd7993ee9aee0b7ad496172633911934e86eb1c`.

## Finding 1

### [P1] Customer routes render Nuxt 500 during launch-gate browser smoke

References:

- `apps/customer/composables/useSiteConfig.ts:156-158`
- `apps/customer/composables/useAppInit.ts:202-205`
- `apps/customer/middleware/init.global.ts:6-16`

After the required Docker build/start sequence, the customer Nuxt server returns HTTP 500 content for customer launch-gate routes instead of rendering usable pages or the expected auth redirects. Repro was captured in the in-app browser after restarting the customer container:

```text
GET http://localhost:3000/search   -> final URL /result, body shows 500
GET http://localhost:3000/checkout -> final URL /login?redirect=/checkout, body shows 500
GET http://localhost:3000/success  -> final URL /login?redirect=/success, body shows 500
GET http://localhost:3000/tickets  -> final URL /login?redirect=/tickets, body shows 500
```

The visible error is:

```text
Cannot stringify arbitrary non-POJOs
```

Service logs show Nuxt failing during SSR payload serialization via `devalue`. The likely direct cause is that `fetchSiteConfig()` and `fetchAppInit()` assign the raw caught error object to Nuxt `useState` (`site_config_error` / `app_init_error`). When the local SSR API init path fails, Nuxt attempts to serialize that non-POJO error into the page payload and the route crashes.

Impact: this blocks the Lane D requirement to validate customer stock/search, checkout, success, and ticket image display behavior. Even unauthenticated routes that should redirect or render fallback UI are not usable in the Docker launch-gate environment.

Evidence:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/browser/customer-smoke-after-restart.json`
- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/browser/browser-smoke.json`
- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/customer-service-logs-after-smoke.log`

## Validation Results

### Baseline / Build

| Check | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/validation/git-diff-check.log` |
| `docker compose build platform-api back-office customer` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/validation/docker-compose-build-all.log` |
| `docker compose up -d postgres valkey platform-api back-office customer` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/validation/docker-compose-up-all.log` |

Build note: back-office `npm ci` emitted `npm audit` summary with 35 vulnerabilities, including 1 critical. This was not a requested audit gate, but it is recorded as residual security signal in the build log.

### Backend

All required backend launch-gate checks passed:

| Check | Result | Evidence |
| --- | --- | --- |
| `PartnerLotteryBrandingAssetTest` | PASS, 1 test / 24 assertions | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/phpunit-partner-branding.log` |
| `LotteryImage` | PASS, 9 tests / 241 assertions | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/phpunit-lottery-image.log` |
| `LotteryImageVisual` | PASS, 1 test / 51 assertions | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/phpunit-lottery-image-visual.log` |
| `LotteryImageOperationsTest` | PASS, 6 tests / 97 assertions | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/phpunit-lottery-image-operations.log` |
| `lottery-images:readiness --format=json` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/readiness-json.log` |
| `lottery-images:check-pending-backgrounds --dry-run` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/backend/pending-backgrounds-dry-run.log` |

Readiness output in local launch-gate state:

```text
disk_driver=local
runtime_webp_ready=true
secrets_redacted=true
production_ready=false
blocking_reasons=object_storage_disk_not_s3_compatible, object_storage_bucket_missing, object_storage_region_missing
required_queue_names=stock-image-generation, stock-partner-image-generation
```

This matches the expected non-production local state.

### Back Office

All required BO checks passed:

| Check | Result | Evidence |
| --- | --- | --- |
| `docker compose run --rm back-office npm run lint` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/back-office/npm-lint.log` |
| `docker compose run --rm back-office npm run test` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/back-office/npm-test.log` |
| `docker compose run --rm back-office npm run build` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/back-office/npm-build.log` |
| `node scripts/check-lottery-image-operations.mjs` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/back-office/structural-lottery-image-ops.log` |

BO source scan confirmed:

- Central route exists at `/admin/central/lottery-images`.
- Dashboard links to the operations page.
- Component references the expected lottery image operations endpoints.
- State-changing calls include `api.idempotencyKey()`.

Evidence:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/back-office/bo-lottery-image-source-scan.log`

Browser smoke:

- `http://localhost:3100/admin/central/lottery-images` redirects to login with `redirect=/admin/central/lottery-images`, as expected without an authenticated admin session.
- `http://localhost:3100/admin/central/dashboard` redirects to login with `redirect=/admin/central/dashboard`, as expected without an authenticated admin session.

Evidence:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/browser/browser-smoke.json`

### Customer

Command validation:

| Check | Result | Evidence |
| --- | --- | --- |
| `docker compose run --rm customer npm run build` | PASS | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/npm-build.log` |
| Customer lint script | SKIPPED, script unavailable per task note | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/package-script-scan-final.log` |
| Customer test script | SKIPPED, script unavailable per task note | `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/package-script-scan-final.log` |

Customer source scan confirmed no calls to central lottery image operations APIs:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/customer-central-api-scan.log`

Customer image field/source scan confirmed usage of `LotteryImage`, `image_url`, `image_thumb_url`, `image_status`, and `image_error` across stock card, checkout, success, ticket list/history/detail code paths:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/customer/customer-image-field-scan.log`

Functional browser validation failed due Finding 1.

## OpenAPI / Credential Scan

OpenAPI YAML parse passed:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/openapi/openapi-yaml-parse.log`

No high-confidence secret patterns were found in launch-gate QA artifacts:

- `ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/scans/artifact-secret-scan.log`

## Residual Risks

- Customer package still has no lint/test scripts; this is documented by the task as a tooling gap, not a blocking failure by itself.
- No real production S3/R2/CDN deployment or real credentials were used.
- BO authenticated destructive workflows were not executed because no admin credentials/session were provided.
- Customer authenticated checkout/ticket visual flows could not be validated because customer routes fail during SSR before the authenticated journey can start.
- The shared worktree contains unrelated dirty/untracked files from other agents; QA did not clean, revert, stage, or commit them.
- Git fetch continues to report the pre-existing local `.git/gc.log` / unreachable loose object housekeeping warning.

## Recommendation

Next Agent: Coordinator

Reason: Launch gate should not be approved while customer routes return Nuxt 500 in the Docker launch-gate environment. Coordinator should route remediation, likely to Customer Develop, for the SSR serialization crash and then re-run launch-gate QA.
