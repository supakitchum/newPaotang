# QA Report

## Task

Task: `stock-generation-realtime-progress-qa`

Result: `PASS WITH RISK`

Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`

Current HEAD: `594a3fb7f0a85fbb2f867cad979bcf50343b6b7f`

`origin/develop`: `594a3fb7f0a85fbb2f867cad979bcf50343b6b7f`

Backend commit under test: `1f0c19b1d1dbd0502a7cbd40cb3dbd709fcfb1f4`

BO commit under test: actual git commit `3cc1ed0f825eeed5fa591fa9e921ea65a71d99ee`

## Scope Tested

- Backend realtime auth for central stock generation channels.
- Tenant/partner scope rejection through `AdminOperationsTest`.
- Backend event dispatch and payload coverage through `CentralStockTest`.
- BO removal of active 5-second `generation-batches` polling.
- BO realtime subscription/auth/reconnect/unsubscribe/fallback wiring.
- BO lint/test/build.
- OpenAPI YAML parse.
- Authenticated BO page smoke for `/admin/central/stock-generation`.
- Runtime restore and login smoke.

## Commands Run

All runtime/test/build commands were run through Docker.

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=AdminOperationsTest --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office sh -lc '<realtime/polling structural check>'
docker compose -p newpaotang run --rm platform-api sh -lc '<OpenAPI YAML parse>'
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
curl --max-time 10 -i -s http://localhost:8000/api/v1/auth/admin/login ...
```

Artifacts: `ai-agents/reports/artifacts/20260516-stock-generation-realtime-progress-qa/`

## Test Results

| Area | Result | Evidence |
| --- | --- | --- |
| Baseline | PASS | HEAD equals `origin/develop`; `git diff --check` passed. |
| Commit presence | PASS WITH NOTE | Backend commit is on `origin/develop`; BO code commit exists and is on `origin/develop`, but BO handoff full hash has a typo. |
| Test DB isolation | PASS | Destructive reset used `APP_ENV=testing` and `DB_DATABASE=newpaotang_test`. Runtime DB `newpaotang` was not wiped. |
| Backend channel auth | PASS | `AdminOperationsTest` passed 8 tests / 116 assertions, including stock generation realtime channel permission checks. |
| Backend events/payload | PASS | `CentralStockTest` passed 6 tests / 219 assertions, including async generation realtime progress events and large async generation. |
| BO lint/test/build | PASS | `npm run lint`, `npm run test`, `npm run build`, and `check-stock-summary-widgets.mjs` passed. |
| 5-second polling removal | PASS | Structural checks found no `pollIntervalMs: 5000` or `window.setInterval`; fallback is `60000ms`, clamped to `30000ms`, and uses `setTimeout`. |
| BO realtime wiring | PASS | Static checks found game channel subscription, `/admin/central/realtime/auth`, `pusher:subscribe`, `pusher:unsubscribe`, ping/pong, reconnect snapshot, and manual refresh wiring. |
| Browser page smoke | PASS WITH RISK | Authenticated `/admin/central/stock-generation` rendered and showed `Fallback 60s`. Local runtime has no realtime URL configured. |
| OpenAPI | PASS | `docs/openapi.yaml` parsed successfully in Docker. |
| Runtime restore/login smoke | PASS | `db:seed` passed; `platform:smoke` showed app/database/cache/monitoring-defaults/seeded-logins `ok`; `/login` returned 200 after Nuxt warm-up; `/admin/login` returned 302 to `/login`; seeded central admin API login returned 200. |
| Artifact credential scan | PASS | Current QA artifacts contain no literal seeded passwords, auth header values, key material, or token values. |

Note: I initially ran `CentralStockTest` and `AdminOperationsTest` in parallel against the same `newpaotang_test` database. They raced inside Laravel refresh/migration setup and failed with duplicate/missing table errors. I reset `newpaotang_test` and reran both sequentially; the sequential results passed and are the results used for this QA decision.

## Defects

### Finding 1 (ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md) [P3]

BO handoff lists implementation commit `3cc1ed0c22645be585353fe1ec9a506299e18d4b`, but `git` reports no such commit. The actual committed BO implementation under the same short hash is `3cc1ed0f825eeed5fa591fa9e921ea65a71d99ee`, and it is present on `origin/develop`.

Impact: QA start-gate traceability is weakened because the full commit hash in the handoff cannot be resolved directly.

Owner recommendation: Coordinator should ask BO/Orchestrator to correct the handoff hash if strict traceability cleanup is required.

## Risks / Not Tested

- Full websocket runtime evidence is not proven in this local stack. Backend local/dev broadcasting defaults to `BROADCAST_CONNECTION=log`, BO runtime config has `adminRealtimeUrl: ""`, and the Reverb deployment docs still mark production websocket delivery as blocked until runtime/host/TLS/scaling/secret evidence exists.
- Direct browser network proof that `generation-batches` is not called every 5 seconds could not be captured from the in-app browser automation surface because resource timing/fetch/XHR APIs are not exposed there, and `platform-api` container logs did not emit HTTP access lines during the observation window.
- The authenticated BO page did prove the no-Reverb local behavior surfaces as `Fallback 60s`; structural checks prove no 5-second polling path remains, but this is not equivalent to end-to-end websocket event receipt.
- No runtime data-mutating browser generation flow was executed because QA rules prohibit mutating the shared runtime DB without explicit Coordinator decision or isolated QA runtime.

## Runtime Restore / Login Smoke

- Runtime seed: passed with `php artisan db:seed --no-interaction`.
- `platform:smoke`: `app: ok`, `database: ok`, `cache: ok`, `queue: redis`, `monitoring-defaults: ok`, `seeded-logins: ok`.
- Back-office service was stopped, removed, and recreated after build/browser QA.
- `/login`: first request immediately after recreate returned transient Nuxt warm-up 503; retry after warm-up returned HTTP 200.
- `/admin/login`: HTTP 302 to `/login`, with no bad redirect loop.
- Seeded central admin API login: HTTP 200.

## Recommendation

Do not mark this as clean `PASS` until an environment with configured Reverb/websocket runtime can prove real `stock.generation.progress.updated` events are received in BO and that `generation-batches` is not called every 5 seconds under an active batch.

For local integrated QA, the backend/BO implementation is acceptable as `PASS WITH RISK`: Docker tests pass, channel auth and event dispatch are covered, 5-second polling is removed structurally, fallback is low-frequency, and runtime login is restored.

## Next Agent

Coordinator
