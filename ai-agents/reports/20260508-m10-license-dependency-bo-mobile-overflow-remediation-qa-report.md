# QA Report

## Task

`20260508-m10-license-dependency-bo-mobile-overflow-remediation`

Date: 2026-05-08  
Agent: QA Tester  
Verdict: PASS - Coordinator review required

## Scope Tested

Focused QA for the BO mobile overflow remediation:

- Mobile 390x844 authenticated tenant hard refresh to `/admin/tenant/maintenance`.
- Mobile sidebar closed/open/reclosed behavior.
- Desktop authenticated hard-refresh regressions for central Partners and tenant Agents/Maintenance.
- SSR protected-route no-marker, exact-marker, and invalid-marker regression checks.
- Docker-only BO lint/test/build and focused backend guardrails.
- Static review of mobile shell/sidebar/content guardrails.

Artifacts:

`ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa/`

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
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose up -d --force-recreate back-office
```

Note: an initial parallel backend test attempt produced expected database-race false failures because all three `RefreshDatabase` suites targeted the same Docker database concurrently. QA reset the DB and reran the same suites sequentially; the sequential results passed and are the authoritative evidence.

## Test Results

Docker guardrails:

- `back-office npm run lint`: PASS
- `back-office npm run test`: PASS
- `back-office npm run build`: PASS, with existing non-blocking `fs.Stats` and unresolved `media-33.jpg` warnings.
- `AdminAuthTest`: PASS, 9 tests / 78 assertions
- `AdminMenuTest`: PASS, 5 tests / 26 assertions
- `MaintenanceTest`: PASS, 2 tests / 52 assertions
- Maintenance bypass route list: PASS, 3 routes shown

SSR/no-browser regression:

- `/admin/central/partners` no marker: 302 to `/login?redirect=/admin/central/partners`
- `/admin/central/partners` exact marker: 200 restore shell only, no login or Partners content
- `/admin/tenant/maintenance` no marker: 302 to `/login?redirect=/admin/tenant/maintenance`
- `/admin/tenant/maintenance` exact marker: 200 restore shell only, no login or Tenant Maintenance content
- `/admin/tenant/growth/agents` no marker: 302 to `/login?redirect=/admin/tenant/growth/agents`
- `/admin/tenant/growth/agents` exact marker: 200 restore shell only, no login or Agents content
- invalid marker on `/admin/tenant/maintenance`: 302 to login and clears `newpaotang_bo_session`

Browser regression:

- Central login and hard refresh `/admin/central/partners`: PASS, Partners rendered, not login or restore shell.
- Tenant login and hard refresh `/admin/tenant/maintenance`: PASS, Tenant Maintenance rendered, not login or restore shell.
- Tenant hard refresh `/admin/tenant/growth/agents`: PASS, Agents rendered, not login or restore shell.

Mobile primary check:

- 390x844 tenant hard refresh `/admin/tenant/maintenance`: PASS.
- Tenant Maintenance starts inside the viewport with no blank left overlay.
- Maintenance form is fully visible horizontally in the screenshot.
- Sidebar is closed by default, opens over the page with backdrop, and closes cleanly.
- Screenshot measurements:
  - current closed screenshot: `390x844`, non-white x-range `12-377`, right-edge non-white samples `0`
  - current reclosed screenshot: `390x844`, non-white x-range `12-377`, right-edge non-white samples `0`
  - prior failed screenshot had no center-left content samples; current screenshot has `1412`, confirming the form is no longer shifted off to the right.

Key artifacts:

- `browser-mobile-tenant-maintenance-closed-reload.png`
- `browser-mobile-tenant-maintenance-sidebar-open.png`
- `browser-mobile-tenant-maintenance-sidebar-reclosed.png`
- `mobile-screenshot-measurements.txt`
- `prior-vs-current-mobile-screenshot-measurements.txt`
- `browser-summary.json`
- `ssr-summary.txt`

## Findings

No blocking findings for this focused remediation.

The original P2 mobile overflow is fixed by QA evidence.

## Risks / Notes

- The Browser API available in this session did not expose page `evaluate()` or element bounding boxes, so QA could not directly record `window.innerWidth`, `documentElement.scrollWidth`, or `getBoundingClientRect()`. QA substituted fresh 390x844 screenshots, DOM snapshots, and PNG pixel-range measurements.
- Browser logs include Vue hydration warnings around header/sidebar classes and sidebar nodes during authenticated hard refresh. The protected pages still render correctly, and this QA task did not require hydration cleanup. Coordinator may choose whether to open a separate hardening item.
- Meno legal/license compliance, npm audit remediation/deferral, BO menu completion, staging, production, client delivery, external secret management, and final M10 approval remain out of scope.

## Recommendation

Accept the focused BO mobile overflow remediation for Coordinator review. The mobile acceptance check now passes, and the protected deep-link behavior remains intact.

QA does not have authority to route implementation work directly. Coordinator should decide the next workflow step.

## Next Agent

Coordinator
