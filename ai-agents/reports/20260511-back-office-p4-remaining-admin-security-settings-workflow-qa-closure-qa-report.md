# back-office-p4-remaining-admin-security-settings-workflow-qa-closure - QA Report

## Scope

- QA date: 2026-05-11
- QA owner: Codex QA Tester
- HEAD under test: `1934b54696b0d48b4837b9899a3031e217e6afa7`
- Primary BO implementation commit: `52e0f728594bdeda4ae0c6262c22c3cae8698a40`
- Accepted remediation commits in scope: `c38aa7cd6811f2c555eedbf166eeced368afd059`, `0da69e0e7a35427fe093fe2144be750c0762d162`
- Focus rows: `central:admin_users`, `central:roles_permissions`, `central:system_settings`, `tenant:admin_users`, `tenant:roles_permissions`, `tenant:support_access_logs`, `tenant:settings`

## Result

Focused QA is ready for Coordinator review. All seven scoped rows passed with Docker validation, API write evidence, real authenticated BO menu evidence, tenant header evidence, reason-guard evidence, and mobile sanity evidence.

| Row | Status | Evidence |
| --- | --- | --- |
| `central:admin_users` | PASS | Real central menu list/detail/action modals rendered; API create/update/disable persisted and disabled DB state was verified. |
| `central:roles_permissions` | PASS | Real central menu typed role modals rendered; API create/update/archive persisted explicit permission-code arrays. |
| `central:system_settings` | PASS | Real central menu typed known-key fields rendered with no JSON-only editor; API save/restore persisted `release_gate_note`. |
| `tenant:admin_users` | PASS | Real tenant menu list/detail/action modals rendered; API create/update/disable persisted with `X-Tenant-Id: ten_demo_alpha`. |
| `tenant:roles_permissions` | PASS | Real tenant menu typed role modals rendered; API create/update/archive persisted tenant permission-code arrays with tenant header. |
| `tenant:support_access_logs` | PASS | Real tenant support menu create/detail/action workflow passed; UI reason guard covered all sensitive actions; API approve/impersonate/elevated/end/revoke persisted and one-time token was redacted. |
| `tenant:settings` | PASS | Real tenant settings menu typed settings/theme/domain controls rendered; API settings/theme save/restore and domain create/detail/update/verify/delete cleanup passed with tenant header. |

## Validation

All application commands were run through Docker:

- `git diff --check` -> pass
- `docker compose up -d postgres valkey platform-api back-office` -> pass
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` -> pass
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` -> 7 passed, 95 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` -> 5 passed, 26 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` -> 9 passed, 78 assertions
- `docker compose run --rm platform-api php artisan test --filter=Support` -> 5 passed, 146 assertions
- `docker compose exec -T platform-api php artisan route:list` -> pass
- `docker compose run --rm back-office npm run lint` -> pass
- `docker compose run --rm back-office npm run test` -> pass
- `docker compose run --rm back-office npm run build` -> pass
- `docker compose up -d --force-recreate back-office` -> pass
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` before QA evidence -> pass
- Docker Playwright browser workflow check -> pass

Observed carry-forward warnings only: Node `DEP0180`, unresolved `media-33.jpg`, known Vue hydration warnings, and one initial browser `Failed to fetch` during session reset. Focused workflows still loaded and passed.

## API Evidence

Artifacts:

- `ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/api/focused-api-evidence.json`
- `ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/api/focused-api-evidence.php`

API summary:

- Central admin users: list/detail/create/update/disable passed. Created fixture used a generated local password that was not written to artifacts; response evidence shows no `password` or `password_hash`. Disabled state was verified in DB because disabled users return 404 by detail API.
- Central roles: create/update/archive passed; permissions changed from `dashboard.view` to `audit.view` + `dashboard.view`.
- Central system settings: `release_gate_note` save returned 200 and restore returned 200.
- Tenant admin users: list/detail/create/update/disable passed with `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha`; disabled DB state verified.
- Tenant roles: create/update/archive passed with tenant header; permissions changed from `dashboard.view` to `dashboard.view` + `order.view`.
- Tenant settings/theme/domain: settings save/restore, theme save/restore, domain create/detail/update/verify/delete all passed.
- Tenant support access: safe local customer fixture created; support request create/detail/approve/impersonate/elevated-action/end-session passed. Separate revoke fixture passed. One-time impersonation token was returned only as a boolean redacted fact, and detail reload did not expose it.

## Browser Evidence

Artifacts:

- `ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/browser/browser-summary.json`
- Screenshots in `ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/browser/`

Browser summary:

- Central and tenant routes were opened from real BO menu links where present; every scoped route had `menu_link_count: 1`.
- Hard refresh on scoped authenticated routes did not render login.
- Admin-user create/update/disable modals rendered typed identity/status/password or invitation/role fields; destructive confirmations showed record context and were disabled until reason.
- Role create/update/archive modals rendered typed name/code/status/permission-code fields; destructive confirmations showed role/scope or tenant context and were disabled until reason.
- Central system settings rendered known typed fields and no JSON editor.
- Tenant settings rendered typed site/SEO/maintenance/API/theme fields, plus domain add/detail/verify/delete context and reason guards.
- Tenant support access create modal exposed contract support scopes, target types, ticket, and reason; create returned 201, reasonless sensitive actions were disabled, reason enabled them, and approve returned 200.
- Captured browser requests proved central `x-admin-scope: central` and tenant `x-admin-scope: tenant` with `x-tenant-id: ten_demo_alpha`.
- Mobile sanity passed at 390x844 for `/admin/central/admin-users` and `/admin/tenant/settings` with no login render and body width equal to viewport width.

## Findings

No defects found in the focused closure scope.

## Notes

- Tenant browser automation used an API-authenticated BO session fallback after the UI tenant login redirect timed out in the Playwright container. The tested tenant pages and writes still used real BO routes, real menu links, and captured tenant-scoped API headers.
- Disabled admin-user detail endpoints return 404 after disable; QA verified persistence through DB status in local Docker evidence.
- No implementation files, docs, Board, decisions, tasks, or handoffs were edited by QA.

## Redaction

Artifacts were checked for literal seeded passwords, bearer token values, access/refresh token values, and support impersonation token strings. Evidence files do not contain real passwords, bearer tokens, private keys, or one-time support tokens. Browser/API scripts use environment variables or in-memory generated fixture secrets only.

## Dirty Workspace

Unrelated existing dirty files observed and left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA-created files are limited to this report and `ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/`.

## Next Agent

Route back to Coordinator for row promotion decision. QA does not mark rows complete directly.
