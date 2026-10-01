# Back Office P2 Partner Billing Alerts Workflows QA Report

Date: 2026-05-10
Task: `back-office-p2-partner-billing-alerts-workflows`
QA: Open Chat QA Tester

## Result

PASS for non-destructive BO workflow QA. No new implementation defect found.

Six rows are completion candidates based on real central-menu browser evidence: `central:partners`, `central:partner_provisioning`, `central:partner_quotas`, `central:billing_plans`, `central:alert_policies`, and `central:alert_events`.

Two rows remain Coordinator permission/UX decision items: `central:partner_monitoring` and `central:partner_usage`. Their list/detail views pass, but BO intentionally exposes no update workflow because menus are view-only while backend PATCH endpoints require manage permissions.

## Head Under Test

- HEAD: `3c7d579` (`develop`, `origin/develop`)
- Implementation commit: `3c6750af9448cc72e56167231b750046ee6e6c19`
- BO handoff commit: `3c33e44b515a1ddb118061e1dcd7c828f4e256e0`

## Workspace Notes

Unrelated dirty/generated files left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`

## Validation

Passed with Docker-only application commands:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest`
- `docker compose exec -T platform-api php artisan route:list`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`
- Final `docker compose run --rm platform-api php artisan migrate:fresh --seed` before API/browser QA

Build warnings carried forward:

- Node `DEP0180` deprecation warning for `fs.Stats` constructor.
- Existing unresolved runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`.

## API Evidence

Central API evidence was collected with `X-Admin-Scope: central`; bearer token was not written to artifacts.

Seeded QA fixtures added locally for rows with empty seeded lists:

- Partner quota: `pqt_p2_qa_20260510`
- Billing plan: `pbp_p2_qa_20260510`
- Alert event: `pae_p2_qa_20260510`

Summary artifact:

- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/api/central-p2-api-summary.json`

The API evidence confirmed non-empty lists/details for all tested browser rows after fixture seeding.

## Browser Evidence

Browser checks used authenticated central scope and entered every target route from the real central menu before collecting route/form/action evidence.

Mobile sanity at `390x844` passed for:

- `/admin/central/partners`
- `/admin/central/billing-plans`
- `/admin/central/alert-events`

Browser summary:

- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/browser/browser-check-summary.json`
- PNG screenshots and DOM snapshots are saved beside each named evidence file.

## Row Results

| Row | Result | Evidence |
| --- | --- | --- |
| `central:partners` | PASS, completion candidate | List/detail from menu render seeded partners; create/update use typed partner fields; update prefilled; suspend modal shows partner/tenant/domain/runtime context and blank-reason Confirm disabled. |
| `central:partner_provisioning` | PASS, completion candidate | List/detail from menu render seeded partners; provision modal shows tenant/domain/owner/site/billing/deployment/feature fields plus partner context and reason guard; suspend modal context/guard pass. |
| `central:partner_quotas` | PASS, completion candidate | QA fixture row renders; create/update quota forms show typed partner/game/quota/status fields; create Confirm disabled while required fields are blank; update prefilled with quota context. |
| `central:partner_monitoring` | PASS view-only, Coordinator decision item | List/detail render from menu; no update action exposed. Record permission ambiguity: menu permission is `partner.monitoring.view`, backend PATCH requires `partner.monitoring.manage`. |
| `central:partner_usage` | PASS view-only, Coordinator decision item | List/detail render from menu; no limit update action exposed. Record permission ambiguity: menu permission is `partner.usage.view`, backend PATCH requires `partner.usage.manage`. |
| `central:billing_plans` | PASS, completion candidate | QA fixture list/detail render; create/update replace raw JSON with typed fee/currency/status/features/limits fields; create Confirm disabled while required fields blank; update prefilled. |
| `central:alert_policies` | PASS, completion candidate | List/detail render; create/update replace raw JSON with typed partner/policy/severity/status/config fields; create Confirm disabled while required fields blank; update prefilled. |
| `central:alert_events` | PASS, completion candidate | QA fixture list/detail render; acknowledge and resolve modals show event partner/policy/severity/status/channel/title/triggered context and blank-reason Confirm disabled. |

## Scope Notes

No Customer frontend was used. No backend, docs, tasks, handoffs, decisions, Board, or implementation files were edited.

No write mutation was submitted from the browser. QA collected non-destructive form/modal evidence because the task primarily required workflow/context/safety verification and Coordinator must decide whether to count these rows toward official BO completion or request write-submission QA with additional fixture approval.

## Findings

None.

## Coordinator Items

- Decide whether `central:partner_monitoring` should receive a manage-permission menu path before BO exposes update.
- Decide whether `central:partner_usage` should receive a manage-permission menu path before BO exposes limit update.
- Decide whether non-destructive typed form/modal evidence is sufficient to mark the six completion-candidate rows complete, or whether a separate write-submission QA pass should be opened.

## Next Agent

Coordinator.
