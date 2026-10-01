# QA Report - 20260519 Virtual Stock Top-Up Cleanup

## Task

`virtual-stock-topup-cleanup-qa`

Result: **PASS WITH RISK**

Canonical report location:

```text
/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/20260519-virtual-stock-topup-cleanup-qa-report.md
```

Canonical worktree after Coordinator policy update:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 5a55817125fec64c6177f742b19896165be9a0a6
origin/develop: 5a55817125fec64c6177f742b19896165be9a0a6
```

Important worktree note: the QA evidence was originally executed before the canonical-worktree correction from:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang-qa-virtual-stock-topup-cleanup
branch: codex/virtual-stock-topup-cleanup-qa
HEAD: fc65c663d36923e19d30bb26343140b318f5fc5f
```

The report and artifacts have now been copied into the canonical `develop` worktree so Coordinator can review them. No implementation code was edited by QA.

Implementation commits under test:

```text
Backend: c61b8ef5bd6612d1734616acb8a6f1d259e4d5c4
Back-office: c1e92e26c9d98dae6eab71c0f722d702d4a65565
```

## Scope Tested

- Initial virtual generate creates profile/supply.
- Second virtual generate/top-up increases generated supply without replacing profile/counters.
- Idempotency replay does not add supply twice, and changed payload conflicts.
- Seed is not visible or required in BO.
- Physical/quota generation options and payloads are gone/rejected.
- Customer search availability increases after top-up where limits allow.
- Reservation lazily materializes real tickets.
- Stock Generation detail shows owner/no-agent and real image data only when present.
- Limits cannot exceed generated combined virtual supply.
- Stock Pattern Coverage updates through websocket without manual refresh.
- Two-browser realtime still works after top-up.
- Runtime restore/login smoke passes after QA activity.

## Commands Run

Docker/runtime commands were run with Docker Compose only. Destructive setup targeted `newpaotang_test` with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.

Key validation commands:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest --display-warnings
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
```

Runtime restore commands:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang up -d --force-recreate back-office
docker compose -p newpaotang up -d --force-recreate customer
curl http://localhost:3000/login
curl http://localhost:3100/admin/login
```

## Test Results

| Check | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/validation/git-diff-check.txt` |
| Docker build `platform-api back-office` | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/validation/docker-build-platform-api-back-office.txt` |
| Test DB migrate fresh seed on `newpaotang_test` | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/backend/migrate-fresh-seed-newpaotang-test.txt` |
| `Tests\\Feature\\CentralStockTest` | PASS WITH WARNINGS, 144 assertions | `artifacts/20260519-virtual-stock-topup-cleanup-qa/backend/phpunit-central-stock-test.txt` |
| `Tests\\Feature\\VirtualStockRealtimeTest` | PASS WITH WARNINGS, 227 assertions | `artifacts/20260519-virtual-stock-topup-cleanup-qa/backend/phpunit-virtual-stock-realtime-test-display-warnings.txt` |
| OpenAPI YAML parse | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/validation/openapi-yaml-parse.txt` |
| Back-office lint | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/back-office/npm-lint.txt` |
| Back-office unit tests | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/back-office/npm-test.txt` |
| Back-office build | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/back-office/npm-build.txt` |
| Artifact secret scan | PASS | `artifacts/20260519-virtual-stock-topup-cleanup-qa/scans/artifact-secret-scan.txt` |

Acceptance evidence:

| Acceptance item | Result | Evidence |
| --- | --- | --- |
| Initial generate without seed exposure | PASS | `api/runtime-topup-api-evidence.jsonl`, `initial_generate_no_seed` |
| Additive top-up keeps profile/counters | PASS | `api/runtime-topup-api-evidence.jsonl`, `second_generate_topup`, `db_after_full_flow` |
| Idempotency replay/conflict | PASS | `api/runtime-topup-api-evidence.jsonl`, `idempotency_replay`, `idempotency_conflict_changed_payload` |
| BO seed/physical/quota controls removed | PASS | `browser/bo-stock-generation-generate-modal-dom.txt`, `browser/bo-stock-generation-generate-modal.png` |
| Retired physical/quota payload rejected | PASS | `api/runtime-topup-api-evidence.jsonl`, `retired_physical_quota_payload_rejected` |
| Customer availability increases after top-up | PASS | `api/runtime-topup-api-evidence.jsonl`, `customer_search_after_initial`, `customer_search_after_topup` |
| Reservation lazy materialization | PASS | `api/runtime-topup-api-evidence.jsonl`, `reservation_lazy_materialization`, `db_after_full_flow` |
| Owner/no-agent and real image only when present | PASS | `api/runtime-topup-api-evidence.jsonl`, `number_detail_owner_image_corrected`, `number_detail_no_agent_unassigned`; `browser/bo-stock-generation-number-detail-owner-image-dom.txt` |
| Limit cannot exceed generated combined supply | PASS | `api/runtime-topup-api-evidence.jsonl`, `limit_override_over_combined_supply_rejected` |
| Stock Pattern Coverage websocket update | PASS | `browser/bo-stock-pattern-coverage-after-override-realtime-dom.txt`, `realtime/api-valid-override-event-trigger-8002.json` |
| Two-browser realtime after top-up | PASS | `realtime/two-browser-realtime-browser-summary.json`, `browser/bo-stock-pattern-coverage-two-browser-*` |

## Runtime Restore / Login Smoke

Runtime was restored after QA activity:

| Restore item | Result | Evidence |
| --- | --- | --- |
| `db:seed` runtime restore | PASS | `runtime/runtime-db-seed.txt` |
| `platform:smoke` including `seeded-logins: ok` | PASS | `runtime/runtime-platform-smoke.txt` |
| Back-office recreated after BO build/browser QA | PASS | `runtime/runtime-back-office-recreate.txt` |
| Customer `/login` | PASS after customer recreate | `runtime/runtime-login-pages-smoke-after-customer-recreate.txt` |
| Back-office `/admin/login` | PASS, redirects/follows to 200 login page | `runtime/runtime-login-pages-smoke-after-customer-recreate.txt` |
| Central admin API login | PASS, HTTP 200 with token presence booleans only | `runtime/runtime-central-admin-api-login-smoke.json` |
| Test-only runtime stopped | PASS | `runtime/test-runtime-stop.txt` |

## Defects

No implementation defect was found in this QA pass.

## Risks / Not Tested

- PHPUnit suites pass but emit dotenv warnings for missing `/var/www/html/.env` in the Docker test container.
- Customer `/login` initially returned 500 during runtime restore because the long-running customer dev server had stale Nuxt/Nitro state. Recreating the customer container restored `/login` to 200.
- QA process note: one non-mutating host-side PHP hash helper was accidentally used while preparing a customer auth fixture. It did not run app tests/builds/migrations, did not mutate project state, and did not write raw token material to artifacts.
- Canonical-worktree policy was updated after the first QA execution. This report is now visible in the canonical worktree, but Coordinator may decide whether to request a full canonical re-run for strict policy compliance.

## Recommendation

Approve the feature scope from a product/acceptance perspective, with Coordinator awareness of the test/runtime hygiene risks above.

## Next Agent

Coordinator
