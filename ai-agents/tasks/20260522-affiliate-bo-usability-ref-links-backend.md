# affiliate-bo-usability-ref-links - Backend Develop

## Target Agent

Backend Develop

## Coordinator / Orchestrator Context

Implement the backend/API part of:

```text
affiliate-bo-usability-ref-links
```

Backend Develop is the first implementation agent. BO Develop and Customer Develop must wait for the backend handoff unless Orchestrator or Coordinator explicitly says otherwise.

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

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or new unknown dirty files overlap backend scope.

Known dirty implementation files already existed before Orchestrator dispatch. Do not revert or overwrite them. Read overlapping files carefully and work with them only if they are part of the intended current state.

Known backend dirty files at Orchestrator dispatch:

```text
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

Never stage `apps/platform-api/.phpunit.result.cache`.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-orchestrator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/openapi.yaml
```

## Backend Scope

Backend Develop owns:

```text
apps/platform-api/**
docs/openapi.yaml only if API response/request contract changes
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
```

Do not edit:

```text
apps/back-office/**
apps/customer/**
```

## Required Backend Behavior

Affiliate/referral code policy:

```text
Affiliate code exactly 6 characters.
Charset A-Z, a-z, 0-9.
Case-sensitive.
Unique per tenant.
Generated server-side for customer self-register and BO create flows.
Ignore user/admin-supplied code in create/update flows.
```

Canonical referral URL:

```text
Use tenant storefront root plus query param: /?ref={CODE}
Stop generating /a/{CODE} as canonical new data.
Keep legacy /a/{CODE} data tolerable in reads where needed.
Responses should expose the canonical URL.
```

Referral attribution:

```text
Resolve ?ref=CODE inside the current tenant only.
Resolution order: active affiliate_links.code, then active affiliate_accounts.code.
Reject inactive or cross-tenant codes.
After customer identity is known, create/update a pending attribution using last-click semantics.
Attribution TTL is 30 days.
Paid order commission calculation must continue to use affiliate attribution as source of truth.
```

Security:

```text
Customer affiliates must not gain BO/admin access.
Backend auth/permission remains source of truth.
Do not allow customer-authenticated affiliate users into admin APIs.
```

Out of scope:

```text
affiliate tiering
new affiliate reporting dashboards
reward payout rule changes
sale price rule changes
apps/back-office/**
apps/customer/**
runtime DB cleanup
```

## Required Validation

Use Docker and test DB only:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AffiliateTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CustomerAffiliateTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter='TenantWalletTest|CustomerTopupTest|SoldSyncTest'
git diff --check
```

If you need destructive setup, it must target:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Do not run destructive DB commands against runtime DB `newpaotang`.

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
```

Include:

```text
worktree path
branch
HEAD and origin/develop at start/end
commit hash pushed
files changed
dirty files consumed vs left untouched
API/code/referral contract summary
validation commands/results
known risks/blockers
Next Agent: Orchestrator
```

Commit and push scoped backend changes and the handoff.

## Next Agent

Orchestrator
