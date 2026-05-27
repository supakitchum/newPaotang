# QA Browser Environment

Visible browser QA must declare the actual browser runtime environment. Automated/destructive validation must run against test env/test DB before any local runtime DB update.

## Required Browser

```text
Google Chrome app, visible to the user
```

Headless browser evidence is not enough for browser acceptance.

## Required Environment Declaration

Every QA task for browser behavior must declare:

```text
browser URL
frontend service
API base URL
APP_ENV
Automated Test DB
Visible Browser Runtime DB
tenant/domain
account/role
test data fixture
fixture creation method
fixture cleanup method
expected evidence path
```

## Default Local Test Values

Use task-specific values when provided. Otherwise use:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
automated test DB: newpaotang_test
visible browser runtime DB: declare actual DB used by running localhost service, often newpaotang
platform-api service: platform-api
back-office service: back-office
customer service: customer
evidence root: ai-sub-agents/reports/artifacts/YYYYMMDD-<task-key>/
```

## Automated Test DB Rule

Before browser acceptance, QA must run focused automated or API-level validation on test env/test DB when the task touches data, backend behavior, tenant behavior, or any risky flow.

Destructive commands are allowed only with:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
```

## Visible Browser Runtime DB Rule

Visible Chrome QA on localhost may use the local runtime DB `newpaotang` when that is what the running frontend/API services actually use.

This is acceptable only if QA records it as browser runtime coverage and keeps it non-destructive:

```text
no migrate:fresh/db:wipe/migrate:reset on newpaotang
no destructive cleanup on runtime DB
fixtures are created through non-destructive seed/API/admin action
cleanup is scoped and documented when possible
runtime DB use is declared as Visible Browser Runtime DB, not Automated Test DB
```

QA must not claim the visible browser used `newpaotang_test` unless the frontend/API runtime wiring proves it.

## Frontend-To-API Proof Rule

Before visible Chrome QA, QA must identify the frontend/API target and DB class used by the browser flow.

Evidence must include at least one of:

```text
environment variable/config captured in report
network request evidence showing API target
seeded test account/data unique to the declared DB
task-specific confirmation from dev handoff
runtime service config or Docker env evidence
```

If QA cannot identify the browser DB/API target, QA must report `BLOCKED` or `PASS WITH RISK`; never clean PASS.

## Evidence Requirements

QA report must include:

```text
Chrome visible to user: Yes
URL(s)
account/role
tenant/domain
automated test DB name
visible browser runtime DB name
screenshots or screen recording path when available
network/config evidence for API target
fixture creation/cleanup notes
scenario-by-scenario result
```

## Runtime DB Rule

QA must not update or migrate local runtime DB as part of acceptance.

Local runtime DB update belongs to GitOps after Coordinator approval.

Visible Chrome using local runtime DB for non-destructive acceptance is not a runtime DB update; it is browser evidence and must be reported separately from test DB validation.
