# QA Report

## Task

`hotfix-quota-session-layout-qa`

Result: PASS

QA validated the latest `origin/develop` hotfix set for stock generation quota contract, BO generate-stock wiring, admin session replacement, lottery image layout defaults including `logo_num_set`, BO lottery image page ordering, OpenAPI/docs alignment, and mandatory runtime restore/login smoke.

## Scope Tested

- Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`
- HEAD under test: `b890746fe62defc4ce4d6de1f980ed210218e2c4`
- `origin/develop`: `b890746fe62defc4ce4d6de1f980ed210218e2c4`
- Required hotfix commits present on `origin/develop`:
  - `d7ec7d5b4791190ebff660a3bc2391a7d6f0039f`
  - `3fd6168`
  - `7a4725a`
  - `bf56bfd`
  - `b9880dc`

Read source-of-truth task/handoff/docs and inspected affected backend tests, OpenAPI, BO operations catalog, admin session behavior, and lottery image layout code.

Artifacts created under:

```text
ai-agents/reports/artifacts/20260515-hotfix-quota-session-layout-qa/
```

## Commands Run

| Command | Result |
| --- | --- |
| `git fetch --all --prune` | PASS, with existing git gc warning about unreachable loose objects. |
| `git status --short --branch` | PASS, clean at start. |
| `git rev-parse HEAD` / `git rev-parse origin/develop` | PASS, both `b890746fe62defc4ce4d6de1f980ed210218e2c4`. |
| `git diff --check` | PASS. |
| `docker compose -p newpaotang build platform-api back-office` | PASS. |
| `docker compose -p newpaotang up -d postgres valkey platform-api back-office` | PASS. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=CentralStockTest` | PASS, 2 tests / 89 assertions. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=LotteryImageTest` | PASS, 3 tests / 89 assertions. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=LotteryImageOperationsTest` | PASS, 13 tests / 390 assertions. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=AdminAuthTest` | PASS, 10 tests / 89 assertions. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest` | PASS, 6 tests / 169 assertions. |
| `docker compose -p newpaotang run --rm back-office npm run lint` | PASS. |
| `docker compose -p newpaotang run --rm back-office npm run build` | PASS. |
| `docker compose -p newpaotang run --rm back-office node scripts/check-lottery-image-operations.mjs` | PASS. |
| `docker compose -p newpaotang run --rm back-office node scripts/check-lottery-branding.mjs` | PASS. |
| Dockerized custom BO structural check | PASS. |
| Dockerized Ruby OpenAPI parse/schema check | PASS. |
| Runtime restore/login smoke commands | PASS. |
| Artifact secret scan | PASS, no matches. |

## Test Results

### Stock Quota Contract

PASS

`CentralStockTest` passed and covers quota validation including removed legacy fields, valid `total_count`, valid manual quota fields, invalid quota ratios, synchronous row cap, generated row count, and 6-digit front/back pairing distribution.

OpenAPI parse/schema check confirmed `/admin/central/stock/generate` request properties are:

```text
back2_count_per_number
back3_count_per_number
front3_count_per_number
game_id
reason
total_count
```

The same OpenAPI check confirmed removed legacy request fields are absent from the generate request schema.

### BO Generate Stock Evidence

PASS

BO structural check confirmed the `Generate stock` action posts to `/admin/central/stock/generate`, exposes `total_count`, `back2_count_per_number`, `back3_count_per_number`, and `front3_count_per_number`, and omits legacy `start_number`, `count`, `requested_count`, `number_digits`, and range fields.

`docs/back-office-crud-coverage.md` describes quota-based generate fields for total count or manual 2-tail/3-tail/3-front counts.

### Admin Session Replacement Evidence

PASS

`AdminAuthTest` passed and includes:

- admin login returns `expires_in=28800`
- second admin login revokes the previous session
- replaced previous session returns `admin_session_replaced`
- logout idempotency guard remains intact

BO lint passed with hydration/auth restore guardrails. Source inspection confirmed BO stores replacement-session notice and redirects to `/login` instead of leaving the admin layout stuck on restore.

### Lottery Image Layout And `logo_num_set`

PASS

`LotteryImageTest` and `LotteryImageOperationsTest` passed. Coverage includes central image generation, partner-branded generation, no partner overlays on central images, layout persistence, preview layout overrides, and branding preview behavior.

Source and structural evidence confirmed:

- `LotteryImageGenerator::DEFAULT_LAYOUT` includes the adopted layout baseline.
- Migration `2026_05_15_000004_adopt_current_lottery_image_layout_defaults.php` includes `logo_num_set`.
- Reset/default migration remains aligned with the same baseline.
- `logo_num_set` has independent x/y/width/height layout values.
- `logo_num_set` renders from `logo_qr_storage_path`, so it reuses the partner `logo_qr` asset.
- Partner branding upload UI has no separate `logo_num_set` upload slot.
- BO layout editor labels the slot as `Logo Num Set`.
- Docs and OpenAPI mention `logo_num_set` and its reuse of `logo_qr`.

### BO Lottery Image Page Layout

PASS

Custom BO structural check confirmed:

- `Image Zip Import` appears before `Background Asset Sets`.
- Both panels are full-width (`col-12`).
- Background Asset Sets still has pagination, selection, sorting, and bulk status actions.

Existing lottery image and branding structural scripts also passed.

### OpenAPI

PASS

Dockerized Ruby YAML parse succeeded and the stock generate request schema matched the quota contract.

### Credential / Artifact Scan

PASS

Artifact scan returned no secret/token/key pattern matches:

```text
0 bytes ai-agents/reports/artifacts/20260515-hotfix-quota-session-layout-qa/scans/artifact-secret-scan.log
```

## Defects

None.

## Risks / Not Tested

- Authenticated BO browser UAT was not performed because the task did not provide a browser session or require destructive real-menu stock generation through the UI.
- Docker build emitted npm audit vulnerability counts during dependency installation and Nuxt emitted the known `fs.Stats` deprecation warning; both are existing tooling/dependency signals and did not fail the requested validation.
- `apps/platform-api/.phpunit.result.cache` was modified by Docker PHPUnit runs as a test side effect and was left untouched.

## Runtime Restore / Login Smoke

PASS

Ran the required restore/login checklist after DB-touching tests and BO build:

| Check | Result |
| --- | --- |
| `docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction` | PASS. |
| `docker compose -p newpaotang exec -T platform-api php artisan platform:smoke` | PASS: `app`, `database`, `cache`, `monitoring-defaults`, and `seeded-logins` all ok; queue reported `redis`. |
| Seeded central admin login API | PASS: HTTP 200. |
| Back-office restart/recreate after build | PASS: `stop`, `rm -f`, `up -d back-office`. |
| `curl --max-time 5 -i -s http://localhost:3100/login` | PASS: HTTP 200 and login shell rendered. |
| `curl --max-time 5 -i -s http://localhost:3100/admin/login` | PASS: HTTP 302 `location: /login`; no `redirect=/admin/login`. |
| Back-office runtime error scan | PASS: no internal server error / Nuxt path / 500 markers. |

## Recommendation

Coordinator can accept this QA PASS for `hotfix-quota-session-layout-qa`.

Unrelated dirty files were not cleaned, staged, reverted, or committed. Only QA-owned report/artifact paths were created, plus the PHPUnit cache side effect noted above.

## Next Agent

Coordinator
