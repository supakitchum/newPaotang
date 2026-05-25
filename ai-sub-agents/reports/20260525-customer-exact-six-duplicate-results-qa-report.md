# Customer Exact Six Duplicate Results QA Report

## Summary

- Task: `ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-qa-tester.md`
- Trigger: `ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.md`
- QA agent: QA Tester
- Execution mode: AUTO
- Recommendation: `BLOCKED`
- Requested final trigger status: `BLOCKED`
- Next Agent: Coordinator

QA validated the backend exact six duplicate-copy behavior and API pagination on `APP_ENV=testing` with `DB_DATABASE=newpaotang_test`. The required visible Chrome acceptance could not be completed to a clean proof: Chrome reached the test-wired `/buy/search` route and issued the stock search request, but the rendered UI assertion for three duplicate `654321` rows timed out before screenshot/JSON evidence could be produced. Because visible Chrome rendered result proof is mandatory, this report is BLOCKED rather than PASS.

## Worktree Evidence

- Canonical worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- `pwd`: `/Users/supakit/WorkSpace/www/newPaotang`
- `git rev-parse --show-toplevel`: `/Users/supakit/WorkSpace/www/newPaotang`
- `git fetch origin`: success
- `git merge --ff-only origin/develop`: `Already up to date.`
- `HEAD`: `d962763677594a14876b7d32173442f2843e181b`
- `origin/develop`: `d962763677594a14876b7d32173442f2843e181b`

Unrelated or pre-existing dirty files were present before QA and were not reverted. They include Coordinator/runner workflow files, dev handoffs/tasks/triggers, `apps/customer/composables/usePlatformApi.ts`, `apps/customer/pages/buy/search.vue`, `apps/customer/utils/stockSearchIdentity.js`, `apps/customer/scripts/check-exact-six-search-identity.mjs`, `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`, and `apps/platform-api/tests/Feature/PublicStockSearchTest.php`.

QA-created or QA-updated files:

- `ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md`
- `ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/create-exact-six-fixture.php`
- `ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/check-api-pagination.php`
- `ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/check-api-regressions.php`
- `ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/create-customer-login.php`
- `ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/chrome-exact-six-visible-check.mjs`
- `ai-sub-agents/memory/qa-tester/memory.md`

Test execution also modified `apps/platform-api/.phpunit.result.cache`.

## Trigger Evidence

- QA trigger status observed: `RUNNING`
- Status owner: AUTO runner; QA did not edit trigger status directly.
- Claim file: `ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.claim.md`
- Runner id: `codex-native-runner-coordinator-20260525T224034+0700`
- Claimed at: `2026-05-25T22:40:34+0700`
- Heartbeat file: `ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.heartbeat.md`
- Dev Customer dependency: trigger status `DONE`
- Dev Backend dependency: trigger status `DONE`
- Required dev and orchestrator handoff files were present.

## Test Env / Test DB Evidence

All backend/data commands used:

```sh
APP_ENV=testing DB_DATABASE=newpaotang_test
```

Testing DB setup:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan migrate:fresh --env=testing --no-interaction
```

Result: PASS. Only `newpaotang_test` was migrated. Local runtime DB `newpaotang` was not wiped, reset, or updated.

Fixture creation:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php /workspace/ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/create-exact-six-fixture.php
```

Fixture result:

```json
{
  "app_env": "testing",
  "db_database": "newpaotang_test",
  "tenant_domain": "localhost",
  "tenant_id": "ten_qa_exact6",
  "partner_id": "par_qa_exact6",
  "game_id": "gam_qa_exact6",
  "exact_full_number": "654321",
  "expected_duplicate_copies": 3,
  "base_lottery_numbers": ["654321", "654322", "123421"],
  "allocation_id": "alc_925c84b1e25803375364",
  "allocated_count": 9
}
```

Customer login fixture:

```json
{
  "app_env": "testing",
  "db_database": "newpaotang_test",
  "tenant_id": "ten_qa_exact6",
  "customer_id": "cus_qa_exact6",
  "phone": "0806543210",
  "role": "customer"
}
```

## Commands Run And Results

Customer static/unit validation:

```sh
docker compose -p newpaotang exec -T customer npm test
```

Result: PASS. Tenant-domain integration checks and exact-six stock search identity checks passed.

Backend focused validation:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=PublicStockSearchTest --env=testing
```

Result: PASS, `13 passed, 158 assertions`.

Known adjacent risk confirmation:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --filter=test_central_stock_virtual_grouped_total_count_sort_and_full_number_detail --env=testing
```

Result: FAIL as expected. `VirtualStockRealtimeTest.php:730` still expects `https://cdn.example.test/central/123456.png` but receives `http://cdn.example.test/central/123456.png`.

Temporary test API server:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan serve --host=0.0.0.0 --port=8010 --no-reload
```

Result: server started for QA, then stopped after report evidence collection.

Temporary customer server:

```sh
docker compose -p newpaotang run --rm --no-deps -p 3010:3000 -e NUXT_PUBLIC_API_BASE_URL=/api/v1 -e NUXT_PLATFORM_API_INTERNAL_BASE_URL=http://platform-api:8010/api/v1 -e NUXT_PUBLIC_SITE_URL=http://localhost:3010 -e NUXT_BUILD_DIR=/tmp/newpaotang-customer-qa-nuxt -e NITRO_NO_UNIX_SOCKET=1 -e NODE_OPTIONS=--no-deprecation customer npm run dev -- --host 0.0.0.0 --port 3000
```

Result: customer app served at `http://localhost:3010`, wired through Nuxt same-origin `/api/v1` proxy to `http://platform-api:8010/api/v1`.

Cleanup:

- Killed temporary Docker compose API/customer server processes after evidence collection.
- Killed separate QA Chrome profile process with `--remote-debugging-port=9223`.
- Follow-up `ps aux | rg "artisan serve --host=0.0.0.0 --port=8010|newpaotang-customer-qa-nuxt|remote-debugging-port=9223"` showed only the `rg` process.

## Backend API Duplicate Pagination Evidence

Pagination script:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php /workspace/ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/check-api-pagination.php
```

Result: PASS.

- API base: `http://127.0.0.1:8010/api/v1`
- Host header: `localhost`
- Game: `gam_qa_exact6`
- Number: `654321`
- Limit: `2`

Page 1:

- HTTP 200
- Count: 2
- Full numbers: `["654321", "654321"]`
- IDs:
  - `vstock:ten_qa_exact6:gam_qa_exact6:654321:0`
  - `vstock:ten_qa_exact6:gam_qa_exact6:654321:1`
- Copy indexes: `[0, 1]`
- `has_more`: true
- `next_cursor`: `eyJudW1iZXJfb2Zmc2V0IjowLCJjb3B5X29mZnNldCI6Mn0=`

Page 2:

- HTTP 200
- Count: 1
- Full numbers: `["654321"]`
- ID: `vstock:ten_qa_exact6:gam_qa_exact6:654321:2`
- Copy index: `[2]`
- `has_more`: false
- `next_cursor`: null

Combined result:

- Three exact duplicate copies returned.
- Full numbers are all `654321`.
- IDs are unique across pages.
- No repeated IDs across pages.

Regression API script:

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php /workspace/ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/check-api-regressions.php
```

Result: PASS.

- `/public/site-config`: 200, tenant `ten_qa_exact6`
- `/public/games/current`: 200, game `gam_qa_exact6`, status `open`
- Exact `654321` limit 10: 3 rows, unique copy-index IDs `:0`, `:1`, `:2`
- Store-filtered exact search: 3 rows
- Partial positional `d1=6&d2=5`: 6 rows across `654321` and `654322`
- Browse/random path: 3 rows and `has_more=true`
- Empty exact `000000`: 0 rows and `has_more=false`
- Invalid digit `d3=12`: 422 `validation_failed`

## Visible Google Chrome Evidence

Visible Chrome was available and used.

Initial visible Chrome attempt:

- Opened `/Applications/Google Chrome.app` to `http://localhost:3010/buy/search`.
- Browser redirected to `http://localhost:3010/login?redirect=/buy/search`, showing tenant title `QA Exact Six Tenant`.
- QA login via visible UI with `0806543210` / test password showed an app alert: `Authentication token is missing, invalid, expired, or revoked.`
- Direct same-origin API checks showed the login token itself was valid; `/customer/auth/me` and `/customer/cart` returned 200 with the issued token.

Separate visible QA Chrome profile:

```sh
open -na "Google Chrome" --args --user-data-dir=/tmp/newpaotang-qa-chrome-exact-six --remote-debugging-port=9223 --new-window 'http://localhost:3010/login?redirect=/buy/search'
```

Chrome DevTools evidence:

- `curl http://127.0.0.1:9223/json/version` returned `Browser: Chrome/148.0.7778.179`.
- `curl http://127.0.0.1:9223/json/list` showed page URL `http://localhost:3010/buy/search` and title `QA Exact Six Tenant`.
- Browser server logs showed requests through the test-wired stack:
  - `/api/v1/customer/auth/login`
  - `/api/v1/public/site-config`
  - `/api/v1/public/games/current`
  - `/api/v1/customer/cart`
  - `/api/v1/customer/auth/me`
  - `/api/v1/customer/realtime/auth`
  - `/api/v1/public/stock/search`

Blocked browser proof:

```sh
QA_CUSTOMER_URL=http://localhost:3010 QA_ARTIFACT_DIR=/Users/supakit/WorkSpace/www/newPaotang/ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results CHROME_DEBUG_PORT=9223 node ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/chrome-exact-six-visible-check.mjs
```

Result: BLOCKED. The script timed out waiting for visible Chrome DOM evidence that at least three rendered result rows had ticket number `654321`:

```text
Error: Timed out waiting for expression:
Array.from(document.querySelectorAll('.lottery-row:not(.is-lazy) .ticket-number'))
  .map((node) => node.textContent.replace(/\D/g, ''))
  .filter((number) => number === "654321")
  .length >= 3
```

No `chrome-cdp-exact-six-results.json` or `chrome-cdp-exact-six-results.png` was produced. Therefore the mandatory visible Chrome rendered-result proof is incomplete.

## Scenario Results

- Worktree start gate: PASS
- Trigger/dependency readiness: PASS
- Test env/test DB setup: PASS
- Fixture with exact six duplicate copies: PASS
- Customer exact-six duplicate identity unit/static checks: PASS
- Backend `PublicStockSearchTest`: PASS
- Backend exact six duplicate pagination over copy indexes: PASS
- Backend regression scenarios for store filter, partial positional search, browse, empty exact, invalid digit: PASS
- Visible Chrome availability: PASS
- Visible Chrome test-env routing: PARTIAL PASS; Chrome reached `localhost:3010`, Nuxt proxy routed to platform API server started with `APP_ENV=testing DB_DATABASE=newpaotang_test`, and server logs showed the expected API calls.
- Visible Chrome rendered exact-six duplicate rows: BLOCKED; timed out before proving three rendered `654321` rows.
- Runtime DB safety: PASS; no wipe/reset/update of local runtime DB `newpaotang`.

## VirtualStockRealtimeTest Risk Note Disposition

Risk remains open and should be carried forward. The focused `VirtualStockRealtimeTest` still fails on the known `https` versus `http` image URL mismatch:

- Expected: `https://cdn.example.test/central/123456.png`
- Actual: `http://cdn.example.test/central/123456.png`
- Location: `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php:730`

This risk is adjacent to the exact-six duplicate result work. It is not fixed by QA.

## Runtime DB Safety

- QA used `APP_ENV=testing` and `DB_DATABASE=newpaotang_test` for all backend/data validation.
- QA ran `migrate:fresh` only against `newpaotang_test`.
- QA did not wipe/reset local runtime DB `newpaotang`.
- QA did not edit implementation files or tests.

## Memory Update Evidence

Updated `ai-sub-agents/memory/qa-tester/memory.md` under `Last Useful Findings` with:

```text
For customer browser QA, a temporary visible Chrome profile with `--remote-debugging-port` can prove the browser reached the test-wired Nuxt route, but a clean PASS still needs rendered UI result evidence; if the DOM assertion times out, report BLOCKED or PASS WITH RISK rather than inferring success from backend API proof alone.
```

## Final Recommendation

Recommendation: `BLOCKED`

Requested final trigger status: `BLOCKED`

Reason: backend and API behavior pass, but the required visible Google Chrome acceptance did not produce rendered exact-six duplicate row evidence. Coordinator should route this back for browser-flow investigation or authorize another QA run with a resolved Chrome/UI verification path.

Next Agent: Coordinator
