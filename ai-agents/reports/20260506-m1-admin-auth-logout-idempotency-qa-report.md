# QA Report

## Task

`20260506-m1-admin-auth-logout-idempotency-qa`

QA reran focused validation after Backend Develop revised admin logout to enforce the required `Idempotency-Key` header.

Backend handoff:

- `ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md`

## Scope Tested

- Reviewed the focused QA task, Backend revision task, Backend handoff, Coordinator QA review decision, previous QA report, QA role, global rules, stage gates, and file ownership rules.
- Reviewed source-of-truth docs relevant to this revision: `docs/openapi.yaml`, `docs/api-conventions.md`, `docs/docker-runtime-policy.md`, `docs/workspace-app-structure.md`, `document/07_SECURITY_ADMIN_PERMISSION.md`, and `document/09_AI_WORK_INSTRUCTIONS.md`.
- Inspected the Backend-reported changed files:
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php`
  - `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
  - `apps/platform-api/tests/Feature/AdminAuthTest.php`
- Verified `POST /api/v1/auth/admin/logout` now rejects missing, too-short, and too-long `Idempotency-Key` headers before revoking the admin session.
- Verified a valid `Idempotency-Key` allows logout and revokes the current session.
- Verified validation errors use the project error envelope and do not include token material.
- Checked that no general idempotency storage or replay semantics were introduced.
- Ran required Docker-only validation commands.

## Commands Run

```sh
find ai-agents/tasks ai-agents/handoffs ai-agents/reports ai-agents/decisions -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,260p' ai-agents/BOARD.md
rg -n "Next Agent|Target Agent|QA Tester|ready_for_qa|qa|revise|D1|Idempotency|admin-auth-menu-read" ai-agents/tasks ai-agents/handoffs ai-agents/decisions ai-agents/reports -S
sed -n '1,240p' ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-qa.md
sed -n '1,220p' ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md
sed -n '1,240p' ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-backend.md
sed -n '1,220p' ai-agents/decisions/20260506-m1-admin-auth-menu-read-qa-review-decision.md
sed -n '1,160p' ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-qa-task-orchestrator-handoff.md
sed -n '1,260p' ai-agents/roles/qa-tester.md
sed -n '1,260p' ai-agents/rules/global-rules.md
sed -n '1,260p' ai-agents/workflow/stage-gates.md
sed -n '1,260p' ai-agents/workflow/file-ownership.md
sed -n '1,360p' docs/api-conventions.md
sed -n '7049,7058p' docs/openapi.yaml
sed -n '1,220p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
sed -n '1,320p' apps/platform-api/tests/Feature/AdminAuthTest.php
git status --short apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php apps/platform-api/app/Shared/Auth/ApiErrorResponse.php apps/platform-api/tests/Feature/AdminAuthTest.php apps/customer apps/back-office docs document apps/platform-api/database apps/platform-api/routes
rg -n "idempot|Idempotency-Key|idempotency" apps/platform-api/app apps/platform-api/database apps/platform-api/routes apps/platform-api/tests docs/openapi.yaml docs/api-conventions.md
nl -ba apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php | sed -n '42,66p'
nl -ba apps/platform-api/app/Shared/Auth/ApiErrorResponse.php | sed -n '1,70p'
nl -ba apps/platform-api/tests/Feature/AdminAuthTest.php | sed -n '112,184p'
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
find apps/platform-api -maxdepth 1 -name '.phpunit.result.cache' -print
rm -f apps/platform-api/.phpunit.result.cache
```

Docker validation results:

```text
docker compose run --rm platform-api php artisan test --filter=AdminAuth: PASS, 9 tests, 78 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenu: PASS, 5 tests, 19 assertions
docker compose run --rm platform-api php artisan test: PASS, 29 tests, 141 assertions
```

## Test Results

`PASS`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| Missing `Idempotency-Key` on admin logout is rejected | PASS | `AdminAuthController::logout()` validates the header before revoke; focused test verifies `422 validation_failed`. |
| Too-short `Idempotency-Key` on admin logout is rejected | PASS | Focused test sends `short` and receives `422 validation_failed`; session remains active. |
| Too-long `Idempotency-Key` on admin logout is rejected | PASS | Focused test sends 129 characters and receives `422 validation_failed`; session remains active. |
| Valid `Idempotency-Key` allows logout and revokes session | PASS | Successful logout test now sends `logout-001`, receives `204`, and revoked token can no longer call `me`. |
| Validation errors use project error format | PASS | `ApiErrorResponse::validationFailed()` returns `error.code`, `message`, `details.fields`, and `request_id`. |
| Validation errors do not leak token material | PASS | Missing-header focused test asserts access/refresh tokens are absent from response; implementation only returns static header validation text. |
| Validation failure does not revoke the current session | PASS | Focused tests assert active access token remains; missing-header test also verifies `me` still returns `200`. |
| No general idempotency storage/replay semantics introduced | PASS | `rg` found no new idempotency storage/service/table usage in application/database/routes; only header validation and tests changed. |
| AdminAuth focused tests pass in Docker | PASS | 9 tests, 78 assertions. |
| AdminMenu regression tests pass in Docker | PASS | 5 tests, 19 assertions. |
| Full platform-api suite passes in Docker | PASS | 29 tests, 141 assertions. |
| No out-of-scope customer/back-office changes for this revision | PASS | `git status --short apps/customer apps/back-office` returned no output during QA. |
| No source-of-truth doc changes for this revision | PASS WITH RISK | Broader docs remain dirty from the milestone flow; Backend handoff did not list docs changes and this focused revision's changed files are limited to controller/helper/test. |
| Docker runtime policy followed | PASS | All application validation ran through `docker compose run --rm platform-api ...`; no host PHP/Composer/Artisan/Node commands were run. |

## Defects

None.

## Risks / Not Tested

- This revision intentionally validates the required header only. It does not implement idempotency persistence, response replay, or conflict semantics; the QA task explicitly marked those behaviors out of scope.
- `docs/openapi.yaml` requires the logout header but does not define a specific validation response for a missing/invalid header. Backend returns `422 validation_failed`, which matches `docs/api-conventions.md` validation shape.
- The worktree remains broadly dirty from previous milestone activity, and `apps/platform-api` is still untracked as a new tree. QA scoped review to the Backend-reported files plus out-of-scope path checks.
- PHPUnit generated `.phpunit.result.cache`; QA removed it after validation.

## Recommendation

Coordinator can approve the focused `m1-admin-auth-logout-idempotency` revision. D1 is fixed, focused/full Docker validation passes, and no new defects were found.

## Next Agent

Coordinator
