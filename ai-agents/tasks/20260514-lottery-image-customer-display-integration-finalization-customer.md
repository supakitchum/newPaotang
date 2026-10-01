# lottery-image-customer-display-integration-finalization - Customer Develop

## Target Agent

Customer Develop

## Why This Task Exists

The user reported all expanded delivery agents are done, but Orchestrator found the Customer lane is not yet committed to git.

Current local handoff:

```text
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
```

The handoff says:

```text
Implementation commit was not created because the required lint and test validation commands fail in the current customer package due missing npm scripts. Build validation passed.
```

This blocks the expanded delivery launch-gate QA because QA needs a committed Customer lane under test.

## Objective

Finalize the Customer image display integration lane so it can be reviewed by QA:

```text
commit the Customer lane implementation
resolve or clearly document the missing lint/test script validation blocker
push the committed Customer lane through the shared branch workflow
write an updated Customer handoff with the final commit hash
```

## Current Customer Lane Files To Review

Inspect the current local changes before editing:

```text
apps/customer/assets/scss/main.css
apps/customer/components/LotteryImage.vue
apps/customer/components/LotteryItem.vue
apps/customer/components/TicketStub.vue
apps/customer/composables/useCart.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/checkout.vue
apps/customer/pages/success.vue
apps/customer/pages/tickets/history.vue
apps/customer/pages/tickets/index.vue
apps/customer/pages/tickets/view.vue
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
```

## Required Scope

Do one of these, preferring the first option if it fits existing package conventions:

```text
add or restore safe customer lint/test scripts if the project already has suitable tooling installed
```

or:

```text
if lint/test scripts genuinely do not exist and adding them would be unrelated tooling work, update the handoff to mark lint/test unavailable and record build-only validation as the lane evidence
```

In either case, the lane must end with a real commit containing the customer implementation and updated handoff.

## Guardrails

```text
Do not edit apps/platform-api/**
Do not edit apps/back-office/**
Do not edit docs/openapi.yaml
Do not call central operations APIs from customer frontend
Do not invent backend endpoints
Do not stage unrelated dirty files from other agents
Do not touch real credentials or local secret artifacts
```

Important credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Checks

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Use Docker commands only for application runtime validation.

Required:

```sh
git diff --check -- apps/customer ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
docker compose run --rm customer npm run build
```

Run these if scripts are added or already available:

```sh
docker compose run --rm customer npm run lint
docker compose run --rm customer npm run test
```

Also verify customer code does not call central operations APIs:

```sh
rg -n "/api/v1/admin/central/lottery-images|/admin/central/lottery-images|lottery-images|branding-assets" apps/customer -g '!node_modules'
```

Expected result is no customer call to central operations APIs. If benign text appears, explain it in the handoff.

## Handoff Requirements

Update or rewrite:

```text
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
```

Must include:

```text
final commit hash
routes/components/composables changed
customer endpoints and payload fields used
image fallback behavior
proof no central operations APIs are called
validation commands and results
manual workflow evidence
whether lint/test scripts were added, passed, unavailable, or still blocked
API gaps, if any
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Customer Develop
