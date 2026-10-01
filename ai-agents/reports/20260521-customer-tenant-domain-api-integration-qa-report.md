# customer-tenant-domain-api-integration QA Report

## Agent

QA Tester

## Task

Validate Customer Develop delivery for `customer-tenant-domain-api-integration`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
git rev-parse HEAD: 1d354e64ad5d4dddcd4dff63b5898091a6a994b8
git rev-parse origin/develop: 1d354e64ad5d4dddcd4dff63b5898091a6a994b8
git status --short --branch: ## develop...origin/develop
known unrelated dirty file: apps/platform-api/.phpunit.result.cache
```

## Commits Under Test

```text
Customer implementation: 2b36f1b13ed914a62fcff665cfd89fdba064e804
Customer handoff: 172c2985810c6fe799a66d63651f079b7e668353
QA HEAD: 1d354e64ad5d4dddcd4dff63b5898091a6a994b8
```

## Scope Tested

```text
apps/customer tenant-domain allowlist
same-origin /api/v1 proxy to platform-api
Host preservation through customer Nuxt proxy
site-config SSR/customer rendering per host
public stores/stock search through storefront hosts
host-scoped auth/session and site-config source evidence
runtime restore/smoke without wiping runtime DB
```

Out of scope per decision: backend implementation changes, back-office changes, `api.*` support, runtime DB cleanup/data creation.

## Commands Run

```text
pwd && git rev-parse --show-toplevel && git fetch origin && git status --short --branch && git merge --ff-only origin/develop && git rev-parse HEAD && git rev-parse origin/develop
Result: PASS; canonical worktree and HEAD matched origin/develop.

git diff --check
Result: PASS

docker compose -p newpaotang run --rm customer npm run lint
Result: PASS

docker compose -p newpaotang run --rm customer npm run test
Result: PASS

docker compose -p newpaotang run --rm customer npm run build
Result: PASS
Note: Nuxt emitted the known DEP0180 fs.Stats deprecation warning; npm printed a major-version notice; build exited 0.

docker compose -p newpaotang restart customer
Result: PASS; run after Nuxt build before local domain smoke.
```

`npm run lint` and `npm run test` both ran `scripts/check-tenant-domain-integration.mjs`, which passed checks for:

```text
public API base defaults to /api/v1
internal platform API base is configured
local tenant storefront hosts are allowlisted
same-origin /api/v1 proxy route exists
proxy targets platform API internal base
proxy preserves tenant Host header
proxy uses Node HTTP client so Host is not stripped by fetch
axios forwards storefront Host on SSR
auth cookies and useState keys are host-scoped
site-config state and promise cache are host-scoped
site-config no longer replaces API base with site-config api.base_url
```

## Local Domain / Site-Config Evidence

All requests used `curl --resolve <host>:3000:127.0.0.1` against the Docker customer service.

| Check | Result |
| --- | --- |
| `http://alpha.newpaotang.test:3000/` | `302 Location: /result`; no Vite/Nuxt blocked-host response |
| `http://beta.newpaotang.test:3000/` | `302 Location: /result`; no Vite/Nuxt blocked-host response |
| `http://gamma.newpaotang.test:3000/` | `302 Location: /result`; no Vite/Nuxt blocked-host response |
| `http://partner-a.test:3000/` | `302 Location: /result`; allowed by customer host policy, but runtime DB lacks this tenant domain |
| `alpha /api/v1/public/site-config` | `200`, `Vary: Host`, `tenant_id=ten_demo_alpha`, `partner_id=par_demo_alpha`, `domain.host=alpha.newpaotang.test`, `site_name=Alpha Lucky Shop` |
| `beta /api/v1/public/site-config` | `200`, `Vary: Host`, `tenant_id=ten_demo_beta`, `partner_id=par_demo_beta`, `domain.host=beta.newpaotang.test`, `site_name=Beta Reward House` |
| `gamma /api/v1/public/site-config` | `200`, `Vary: Host`, `tenant_id=ten_demo_gamma`, `partner_id=par_demo_gamma`, `domain.host=gamma.newpaotang.test`, `site_name=Gamma Prize Market` |
| `partner-a /api/v1/public/site-config` | `404 tenant_not_found`; expected local runtime data limitation from handoff |

## Customer Rendering Evidence

`/result` rendered tenant-specific SSR metadata and state per host:

| Host | Evidence |
| --- | --- |
| `alpha.newpaotang.test` | HTTP `200`, `<title>Alpha Lucky Shop</title>`, description `Demo Alpha Lottery demo tenant for local development.`, Nuxt state keys include `auth_token_state_alpha_newpaotang_test` and `site_config_alpha_newpaotang_test` |
| `beta.newpaotang.test` | HTTP `200`, `<title>Beta Reward House</title>`, description `Demo Beta Rewards demo tenant for local development.`, Nuxt state keys include `auth_token_state_beta_newpaotang_test` and `site_config_beta_newpaotang_test` |

The in-app browser could not resolve `.test` DNS without the curl `--resolve` override, so browser screenshot evidence was not used. Curl/SSR evidence above proves the local customer service accepts these hosts and renders different tenant identity.

## Public Customer API Tenant-Resolution Evidence

Runtime has one game row:

```text
game_id: gam_01KS29G2SJBX41ZZ51YKRVKB0B
status: open
```

Same-origin public calls through customer proxy:

| Check | Result |
| --- | --- |
| `alpha /api/v1/public/stores?limit=2` | `200`, `Vary: Host`, `{"data":[],"meta":{"next_cursor":null,"has_more":false}}` |
| `beta /api/v1/public/stores?limit=2` | `200`, `Vary: Host`, `{"data":[],"meta":{"next_cursor":null,"has_more":false}}` |
| `alpha /api/v1/public/stock/search?game_id=...&mode=random&limit=2` | `200`, `Vary: Host`, empty data/meta response |
| `beta /api/v1/public/stock/search?game_id=...&mode=random&limit=2` | `200`, `Vary: Host`, empty data/meta response |
| `partner-a /api/v1/public/stores?limit=2` | `404 tenant_not_found` |
| `partner-a /api/v1/public/stock/search?game_id=...&mode=random&limit=2` | `404 tenant_not_found` |

This proves public customer APIs are routed same-origin through the customer app and platform-api still resolves tenant from storefront Host. Empty public data is a runtime fixture state, not a proxy failure.

## No `api.*` Dependency Evidence

Static/source evidence:

```text
apps/customer/.env.example: NUXT_PUBLIC_API_BASE_URL=/api/v1
compose.yaml customer env: NUXT_PUBLIC_API_BASE_URL=/api/v1
apps/customer/nuxt.config.ts: public apiBaseUrl defaults to /api/v1
apps/customer/server/routes/api/v1/[...path].ts: proxies /api/v1/* to platformApiInternalBaseUrl and sets headers.host from incoming storefront host
apps/customer/plugins/axios.ts: SSR relative public API base resolves to platformApiInternalBaseUrl and forwards Host
```

`rg` found no customer dependency on `api.*`; the only non-customer admin API base hit was `VITE_ADMIN_API_BASE` under the back-office service env in `compose.yaml`, which is outside this customer scope.

## Auth / Session Isolation Evidence

No seeded runtime customer credentials are available:

```text
select count(*) from customers: 0
select count(*) from customer_auth_sessions: 0
```

QA did not register or create runtime customers because the task says to document the blocker if seeded runtime customer credentials are unavailable, and runtime DB writes were not needed for public/domain validation.

Source and SSR evidence for isolation:

```text
apps/customer/composables/useAuth.ts uses tenantHostScope(normalizeTenantHost(...)) for auth_token, auth_refresh_token, auth_user, line_redirect cookies and matching useState keys.
apps/customer/composables/useSiteConfig.ts scopes site_config, site_config_error, site_config_loading, and in-flight promise cache by host scope.
alpha SSR state uses auth_token_state_alpha_newpaotang_test and site_config_alpha_newpaotang_test.
beta SSR state uses auth_token_state_beta_newpaotang_test and site_config_beta_newpaotang_test.
apps/customer/plugins/axios.ts sends Authorization only from the current host-scoped useAuth state.
```

Authenticated private customer flow was not executed due missing seeded credentials. This is a test data limitation, not an observed implementation failure.

## Test DB Isolation Evidence

No destructive DB command was run for this QA task.

```text
Runtime DB newpaotang was not wiped.
No migrate:fresh, migrate:refresh, migrate:reset, or db:wipe was run.
No APP_ENV=testing destructive setup was needed for this customer-only validation.
```

Runtime DB writes were limited to the idempotent `db:seed --no-interaction` command required by the QA runtime restore checklist.

## Defects

No implementation defect found in the Customer delivery.

## Risks / Not Tested

```text
1. Authenticated customer session/token reuse across alpha/beta was not exercised end-to-end because runtime has no seeded customers or customer sessions. Source/SSR evidence supports host-scoped storage.
2. partner-a.test reaches the customer app but platform-api returns tenant_not_found because runtime DB lacks partner-a.test in partner_tenant_domains. QA used seeded alpha/beta/gamma as instructed.
3. /public/games/current returns 404 in current runtime because the seeded open game close_at is already in the past for 2026-05-21; public stock search was validated by supplying the existing game_id directly.
4. In-app Browser could not resolve .test hostnames without --resolve; curl --resolve evidence was used for host-specific local QA.
```

## Runtime Restore / Login Smoke

```text
worktree path: /Users/supakit/WorkSpace/www/newPaotang
HEAD: 1d354e64ad5d4dddcd4dff63b5898091a6a994b8
test database used for destructive commands: none
destructive DB commands against runtime newpaotang: none
```

Runtime commands:

```text
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
Result: PASS
Note: idempotent runtime seed completed after QA; this was not destructive restore.

docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
Result: PASS
Output includes: app ok, database ok, cache ok, queue redis, monitoring-defaults ok, base-lottery-numbers ok, seeded-logins ok.

central admin login API status
Result: 200, user=admin@newpaotang.test, first_scope=central.

curl --max-time 5 -i -s http://localhost:3000/
Result: HTTP 302 Found, Location: /result.

back-office /login status
Result: HTTP 200 OK.

back-office /admin/login redirect target
Result: HTTP 302 Found, Location: /login.

back-office restart/recreate after QA
Result: not applicable; this task built/restarted customer only.
```

## Unrelated Dirty Files Left Unstaged

```text
apps/platform-api/.phpunit.result.cache
```

QA-created report is intentionally unstaged per no-stage/no-commit rule.

## Recommendation

PASS recommendation for `customer-tenant-domain-api-integration`, with the authenticated-customer test-data limitation documented for Coordinator review.

## Next Agent

Coordinator
