# affiliate-bo-usability-ref-links BO/Customer Dispatch Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop and Customer Develop after Backend Develop completed `affiliate-bo-usability-ref-links-backend`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
origin/develop at dispatch start: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
git status --short --branch: ## develop...origin/develop plus pre-existing dirty implementation files
```

Known dirty files left unstaged include existing BO/customer hotfix files plus unrelated backend files:

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
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
apps/platform-api/tests/Feature/TenantWalletTest.php
```

Orchestrator did not stage, revert, or overwrite these files.

## What Was Done

Read Backend handoff:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
```

Backend commits to consume:

```text
backend implementation: c060d1e875d93cf1ba7c7a1b9ce93066baf9c817
backend handoff: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
```

Updated downstream tasks with backend commit context:

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
```

Clarified backend handoff questions using existing Coordinator scope:

```text
Customer Develop should submit/apply stored ref after login/register or before checkout through POST /customer/affiliate/referrals/apply.
BO Develop should treat /?ref={CODE} canonical URL as the primary referral link display and keep code/url generated/read-only.
```

Updated Board so both BO Develop and Customer Develop can start from their task files.

## Files Changed

```text
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-bo-customer-dispatch-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-orchestrator-bo-customer-dispatch-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: orchestration files plus pre-existing dirty implementation files before staging
```

## Known Risks

```text
Shared worktree still contains pre-existing dirty BO/customer/backend files. BO and Customer agents must inspect and work with overlapping files, stage only their scoped intentional changes, and leave unrelated dirty files untouched.
apps/platform-api/.phpunit.result.cache must not be staged.
QA cannot start until BO and Customer handoffs are pushed.
```

## Questions For Coordinator

None.

## Next Agent

BO Develop and Customer Develop
