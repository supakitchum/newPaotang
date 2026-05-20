# QA Report - retire-physical-stock-flow

## Task

Result: **PASS**

Task: `retire-physical-stock-flow-qa`

Validated active retirement of the physical/partner-quota stock flow while keeping virtual stock generation, percent allocation, partner/customer visibility, partner sync metadata, and lazy materialization behavior working.

## Worktree / HEAD

```text
worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD tested: 2f55196abff7314df1580da5253c4ca5a521da2d
origin/develop: 2f55196abff7314df1580da5253c4ca5a521da2d
git status at start gate: ## develop...origin/develop
start gate note: ai-agents/handoffs/20260520-qa-agent-new-chat-handoff.md was untracked and was the user-provided QA handoff for this chat.
```

Commits under test:

```text
Backend: 9876c9226410becc13136dfc7308bb3b721b1137
Backend: c2774dc186f262b94ddac8130c458cc7b7a6101b
BO: 3d46de9e5f656dcc8e480dc338302219315ea783
BO: 40e03dc1edfedb2cb81db4b00b20f8489c67cba7
```

## Scope Tested

- API rejects retired stock generation modes/fields: `quota_random`, `quota`, `physical`, `total_count`, `back2_count_per_number`, `back3_count_per_number`, `front3_count_per_number`, `start_number`, `count`, `number_digits`.
- API rejects allocation create payloads containing `requested_count`.
- API accepts `allocation_percent` and writes `partner_stock_allocations` plus `stock_partner_distributions`.
- Virtual allocation does not bulk assign `stock_items` and does not create `partner_stock_allocation_items` as active source-of-truth rows.
- Customer search/reservation visibility uses active `stock_partner_distributions`, and reservation lazily materializes `stock_items` / `local_stock_items`.
- `GET /partner-sync/allocations` returns virtual allocation/distribution metadata.
- `GET /admin/central/partner-quotas` remains permissioned legacy read-only; `POST` returns `410 retired_flow`.
- Authenticated BO navigation no longer shows Partner Quotas under Partner Operations.
- Stale BO deep link `/admin/central/partner-quotas` shows retired guidance and no create/update write path.
- BO structural checks prove Partner Quotas write operations and `requested_count` are absent from active operation catalog, while `allocation_percent` and virtual-only stock generation remain present.

## Commands Run

All app/test/build/migration commands used Docker.

```sh
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git diff --check
docker compose -p newpaotang build platform-api back-office
docker compose -p newpaotang up -d postgres valkey platform-api back-office
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerSyncAllocationTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerQuotaTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=LocalStockSyncTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang stop back-office && docker compose -p newpaotang rm -f back-office && docker compose -p newpaotang up -d back-office
```

## Test Results

Backend focused tests:

```text
CentralStockTest: PASS, 5 tests / 161 assertions
CentralAllocationTest: PASS, 4 tests / 116 assertions
PartnerSyncAllocationTest: PASS, 1 test / 18 assertions
PublicStockSearchTest: PASS, 5 tests / 72 assertions
VirtualStockRealtimeTest: PASS, 7 tests / 227 assertions
PartnerQuotaTest: PASS, 1 test / 15 assertions
LocalStockSyncTest: PASS, 1 test / 25 assertions
```

BO validation:

```text
npm run lint: PASS
npm run test: PASS
node scripts/check-stock-summary-widgets.mjs: PASS
npm run build: PASS
```

Nuxt build emitted the existing Node `DEP0180` deprecation warning and exited `0`.

Focused API/browser evidence:

```text
central admin API login: 200
GET /api/v1/admin/central/partner-quotas: 200
POST /api/v1/admin/central/partner-quotas: 410
POST /api/v1/admin/central/partner-quotas error.code: retired_flow
BO authenticated login: success, landed on /admin/central/dashboard
BO Partner Operations menu children: Partners, Partner Provisioning, Partner Monitoring, Partner Usage, Billing Plans, Alert Policies, Alert Events
BO stale /admin/central/partner-quotas deep link: showed retired guidance copy and no create/update actions
```

## Defects

None found.

## Risks / Not Tested

- Full platform test suite was not run; QA ran the focused Docker filters required by the task.
- No destructive command was run against runtime DB `newpaotang`. Destructive migration was run only with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- `apps/platform-api/.phpunit.result.cache` was modified by PHPUnit during QA. It was not staged or committed.

## Runtime Restore / Login Smoke

Runtime restore commands:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office
docker compose -p newpaotang rm -f back-office
docker compose -p newpaotang up -d back-office customer
```

Runtime smoke result:

```text
app: ok
database: ok
cache: ok
queue: redis
monitoring-defaults: ok
base-lottery-numbers: ok
seeded-logins: ok
```

Login smoke:

```text
test DB used for destructive commands: newpaotang_test
runtime DB newpaotang wiped: no
customer /login: 200
back-office /login: 200
back-office /admin/login: 302 Location /login
back-office /admin/login follow: 200
central admin API login: 200
back-office restarted/recreated after build/browser QA: yes
```

## Recommendation

Approve `retire-physical-stock-flow` for Coordinator review. Backend and BO acceptance criteria passed with isolated test DB evidence, authenticated BO evidence, and runtime restore/login smoke.

## Next Agent

Coordinator
