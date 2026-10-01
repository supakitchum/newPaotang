# Back Office P3 Reward Report Log Workflows QA Report

Date: 2026-05-10
Task: `back-office-p3-reward-report-log-workflows`
QA: Open Chat QA Tester

## Result

CONDITIONAL PASS with one new P2 finding for Coordinator review.

Eight rows are completion candidates after Docker validation, authenticated API checks, and real BO browser QA:

- `central:rewards`
- `central:prize_checking`
- `central:settlement`
- `central:reports`
- `central:webhook_logs`
- `central:audit_logs`
- `tenant:reports`
- `tenant:audit_logs`

`tenant:sync_logs` is functionally reachable and lists tenant-scoped data, but is held by the finding below because its status filter omits the real `processed` status shown by the list/API.

Next agent: Coordinator.

## Head Under Test

- HEAD: `bfb07363c3209e1bf51db17ca6e2c0e2ee377ed0` (`develop`, `origin/develop`)
- Latest task context: `back-office-p3-reward-report-log-workflows`

## Workspace Notes

Unrelated dirty/generated files were left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA only wrote this report and artifacts under:

- `ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md`
- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/`

## Validation

Passed with Docker-only application commands:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest`
- `docker compose exec -T platform-api php artisan route:list`
- `docker compose run --rm platform-api php artisan test --filter=RewardEngineTest`
- `docker compose run --rm platform-api php artisan test --filter=ReportTest`
- `docker compose run --rm platform-api php artisan test --filter=SettlementTest`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`
- Final `docker compose run --rm platform-api php artisan migrate:fresh --seed` before browser QA

Validation artifacts are in:

- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/validation/`

Build warnings carried forward:

- Node `DEP0180` deprecation warning for `fs.Stats` constructor.
- Existing unresolved runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`.

## API Evidence

API evidence was collected with `X-Admin-Scope` and `X-Tenant-Id` where required; bearer tokens were not written to artifacts.

Before evidence:

- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/before-api-summary.json`
- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/before-api-evidence.json`

After evidence:

- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/after-api-evidence.json`
- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/after-db-export-jobs.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/tenant-sync-fixture-db.txt`

After API statuses were all `200` for:

- central reward list/detail/check-batches
- central settlement detail
- central report overview
- central webhook detail
- central audit logs
- tenant report overview
- tenant sync logs
- tenant audit logs

Key persisted after-state:

- Reward `rew_01KR93RA17AHD8Z5R84XA5S0FW`: game `gam_p3_reward_ui10`, status `corrected`, first prize `654321`, check batch `completed`, verified and published timestamps present.
- Settlement `pst_p3_qa10`: status `approved`, tenant `ten_demo_alpha`, net amount `108000 THB`.
- Report exports: central and tenant overview CSV export jobs both `ready`.
- Webhook `whc_p3_qa10`: raw seeded secret/token/auth values absent; `[REDACTED]` markers present.
- Tenant sync fixture `sin_p3_qa10`: present for `ten_demo_alpha`, status `processed`.

## Browser Evidence

Browser checks used authenticated BO central and tenant scopes from the real menus. PNG screenshots and DOM snapshots are saved under:

- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/browser/`

Captured workflow evidence includes:

- Rewards create/update/verify/publish/correct before-submit and after-submit evidence.
- Prize check batch evidence from the reward detail page.
- Settlement list/detail/approve before-submit and after-submit evidence.
- Central and tenant report index/detail/export evidence.
- Webhook list/detail redaction evidence.
- Central and tenant audit log evidence.
- Tenant sync log evidence.
- Mobile sanity at `390x844` for central rewards, central reports, and tenant reports.

## Row Results

| Row | Result | Evidence |
| --- | --- | --- |
| `central:rewards` | PASS, completion candidate | Browser create/update/verify/publish/correct; API final status `corrected`. |
| `central:prize_checking` | PASS, completion candidate | Reward detail showed completed prize check batch; API check-batches returned `200`. |
| `central:settlement` | PASS, completion candidate | Browser approve flow; API settlement `pst_p3_qa10` status `approved`. |
| `central:reports` | PASS, completion candidate | Browser overview report and export; DB export job `central / overview / ready`. |
| `central:webhook_logs` | PASS, completion candidate | Browser detail and API confirmed webhook payload/response redaction. |
| `central:audit_logs` | PASS, completion candidate | Browser/API show `p3.qa.central.audit`. |
| `tenant:reports` | PASS, completion candidate | Tenant overview report and export; DB export job `tenant / overview / ready`. |
| `tenant:sync_logs` | HOLD, finding | Tenant list/API show `sin_p3_qa10`, but UI filter cannot select the real `processed` status. |
| `tenant:audit_logs` | PASS, completion candidate | Browser/API show `p3.qa.tenant.audit` scoped to `ten_demo_alpha`. |

## Findings

### Finding 1: `apps/back-office/composables/useAdminOperationsCatalog.ts:778` [P2]

Tenant sync-log status filter omits the `processed` status returned by the API.

The tenant sync-log list displays fixture `sin_p3_qa10` with status `Processed`, and DB evidence confirms the underlying `sync_inbox.status` is `processed`. However, the BO filter options for `tenant:sync_logs` are `pending`, `running`, `completed`, and `failed`, so users cannot filter for the status that the page actually displays. This breaks the expected list/filter workflow for the P3 `tenant:sync_logs` row.

Evidence:

- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/browser/tenant-sync-logs-list.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/tenant-sync-fixture-db.txt`

## Scope Notes

No Customer frontend was used.

No implementation files, docs, tasks, handoffs, decisions, or Board files were edited.

This QA report routes the finding to Coordinator. QA did not instruct Backend or BO directly.

## Coordinator Items

- Decide whether to promote the eight PASS rows to complete.
- Route Finding 1 for triage before promoting `tenant:sync_logs`.
