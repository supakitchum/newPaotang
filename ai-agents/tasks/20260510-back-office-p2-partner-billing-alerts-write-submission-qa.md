# back-office-p2-partner-billing-alerts-write-submission-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator reviewed the P2 partner/billing/alerts non-destructive QA pass.

Open focused write-submission verification:

```text
back-office-p2-partner-billing-alerts-write-submission-qa
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-workflows-qa/
```

## Objective

Verify that the six P2 completion-candidate rows submit real create/update/action requests successfully through authenticated BO central menus using local Docker QA fixture data.

This is a QA task only. Do not patch implementation.

## Scope

Write-submission rows:

```text
central:partners
central:partner_provisioning
central:partner_quotas
central:billing_plans
central:alert_policies
central:alert_events
```

Out of scope:

```text
central:partner_monitoring
central:partner_usage
```

Monitoring and usage remain view-only permission/UX decision items. Do not test update submissions for those rows.

## Source Of Truth

Read before testing:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-qa.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-task-orchestrator-handoff.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md
```

## Required QA Behavior

Use Docker-only application commands.

For each row, capture sanitized API evidence before and after browser submission. Do not write bearer tokens or secrets to artifacts.

Use real authenticated central-menu navigation before testing browser submissions. Do not rely only on direct URL hard refreshes.

Use safe local QA fixture data only:

- Create/update/suspend a QA-created partner for `central:partners`.
- Provision/suspend only a QA-created partner for `central:partner_provisioning`.
- Create/update a QA quota for `central:partner_quotas`.
- Create/update a QA billing plan for `central:billing_plans`.
- Create/update a QA alert policy for `central:alert_policies`.
- Acknowledge/resolve only a QA alert event fixture for `central:alert_events`.

If a write fails, capture:

```text
row
route
button/form used
request payload shape without secrets
HTTP status
response body sanitized
likely owner: BO, backend contract, permission, or QA fixture
```

Do not patch implementation or backend.

## Acceptance Criteria

- Docker validation passes.
- Each in-scope row is tested from the real central menu.
- Each in-scope create/update/action submission reaches the backend and returns a successful result, or a precise blocker is reported.
- Before/after API evidence proves the mutation/action result.
- Browser evidence proves success/error state handling after submission.
- Reason guards remain required where applicable.
- Customer frontend is not used.
- No backend/customer/OpenAPI implementation files are edited.

## Validation Commands

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose exec -T platform-api php artisan route:list
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

## Expected Output

Write QA report:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md
```

Write artifacts under:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/
```

Report must include:

```text
result
head under test
validation commands and results
per-row before/after API evidence summary
per-row browser submission evidence summary
findings
known risks
next agent: Coordinator
```
