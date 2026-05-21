# customer-tenant-domain-api-integration Customer Handoff

## Agent

Customer Develop

## Task

Implement customer storefront tenant-domain API integration:

```text
partner-a.test -> customer storefront
partner-a.test/api/v1/* -> platform-api /api/v1/* with Host preserved as partner-a.test
Customer must not depend on api.* or hard-coded tenant IDs.
Seeded local hosts alpha/beta/gamma must not be blocked by local customer dev host policy.
```

## Worktree / Branch / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
start HEAD: 53c70cdfe5034b64f3913c02d88ac7939722d992
start origin/develop: 53c70cdfe5034b64f3913c02d88ac7939722d992
implementation commit: 2b36f1b13ed914a62fcff665cfd89fdba064e804
status after implementation commit: ## develop...origin/develop [ahead 1] plus unrelated apps/platform-api/.phpunit.result.cache
```

Start gate was completed before edits:

```text
pwd: /Users/supakit/WorkSpace/www/newPaotang
git top-level: /Users/supakit/WorkSpace/www/newPaotang
git fetch origin: completed
git merge --ff-only origin/develop: Already up to date.
HEAD equaled origin/develop at start.
```

## Files Changed

```text
apps/customer/.env.example
apps/customer/composables/useAuth.ts
apps/customer/composables/useSiteConfig.ts
apps/customer/nuxt.config.ts
apps/customer/package.json
apps/customer/pages/index.vue
apps/customer/plugins/axios.ts
apps/customer/scripts/check-tenant-domain-integration.mjs
apps/customer/server/routes/api/v1/[...path].ts
apps/customer/server/routes/robots.txt.ts
apps/customer/server/routes/sitemap.xml.ts
apps/customer/utils/tenantHost.ts
compose.yaml
```

No backend, back-office, OpenAPI, or shared docs were edited.

## What Changed

Customer API base and local dev:

```text
NUXT_PUBLIC_API_BASE_URL defaults to /api/v1.
NUXT_PLATFORM_API_INTERNAL_BASE_URL defaults to http://platform-api:8000/api/v1.
compose customer env now uses same-origin /api/v1 plus internal platform API base.
Vite allowedHosts includes partner-a.test, alpha.newpaotang.test, beta.newpaotang.test, gamma.newpaotang.test.
```

Same-origin customer proxy:

```text
Added apps/customer/server/routes/api/v1/[...path].ts.
Browser calls to /api/v1/* now terminate at the customer Nuxt server and proxy to platform-api /api/v1/*.
The proxy normalizes the incoming storefront Host and sends it as the upstream host header.
The proxy uses Node http/https request instead of fetch/$fetch because Node fetch strips/ignores Host in this runtime.
Vary: Host is set on proxied responses.
Selected request headers are forwarded: accept, accept-language, authorization, content-type, idempotency-key, x-request-id.
Selected response headers are copied back, including content-type, x-request-id, retry-after, and rate-limit headers.
```

SSR/customer API client:

```text
Browser axios stays on same-origin /api/v1.
SSR axios resolves relative public API base to platformApiInternalBaseUrl and sends the storefront Host to platform-api.
No api.* dependency or tenant ID fallback was introduced.
```

Tenant scoping:

```text
Added apps/customer/utils/tenantHost.ts for normalized host and state/cookie scope keys.
Auth cookies and auth useState keys are scoped by normalized tenant host.
Site-config state, loading/error state, and in-flight promise cache are scoped by normalized tenant host.
useSiteConfig no longer replaces the API base with siteConfig.api.base_url; the customer stays same-origin.
```

Branding/SEO/server routes:

```text
robots.txt and sitemap.xml now fetch site-config through the internal platform API base on SSR and preserve Host.
News asset URL base strips /api/v1 so relative upload URLs do not become /api/v1/upload/*.
```

Validation guard:

```text
Added apps/customer/scripts/check-tenant-domain-integration.mjs.
apps/customer package lint/test scripts run this structural guard.
The guard verifies same-origin /api/v1, internal base, allowed hosts, proxy Host preservation, SSR Host forwarding, host-scoped auth/site-config, and no site-config API-base override.
```

## API Base / Host Preservation

```text
Client browser base: /api/v1
Customer proxy target: http://platform-api:8000/api/v1
SSR axios base when public base is relative: http://platform-api:8000/api/v1
Host preservation: incoming storefront Host is normalized and sent upstream as host header.
```

Important implementation note:

```text
Testing inside the customer container showed Node fetch to platform-api with Host: alpha.newpaotang.test still returned tenant_not_found.
Switching the customer proxy to Node http/https request made platform-api resolve alpha/beta/gamma correctly through the customer /api/v1 proxy.
```

## Validation

All required customer validation passed after the final code changes:

```text
docker compose -p newpaotang run --rm customer npm run lint: PASS
docker compose -p newpaotang run --rm customer npm run test: PASS
docker compose -p newpaotang run --rm customer npm run build: PASS
git diff --check: PASS
```

Notes:

```text
Nuxt build emits the existing Node DEP0180 fs.Stats deprecation warning; build exits 0.
npm prints a major-version notice; not a validation failure.
```

## Local Smoke Evidence

Services were brought up with:

```text
docker compose -p newpaotang up -d postgres valkey platform-api customer
docker compose -p newpaotang restart customer
```

Smoke results:

```text
curl --resolve partner-a.test:3000:127.0.0.1 http://partner-a.test:3000/
=> HTTP/1.1 302 Found, location: /result
=> No "Blocked request. This host (...) is not allowed."

curl --resolve alpha.newpaotang.test:3000:127.0.0.1 http://alpha.newpaotang.test:3000/api/v1/public/site-config
=> 200, tenant_id ten_demo_alpha, host alpha.newpaotang.test

curl --resolve beta.newpaotang.test:3000:127.0.0.1 http://beta.newpaotang.test:3000/api/v1/public/site-config
=> 200, tenant_id ten_demo_beta, host beta.newpaotang.test

curl --resolve gamma.newpaotang.test:3000:127.0.0.1 http://gamma.newpaotang.test:3000/api/v1/public/site-config
=> 200, tenant_id ten_demo_gamma, host gamma.newpaotang.test
```

Runtime data note:

```text
partner-a.test is allowed by customer dev host policy and reaches the customer storefront.
The current runtime DB does not contain partner-a.test in partner_tenant_domains, so /api/v1/public/site-config for partner-a.test returns platform-api tenant_not_found.
DB does contain active alpha/beta/gamma tenant domains, and all three resolve correctly through the customer same-origin proxy.
```

Operational smoke note:

```text
Running nuxt build while the dev server is mounted to the same .nuxt volume caused one transient Nitro dev-server EADDRINUSE worker socket error and hanging curl attempts.
Restarting the customer service cleared it, and the final smoke evidence above passed.
```

## API Gaps / Risks

```text
No customer-side API contract gap remains for same-origin /api/v1 or Host preservation.
If QA expects partner-a.test site-config to return 200 in this local runtime, backend seed/runtime data must add partner-a.test as an active domain. Customer lane did not edit backend data or seeders.
Host-scoped cookie names may require users with old unscoped local auth cookies to log in again; this is intentional for tenant isolation.
```

## Unrelated Dirty Files

```text
apps/platform-api/.phpunit.result.cache
```

This was dirty before Customer Develop edits and was not staged or modified by this task.

## Next Agent

QA Tester
