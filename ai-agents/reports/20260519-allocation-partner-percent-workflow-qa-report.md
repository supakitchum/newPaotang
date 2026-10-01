# QA Report - 20260519 Allocation Partner Percent Workflow

## Task

`allocation-partner-percent-workflow-qa`

Result: **PASS WITH RISK**

The backend/API acceptance criteria passed through Docker tests and an additional HTTP-kernel API workflow evidence run on `newpaotang_test`. Back-office lint/test/build passed, route/source wiring for the allocation percent workflow is present, and runtime restore/login smoke passed.

The risk is that authenticated browser automation was not available in this Codex turn after tool discovery, so BO evidence is static source wiring plus HTTP route smoke, not a full authenticated browser workflow.

## Scope Tested

- Allocation option APIs for partners, tenants, and games.
- Partner -> tenant filtering and tenant metadata.
- Single active tenant auto-fill through backend create behavior.
- Multi-tenant explicit tenant validation.
- No-active-tenant validation.
- Create allocation using `allocation_percent` with no `requested_count` in the QA request payload.
- Allocation list/detail display metadata and percent/count fields.
- Idempotency replay and changed-payload conflict.
- Partner stock percent total `<= 100` validation.
- Usage-protection rejection when lowering percent below reserved/sold usage.
- Recall-all and redistribute state transitions.
- Redistribute blocked unless allocation is recalled.
- BO allocation percent field/action/source wiring and scoped stock route wiring.
- Required backend and BO focused validations.
- Runtime restore/login smoke.

## Commands Run

Canonical start gate:

```sh
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Required validation:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Additional API workflow evidence:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -v .../run-allocation-workflow-evidence.php:/tmp/run-allocation-workflow-evidence.php:ro -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php /tmp/run-allocation-workflow-evidence.php
```

Runtime restore:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 http://localhost:3000/login
curl --max-time 5 http://localhost:3100/login
curl --max-time 5 http://localhost:3100/admin/login
```

## Test Results

| Check | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/validation/git-diff-check.txt` |
| Docker build `platform-api back-office` | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/validation/docker-build-platform-api-back-office.txt` |
| Docker runtime up | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/validation/docker-up-runtime.txt` |
| Test DB migrate fresh seed on `newpaotang_test` | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/backend/migrate-fresh-seed-newpaotang-test.txt` |
| `CentralAllocationTest` | PASS, 3 tests / 117 assertions | `artifacts/20260519-allocation-partner-percent-workflow-qa/backend/phpunit-central-allocation-test.txt` |
| `CentralStockTest` | PASS, 5 tests / 161 assertions | `artifacts/20260519-allocation-partner-percent-workflow-qa/backend/phpunit-central-stock-test.txt` |
| `VirtualStockRealtimeTest` | PASS, 7 tests / 227 assertions | `artifacts/20260519-allocation-partner-percent-workflow-qa/backend/phpunit-virtual-stock-realtime-test.txt` |
| BO lint | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/back-office/npm-lint.txt` |
| BO test | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/back-office/npm-test.txt` |
| BO build | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/back-office/npm-build.txt` |
| Artifact secret scan | PASS | `artifacts/20260519-allocation-partner-percent-workflow-qa/scans/artifact-secret-scan.txt` |

API workflow evidence:

| Acceptance item | Result | Evidence |
| --- | --- | --- |
| Partner options include display names and active tenant metadata | PASS | `api/allocation-workflow-evidence.jsonl`, `partner_options` |
| Tenant options are filtered by partner | PASS | `api/allocation-workflow-evidence.jsonl`, `tenant_options_filtered_by_partner` |
| Game options expose generated supply metadata | PASS | `api/allocation-workflow-evidence.jsonl`, `game_options` |
| Single-tenant create auto-fills tenant | PASS | `api/allocation-workflow-evidence.jsonl`, `create_allocation_single_tenant_auto_fill` |
| Create payload used `allocation_percent` and omitted `requested_count` | PASS | `api/allocation-workflow-evidence.jsonl`, `sent_requested_count:false` |
| Idempotency replay does not duplicate allocation | PASS | `api/allocation-workflow-evidence.jsonl`, `idempotency_replay_same_payload` |
| Changed payload with same idempotency key conflicts | PASS | `api/allocation-workflow-evidence.jsonl`, `idempotency_conflict_changed_payload` |
| Multi-tenant partner requires explicit tenant | PASS | `api/allocation-workflow-evidence.jsonl`, `multi_tenant_requires_explicit_tenant` |
| No-active-tenant partner is blocked | PASS | `api/allocation-workflow-evidence.jsonl`, `no_active_tenant_blocked` |
| Active partner percent total over 100 is rejected | PASS | `api/allocation-workflow-evidence.jsonl`, `partner_percent_over_100_rejected` |
| Partner percent can be set up to total 100 | PASS | `api/allocation-workflow-evidence.jsonl`, `partner_percent_set_to_total_100` |
| Usage protection rejects lowering below reserved/sold usage | PASS | `api/allocation-workflow-evidence.jsonl`, `usage_protection_rejects_lower_percent` |
| Allocation detail/list include display metadata and percent/counts | PASS | `api/allocation-workflow-evidence.jsonl`, `allocation_detail_metadata`, `allocation_list_metadata` |
| Recall-all updates allocation and distribution state | PASS | `api/allocation-workflow-evidence.jsonl`, `recall_all` |
| Redistribute succeeds after recall | PASS | `api/allocation-workflow-evidence.jsonl`, `redistribute_after_recall` |
| Redistribute is blocked when not recalled | PASS | `api/allocation-workflow-evidence.jsonl`, `redistribute_disabled_by_state_api_conflict` |

BO evidence:

| Acceptance item | Result | Evidence |
| --- | --- | --- |
| Allocation uses `allocation_percent` field | PASS (source) | `source/useAdminOperationsCatalog-allocation-fields.txt`, `source/bo-allocation-static-rg.txt` |
| Option-backed partner/tenant/game APIs are wired | PASS (source) | `source/AdminOperationsPage-allocation-options.txt` |
| Partner stock percent edit endpoint is wired | PASS (source) | `source/useAdminOperationsCatalog-allocation-actions.txt` |
| Stock coverage row route includes `game_id`, `scope_type=partner`, `scope_id` | PASS (source + route smoke) | `source/useAdminOperationsCatalog-allocation-actions.txt`, `browser/bo-route-http-smoke.txt` |
| Remaining stock route includes game/partner/tenant/allocation/status params | PASS (source + route smoke) | `source/useAdminOperationsCatalog-allocation-actions.txt`, `browser/bo-route-http-smoke.txt` |
| Recall-all and redistribute actions are wired, redistribute disabled until recalled | PASS (source) | `source/useAdminOperationsCatalog-allocation-actions.txt` |

## Defects

No implementation defect was found in this QA pass.

## Risks / Not Tested

- Authenticated BO browser workflow was not executed because the Browser automation JavaScript tool was not exposed after tool discovery in this turn. BO evidence is source wiring plus unauthenticated HTTP route smoke.
- `apps/platform-api/.phpunit.result.cache` was dirty before QA started and is documented by the task as an unrelated Backend PHPUnit artifact. QA did not include it in the report artifacts intentionally.
- The API workflow evidence runner was mounted into a Docker container for execution and then removed from artifacts to avoid storing credential-handling helper code. The sanitized JSONL output is retained.

## Runtime Restore / Login Smoke

Worktree and HEAD used:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 7189b18e8d19f2cc8b224703b156cfa046d69506
origin/develop: 7189b18e8d19f2cc8b224703b156cfa046d69506
```

Test database isolation:

```text
destructive database commands used: newpaotang_test
APP_ENV: testing
DB_DATABASE: newpaotang_test
runtime DB newpaotang wipe/destructive migration: not used
```

Restore results:

| Restore item | Result | Evidence |
| --- | --- | --- |
| Runtime `db:seed` | PASS | `runtime/runtime-db-seed.txt` |
| `platform:smoke` | PASS, includes `seeded-logins: ok` | `runtime/runtime-platform-smoke.txt` |
| Back-office restarted/recreated after BO build | PASS | `runtime/runtime-back-office-stop.txt`, `runtime/runtime-back-office-rm.txt`, `runtime/runtime-back-office-up-after-restore.txt` |
| Customer `/login` | PASS, 200 | `runtime/runtime-login-pages-smoke.txt` |
| Back-office `/login` | PASS, 200 | `runtime/runtime-login-pages-smoke.txt` |
| Back-office `/admin/login` redirect target | PASS, 302 to `/login`, follow 200 | `runtime/runtime-login-pages-smoke.txt` |
| Central admin API login | PASS, 200 with token-presence booleans only | `runtime/runtime-central-admin-api-login-smoke.json` |

## Recommendation

Coordinator can approve the backend/API workflow from QA evidence. If Coordinator requires strict BO visual approval, assign a browser-enabled QA rerun specifically for authenticated BO allocation UI workflows.

## Next Agent

Coordinator
