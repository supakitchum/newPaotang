# QA Report: Stock Generation Summary Widgets

## Result

PASS

No Coordinator-routable defects found for `stock-generation-summary-widgets-qa`.

## Scope

Validated the completed Backend + Back Office stock generation summary widget work after the start gate was satisfied.

- Backend handoff: `ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md`
- Back Office handoff: `ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md`
- QA dispatch: `ai-agents/handoffs/20260515-stock-generation-summary-widgets-qa-dispatch-orchestrator-handoff.md`
- Worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- Commit tested: `f534e0a8b1ce928e26a33999077f2e42b939502c`

The earlier start-gate blocker is resolved. The BO handoff now exists and the BO implementation commit is reachable from `origin/develop`.

## Evidence

Artifacts:

`ai-agents/reports/artifacts/20260515-stock-generation-summary-widgets-qa/`

Key logs:

- `backend/migrate-fresh-test-db.log`
- `backend/phpunit-central-stock.log`
- `backend/route-list-stock-summary.log`
- `back-office/npm-lint.log`
- `back-office/npm-test.log`
- `back-office/npm-build.log`
- `back-office/check-stock-summary-widgets.log`
- `back-office/structural-stock-summary-widgets-qa-final.log`
- `openapi/openapi-stock-summary-parse-contract-rerun.log`
- `browser/stock-page-authenticated-dom.txt`
- `browser/stock-page-game-selected-dom.txt`
- `browser/runtime-api-summary-match.log`
- `runtime/runtime-db-seed.log`
- `runtime/runtime-platform-smoke.log`
- `runtime/runtime-login-smoke.log`
- `scans/artifact-secret-scan.log`

Browser screenshots:

- `browser/stock-page-authenticated.png`
- `browser/stock-page-game-selected.png`

## Validation Summary

| Check | Result | Notes |
| --- | --- | --- |
| Start gate | PASS | Backend + BO handoffs present; implementation commits reachable from `origin/develop`. |
| Test DB isolation | PASS | Destructive migration ran only with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`. |
| Backend route/contract | PASS | `GET api/v1/admin/central/stock/summary` is registered. |
| Backend focused tests | PASS | `CentralStockTest`: 3 passed, 148 assertions. Covers central scope, permission behavior, filters, empty state, 1000/3000 aggregate coverage, and generate flow regression. |
| OpenAPI parse/contract | PASS | Path parses; `game_id`, `batch_id`, required status counts, `empty`, and back2/back3/front3 coverage schemas are documented. |
| Back Office lint/test/build | PASS | `npm run lint`, `npm run test`, and `npm run build` passed in Docker. |
| Back Office widget wiring | PASS | Summary endpoint, game/batch filter, refresh key, loading/error/empty states, and quota generate fields verified. |
| Browser authenticated UI | PASS | `/admin/central/stock` rendered authenticated Central Stock page; no-game state displayed before selecting game. |
| Browser game filter/widgets | PASS | After selecting seeded game and applying filters, widgets rendered Total tickets, coverage cards, status totals, and table rows for the selected game. |
| Runtime API/UI value match | PASS | Runtime summary API returned `total_count=1000`, status total 1000, back2 100/100 min/max 10, back3 1000/1000 min/max 1, front3 1000/1000 min/max 1; UI displayed the same coverage totals. |
| Generate Stock regression | PASS | Existing generate flow covered by focused backend test and BO structural check confirms quota fields remain and legacy range fields are absent. |
| Runtime restore/login smoke | PASS | Non-destructive seed, `platform:smoke`, BO recreate, `/login`, `/admin/login`, and central seeded login all passed. |
| Artifact/credential scan | PASS | Current QA artifacts contain no literal seeded passwords, bearer tokens, authorization headers, private keys, or token values. Credential-bearing artifact from the prior protected task was untouched. |

## Commands Run

```sh
git status --short --branch
git rev-parse HEAD
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang ps
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan route:list --path=admin/central/stock/summary --env=testing
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office node - <<'NODE'
docker run --rm -i -v /Users/supakit/WorkSpace/www/newPaotang:/repo -w /repo ruby:3.3-alpine ruby - <<'RUBY'
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 10 -i -s http://localhost:3100/login
curl --max-time 10 -i -s http://localhost:3100/admin/login
curl --max-time 10 -sS -o "$login_body" -w '%{http_code}' -H 'Content-Type: application/json' -X POST http://localhost:8000/api/v1/auth/admin/login -d "$login_payload"
rg -n --hidden -i "(access_token|refresh_token|bearer [a-z0-9._-]+|seeded password literals|password_hash|api_key|secret|private key|authorization:)" ai-agents/reports/artifacts/20260515-stock-generation-summary-widgets-qa || true
git status --short --branch
git diff --name-only
```

Browser checks were run through the Codex in-app browser against `http://localhost:3100/admin/central/stock`.

## Test DB Isolation Evidence

The only destructive database command was:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests also ran with:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime database `newpaotang` was not wiped or destructively migrated.

## Runtime Restore / Login Smoke

PASS.

Non-destructive runtime restore/login smoke completed:

- `php artisan db:seed --no-interaction`: PASS
- `php artisan platform:smoke`: `app: ok`, `database: ok`, `cache: ok`, `seeded-logins: ok`
- Back Office container stop/rm/up: PASS
- `GET /login`: HTTP 200
- `GET /admin/login`: HTTP 302 to `/login`
- `POST /api/v1/auth/admin/login`: HTTP 200, access token present, central scope present

## Defects

None.

## Risks / Notes

- Browser UAT uses local seeded runtime data. It verified the widget render and values for the seeded game currently available in runtime.
- A direct summary API call requires `X-Admin-Scope: central` with the bearer token; without that scope header the route correctly rejects with 403.
- Two exploratory QA helper checks initially used overly narrow assumptions and were rerun with corrected contract resolution/token checks. Final passing evidence is in the `*-final.log` and `*-rerun.log` artifacts listed above.

## Recommendation

Coordinator may accept the task as QA PASS for the local/Docker validation boundary.

Next agent: Coordinator.
