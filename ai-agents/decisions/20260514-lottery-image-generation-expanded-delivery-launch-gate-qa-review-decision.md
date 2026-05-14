# Lottery Image Generation Expanded Delivery Launch Gate QA Review Decision

Date: 2026-05-14
Owner: Coordinator
Task: `lottery-image-generation-expanded-delivery-launch-gate`
Result: REJECTED - CUSTOMER REMEDIATION REQUIRED

## Context

QA Tester completed launch-gate QA for the expanded lottery image generation delivery.

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
```

Lane commits under test:

```text
BO implementation: f853c82805ce9f589bc5f7e432a200d48088ba5e
BO handoff: e5fc5f4b328c87f24eba1e62656affe8bf4aac13
Backend/Ops implementation: e5513c923dd91024238d175bb1de2a68bebb173f
Backend/Ops handoff: e41026cb08cb5f55acf9e2a34dcb167a0a57a781
Customer implementation: afd7993ee9aee0b7ad496172633911934e86eb1c
Customer handoff: 1f9abb62310c3a2f58a2b6494d1af73a5697a02c
QA dispatch: b2c0893734ccd94e3af92fcafd559693c99fb295
```

## QA Result

QA result is FAIL.

The launch gate is not approved.

## Blocking Finding

P1 customer launch-gate browser smoke fails with Nuxt 500 pages.

Affected routes:

```text
GET http://localhost:3000/search   -> final URL /result, body shows 500
GET http://localhost:3000/checkout -> final URL /login?redirect=/checkout, body shows 500
GET http://localhost:3000/success  -> final URL /login?redirect=/success, body shows 500
GET http://localhost:3000/tickets  -> final URL /login?redirect=/tickets, body shows 500
```

Visible error:

```text
Cannot stringify arbitrary non-POJOs
```

Likely source files from QA report:

```text
apps/customer/composables/useSiteConfig.ts
apps/customer/composables/useAppInit.ts
apps/customer/middleware/init.global.ts
```

QA assessment: `fetchSiteConfig()` and `fetchAppInit()` appear to assign raw caught Error objects to Nuxt `useState` values. Nuxt SSR then tries to serialize those non-POJO values via `devalue`, causing route-level 500 failures.

## Passed Areas

The following areas are not blocked by this review:

```text
Backend launch-gate checks passed
BO lint/test/build/structural checks passed
BO unauthenticated browser redirects behaved as expected
Customer build passed
Customer source scan found no central lottery image operations API calls
OpenAPI YAML parse passed
Launch-gate artifact credential scan passed
```

## Decision

Coordinator rejects the launch gate until the customer SSR serialization failure is fixed and QA reruns the affected launch-gate coverage.

No Backend or BO remediation is required from this QA report.

## Required Remediation

Route a focused Customer remediation through Orchestrator.

Expected task:

```text
lottery-image-customer-ssr-error-serialization-remediation
```

Customer Develop must:

```text
replace raw Error/useFetch error objects stored in useState with plain serializable objects or strings
ensure /search, /checkout, /success, and /tickets no longer render Nuxt 500 in Docker SSR
preserve existing auth redirects and app-init/site-config fallback behavior
preserve lottery image display integration
continue avoiding central lottery image operations APIs
document customer lint/test script gap if still unavailable
```

## Required Retest

After Customer remediation, Orchestrator must route QA Tester to rerun focused launch-gate remediation QA.

Required QA scope:

```text
docker compose build customer
docker compose up -d postgres valkey platform-api customer
browser smoke for /search, /checkout, /success, /tickets
customer service logs show no serialization crash
customer image field/source scan remains valid
no central lottery image operations API usage from apps/customer/**
backend/BO smoke only as needed to prove launch-gate integration remains intact
```

## Next Agent

```text
Orchestrator
```

Orchestrator should dispatch Customer Develop for remediation, then route QA Tester for focused retest.
