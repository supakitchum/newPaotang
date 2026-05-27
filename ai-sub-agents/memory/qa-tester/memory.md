# QA Tester Memory

Memory is cache, not source of truth. Trust current task, handoffs, docs, tests, and code over this file.

## Stable Context

- QA tests everything on test env/test DB before any local runtime DB update.
- QA browser acceptance must use real visible Google Chrome.
- Automated/destructive validation DB and visible browser runtime DB must be reported separately.
- Visible Chrome localhost may use runtime DB `newpaotang`; that is acceptable only as non-destructive browser coverage with fixture notes.
- QA reports go to Coordinator.
- QA requires a trigger file and worktree start gate before testing.

## Common Commands

```sh
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan migrate:fresh --seed --env=testing --no-interaction
docker compose -p newpaotang exec -T platform-api env APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test --env=testing
```

Use task-specific Docker commands for BO/customer validation.

## Known Patterns

- QA report must include test env/test DB evidence, visible Google Chrome evidence, runtime DB safety, defects, risks, and recommendation.
- QA report must name automated test DB, visible browser runtime DB, fixture creation, fixture cleanup, and browser API/DB proof.
- Recommendation values: `PASS`, `FAIL`, `PASS WITH RISK`, `BLOCKED`.

## Gotchas

- Never wipe/reset local runtime DB `newpaotang`.
- Missing visible Google Chrome evidence means no clean PASS for browser flow.
- Missing test env evidence means no clean PASS.
- In AUTO Mode, runner owns trigger status; QA writes requested final status in report.
- Missing proof of which API/DB visible Chrome uses means no clean PASS.
- Visible Chrome QA must record browser URL, API base URL, APP_ENV, DB_DATABASE, account/role, test data, and evidence path.
- Do not claim visible Chrome used `newpaotang_test` unless runtime wiring proves it.

## Last Useful Findings

- Runtime DB migration belongs to GitOps after Coordinator approval, not QA.
- For customer browser QA, a temporary visible Chrome profile with `--remote-debugging-port` can prove the browser reached the test-wired Nuxt route, but a clean PASS still needs rendered UI result evidence; if the DOM assertion times out, report BLOCKED or PASS WITH RISK rather than inferring success from backend API proof alone.

## Do Not Trust Without Rechecking

- Current app URLs and ports.
- Current seeded login accounts.
- Whether the latest dev handoff changed the test scope.
