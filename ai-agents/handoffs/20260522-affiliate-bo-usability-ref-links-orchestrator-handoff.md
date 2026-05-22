# affiliate-bo-usability-ref-links Handoff

## Agent

Orchestrator

## Task

Split and dispatch `affiliate-bo-usability-ref-links`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: a57f0729daf5934a701a8c4cc261a09746732e39
origin/develop at dispatch start: a57f0729daf5934a701a8c4cc261a09746732e39
```

Start gate completed:

```text
pwd: /Users/supakit/WorkSpace/www/newPaotang
git top-level: /Users/supakit/WorkSpace/www/newPaotang
git fetch origin: completed
git merge --ff-only origin/develop: Already up to date.
HEAD equals origin/develop.
```

The worktree contains pre-existing dirty implementation changes from prior Hotfix work. Orchestrator did not stage, revert, or overwrite them.

Known dirty files at dispatch:

```text
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStatusBadge.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/components/AdminCustomerDetail.vue
apps/back-office/components/AdminWalletDetail.vue
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
apps/platform-api/.phpunit.result.cache
apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php
apps/platform-api/app/Modules/Commerce/Http/Requests/CommerceRequestValidator.php
apps/platform-api/app/Modules/Commerce/Services/CommerceService.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/AffiliateTest.php
apps/platform-api/tests/Feature/TenantWalletTest.php
apps/platform-api/tests/Support/M8GrowthFixtures.php
apps/platform-api/app/Modules/Growth/Http/Controllers/CustomerAffiliateController.php
apps/platform-api/tests/Feature/CustomerAffiliateTest.php
```

## What Was Done

Read:

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
```

Created task prompts:

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-qa.md
```

Dispatch order:

```text
Backend Develop -> Orchestrator -> BO Develop + Customer Develop -> Orchestrator -> QA Tester -> Coordinator
```

Backend is first because it owns code generation, canonical referral URL, ref attribution, and commission source-of-truth behavior. BO and Customer tasks must wait for the backend handoff.

## Files Changed

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-qa.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-qa.md ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: orchestration files plus pre-existing dirty implementation files before staging
```

## Known Risks

```text
Worktree has extensive pre-existing dirty implementation files. Downstream agents must inspect and work with overlapping files instead of overwriting them, and stage only scoped changes they intentionally own.
apps/platform-api/.phpunit.result.cache must not be staged.
Reward payout rules and sale price rules are explicitly out of scope.
Runtime DB newpaotang must not be wiped.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop
