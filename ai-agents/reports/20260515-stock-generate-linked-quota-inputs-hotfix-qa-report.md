# QA Report

## Task

`stock-generate-linked-quota-inputs-hotfix-qa`

Result: PASS

No Coordinator-routable defects found.

## Scope Tested

Validated the BO hotfix for Stock Generation linked quota inputs and current-game defaulting.

- Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- Current HEAD: `1d360be58629d798ba4de3f4ada131b7e6c8cc18`
- `origin/develop`: `1d360be58629d798ba4de3f4ada131b7e6c8cc18`
- BO implementation commit under test: `15ddf0a7bdd073a2b94e633a8b99bad50f1e6e62`
- BO handoff: `ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-bo-handoff.md`

The BO commit is present on:

```text
origin/codex/stock-generate-linked-quota-inputs-hotfix-bo
origin/codex/stock-generate-linked-quota-inputs-hotfix-qa-dispatch
origin/develop
```

## Commands Run

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
git branch -r --contains 15ddf0a7bdd073a2b94e633a8b99bad50f1e6e62
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang up -d --force-recreate back-office
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office
curl --max-time 10 -i -s http://localhost:3100/login
curl --max-time 10 -i -s http://localhost:3100/admin/login
```

Browser QA used the Codex in-app browser against:

```text
http://localhost:3100/admin/central/stock-generation
```

## Test Results

PASS.

| Check | Result | Evidence |
| --- | --- | --- |
| BO start gate | PASS | BO handoff exists and commit is reachable from `origin/develop`. |
| BO validation | PASS | `build`, `lint`, `test`, Nuxt `build`, and stock structural script passed. Nuxt emitted the known Node `DEP0180` warning but exited 0. |
| Test DB isolation | PASS | Destructive migration ran only against `newpaotang_test` with `APP_ENV=testing` and `--env=testing`. |
| Controlled valid backend path | PASS | `CentralStockTest`: 3 passed, 148 assertions. Covers valid generate path and backend quota validation. |
| Authenticated Stock Generation page | PASS | Logged into central BO and opened `/admin/central/stock-generation`. |
| Current game default | PASS | Page Game selector selected the single current game by default. |
| ALL removed from Stock Generate game selector | PASS | Generate modal `Current game *` selector had one option only: the current game. No `ALL` option. |
| Empty/all-game submit prevention | PASS | Initial modal with current game but no quota had `Confirm` disabled and inline message: enter total tickets or quota before submitting. No empty/all-game game value was available in the modal. |
| 2-tail linked values | PASS | Typing `2-tail=20` immediately set `3-tail=2`, `3-front=2`, and `total=2000`. |
| 3-tail linked values | PASS | Typing `3-tail=3` immediately set `2-tail=30`, `3-front=3`, and `total=3000`. |
| 3-front linked values | PASS | Typing `3-front=4` immediately set `2-tail=40`, `3-tail=4`, and `total=4000`. |
| Invalid 2-tail inline validation | PASS | Typing `2-tail=25` showed `2-tail quota must be divisible by 10.` and `2-tail quota must equal 10 x 3-tail quota.` before submit; Confirm stayed disabled. |
| Valid UI submit guard | PASS | With `3-tail=2` and a reason, modal showed `2-tail=20`, `3-front=2`, `total=2000`, and `Confirm` became enabled. QA did not click Confirm to avoid runtime data mutation; controlled backend path is covered in test DB. |
| Summary widget regression | PASS | Summary widgets rendered on Stock Generation page for the current game and showed `total_count=1000`, coverage cards, and status totals aligned to the selected game. |
| Legacy fields absent | PASS | Structural check confirmed `start`, `count`, `range`, and `number_digits` generation fields did not return. |
| Credential/artifact scan | PASS | Current QA artifacts contain no literal seeded passwords, bearer tokens, auth headers, private keys, or token values. Protected credential-bearing artifact from the prior task was untouched. |
| Runtime restore/login smoke | PASS | See dedicated section below. |

## Artifacts

Artifacts directory:

```text
ai-agents/reports/artifacts/20260515-stock-generate-linked-quota-inputs-hotfix-qa/
```

Key evidence:

```text
validation/start-gate-and-diff-check.log
back-office/docker-build-back-office.log
back-office/npm-lint.log
back-office/npm-test.log
back-office/npm-build.log
back-office/check-stock-summary-widgets.log
back-office/structural-linked-quota-hotfix-qa-rerun.log
backend/migrate-fresh-test-db.log
backend/phpunit-central-stock-controlled-valid-path.log
browser/stock-generation-route-current-game-summary-dom.txt
browser/stock-generation-route-current-game-summary.png
browser/stock-generation-generate-modal-initial-dom.txt
browser/stock-generation-generate-modal-initial.png
browser/linked-quota-field-states.json
browser/linked-quota-invalid-2tail.png
browser/stock-generation-valid-submit-guard-states.json
browser/stock-generation-valid-submit-enabled-not-submitted.png
runtime/runtime-db-seed.log
runtime/runtime-platform-smoke.log
runtime/runtime-login-smoke.log
scans/artifact-secret-scan.log
```

## Authenticated BO Workflow Evidence

Authenticated route:

```text
http://localhost:3100/admin/central/stock-generation
```

Observed current-game default:

```text
Game selector options: ["งวดวันที่ 16 พ.ค. 2569 (16052569) (Current)"]
Selected value: gam_01KRNMWTAHF07YGN365E00NW42
```

Observed summary widgets:

```text
Total tickets: 1,000
2-tail coverage: 100 / 100, min 10, max 10, tickets 1,000
3-tail coverage: 1,000 / 1,000, min 1, max 1, tickets 1,000
3-front coverage: 1,000 / 1,000, min 1, max 1, tickets 1,000
Status totals: 1,000
```

Observed Generate modal:

```text
Current game * selector had exactly one option: current game.
No ALL option was available in the Stock Generate selector.
Confirm was disabled before quota input.
```

## Linked Quota Input Evidence

Observed browser states:

```text
2-tail=20  -> total=2000, back2=20, back3=2, front3=2
3-tail=3  -> total=3000, back2=30, back3=3, front3=3
3-front=4 -> total=4000, back2=40, back3=4, front3=4
2-tail=25 -> inline validation before submit, Confirm disabled
```

Invalid 2-tail messages:

```text
2-tail quota must be divisible by 10.
2-tail quota must equal 10 x 3-tail quota.
```

Valid non-submitted UI state:

```text
3-tail=2 -> total=2000, back2=20, back3=2, front3=2
Reason entered
Confirm enabled
```

QA intentionally did not click Confirm in the browser to avoid mutating runtime stock data. The accepted backend path was validated in controlled test DB via `CentralStockTest`.

## Test DB Isolation Evidence

Destructive DB command used:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend tests used:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime DB `newpaotang` was not wiped or destructively migrated.

## Runtime Restore / Login Smoke

PASS.

Runtime restore was non-destructive against `newpaotang`.

```text
php artisan db:seed --no-interaction: PASS
php artisan platform:smoke: app/database/cache/monitoring-defaults/seeded-logins ok
back-office stop/rm/up after build/browser QA: PASS
GET /login: HTTP 200
GET /admin/login: HTTP 302 Location /login
POST /api/v1/auth/admin/login: HTTP 200, access token present, central scope present
```

## Defects

None.

## Risks / Not Tested

- Browser QA verified the valid UI state up to enabled Confirm but did not click Confirm, to avoid runtime stock mutation. Backend acceptance for the valid generate payload was covered through the isolated test DB feature test.
- The page route that implements the hotfix is `/admin/central/stock-generation`; the raw `/admin/central/stock` route remains a general stock view with an `All` list filter.
- Git reported an existing gc housekeeping warning during fetch; QA did not modify `.git/gc.log` or run prune.

## Recommendation

Coordinator may accept this hotfix as QA PASS within the local Docker validation boundary.

## Next Agent

Coordinator
