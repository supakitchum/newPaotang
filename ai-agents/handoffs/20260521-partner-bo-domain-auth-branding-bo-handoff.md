# partner-bo-domain-auth-branding-bo Handoff

## Agent

BO Develop

## Task

Implement Back Office support for partner-specific BO domains where hosts that start with `bo.` use tenant-only partner mode, same-origin `/api/v1`, and branded login config from the backend public admin site config endpoint.

## Backend Handoff / Commit Consumed

```text
backend handoff: ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
backend implementation commit consumed: 643e5ee3fc47c047bd90b1090396f0a34bac6831
backend handoff commit present before BO work: ee17699bf957171431bbe9211a6523d2330a6eda
```

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
git rev-parse HEAD after BO implementation commit: fcb4be74b5aae8fa31bb551671618eb92f30e68d
git rev-parse origin/develop before BO handoff commit/push: ee17699bf957171431bbe9211a6523d2330a6eda
git status --short --branch after BO implementation commit:
## develop...origin/develop [ahead 1]
 M apps/platform-api/.phpunit.result.cache
```

Known unrelated dirty artifact remains unstaged:

```text
apps/platform-api/.phpunit.result.cache
```

BO implementation commit created:

```text
fcb4be74b5aae8fa31bb551671618eb92f30e68d partner-bo-domain-auth-branding-bo: add partner host login mode
```

## What Was Done

- Added partner BO host mode detection for hosts starting with `bo.`.
- Switched BO API base to same-origin `/api/v1` only in partner BO mode; central mode keeps `NUXT_PUBLIC_ADMIN_API_BASE` / current env behavior.
- Added admin site config fetch/cache for `GET /api/v1/public/admin-site-config`.
- Updated login page so partner BO mode:
  - renders partner display name/logo when config is available, with current logo/text fallback,
  - hides scope selector and Tenant ID input,
  - submits `scope=tenant` without `tenant_id`,
  - routes after login to `/admin/tenant/dashboard`,
  - blocks `/admin/central/*` safe redirects.
- Updated session and route middleware so partner BO sessions cannot align to central paths, and stale sessions without tenant scope are cleared with a login notice.
- Added local dev support for `.test` partner hosts and a same-origin `/api/v1` Vite proxy that preserves Host headers to `platform-api`.
- Added BO static checks for partner host detection, same-origin API base, config cache, hidden login fields, tenant-only login payload, central redirect blocking, central login compatibility, and brand render evidence.

## Files Changed

```text
apps/back-office/composables/useAdminHostMode.ts
apps/back-office/composables/useAdminSiteConfig.ts
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/middleware/admin.global.ts
apps/back-office/nuxt.config.ts
apps/back-office/pages/login.vue
apps/back-office/scripts/check.mjs
```

## Validation

```sh
docker compose -p newpaotang run --rm back-office npm run lint
```

Result:

```text
PASS
```

```sh
docker compose -p newpaotang run --rm back-office npm run test
```

Result:

```text
PASS
```

```sh
docker compose -p newpaotang run --rm back-office npm run build
```

Result:

```text
PASS
Note: Nuxt build emitted the existing Node DEP0180 fs.Stats deprecation warning, but exited 0.
```

```sh
git diff --check
```

Result:

```text
PASS - no whitespace errors
```

Additional local runtime smoke after restarting `back-office`:

```sh
curl --max-time 10 -s -H 'Host: bo.partner-a.test' http://localhost:3100/login
```

Result:

```text
PASS - HTTP 200, SSR rendered partner mode with data-partner-login-tenant-only and without Scope/Tenant ID controls.
```

```sh
curl --max-time 10 -s http://localhost:3100/login
```

Result:

```text
PASS - HTTP 200, central login still rendered Scope selector and Tenant ID input.
```

```sh
curl --max-time 10 -i -s -H 'Host: bo.partner-a.test' http://localhost:3100/api/v1/public/admin-site-config
```

Result:

```text
PASS WITH LOCAL DATA NOTE - request reached platform-api via same-origin BO dev proxy and preserved Host: bo.partner-a.test. The local runtime returned 404 tenant_not_found because this local database does not currently have partner-a.test seeded.
```

## Known Risks

- Full partner logo/name rendering depends on QA using a host that exists in `partner_tenant_domains.host`; the local smoke host `bo.partner-a.test` reached backend correctly but returned `tenant_not_found` with current local runtime data.
- The unrelated `apps/platform-api/.phpunit.result.cache` dirty artifact remains unstaged.

## Questions For Coordinator

None.

## Next Agent

Orchestrator
