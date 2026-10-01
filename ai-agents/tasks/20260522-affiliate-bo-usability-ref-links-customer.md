# affiliate-bo-usability-ref-links - Customer Develop

## Target Agent

Customer Develop

## Coordinator / Orchestrator Context

Implement customer referral capture and affiliate self-service updates for:

```text
affiliate-bo-usability-ref-links
```

Do not start until Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
```

Backend handoff/commit to consume:

```text
backend implementation: c060d1e875d93cf1ba7c7a1b9ce93066baf9c817
backend handoff: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
```

## Canonical Worktree Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or new unknown dirty files overlap customer scope.

Known customer dirty files at Orchestrator dispatch:

```text
apps/customer/assets/scss/main.css
apps/customer/components/LotteryItem.vue
apps/customer/components/StatusBar.vue
apps/customer/composables/useAppInit.ts
apps/customer/composables/useCart.ts
apps/customer/composables/useCustomerStockRealtime.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useTenantSeo.ts
apps/customer/data/lottery.ts
apps/customer/pages/cart.vue
apps/customer/pages/profile.vue
apps/customer/composables/useCustomerPresence.ts
apps/customer/pages/affiliate.vue
```

Do not revert or overwrite these. Inspect and work with overlapping changes only if they are part of the intended current state. Stage only files in customer scope that you intentionally own for this task.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/api-conventions.md
docs/docker-runtime-policy.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
```

## Customer Scope

Customer Develop owns:

```text
apps/customer/**
docs/customer-api-integration-map.md only for status/gap notes if needed
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-customer-handoff.md
```

Do not edit:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
```

## Required Customer Behavior

Referral capture:

```text
Capture ?ref=CODE on tenant storefront routes.
Store the ref tenant-scoped for 30 days.
Use last-click behavior when a new ref appears.
Treat CODE as case-sensitive.
Do not introduce /a/{CODE} as a new canonical route.
```

Referral apply flow:

```text
Submit/apply the stored ref after login/register or before checkout so backend can create/update pending attribution.
Use POST /api/v1/customer/affiliate/referrals/apply for the apply step.
Do not leak stored ref across tenant hosts.
Preserve existing checkout/cart UI flow.
Customer writes must keep Idempotency-Key where required.
```

Customer affiliate page:

```text
/affiliate displays server-provided 6-character code.
/affiliate displays canonical /?ref=CODE referral link.
Do not give customer affiliates BO access or admin API access.
```

Out of scope:

```text
backend logic changes
BO changes
route redesign
customer visual redesign
reward payout rule changes
sale price rule changes
real payment provider changes
```

## Required Validation

Use Docker only:

```sh
docker compose -p newpaotang run --rm customer npm run lint
docker compose -p newpaotang run --rm customer npm run test
docker compose -p newpaotang run --rm customer npm run build
git diff --check
```

Local smoke if practical:

```sh
docker compose -p newpaotang up -d postgres valkey platform-api customer
curl --resolve alpha.newpaotang.test:3000:127.0.0.1 'http://alpha.newpaotang.test:3000/?ref=Ab3Z9x'
curl --resolve alpha.newpaotang.test:3000:127.0.0.1 'http://alpha.newpaotang.test:3000/affiliate'
```

Record limitations clearly. Do not wipe runtime DB.

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-customer-handoff.md
```

Include:

```text
backend handoff/commit consumed
worktree path
branch
HEAD and origin/develop at start/end
commit hash pushed
files changed
dirty files consumed vs left untouched
ref capture/storage/apply summary
/affiliate code/link display summary
validation commands/results
known risks/blockers
Next Agent: Orchestrator
```

Commit and push scoped customer changes and the handoff.

## Next Agent

Orchestrator
