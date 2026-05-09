# 20260508-m10-full-k6-load-test-execution - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved Backend Module Structure Remediation and instructed Orchestrator to resume the previously paused M10 release-gate follow-up planning.

Coordinator previously approved the M10 backend/ops foundation for local/dev QA readiness only. The following release gate remains open and is the first prioritized follow-up slice:

```text
Full k6 load-test execution with fixture data, bearer tokens, thresholds, and runner ownership
```

This slice must turn the current k6 scaffolds into a repeatable Docker-only local/dev execution workflow with explicit fixture setup, token generation or token capture, threshold profiles, evidence artifacts, and honest release-gate boundaries.

## Objective

Implement the first M10 release-gate follow-up slice: make the existing k6 load-test scenarios executable with prepared local/dev data and credentials, then run and record a short baseline pass through Docker.

The goal is not to claim production readiness. The goal is to prove that the load-test workflow no longer depends on manual guesswork or missing environment variables for the local/dev release-readiness baseline.

## Source Of Truth

- `ai-agents/decisions/20260508-backend-module-structure-remediation-approval-decision.md`
- `ai-agents/handoffs/20260508-backend-module-structure-remediation-approval-coordinator-handoff.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/decisions/20260508-m10-deployment-monitoring-load-test-approval-decision.md`
- `ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md`
- `ai-agents/tasks/20260508-m10-deployment-monitoring-load-test-backend.md`
- `ai-agents/handoffs/20260508-m10-deployment-monitoring-load-test-backend-handoff.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `ops/m10/runtime-readiness.md`
- `load-tests/README.md`
- `load-tests/k6/*.js`
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Implement a focused Backend/Ops slice for local/dev full k6 execution readiness.

Approved implementation scope:

```text
load-tests/**
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
apps/platform-api/database/seeders/**
apps/platform-api/app/Console/Commands/**
apps/platform-api/tests/**
apps/platform-api/routes/**
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/**
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

Use the narrowest possible backend changes needed to create deterministic local/dev load-test fixtures and credentials. Prefer scripts, fixture manifests, seed helpers, console commands, and tests over changing product behavior.

Required load-test scenarios:

```text
customer-stock-search.js
concurrent-booking-same-stock.js
checkout-wallet-consistency.js
partner-tenant-burst-sync.js
reward-publish-spike.js
reward-checking-queue-chunk.js
ticket-image-cdn-spike.js
```

Required capabilities:

```text
fixture data creation for local/dev k6 baseline
bearer token generation or documented token capture for customer, admin, and partner scenarios
stable tenant host/base URL defaults for Docker execution
scenario threshold profiles for smoke, baseline, and release-candidate intent
Docker-only runner commands or scripts
machine-readable fixture/env artifact with no committed secrets
k6 summary/artifact capture for QA review
clear separation between local/dev baseline and production/staging release approval
```

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not change public customer flow.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, or business rules.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not claim staging, production, client-delivery, Cloudflare, HTTPS, WAF, CDN/R2, Horizon, Reverb, migration, license, npm audit, or full production observability approval.
- Do not solve real Cloudflare/R2 integration in this slice except by making `ticket-image-cdn-spike.js` runnable when an explicit CDN/R2 base URL and image path are supplied.
- Do not add new external infrastructure, a second operational database, analytics database, search engine, or NoSQL store without a Coordinator decision.
- Do not commit real bearer tokens, passwords, secrets, Cloudflare credentials, R2 keys, or production URLs.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
load-tests/**
ops/m10/**
scripts/**
docs/m10-deployment-monitoring-load-test.md
apps/platform-api/database/seeders/**
apps/platform-api/app/Console/Commands/**
apps/platform-api/tests/**
apps/platform-api/routes/**
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/**
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/events.md
document/**
compose.yaml unless a Docker-only k6 runner profile is impossible without it
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, runtime, migration, queue, scheduler, and k6 commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect the current k6 scripts and their required environment variables.
5. Design a local/dev fixture workflow that prepares enough deterministic data for the seven M10 scenarios without changing production business behavior.
6. Implement fixture setup using the smallest appropriate backend mechanism, such as a local/test-only seeder, console command, script, or documented Docker workflow.
7. Provide a safe way to obtain or emit local/dev scenario values:

```text
BASE_URL
TENANT_HOST
GAME_ID
SEARCH_NUMBER
LOCAL_STOCK_ITEM_ID
RESERVATION_ID
CUSTOMER_TOKEN
ADMIN_TOKEN
PARTNER_TOKEN
PARTNER_ID
TENANT_ID
PARTNER_SYNC_PATH
REWARD_RESULT_ID
CDN_BASE_URL or BASE_URL for the image scenario when explicitly available
IMAGE_PATH when explicitly available
```

8. Ensure any generated fixture/env artifact is ignored or stored only as a sample/template when it could contain secrets.
9. Add or update load-test docs so QA can run:

```text
fixture setup
token generation or capture
single-scenario k6 runs
all-scenario baseline run
artifact collection
threshold interpretation
known skipped/external gates
```

10. Add or update scripts under `load-tests/**` or `scripts/**` for Docker-only k6 execution. Scripts may wrap Docker commands, but must not run local `k6`, PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, migration, queue, scheduler, or runtime commands on the host.
11. Add or update backend tests for the fixture/token workflow where practical.
12. Run a short local/dev baseline so all API-backed k6 scenarios run to completion instead of failing early on missing fixture env.
13. For `ticket-image-cdn-spike.js`, either run it against an explicit local/dev CDN/object-storage fixture if available, or document it as blocked by the separate Cloudflare/CDN/R2 release gate while preserving a runnable command template.
14. Capture k6 summaries/artifacts in a safe path under `load-tests/results/**` or another documented load-test artifact path. Do not commit generated secret env files.
15. Update `docs/m10-deployment-monitoring-load-test.md` and `load-tests/README.md` with the new workflow and boundaries.
16. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed for every PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, and runtime command.
- A repeatable fixture setup exists for local/dev k6 baseline data.
- Local/dev bearer tokens or equivalent authenticated scenario credentials can be generated or captured without committing secrets.
- Existing k6 scripts are executable with documented env values and no longer depend on guesswork.
- API-backed scenarios run to completion in a short local/dev baseline:

```text
customer-stock-search.js
concurrent-booking-same-stock.js
checkout-wallet-consistency.js
partner-tenant-burst-sync.js
reward-publish-spike.js
reward-checking-queue-chunk.js
```

- `ticket-image-cdn-spike.js` has a runnable command template and either a real explicit local/dev artifact run or a documented blocker tied to the separate Cloudflare/CDN/R2 gate.
- Thresholds are explicit and separated by profile, such as smoke, baseline, and release-candidate intent.
- k6 output artifacts are captured for QA review.
- The implementation does not change API contracts, response envelopes, permissions, tenant isolation, customer flow, back-office flow, or business rules.
- The implementation does not move tenant logo/theme/payment/domain/feature config into env.
- Docs clearly state this slice is local/dev load-test execution readiness, not staging/production/client-delivery approval.
- Known open gates remain carried forward:

```text
production observability and alert channels
Cloudflare HTTPS/WAF/rate-limit/CDN/R2 integration
Horizon/Reverb hardening
scheduler workload registration
migration rehearsal/cutover/rollback
production secret management
Meno license compliance
npm audit remediation
back-office hydration/stale-marker/menu metadata risks
maintenance bypass list endpoint
backend menu category/icon fields
```

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6 commands.

Minimum required validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker run --rm grafana/k6:latest version
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/customer-stock-search.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/concurrent-booking-same-stock.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/checkout-wallet-consistency.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/partner-tenant-burst-sync.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-publish-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/reward-checking-queue-chunk.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

Also run the Docker-only k6 baseline commands or scripts created by this task. The final commands and results must be listed in the Backend handoff.

If a command is intentionally not run, the handoff must explain why, what gate blocks it, and which next owner should resolve it.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
```

Must include:

```text
what was done
files changed
fixture setup design
generated env/artifact policy
token/credential handling
scenario coverage table
k6 threshold profiles
Docker validation commands and results
k6 run commands and results
artifact locations
release gates still open
known risks
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
