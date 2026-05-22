# affiliate-bo-usability-ref-links Handoff

## Agent

Backend Develop

## Task

Implement backend/API support for `affiliate-bo-usability-ref-links`:

- Server-owned 6-character Base62 affiliate/referral codes.
- Canonical tenant storefront referral URLs using `/?ref={CODE}`.
- Customer referral apply endpoint with tenant-scoped last-click attribution and 30-day TTL.
- Commission calculation remains attribution-driven.

## Worktree / HEAD

- Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- Start HEAD: `4142de2de65eb2284c8ceb9af48c2193d614d255`
- Start origin/develop: `4142de2de65eb2284c8ceb9af48c2193d614d255`
- Implementation commit: `c060d1e875d93cf1ba7c7a1b9ce93066baf9c817`
- End HEAD at handoff write: `c060d1e875d93cf1ba7c7a1b9ce93066baf9c817`
- End origin/develop before push: `4142de2de65eb2284c8ceb9af48c2193d614d255`
- Commit hash pushed: `c060d1e875d93cf1ba7c7a1b9ce93066baf9c817`
- Status at handoff write: `develop...origin/develop [ahead 1]` with unrelated dirty files left unstaged.

## What Was Done

- Generated affiliate account/link codes server-side as exactly 6 characters using `A-Z`, `a-z`, `0-9`.
- Ignored supplied `code` and `url` in affiliate account/link create/update flows.
- Returned canonical referral URLs as tenant storefront root plus `/?ref={CODE}`; old stored `/a/{CODE}` URLs remain readable as `legacy_url`.
- Added customer-authenticated referral apply flow at `POST /api/v1/customer/affiliate/referrals/apply`.
- Resolved referral codes inside the current tenant only: active `affiliate_links.code` first, then active `affiliate_accounts.code`.
- Created/updated one pending attribution per customer using last-click semantics and metadata TTL of 30 days.
- Made paid-order commission calculation skip expired pending attributions and keep using affiliate attribution as source of truth.
- Added/updated tests for generated code policy, canonical URLs, tenant-scoped referral apply, last-click update, TTL expiry, and commission source.
- Updated `docs/openapi.yaml` for customer affiliate self-service/referral endpoints and canonical referral URL contract.

## Files Changed

Committed in implementation commit `c060d1e875d93cf1ba7c7a1b9ce93066baf9c817`:

- `apps/platform-api/app/Modules/Growth/Services/GrowthService.php`
- `apps/platform-api/app/Modules/Growth/Http/Controllers/CustomerAffiliateController.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/AffiliateTest.php`
- `apps/platform-api/tests/Feature/CustomerAffiliateTest.php`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php`
- `docs/openapi.yaml`

Backend dirty files consumed from pre-dispatch state:

- `apps/platform-api/app/Modules/Growth/Services/GrowthService.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/AffiliateTest.php`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php`
- `apps/platform-api/app/Modules/Growth/Http/Controllers/CustomerAffiliateController.php`
- `apps/platform-api/tests/Feature/CustomerAffiliateTest.php`

Dirty files intentionally left untouched / unstaged:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php`
- `apps/platform-api/app/Modules/Commerce/Http/Requests/CommerceRequestValidator.php`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/tests/Feature/TenantWalletTest.php`
- Existing `apps/back-office/**` dirty/untracked files.
- Existing `apps/customer/**` dirty/untracked files.

## API Endpoints Implemented

- `GET /api/v1/customer/affiliate`
- `POST /api/v1/customer/affiliate`
- `POST /api/v1/customer/affiliate/referrals/apply`
- `GET /api/v1/customer/affiliate/commissions`
- `GET /api/v1/customer/affiliate/payouts`
- `POST /api/v1/customer/affiliate/payouts`

Admin affiliate account/link create/update behavior was changed without adding new admin routes:

- `POST/PATCH /api/v1/admin/tenant/affiliates`
- `POST/PATCH /api/v1/admin/tenant/affiliate-links`

## Permissions / Tenant Checks Enforced

- Customer affiliate endpoints require `customer.auth`.
- Customer tenant context is resolved from storefront `Host` and must match the authenticated customer session tenant.
- Referral resolution only queries the current tenant.
- Inactive/cross-tenant referral codes return not found.
- Admin affiliate endpoints continue to use tenant admin auth/RBAC permissions from `TenantGrowthController`.
- Customer affiliate creation does not create admin users, roles, scopes, or BO access.

## Validation

Docker/test DB commands run:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AffiliateTest
```

Result: PASS, 3 tests / 68 assertions. Note: this filter also matched `CustomerAffiliateTest` by class-name suffix.

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CustomerAffiliateTest
```

Result: PASS, 2 tests / 38 assertions.

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter='TenantWalletTest|CustomerTopupTest|SoldSyncTest'
```

Result: PASS, 3 tests / 51 assertions.

```sh
git diff --check
```

Result: PASS.

## Known Risks

- Customer and BO apps still need their own agents to consume the canonical `/?ref={CODE}` contract and new referral apply endpoint.
- Existing unrelated dirty files remain in the shared worktree and were not staged.
- `apps/platform-api/.phpunit.result.cache` changed from test execution and was intentionally not staged.
- No runtime DB cleanup or browser QA was performed because this backend task required Docker PHPUnit validation against `newpaotang_test`.

## Questions For Coordinator

- Confirm whether Customer Develop should submit stored `ref` after login/register and before checkout via `POST /customer/affiliate/referrals/apply`.
- Confirm whether BO Develop should display `canonical_url`/`url` from affiliate links and stop showing legacy `/a/{CODE}` as the primary referral link.

## Next Agent

Orchestrator
