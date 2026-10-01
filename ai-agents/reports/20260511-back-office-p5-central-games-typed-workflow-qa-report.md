# back-office-p5-central-games-typed-workflow - QA Report

## Result

Focused QA result: PASS.

`central:games` is a completion candidate after this implementation. Coordinator can decide whether to promote the row to complete.

## Scope

Tested only:

```text
central:games
/admin/central/games
```

No Customer frontend was used. No implementation files were edited by QA.

## HEAD Under Test

```text
95519edd9754a34b1dca02aab60634d6201bfa2f
```

Implementation commit under test:

```text
1a79d3351135622984816eb4ef0469a9315149cf
```

BO handoff commit:

```text
695978d28d2dbd02b1af673f3deabee485ff56a6
```

Implementation diff reviewed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
```

## Docker Validation

Artifact directory:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/
```

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.txt` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.txt` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.txt`, `validation/migrate-fresh-seed-before-qa.txt` |
| `docker compose run --rm platform-api php artisan test --filter=CentralGameTest` | PASS, 1 test / 25 assertions | `validation/phpunit-central-game.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 tests / 26 assertions | `validation/phpunit-admin-menu.txt` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.txt` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.txt` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.txt` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-recreate.txt` |

## API Evidence

Evidence:

```text
api/central-games-api-evidence.php
api/central-games-api-evidence.json
```

API workflow used safe local game code `p5_games_api_<run>`.

| Check | HTTP | Scope / idempotency | Result |
| --- | ---: | --- | --- |
| `GET /admin/central/games?limit=20` | 200 | central | List loaded. |
| `POST /admin/central/games` | 201 | central + idempotency present | Draft game created. |
| `GET /admin/central/games/{game_id}` | 200 | central | Created detail loaded. |
| `PATCH /admin/central/games/{game_id}` | 200 | central + idempotency present | Draft -> open update succeeded. |
| `POST /admin/central/games/{game_id}/close` | 200 | central + idempotency present | Open -> closed succeeded. |
| `POST /admin/central/games/{game_id}/archive` | 200 | central + idempotency present | Closed -> archived succeeded. |
| `GET /admin/central/games?status=archived&limit=20` | 200 | central | Archived row returned. |

## Browser Evidence

Evidence:

```text
browser/browser-summary.json
browser/central-games-list-before-create.png
browser/central-games-create-modal.png
browser/central-games-list-after-create.png
browser/central-games-detail-after-create.png
browser/central-games-update-modal.png
browser/central-games-detail-after-update.png
browser/central-games-close-modal.png
browser/central-games-detail-after-close.png
browser/central-games-archive-modal.png
browser/central-games-detail-after-archive.png
browser/central-games-archived-filter.png
browser/central-games-reward-published-empty.png
```

Browser workflow used safe local game code `p5_games_ui_1b12dq`.

| Check | Result |
| --- | --- |
| Real central BO menu opened `/admin/central/games` | PASS, menu link count 2. |
| List API-backed UI | PASS, list rendered and captured `GET /api/v1/admin/central/games?limit=20`. |
| Create modal typed fields | PASS, fields: Game code, Game name, Draw at, Close at, Initial status. `draw_at` and `close_at` are `datetime-local`; status options are blank/draft/open. |
| Create required-field guard | PASS, Confirm disabled initially and enabled after required fields. |
| Create submission | PASS, `POST /api/v1/admin/central/games` returned 201 with `x-admin-scope: central` and idempotency key present. |
| Created list/detail | PASS, row appeared as Draft; Detail opened from real row and showed code/name/draw/close/status. |
| Update modal typed fields | PASS, fields: Game code, Game name, Draw at, Close at, Lifecycle transition. Transition options include blank/open/reward_recorded/reward_checking/reward_verified/reward_published. |
| Update submission | PASS, `PATCH /api/v1/admin/central/games/{game_id}` returned 200 with central scope and idempotency key present; valid draft -> open transition succeeded. |
| Close confirmation | PASS, modal showed game context, required reason, and disabled Confirm before reason. Execution returned 200 and final detail showed `closed`. |
| Archive confirmation | PASS, modal showed game context, required reason, and disabled Confirm before reason. Execution returned 200 and final detail showed `archived`. |
| Hard refresh | PASS, archived detail hard refresh retained authenticated route and did not render login. |
| Filter/empty behavior | PASS, archived filter returned the QA game; reward_published filter rendered coherent empty state with no error alert. |

Captured browser write requests all included `x-admin-scope: central`, no `x-tenant-id`, and an idempotency key:

```text
POST /api/v1/admin/central/games
PATCH /api/v1/admin/central/games/{game_id}
POST /api/v1/admin/central/games/{game_id}/close
POST /api/v1/admin/central/games/{game_id}/archive
```

Observed browser console warnings are the known BO shell Vue hydration mismatch warnings. They did not block menu navigation, typed modals, API submission, detail refresh, close/archive actions, or filters.

## Status Transition Note

The update modal exposes forward lifecycle targets and explains that backend validation allows only the next valid transition. QA selected the safe valid transition `draft -> open`. No invalid transition was submitted in browser QA.

## Defects

No new P1/P2/P3 product defects found in this focused QA.

## Redaction

Artifacts were checked for seeded password literals, bearer-token values, access/refresh token JSON values, support token patterns, and private key markers. Evidence contains only safe fixture ids/codes, request paths, scope/idempotency presence, payload key names, status summaries, and screenshots.

## Unrelated Dirty Workspace Files Observed

Left untouched:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

New files created only in the allowed QA report/artifact paths for this task.

## Routing

Route back to Coordinator for promotion decision on:

```text
central:games
```
