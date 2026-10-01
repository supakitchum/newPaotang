# QA Report

## Task

`20260508-m10-license-dependency-bo-protected-deeplink-remediation`

Date: 2026-05-08  
Agent: QA Tester  
Verdict: FAIL - Coordinator review required

## Scope Tested

Focused QA for the BO protected deep-link remediation:

- SSR protected-route behavior for no marker, exact marker, and invalid marker.
- Authenticated browser hard refresh/deep-link behavior for central and tenant scopes.
- Mobile 390x844 tenant maintenance hard refresh.
- Docker-only BO lint/test/build and backend focused guardrails.
- Static review of marker/session restore guardrails.

Artifacts:

`ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/`

## Commands Run

All runtime/package/build/test commands were run through Docker.

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
docker compose up -d --force-recreate back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Browser checks used the in-app Browser against `http://127.0.0.1:3100` to avoid stale `localhost` browser state after database reseeding.

## Test Results

Docker guardrails:

- `back-office npm run lint`: PASS
- `back-office npm run test`: PASS
- `back-office npm run build`: PASS, with existing non-blocking warnings for `fs.Stats` deprecation and unresolved `media-33.jpg`.
- `AdminAuthTest`: PASS, 9 tests / 78 assertions
- `AdminMenuTest`: PASS, 5 tests / 26 assertions
- `MaintenanceTest`: PASS, 2 tests / 52 assertions
- Maintenance bypass route list: PASS, 3 routes shown

SSR/no-browser:

- `/admin/central/partners` no marker: 302 to `/login?redirect=/admin/central/partners`
- `/admin/central/partners` exact marker: 200 restore shell only, no login or protected Partners content
- `/admin/tenant/maintenance` no marker: 302 to `/login?redirect=/admin/tenant/maintenance`
- `/admin/tenant/maintenance` exact marker: 200 restore shell only, no login or Tenant Maintenance content
- `/admin/tenant/growth/agents` no marker: 302 to `/login?redirect=/admin/tenant/growth/agents`
- `/admin/tenant/growth/agents` exact marker: 200 restore shell only, no login or Agents content
- invalid marker on `/admin/tenant/maintenance`: 302 to login and clears `newpaotang_bo_session`

Authenticated browser:

- Central login reached `/admin/central/dashboard`.
- Central hard navigate + reload to `/admin/central/partners` rendered Partners, not login or restore shell.
- Tenant login reached `/admin/tenant/dashboard`.
- Tenant hard navigate + reload to `/admin/tenant/maintenance` rendered Tenant Maintenance, not login or restore shell.
- Tenant hard navigate + reload to `/admin/tenant/growth/agents` rendered Agents, not login or restore shell.
- Browser logs captured during these checks had no warnings/errors.

## Defects

### Finding 1 (apps/back-office/layouts/admin.vue:6, apps/back-office/assets/css/admin-foundation.css:90-110) [P2]

Mobile tenant maintenance still horizontally overflows after a valid hard refresh.

At viewport 390x844 with a valid tenant session, hard navigating/reloading `/admin/tenant/maintenance` renders the protected Tenant Maintenance page, but the visible viewport is shifted so the main form content starts off the right side of the screen. The left side of the screenshot is mostly blank sidebar/content offset space, while only the right portion of the maintenance form is visible. This violates the QA task requirement that mobile `/admin/tenant/maintenance` render without horizontal overflow.

Evidence:

- `browser-mobile-tenant-maintenance-reload.txt`: URL stayed on `/admin/tenant/maintenance`, `Tenant Maintenance` rendered, no login or restore shell.
- `browser-mobile-tenant-maintenance-reload.png`: 390x844 screenshot shows the content clipped/offset to the right.

Recommended owner for Coordinator decision: BO Develop.

## Risks / Not Tested

- Main P1 remediation is closed by QA evidence: authenticated central and tenant hard refresh/deep-link now render protected pages correctly.
- Stale-marker safety was verified with SSR/no-browser invalid-marker and exact-marker restore-shell checks. A JS-capable stale-marker browser case could not be isolated cleanly because the Browser tab API does not expose safe sessionStorage/cookie mutation, and new Browser tabs may inherit session state from the opener.
- Tenant request headers were reviewed statically through `useAdminApi`; the Browser API available in this session did not expose network request header capture.
- Meno legal/license compliance, npm audit remediation/deferral, staging, production, client delivery, external secret management, and final M10 approval remain out of scope.

## Recommendation

Do not approve this QA slice as clean because the required mobile no-overflow check fails. Route this report to Coordinator for decision.

QA does not have authority to route implementation work directly. Coordinator should decide whether this mobile overflow requires BO remediation before accepting the protected deep-link remediation.

## Next Agent

Coordinator
