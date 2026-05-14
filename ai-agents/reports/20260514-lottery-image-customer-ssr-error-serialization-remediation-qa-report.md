# lottery-image-customer-ssr-error-serialization-remediation - QA Report

## Result

PASS

Focused QA accepts the Customer SSR serialization remediation. The previously failing launch-gate routes no longer render Nuxt 500 pages, and the customer logs captured after smoke do not show the `Cannot stringify arbitrary non-POJOs` / `devalue` crash.

## Commits Under Test

- Customer remediation: `c351606c7924dfd85824dd442ef03be7a2d2f98d`
- Customer handoff: `212fa9d`
- QA dispatch / current HEAD: `450cec85b32e452e06968ad7271e2994a6a2a7ab`
- `origin/develop`: `450cec85b32e452e06968ad7271e2994a6a2a7ab`

## Scope

Validated the focused remediation requested by:

- `ai-agents/tasks/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa.md`
- `ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md`
- `ai-agents/decisions/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-review-decision.md`

## Commands Run

| Check | Result | Notes |
| --- | --- | --- |
| `git status --short --branch` | PASS with known dirty workspace | Shared worktree still contains unrelated dirty/untracked files from other agents; QA artifacts are the only new files from this pass. |
| `git rev-parse HEAD` | PASS | `450cec85b32e452e06968ad7271e2994a6a2a7ab` |
| `git rev-parse origin/develop` | PASS | `450cec85b32e452e06968ad7271e2994a6a2a7ab` |
| `git diff --check c351606c7924dfd85824dd442ef03be7a2d2f98d..HEAD` | PASS | No whitespace errors. |
| `docker compose build customer` | PASS | Customer image built successfully. |
| `docker compose up -d postgres valkey platform-api customer` | PASS | Services running; postgres and valkey healthy. |
| `docker compose run --rm customer npm run build` | PASS | Nuxt build and Nitro server build completed. Existing `fs.Stats` deprecation warning remains. |
| Customer package script review | PASS with tooling gap | `apps/customer/package.json` has `dev`, `build`, `generate`, `preview`; no `lint` or `test` scripts. |

## Route Smoke

Docker-container HTTP smoke artifact:

- `ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa/docker-node-route-smoke-refined.json`

Browser smoke artifact:

- `ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa/browser-route-smoke.json`

| Route | HTTP status | Final URL | Body / Browser Error Scan |
| --- | ---: | --- | --- |
| `/search` | 200 | `http://127.0.0.1:3000/result` and browser `http://localhost:3000/result` | PASS: no `Internal Server Error`, `Cannot stringify`, `devalue`, or `non-POJO`; browser shows results page shell/loading state. |
| `/checkout` | 200 | `http://127.0.0.1:3000/login?redirect=/checkout` and browser equivalent | PASS: no serialization crash; auth redirect preserved. |
| `/success` | 200 | `http://127.0.0.1:3000/login?redirect=/success` and browser equivalent | PASS: no serialization crash; auth redirect preserved. |
| `/tickets` | 200 | `http://127.0.0.1:3000/login?redirect=/tickets` and browser equivalent | PASS: no serialization crash; auth redirect preserved. |

Note: the broad string `500` appears in the raw HTML smoke because of normal non-error content such as color text (`#0a87f5`) and/or bundled error asset references. The refined scan found no visible/server error markers: `Internal Server Error`, `Cannot stringify`, `Cannot stringify arbitrary non-POJOs`, `devalue`, `non-POJO`, `__nuxt_error`, or `data-nuxt-error`.

## Customer Log Serialization-Crash Scan

Artifacts:

- `ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa/customer-logs-after-browser-smoke.txt`
- `ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa/customer-logs-since-restart-route-smoke.txt`

Result: PASS. `rg` found no matches for:

```text
Cannot stringify arbitrary non-POJOs
devalue
non-POJO
[500]
Internal Server Error
```

Operational note: after `docker compose run --rm customer npm run build`, the mounted Nuxt build output caused the already-running dev server to restart and log an `EADDRINUSE` warning. I restarted only the `customer` service before the final route smoke. The post-restart/post-smoke logs used for this QA decision contain no serialization crash.

## Source Scans

### Central Operations API

Command:

```sh
rg -n "/api/v1/admin/central/lottery-images|/admin/central/lottery-images|lottery-images|branding-assets" apps/customer -g '!node_modules'
```

Result: PASS. No matches in `apps/customer`; customer still does not call central lottery image operations APIs.

### Lottery Image Integration Fields

Command:

```sh
rg -n "image_url|image_thumb_url|image_status|image_error|LotteryImage" apps/customer -g '!node_modules'
```

Result: PASS. Expected image display integration remains present in customer pages/components/composables, including:

- `apps/customer/pages/checkout.vue`
- `apps/customer/pages/success.vue`
- `apps/customer/pages/tickets/index.vue`
- `apps/customer/pages/tickets/history.vue`
- `apps/customer/pages/tickets/view.vue`
- `apps/customer/components/LotteryItem.vue`
- `apps/customer/components/TicketStub.vue`
- `apps/customer/composables/useCart.ts`
- `apps/customer/composables/useUserTickets.ts`
- `apps/customer/composables/usePlatformApi.ts`

### Raw Error State

Command:

```sh
rg -n "error\.value\s*=\s*e|error\.value\s*=\s*error|useState<.*Error|useState\(.*error" apps/customer/composables apps/customer/middleware apps/customer/utils -g '!node_modules'
```

Result: PASS. Matches are only the new serializable state types:

- `apps/customer/composables/useAppInit.ts:150` uses `useState<SerializableError | null>`.
- `apps/customer/composables/useSiteConfig.ts:97` uses `useState<SerializableError | null>`.

Inspected remediation code:

- `apps/customer/utils/serializableError.ts:1` defines a plain `SerializableError` shape.
- `apps/customer/utils/serializableError.ts:34` converts unknown errors into JSON-safe fields only.
- `apps/customer/composables/useSiteConfig.ts:158` stores `toSerializableError(e)` instead of raw `e`.
- `apps/customer/composables/useAppInit.ts:203` stores `toSerializableError(e)` instead of raw `e`.

## Credential / Artifact Scan

Command, scoped to this QA artifact directory:

```sh
rg -n "<credential-patterns>" ai-agents/reports/artifacts/20260514-lottery-image-customer-ssr-error-serialization-remediation-qa
```

Result: PASS. No credential-like matches in this QA artifact directory.

## Findings

No blocking findings.

## Residual Risks

- Authenticated checkout/ticket image journeys were not exercised because the focused task does not provide a seeded authenticated customer session.
- Customer still has no `lint` or `test` package scripts; build plus route/browser smoke were the available validation gates.
- Full expanded-delivery launch gate remains a Coordinator decision; this report only accepts the focused Customer SSR serialization remediation.

## Recommendation

Next Agent: Coordinator

Reason: Coordinator should review this focused PASS and decide whether to re-approve or rerun the full expanded-delivery launch gate.
