# back-office-p4-administration-security-settings-workflows-remediation - QA Report

## Scope

- QA date: 2026-05-11
- QA owner: Codex QA Tester
- HEAD under test: `fda9dfc97ca11403a6bdbd755f46b9ceeb510a42`
- Implementation commit under test: `c38aa7cd6811f2c555eedbf166eeced368afd059`
- BO handoff commit under test: `f9d79d5b4afc327516cf1a17f4d23c567a298437`
- Focus rows: `central:menu_management`, `tenant:menu_management`, `tenant:maintenance`

## Result

Focused remediation is ready for Coordinator review with one scoped PASS and two HOLD rows caused by incomplete tenant browser evidence, not by a confirmed BO implementation defect.

| Row | Status | Evidence |
| --- | --- | --- |
| `central:menu_management` | PASS | Browser modal/cancel/confirm/restore passed; API reversible save passed. |
| `tenant:menu_management` | HOLD | API reversible save with `X-Tenant-Id: ten_demo_alpha` passed and shared component review shows the same confirmation path, but tenant browser modal evidence could not be completed before browser runtime blocker. |
| `tenant:maintenance` | HOLD | API ticketed create/list/revoke passed and UI source review shows reason/ticket guard, but browser missing-ticket evidence could not be completed before browser runtime blocker. |

## Validation

All required Docker validation commands completed successfully:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` -> 7 passed
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` -> 5 passed
- `docker compose run --rm platform-api php artisan test --filter=Maintenance` -> 4 passed
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`

Observed carry-forward build warnings only: Node `DEP0180` and unresolved `media-33.jpg`; no new validation blocker.

## API Evidence

Artifact: `ai-agents/reports/artifacts/20260511-back-office-p4-administration-security-settings-workflows-remediation-qa/api/focused-api-evidence.json`

- Central menu-management: login OK, GET OK, PUT changed `Dashboard` to `Dashboard [QA-CENTRAL]`, GET confirmed, PUT restored, GET confirmed restored.
- Tenant menu-management: login OK with `tenant_id=ten_demo_alpha`, GET OK, PUT changed `Dashboard` to `Dashboard [QA-TENANT]`, GET confirmed, PUT restored, GET confirmed restored.
- Tenant maintenance: GET OK, ticketed bypass POST returned 201, active list included created bypass, DELETE returned 204, revoked list included cleanup result.
- Known residual backend observation: direct API POST without `ticket_id` still returned 201 and was cleaned up. Per task note, this is recorded as frozen backend residual behavior, not a UI remediation failure.

## Browser Evidence

Central browser evidence completed:

- `browser/central-menu-confirm-modal.txt`
- `browser/central-menu-confirm-before-submit.png`
- `browser/central-menu-confirm-ready-to-save.png`
- `browser/central-menu-save-summary.json`

Central result:

- Real authenticated central BO menu link was present and used.
- Confirmation opened before any PUT.
- Modal showed `Central`, reason, menu item count, changed item count, changed item identity, and label field context.
- Cancel closed the modal with PUT count still `0`.
- Confirm save submitted PUT 200; restore submitted PUT 200; label returned to `Dashboard`.

Tenant browser evidence could not be completed:

- In-app Browser could not type into `input[type=email]` due runtime `setRangeText` limitation.
- Docker back-office container is Alpine; Playwright's downloaded Chromium required glibc and could not launch.
- A temporary Alpine Chromium attempt produced central evidence once, but later runs were too slow/unstable.
- Playwright official image pull exceeded the QA time budget and was aborted; log captured in `validation/browser-ui-check.txt`.

## Source Review

- `AdminMenuTreeEditor.vue` now gates `Save menu` behind `openConfirm`, computes pending clean items, displays scope/reason/menu counts/changed fields, and emits `save` only from `Confirm save`.
- `tenant/maintenance.vue` now separates bypass validation, disables create when reason or ticket is missing, shows explicit Ticket ID helper text, and blocks submit path before calling the API.
- No backend, customer frontend, OpenAPI, compose, GitHub workflow, Board, task, handoff, or decision files were edited.

## Findings

No confirmed BO implementation defect was found in the focused remediation.

Residual backend observation for Coordinator:

- Severity: P2, backend/frozen scope
- `POST /admin/tenant/maintenance/bypasses` still accepts a missing `ticket_id` and returns 201.
- Evidence: `api/focused-api-evidence.json` -> `missing_ticket_direct_api_observation.accepted_without_ticket: true`
- Recommendation: Coordinator decides whether to open a backend task after freeze, or keep as accepted residual while the UI remediation is reviewed.

## Redaction

Artifacts were checked for bearer tokens and seeded password values. API evidence records only statuses, scope, tenant id, safe ids, and labels; auth tokens are not written.

## Dirty Workspace

Unrelated existing dirty files observed and left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA-created files are limited to the approved remediation QA report and artifact directory.
