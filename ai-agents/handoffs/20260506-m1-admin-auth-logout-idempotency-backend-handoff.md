# m1-admin-auth-logout-idempotency - Backend Develop Handoff

## What Was Done

- Fixed QA defect D1 by enforcing `Idempotency-Key` on `POST /api/v1/auth/admin/logout`.
- Added project-format validation errors for invalid logout idempotency headers:
  - missing `Idempotency-Key`
  - shorter than 8 characters
  - longer than 128 characters
- Ensured validation failure returns `validation_failed` and does not revoke the current admin session.
- Kept this revision limited to header contract enforcement only.
- Did not implement general idempotency persistence, replay, or conflict semantics.
- Updated successful logout coverage to send a valid `Idempotency-Key`.
- Added focused tests for missing, too-short, too-long, and valid idempotency keys.

## Files Changed

- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php`
- `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`

## Validation

All validation commands were run through Docker Compose against the `platform-api` service.

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuth
# PASS: 9 tests, 78 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminMenu
# PASS: 5 tests, 19 assertions
```

```sh
docker compose run --rm platform-api php artisan test
# PASS: 29 tests, 141 assertions
```

## Known Risks

- This revision validates the required header only. It intentionally does not store idempotency keys or replay stored responses, per task out-of-scope.
- Validation currently returns HTTP `422` with the project `validation_failed` error shape. `docs/openapi.yaml` lists the required header but does not define a dedicated logout validation response code.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator
