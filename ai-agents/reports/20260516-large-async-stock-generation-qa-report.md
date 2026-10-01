# QA Report

## Task

`large-async-stock-generation-qa`

Result: PASS WITH RISK

Backend async generation, BO build/structural wiring, OpenAPI, and runtime restore/login smoke passed. The risk is limited to authenticated BO browser UAT: the in-app browser was unavailable and Computer Use permission remained pending, so QA could not execute a live authenticated BO large-submit/progress-polling workflow. BO behavior was covered by Docker structural checks and backend behavior was covered by isolated feature tests.

## Scope Tested

- Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- Current HEAD: `fd04201df63b93001a19d689ad718538be933e6e`
- `origin/develop`: `fd04201df63b93001a19d689ad718538be933e6e`
- Backend commit under test: `748f4d1d53e4daf03246dd43bfb4cf53c069ce09`
- BO commit under test: `a038d5885dd1f070c46c32455e80cfb3587b8e59`

Both implementation commits are present locally and reachable from `origin/develop`.

## Commands Run

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
git branch -r --contains 748f4d1d53e4daf03246dd43bfb4cf53c069ce09
git branch -r --contains a038d5885dd1f070c46c32455e80cfb3587b8e59
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=LotteryImage --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office node - <<'NODE'
docker compose -p newpaotang run --rm platform-api sh -lc 'tmp="$(mktemp -d)"; composer require --working-dir="$tmp" --no-interaction --quiet symfony/yaml:^7; php -r "require \"$tmp/vendor/autoload.php\"; \Symfony\Component\Yaml\Yaml::parseFile(\"/workspace/docs/openapi.yaml\"); echo \"OpenAPI YAML parsed\n\";"'
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan route:list --path=admin/central/stock --env=testing
docker run --rm -i -v /Users/supakit/WorkSpace/www/newPaotang:/repo -w /repo ruby:3.3-alpine ruby - <<'RUBY'
curl --max-time 10 -i -s http://localhost:3100/admin/central/stock-generation
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 10 -i -s http://localhost:3100/login
curl --max-time 10 -i -s http://localhost:3100/admin/login
```

## Test Results

| Check | Result | Evidence |
| --- | --- | --- |
| Start gate | PASS | Backend + BO handoffs exist; commits reachable from `origin/develop`. |
| Test DB isolation | PASS | Destructive migration ran only with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`. |
| Backend CentralStock async suite | PASS | `CentralStockTest`: 5 passed, 210 assertions. |
| 1,000 sync path | PASS | Covered by `CentralStockTest` sync generate/list/summary coverage. |
| 12,000 async completion | PASS | Covered by `test_CentralStock_large_async_generation_chunks_progress_idempotency_duplicates_and_image_dispatch`: queued response, 3 chunk jobs, manual chunk handling, 12,000 persisted rows, completed batch. |
| Duplicate `full_number` preservation | PASS | Same async test asserts at least one duplicate generated `full_number`; import path also preserves duplicate `000011`. |
| Completed chunk retry | PASS | Same async test retries completed first chunk and row count stays at 5,000 before remaining chunks run. |
| Failed chunk rollback | PASS | `test_CentralStock_async_generation_failed_chunk_rolls_back_without_partial_rows` passed. |
| Idempotency replay/conflict | PASS | Same async test asserts replay returns the same batch and changed payload returns 409 `idempotency_conflict`. |
| Image dispatch separation | PASS | Same async test asserts no image dispatcher during large request, then final stock completion dispatches `DispatchStockBatchImageJobs`; LotteryImage suite passed. |
| Batch API progress | PASS | Route list shows generation batch list/detail endpoints; feature test asserts list/detail returns completed progress and chunks. |
| No `insertOrIgnore` | PASS | Source scan found no `insertOrIgnore` in stock generation service/jobs; normal `StockItem::query()->insert($chunk)` evidence captured. |
| BO lint/test/build | PASS | `npm run lint`, `npm run test`, and `npm run build` passed. Build has existing Node `DEP0180` warning but exits 0. |
| BO async progress structural wiring | PASS | `AdminStockGenerationBatches` polls list/detail every 5s, shows requested/generated/round/chunk/failure fields, has queued/processing active states, fallback image-state labels, and is mounted on Stock Generation page. |
| BO duplicate submit prevention | PASS | Structural check verifies `stockGenerationHasActiveBatch`, active batch detection, disabled generate action, and disabled reason. |
| BO linked quota/current game/no ALL regression | PASS | Structural check verifies linked quota guardrails and current-game-only generate selector remain. Previous hotfix test behavior remains covered by prior browser QA and current source guardrails. |
| OpenAPI parse/contract | PASS | YAML parsed; contract check confirms generate 202/409 and generation batch schemas/endpoints. |
| Runtime restore/login smoke | PASS | Non-destructive runtime seed, `platform:smoke`, BO recreate, `/login`, `/admin/login`, and central login API passed. |
| Artifact/credential scan | PASS | Current QA artifacts contain no literal seeded passwords, bearer tokens, auth headers, private keys, or token values. Protected credential artifact was untouched. |
| Authenticated BO browser UAT | RISK | Not completed: Codex in-app browser returned unavailable for `iab`; Computer Use remained pending macOS permission; no Playwright/Puppeteer/jsdom package exists in the BO container. |

## Artifacts

Artifacts directory:

```text
ai-agents/reports/artifacts/20260516-large-async-stock-generation-qa/
```

Key files:

```text
validation/start-gate-and-diff-check.log
validation/docker-build-platform-api-back-office.log
validation/docker-up-services.log
backend/migrate-fresh-test-db.log
backend/phpunit-central-stock.log
backend/phpunit-lottery-image.log
backend/route-list-central-stock.log
back-office/npm-lint.log
back-office/npm-test.log
back-office/npm-build.log
back-office/check-stock-summary-widgets.log
back-office/structural-async-progress-qa-rerun.log
openapi/openapi-yaml-parse.log
openapi/openapi-async-stock-contract.log
source/stock-generation-source-scan.log
browser/browser-runtime-availability.log
browser/stock-generation-route-curl-smoke.log
runtime/runtime-db-seed.log
runtime/runtime-platform-smoke.log
runtime/runtime-login-smoke.log
scans/artifact-secret-scan.log
```

## Backend Evidence Details

`CentralStockTest` passed:

```text
5 passed (210 assertions)
```

Coverage includes:

```text
sync generation/import/export/list/recall
summary widgets aggregate coverage
large async 12,000 generation
queued batch response and chunk jobs
completed chunk retry skip
duplicate full_number preservation
idempotency replay and conflict
image dispatch separation
batch list/detail progress
failed chunk rollback
quota conflict validation
```

`LotteryImage` regression passed:

```text
16 passed (479 assertions)
```

## BO Evidence Details

BO Docker validation passed:

```text
lint passed
test passed
Nuxt build passed
stock summary widget check passed
custom async progress structural check passed
```

Structural checks verified:

```text
AdminStockGenerationBatches polls /admin/central/stock/generation-batches and detail endpoint
progress fields include requested_count, generated_count, total_rounds, processed_rounds, chunk_rounds, failure_reason, chunks
queued/pending/processing active states drive polling/disable behavior
failure_reason renders in detail panel
image fallback labels distinguish stock completion from image reporting
Generate Stock is disabled while an active batch exists for the current game
summary widgets refresh on meaningful progress changes
old 10,000 synchronous UI cap is removed
linked quota and current-game/no-ALL guardrails remain
```

Protected route curl smoke:

```text
GET /admin/central/stock-generation -> HTTP 302 /login?redirect=/admin/central/stock-generation
```

This confirms the rebuilt BO route resolves through the auth guard without SSR/server crash, but it is not a substitute for authenticated browser UAT.

## Test DB Isolation Evidence

The only destructive DB command was:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests also ran with:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime DB `newpaotang` was not wiped or destructively migrated.

## Runtime Restore / Login Smoke

PASS.

Non-destructive runtime restore completed:

```text
php artisan db:seed --no-interaction: PASS
php artisan platform:smoke: app/database/cache/monitoring-defaults/seeded-logins ok
back-office stop/rm/up after build/browser attempts: PASS
GET /login: HTTP 200
GET /admin/login: HTTP 302 Location /login
POST /api/v1/auth/admin/login: HTTP 200, access token present, central scope present
```

## Defects

None confirmed.

## Risks / Not Tested

- Authenticated BO browser UAT for actual large submit/progress polling was not completed because available UI automation failed:
  - Codex in-app browser: `Browser is not available: iab`
  - Computer Use: macOS Accessibility/Screen Recording permission remained pending
  - BO container has no Playwright/Puppeteer/jsdom fallback package
- QA did not create a live 12,000 batch through the runtime BO because that would mutate runtime DB `newpaotang`; accepted async submit/progress behavior was proven on `newpaotang_test` feature tests and BO structural wiring.
- Git reported the existing gc housekeeping warning during fetch; QA did not modify `.git/gc.log` or run prune.

## Recommendation

Coordinator can accept Backend/API behavior as validated and BO wiring as structurally validated. For release confidence, route a small follow-up UAT pass once browser automation/Computer Use permissions are available, focused only on authenticated BO large-submit progress polling.

## Next Agent

Coordinator
