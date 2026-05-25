# QA Browser Environment

Visible browser QA must run against the intended test environment before any local runtime DB update.

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
DB_DATABASE
tenant/domain
account/role
test data fixture
expected evidence path
```

## Default Local Test Values

Use task-specific values when provided. Otherwise use:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
platform-api service: platform-api
back-office service: back-office
customer service: customer
evidence root: ai-sub-agents/reports/artifacts/YYYYMMDD-<task-key>/
```

## Frontend-To-Test-API Rule

Before visible Chrome QA that mutates data, QA must confirm the frontend under test is pointing at the test API/test DB, not the local runtime DB.

Evidence must include at least one of:

```text
environment variable/config captured in report
network request evidence showing test API target
seeded test account/data unique to test DB
task-specific confirmation from dev handoff
```

If QA cannot prove browser flow is using test env/test DB, QA must report `BLOCKED` or `PASS WITH RISK`; never clean PASS.

## Evidence Requirements

QA report must include:

```text
Chrome visible to user: Yes
URL(s)
account/role
tenant/domain
test DB name
screenshots or screen recording path when available
network/config evidence for test API
scenario-by-scenario result
```

## Runtime DB Rule

QA must not switch browser QA back to local runtime DB as part of acceptance.

Local runtime DB update belongs to GitOps after Coordinator approval.
