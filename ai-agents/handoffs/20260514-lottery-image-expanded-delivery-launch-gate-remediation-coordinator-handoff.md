# Lottery Image Expanded Delivery Launch Gate Remediation Coordinator Handoff

## Agent

Coordinator

## Task

Review failed launch-gate QA for:

```text
lottery-image-generation-expanded-delivery-launch-gate
```

## Decision

Rejected. Customer remediation required.

Decision file:

```text
ai-agents/decisions/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-review-decision.md
```

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa-report.md
```

QA artifacts:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-expanded-delivery-launch-gate-qa/**
```

## Blocking Issue

Customer Docker SSR launch-gate routes return Nuxt 500:

```text
/search
/checkout
/success
/tickets
```

Error:

```text
Cannot stringify arbitrary non-POJOs
```

QA suspects raw caught Error objects are stored in Nuxt state in:

```text
apps/customer/composables/useSiteConfig.ts
apps/customer/composables/useAppInit.ts
apps/customer/middleware/init.global.ts
```

## Passed Scope

No remediation is currently requested for:

```text
Backend/Ops lane
BO operations lane
OpenAPI parse
credential scan
customer build
customer central-API source boundary
```

## Orchestrator Instruction

Create and dispatch a focused Customer Develop task:

```text
lottery-image-customer-ssr-error-serialization-remediation
```

Do not send this directly to QA before Customer Develop fixes the SSR serialization issue.

## Customer Remediation Requirements

Customer Develop must:

```text
store only plain serializable error state in Nuxt useState
remove raw Error, FetchError, Response, Request, or other class instances from SSR state
preserve app-init and site-config fallback behavior
preserve auth redirect behavior
preserve lottery image display integration and fallbacks
keep customer free of central lottery image operations API calls
run docker compose run --rm customer npm run build
run any available targeted smoke/route checks
write a handoff with exact files changed and validation results
```

## QA Retest Requirements

After remediation, Orchestrator should route focused QA:

```text
lottery-image-customer-ssr-error-serialization-remediation-qa
```

QA must verify:

```text
/search does not render Nuxt 500
/checkout redirects or renders without Nuxt 500
/success redirects or renders without Nuxt 500
/tickets redirects or renders without Nuxt 500
customer service logs have no devalue/non-POJO serialization crash
customer image field/source scan still passes
customer central operations API scan still has no matches
```

## Board Update

Set active task to:

```text
lottery-image-customer-ssr-error-serialization-remediation
```

## Next Agent

```text
Orchestrator
```
