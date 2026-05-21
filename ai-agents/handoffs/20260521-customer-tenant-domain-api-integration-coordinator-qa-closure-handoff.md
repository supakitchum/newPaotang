# Customer Tenant Domain API Integration - Coordinator QA Closure Handoff

## Date

2026-05-21

## From

Coordinator

## To

User

## Worktree

```text
/Users/supakit/WorkSpace/www/newPaotang
```

## Task

```text
customer-tenant-domain-api-integration
```

## Coordinator Result

QA returned PASS for Customer Develop delivery.

Coordinator accepts QA PASS recommendation with documented test-data limitations.

## QA Report

```text
ai-agents/reports/20260521-customer-tenant-domain-api-integration-qa-report.md
```

## Scope Verified By QA

```text
Customer local dev no longer blocks alpha.newpaotang.test, beta.newpaotang.test, or gamma.newpaotang.test.
Customer same-origin /api/v1 proxy reaches platform-api and preserves storefront Host.
alpha.newpaotang.test resolves ten_demo_alpha through /api/v1/public/site-config.
beta.newpaotang.test resolves ten_demo_beta through /api/v1/public/site-config.
Customer SSR renders different tenant metadata/state keys per host.
Public stores and public stock search route through the storefront host and return Vary: Host.
Customer config defaults to /api/v1 and has no api.* dependency.
Auth/session/site-config storage is host-scoped in source and SSR state.
No backend or back-office implementation changes were part of the customer task.
```

## Commands Reported Passing

```text
git diff --check
docker compose -p newpaotang run --rm customer npm run lint
docker compose -p newpaotang run --rm customer npm run test
docker compose -p newpaotang run --rm customer npm run build
docker compose -p newpaotang restart customer
runtime db:seed --no-interaction
runtime platform:smoke
runtime central admin login API smoke
```

## Coordinator Caveats

```text
Authenticated customer end-to-end flow was not executed because runtime DB has no seeded customers or customer sessions.
partner-a.test is allowed by customer host policy but returns tenant_not_found at platform-api because runtime DB lacks that domain.
/public/games/current returns 404 in current runtime because the seeded open game close_at is already in the past for 2026-05-21.
In-app Browser could not resolve .test domains without curl --resolve; QA used curl/SSR evidence.
Known dirty file apps/platform-api/.phpunit.result.cache remains unstaged runtime/test noise.
```

## Decision

```text
Coordinator accepts QA PASS recommendation. No implementation defect is open for this task.
```

## Next Agent

```text
User
```
