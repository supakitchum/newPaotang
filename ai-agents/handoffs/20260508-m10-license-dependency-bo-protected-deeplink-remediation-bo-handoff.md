# M10 License Dependency BO Protected Deeplink Remediation BO Handoff

Date: 2026-05-08
Agent: BO Develop
Next Agent: Orchestrator

## Task

Executed focused BO remediation:

```text
ai-agents/tasks/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo.md
```

## What Was Done

Fixed the P1 hard-refresh/deep-link defect for protected BO admin routes.

Implementation now follows the required marker bridge:

```text
SSR protected route with no exact marker -> /login?redirect=<target>
SSR protected route with exact newpaotang_bo_session=1 marker -> non-sensitive restore shell only
Client route guard -> restore sessionStorage, validate auth, align scope/tenant, then load protected content
Stale client marker with no sessionStorage -> client restore clears marker and redirects to login
Wrong scope or missing tenant -> /admin/403
```

Key implementation notes:

- `apps/back-office/middleware/admin.global.ts` now reads `newpaotang_bo_session` with raw cookie decode so the exact wire value `1` is not coerced by Nuxt cookie decoding.
- The marker is not treated as authentication. It only permits SSR to return the restore shell; client `sessionStorage` remains the auth source.
- Invalid marker values are cleared server-side and redirected to login.
- Client middleware still runs `session.restore()` and `session.alignScopeForPath(to.path)` before protected content can render.
- `apps/back-office/components/AdminProtectedContent.vue` keeps the protected slot hidden while rendering the restore card, and marks Nuxt dev page usage without rendering the route slot, preventing the previous dev-only `NuxtPage` warning without leaking route content.
- `apps/back-office/scripts/check.mjs` now statically checks the exact-marker bridge, raw cookie decode, marker-not-auth behavior, protected shell guardrails, and tenant maintenance client-only loading.
- `docs/back-office-admin-foundation.md` documents the updated SSR marker/session restore contract.

## Files Changed

```text
apps/back-office/middleware/admin.global.ts
apps/back-office/components/AdminProtectedContent.vue
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

## Validation

Docker validation:

```text
docker compose run --rm back-office npm run lint
PASS

docker compose run --rm back-office npm test
PASS

docker compose run --rm back-office npm run build
PASS
```

Build completed with existing non-blocking warnings:

```text
[DEP0180] fs.Stats constructor is deprecated
/admin-template/assets/images/media/media-33.jpg ... didn't resolve at build time, it will remain unchanged to be resolved at runtime
```

Runtime SSR evidence after `docker compose restart back-office`:

```text
no_marker /admin/central/partners status=302 redirect=http://localhost:3100/login?redirect=/admin/central/partners
marker /admin/central/partners status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

no_marker /admin/tenant/maintenance status=302 redirect=http://localhost:3100/login?redirect=/admin/tenant/maintenance
marker /admin/tenant/maintenance status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

no_marker /admin/tenant/growth/agents status=302 redirect=http://localhost:3100/login?redirect=/admin/tenant/growth/agents
marker /admin/tenant/growth/agents status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

bad_marker /admin/tenant/maintenance HTTP/1.1 302 Found
set-cookie: newpaotang_bo_session=; Max-Age=0; Path=/
location: /login?redirect=/admin/tenant/maintenance
```

Browser automation note:

```text
Browser plugin/tooling was not exposed by tool_search in this session.
node_repl Playwright import was also unavailable: Module not found: playwright.
```

Because of that, BO validated the SSR marker/no-marker behavior with curl and static client guardrails, but did not capture a real browser sessionStorage hard-refresh screenshot. QA should run the same authenticated browser cases from the failed report.

## Acceptance Mapping

Covered:

- no marker on SSR protected route redirects to login with target redirect.
- exact `newpaotang_bo_session=1` marker returns only restore shell and no route protected text.
- invalid marker is cleared and redirected.
- marker remains non-auth; client `sessionStorage` is still required before protected slot/API loading.
- wrong-scope/missing-tenant path remains guarded by client `alignScopeForPath`.
- same-scope login redirect safety remains covered by existing static check.

Needs QA browser confirmation:

- valid central authenticated hard refresh to `/admin/central/partners`.
- valid tenant authenticated hard refresh to `/admin/tenant/maintenance`.
- valid tenant authenticated hard refresh to `/admin/tenant/growth/agents`.
- mobile hard refresh for `/admin/tenant/maintenance`.
- stale exact marker in a JS-capable browser clears marker and lands on login without loop or protected content leak.

## Known Risks

Meno original legal agreement is still absent and remains a release/client-delivery blocker.

`npm audit` vulnerability decisions remain outside this focused remediation.

The workspace is broadly dirty/untracked from multi-agent work. This handoff only claims the files listed above.

## Next Required Step

Orchestrator should create a focused QA task for the protected deep-link remediation and attach the runtime evidence above.

## Next Agent

Orchestrator
