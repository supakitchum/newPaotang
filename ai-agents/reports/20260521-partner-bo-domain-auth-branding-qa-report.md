# partner-bo-domain-auth-branding QA Report

## Agent

QA Tester

## Task

Validate Backend and Back Office delivery for `partner-bo-domain-auth-branding`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
git rev-parse HEAD: 17b80fab0871ca161d6d89d80014f46bd9f27a2b
git rev-parse origin/develop: 17b80fab0871ca161d6d89d80014f46bd9f27a2b
git status --short --branch: ## develop...origin/develop
known dirty file before QA and still unstaged: apps/platform-api/.phpunit.result.cache
```

## Commits Under Test

```text
Backend implementation: 643e5ee3fc47c047bd90b1090396f0a34bac6831
Backend handoff: ee17699bf957171431bbe9211a6523d2330a6eda
Back Office implementation: fcb4be74b5aae8fa31bb551671618eb92f30e68d
Back Office handoff: f4ad35fb73e9e84847b03d02a314cfccd1e2d1f4
QA HEAD: 17b80fab0871ca161d6d89d80014f46bd9f27a2b
```

## Test Data / Host Selection

Runtime DB did not have `partner-a.test`. Per QA task instruction, QA used an actual seeded active storefront host from `partner_tenant_domains`:

```text
storefront host: alpha.newpaotang.test
partner BO host: bo.alpha.newpaotang.test
tenant_id: ten_demo_alpha
partner_id: par_demo_alpha
tenant admin: owner@alpha.newpaotang.test
cross-tenant admin used for rejection check: owner@beta.newpaotang.test
central admin: admin@newpaotang.test
```

Seeded `partner_tenant_themes.logo_url` for `ten_demo_alpha` is `null`; browser evidence verifies partner display name and fallback logo element, while the backend feature test covers non-null tenant theme logo propagation for `bo.partner-a.test`.

## Commands And Results

```text
git diff --check
Result: PASS

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
Result: PASS
Evidence: migration 2026_05_21_000001_guard_partner_tenants_one_tenant_per_partner ran on newpaotang_test; seed completed.

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter='AdminAuthTest|AdminMenuTest|BootstrapSeederTest' --env=testing
Result: PASS
Evidence: 23 passed, 241 assertions.

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter='PartnerProvisioningTest' --env=testing
Result: PASS
Evidence: 7 passed, 172 assertions.

docker compose -p newpaotang run --rm back-office npm run lint
Result: PASS

docker compose -p newpaotang run --rm back-office npm run test
Result: PASS

docker compose -p newpaotang run --rm back-office npm run build
Result: PASS
Note: Nuxt emitted the existing DEP0180 deprecation warning, build exited 0.
```

## API Host-Header Evidence

All API checks used Docker runtime services and did not print tokens.

| Check | Result |
| --- | --- |
| `GET /api/v1/public/admin-site-config` with `Host: bo.alpha.newpaotang.test` | `200`, `mode=partner`, `storefront_host=alpha.newpaotang.test`, `bo_host=bo.alpha.newpaotang.test`, `display=Demo Alpha Lottery` |
| `GET /api/v1/public/site-config` with `Host: alpha.newpaotang.test` | `200`, `tenant=ten_demo_alpha`, `partner=par_demo_alpha`, `host=alpha.newpaotang.test` |
| BO same-origin proxy `http://bo.alpha.newpaotang.test:3100/api/v1/public/admin-site-config` with `--resolve` | `200`, reached platform-api and resolved partner mode |
| Tenant admin login on partner BO host without `tenant_id` | `200`, `scopes=1`, `scope=tenant`, `tenant_id=ten_demo_alpha` |
| Same tenant admin login with `scope=central` on partner BO host | `401`, `authentication_required` |
| Other tenant admin login on partner BO host | `401`, `authentication_required` |
| `GET /auth/admin/me` on partner BO host with tenant token | `200`, `active_scope=tenant`, `active_tenant_id=ten_demo_alpha`, one scope only |
| Tenant menu on partner BO host without `X-Tenant-Id` | `403`, `permission_denied` |
| Tenant menu on partner BO host with wrong `X-Tenant-Id=ten_demo_beta` | `403`, `permission_denied` |
| Tenant menu on partner BO host with matching `X-Tenant-Id=ten_demo_alpha` | `200`, `menu_count=32` |
| Central host login with central admin | `200`, `scope=central` |
| Central route on partner BO host with central token | `403`, `permission_denied` |
| Central route on central host with central token | `200`, `menu_count=25` |

## Local Proxy / Customer Limitation

`bo.alpha.newpaotang.test -> back-office -> /api/v1/* -> platform-api` is validated by same-origin proxy evidence above.

Direct customer browser/proxy evidence for `alpha.newpaotang.test:3000` is blocked by the local customer Vite `server.allowedHosts` policy:

```text
curl --resolve alpha.newpaotang.test:3000:127.0.0.1 http://alpha.newpaotang.test:3000/
Result: 403
Message: Blocked request. This host ("alpha.newpaotang.test") is not allowed.
```

QA used platform-api Host-header site-config evidence to prove storefront tenant resolution instead of changing customer implementation or local runtime host policy.

## Browser / Login Evidence

Screenshots:

```text
ai-agents/reports/artifacts/20260521-partner-bo-domain-auth-branding/partner-login.png
ai-agents/reports/artifacts/20260521-partner-bo-domain-auth-branding/partner-tenant-dashboard.png
ai-agents/reports/artifacts/20260521-partner-bo-domain-auth-branding/central-login.png
ai-agents/reports/artifacts/20260521-partner-bo-domain-auth-branding/central-dashboard.png
```

Browser checks:

| Check | Result |
| --- | --- |
| `http://bo.alpha.newpaotang.test:3100/login` partner branding | Shows `Demo Alpha Lottery sign in`; logo element alt is `Demo Alpha Lottery`; image source falls back to Meno logo because seeded `logo_url` is null |
| Partner login controls | `data-central-login-scope-controls=false`; visible labels only `Email`, `Password`; no Scope, Tenant ID, or Partner ID field |
| Partner tenant-only marker | Shows `Tenant admin access for Demo Alpha Lottery` |
| Partner login success | Tenant admin lands on `http://bo.alpha.newpaotang.test:3100/admin/tenant/dashboard` with `Tenant Dashboard` |
| Partner deep link to `/admin/central/dashboard` | Redirects/blocks to `http://bo.alpha.newpaotang.test:3100/admin/tenant/dashboard`; central dashboard not rendered |
| Central login page | `http://localhost:3100/login` shows Scope selector and Tenant ID field; no partner tenant-only marker |
| Central login success | Central admin lands on `http://localhost:3100/admin/central/dashboard` with `Central Dashboard` |

## Test DB Isolation Evidence

Destructive DB setup was run only against:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

No `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` command was run against runtime DB `newpaotang`.

Runtime DB migration status was inspected only. Current runtime DB still has pending migrations:

```text
2026_05_20_000003_add_virtual_ticket_image_snapshot_and_canonical_branding_assets: Pending
2026_05_21_000001_guard_partner_tenants_one_tenant_per_partner: Pending
```

QA did not run runtime migrations because the QA task only authorized runtime seed/smoke restore, not schema migration on the main runtime DB. The current task migration and 1 Partner = 1 Tenant guard were validated on `newpaotang_test`.

## Runtime Restore / Login Smoke

```text
worktree path: /Users/supakit/WorkSpace/www/newPaotang
HEAD: 17b80fab0871ca161d6d89d80014f46bd9f27a2b
test database used for destructive commands: newpaotang_test
destructive DB commands against runtime newpaotang: none
```

Runtime restore/check commands:

```text
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
Result: PASS
Note: idempotent runtime seed completed after DB-touching tests; this was not used as destructive restore.

docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
Result: PASS
Output includes: app ok, database ok, cache ok, queue redis, monitoring-defaults ok, base-lottery-numbers ok, seeded-logins ok.

central admin login API status
Result: 200, user=admin@newpaotang.test, first_scope=central.

docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
Result: PASS

curl --max-time 5 -i -s http://localhost:3100/login
Result: initial cold-start 503 "Starting Nuxt...", retry PASS with HTTP 200 OK.

curl --max-time 5 -i -s http://localhost:3100/admin/login
Result: HTTP 302 Found, Location: /login.
```

## Defects / Risks For Coordinator

No implementation defect was found in Backend or BO behavior under the required Docker validation and host-header/browser checks.

Coordinator-visible runtime/local caveats:

```text
1. Runtime DB has pending migrations, including the current 2026_05_21 one-tenant-per-partner guard. QA validated it on newpaotang_test only.
2. Local customer service blocks alpha.newpaotang.test by Vite allowedHosts, so customer domain browser/proxy evidence is limited to platform-api Host-header site-config.
3. Seeded runtime tenant theme logo_url is null, so browser runtime shows partner display name plus fallback Meno logo. Backend feature test validates non-null theme logo propagation.
```

## Unrelated Dirty Files Left Unstaged

```text
apps/platform-api/.phpunit.result.cache
```

QA-created report/artifacts are intentionally unstaged per QA no-stage/no-commit rule.

## Recommendation

PASS recommendation for `partner-bo-domain-auth-branding`, with the local-runtime caveats above for Coordinator review.

## Next Agent

Coordinator
