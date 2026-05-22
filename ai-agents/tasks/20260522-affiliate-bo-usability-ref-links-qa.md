# affiliate-bo-usability-ref-links - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Validate the completed Backend, BO, and Customer delivery for:

```text
affiliate-bo-usability-ref-links
```

Do not start until these handoffs exist and include pushed commits:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-customer-handoff.md
```

## QA Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before testing:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or unknown dirty files overlap QA evidence.

Known unrelated artifact:

```text
apps/platform-api/.phpunit.result.cache
```

Do not stage it.

## Source Of Truth

Read before QA:

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-bo.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-customer.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-customer-handoff.md
docs/docker-runtime-policy.md
docs/customer-api-integration-map.md
docs/admin-dashboard-template-guidelines.md
docs/openapi.yaml
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
```

## Required QA Coverage

Backend/API:

```text
affiliate account/link codes are exactly 6 Base62 characters
codes are case-sensitive and unique per tenant
server ignores user/admin-supplied code for create flows
responses expose canonical /?ref=CODE URL
legacy /a/{CODE} data remains tolerable in reads where applicable
?ref=CODE resolves only in current tenant
inactive and cross-tenant refs are rejected
last-click attribution with 30-day TTL is applied
paid order commission can convert new attribution into commission transaction
customer affiliate account cannot access BO/admin APIs
```

BO browser/usability:

```text
Affiliate/Growth resources remain available
Affiliate, Affiliate Links, Attributions, Commission Rules, Transactions, and Payouts are usable without raw JSON for normal workflows
detail views do not render raw JSON object dumps for normal fields
generated code/url fields are not editable
money uses baht input
enum fields use selects
bank account fields are split where practical
operators can choose customers/affiliates/programs without copying raw IDs where practical
```

Customer browser:

```text
tenant storefront /?ref=CODE captures ref tenant-scoped
new ref replaces old ref using last-click behavior
ref expires or is treated as 30-day TTL per implementation evidence
stored ref does not leak across tenants
login/register/checkout apply path creates or updates backend attribution where fixtures allow
/affiliate shows server-provided 6-character code and /?ref= link
no new /a/{CODE} canonical flow
```

## Required Commands

Use Docker only:

```sh
git diff --check
docker compose -p newpaotang build platform-api back-office customer
docker compose -p newpaotang up -d postgres valkey platform-api back-office customer
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AffiliateTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CustomerAffiliateTest
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm customer npm run lint
docker compose -p newpaotang run --rm customer npm run test
docker compose -p newpaotang run --rm customer npm run build
```

Destructive DB commands must use:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Do not wipe runtime DB `newpaotang`.

## Runtime Restore / Login Smoke

Before clean PASS, QA must restore/check local Docker runtime without wiping runtime DB:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang stop back-office customer
docker compose -p newpaotang rm -f back-office customer
docker compose -p newpaotang up -d back-office customer
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3000/
```

The report must include `Runtime Restore / Login Smoke`.

## Report

Write:

```text
ai-agents/reports/20260522-affiliate-bo-usability-ref-links-qa-report.md
```

Include:

```text
worktree path
branch
HEAD and origin/develop
backend/BO/customer commits under test
commands and results
API evidence
BO browser/usability evidence
customer browser/ref evidence
test DB isolation evidence
runtime restore/login smoke
defects with owner recommendation
unrelated dirty files left unstaged
PASS/FAIL/PASS WITH RISK/BLOCKED
Next Agent: Coordinator
```

## Next Agent

Coordinator
