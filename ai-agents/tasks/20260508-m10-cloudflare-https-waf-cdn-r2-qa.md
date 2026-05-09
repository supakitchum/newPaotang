# 20260508-m10-cloudflare-https-waf-cdn-r2 - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved `20260508-m10-production-observability-alerting` for local/dev readiness and instructed Orchestrator to open the next M10 release-gate slice:

```text
20260508-m10-cloudflare-https-waf-cdn-r2
```

Backend Develop reports Cloudflare, HTTPS, WAF/rate-limit, cache-bypass, CDN/R2 ticket-image strategy, and ticket-image load-test prerequisite readiness foundations are complete. Validate this slice without granting staging, production, client-delivery, real Cloudflare activation, DNS ownership, HTTPS enforcement, WAF deployment, real R2 delivery, or real CDN cache-hit approval unless concrete evidence exists.

## Objective

Verify that Backend implemented a Docker-only, QA-verifiable local/dev foundation for Cloudflare/HTTPS/WAF/CDN/R2 readiness:

```text
Cloudflare/CDN readiness report command
custom-domain readiness evidence fields and activation guard behavior
safe env/secret boundary
WAF/rate-limit templates
cache-bypass templates
CDN/R2 ticket-image strategy
ticket-image-cdn-spike prerequisite guard
Docker-only scripts
docs/runbook release boundary
no API/customer/back-office contract drift
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-production-observability-alerting-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-production-observability-alerting-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-planning-orchestrator-handoff.md`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-backend.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md`
- `document/08_IMPLEMENTATION_ROADMAP.md`
- `document/10_TRAFFIC_PERFORMANCE_SCALING.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `document/12_MONITORING_OBSERVABILITY.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-console-commands.md`
- `docs/backend-model-layer.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/cloudflare-waf-rate-limit-rules.json`
- `ops/m10/cloudflare-cache-bypass-rules.json`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `load-tests/README.md`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `scripts/platform-cloudflare-readiness.sh`
- `scripts/ticket-image-cdn-check.sh`
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Validate Backend/Ops implementation for M10 Cloudflare/HTTPS/WAF/CDN/R2 readiness.

Inspect at minimum:

```text
apps/platform-api/.env.example
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php
apps/platform-api/app/Console/README.md
apps/platform-api/app/Models/PartnerTenantDomain.php
apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php
apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php
apps/platform-api/database/migrations/2026_05_08_000002_add_cloudflare_readiness_to_partner_tenant_domains.php
apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php
apps/platform-api/tests/Feature/M10K6LoadTestExecutionTest.php
apps/platform-api/tests/Feature/M10DeploymentReadinessTest.php
apps/platform-api/tests/Feature/PartnerProvisioningTest.php
apps/platform-api/tests/Feature/TenantResolutionTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/cloudflare-waf-rate-limit-rules.json
ops/m10/cloudflare-cache-bypass-rules.json
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
load-tests/README.md
load-tests/k6/ticket-image-cdn-spike.js
scripts/platform-cloudflare-readiness.sh
scripts/ticket-image-cdn-check.sh
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not approve staging, production, client delivery, Cloudflare production activation, DNS ownership, HTTPS enforcement, WAF/rate-limit deployment, cache-bypass deployment, real R2 delivery, real CDN cache-hit ratio, Horizon/Reverb, migration rehearsal, production secret management, Meno license, npm audit, or back-office production-readiness gates.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.
- Do not copy real Cloudflare tokens, account IDs tied to production, R2 keys, signed URLs, bearer tokens, private certificates, production URLs, or other secrets into QA reports/artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md
ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md and ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/**
```

If a defect requires implementation, docs, schema, command, readiness logic, Cloudflare/R2 artifact, secret boundary, k6 guard, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, Cloudflare, wrangler, aws, and runtime commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
files changed
schema/model/service changes
Cloudflare/custom-domain readiness summary
HTTPS/proxy/WAF/rate-limit summary
cache-bypass summary
CDN/R2 ticket-image strategy
ticket-image load-test prerequisite handling
safe env/secret boundary
ops artifacts
local/dev vs production boundary
Docker validation commands and results
known risks and blockers
release gates still open
```

5. Verify schema/model readiness:

```text
partner_tenant_domains.dns_verified_at
partner_tenant_domains.cloudflare_proxy_verified_at
partner_tenant_domains.https_enforced_at
partner_tenant_domains.cloudflare_readiness_checked_at
PartnerTenantDomain fillable/casts
```

Confirm migration is additive and does not break tenant/domain resolution.

6. Verify command registration and safe output:

```text
platform:cloudflare:readiness --format=json
```

The command must emit safe JSON, avoid external Cloudflare/R2 mutation, report blockers, and keep `production_approved=false` unless real QA-verifiable evidence exists.

7. Verify domain activation/readiness guard behavior:

```text
custom domains must not become active before DNS ownership, SSL readiness, Cloudflare proxy requirement, and HTTPS enforcement evidence exist
local .test subdomains can remain active only when marked local-only in readiness output
unsafe active domains must be reported
verified_at and ssl_ready_at semantics remain compatible with existing tests
```

8. Verify WAF/rate-limit artifact:

```text
ops/m10/cloudflare-waf-rate-limit-rules.json
```

It must parse as JSON and cover:

```text
public tenant pages
public stock/search/result endpoints
customer auth/booking/checkout endpoints
admin/back-office APIs
partner sync endpoints
payment/topup webhooks
support/impersonation-sensitive endpoints
```

9. Verify cache-bypass artifact:

```text
ops/m10/cloudflare-cache-bypass-rules.json
```

It must parse as JSON and cover:

```text
/api/**
/api/v1/webhooks/payments/**
/api/v1/webhooks/topups/**
/api/v1/admin/**
auth/session-protected routes
customer dynamic routes
tenant maintenance dynamic pages
partner sync
immutable static assets
immutable ticket-image paths
```

10. Verify CDN/R2 ticket-image strategy:

```text
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
```

Docs must state:

```text
DB stores image key/path or CDN URL policy, not base64
customer-facing responses should use CDN or signed CDN URLs where applicable
Laravel should not proxy image bytes per request
immutable images use long-lived cache headers
private image behavior uses signed URL or equivalent edge access control
real Cloudflare/R2 remains a separate evidence gate
```

11. Verify k6 ticket-image guard:

```text
load-tests/k6/ticket-image-cdn-spike.js
scripts/ticket-image-cdn-check.sh
scripts/k6-run-baseline.sh
```

The ticket-image scenario must only claim CDN/R2 coverage when explicit `CDN_BASE_URL` and `IMAGE_PATH` exist, and normal API `BASE_URL` must not count as CDN coverage.

12. Verify env and secret boundary:

```text
Cloudflare/R2/CDN env placeholders are infrastructure-only
no tenant logo/theme/payment/domain/feature config moved to env
no real Cloudflare token, R2 secret key, private cert, signed URL, bearer token, or production credential appears in source/docs/ops/scripts/handoff
readiness output redacts sensitive fields and reports credential presence booleans only
```

13. Verify docs:

```text
docs/m10-deployment-monitoring-load-test.md documents Cloudflare/CDN/R2 readiness commands and blockers
docs/backend-console-commands.md includes platform:cloudflare:readiness
docs/backend-architecture-compliance.md documents Shared Cloudflare primitive if used
docs/backend-model-layer.md includes new domain readiness fields if applicable
docs/backend-bootstrap-seeders.md remains accurate for local .test domains and readiness boundary
```

14. Verify no forbidden areas were changed by this slice:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
document/**
```

The workspace is noisy; fail only when evidence ties forbidden drift to this slice.

15. Run Docker validation commands.
16. Capture or summarize safe command output under:

```text
ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/**
```

Do not copy secrets into artifacts. Redact any sensitive-looking values.

17. Write QA report to:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- New schema/model changes are additive and scoped to Cloudflare/CDN/R2 readiness.
- `M10CloudflareHttpsWafCdnR2Test` passes.
- `M10K6LoadTestExecutionTest` passes.
- `M10DeploymentReadinessTest` passes.
- `PartnerProvisioningTest` passes.
- `TenantResolutionTest` passes.
- `ConsoleCommandStructureTest` passes.
- Full platform-api test suite passes.
- `route:list` passes and shows no public API contract drift attributable to this slice.
- `platform:smoke` passes.
- `platform:cloudflare:readiness --format=json` passes and emits safe JSON.
- Readiness output reports real blockers and `production_approved=false` when real Cloudflare/R2 evidence is unavailable.
- WAF/rate-limit and cache-bypass JSON templates parse and cover required route classes.
- CDN/R2 ticket-image strategy and load-test runbook clearly preserve the production boundary.
- `ticket-image-cdn-spike.js` passes k6 inspect through Docker.
- Ticket-image CDN runner/check refuses to claim coverage without explicit `CDN_BASE_URL` and `IMAGE_PATH`.
- `.env.example` contains only infrastructure-level Cloudflare/R2/CDN placeholders and no tenant logo/theme/payment/domain/feature config.
- Secret scans show no real Cloudflare/R2/private credential leakage.
- No customer/back-office/source-of-truth contract drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, Cloudflare, wrangler, aws, and runtime commands.

Required Docker validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioningTest
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

Required helper/static validation:

```sh
git status --short
bash -n scripts/platform-cloudflare-readiness.sh
bash -n scripts/ticket-image-cdn-check.sh
jq empty ops/m10/cloudflare-waf-rate-limit-rules.json
jq empty ops/m10/cloudflare-cache-bypass-rules.json
scripts/ticket-image-cdn-check.sh
rg -n "CLOUDFLARE|R2_|CDN_BASE_URL|TICKET_IMAGE_CDN" apps/platform-api/.env.example docs/m10-deployment-monitoring-load-test.md ops/m10 scripts apps/platform-api/app apps/platform-api/tests load-tests
rg -n "logo|theme|payment|domain|feature" apps/platform-api/.env.example
rg -n "cloudflare.*api.*token|secret_access_key|private_key|BEGIN CERTIFICATE|BEGIN PRIVATE KEY|Bearer " apps/platform-api docs ops/m10 scripts load-tests ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
rg -n "platform:cloudflare:readiness|ticket-image-cdn-spike|CDN_BASE_URL|IMAGE_PATH" apps/platform-api/app apps/platform-api/tests docs/m10-deployment-monitoring-load-test.md ops/m10 scripts load-tests
```

Interpretation notes:

```text
Secret scans may match safe placeholders, env names, docs examples, and k6 variable names. QA must distinguish placeholders/redacted output from real secret leakage.
scripts/ticket-image-cdn-check.sh may print a blocker and exit 0 when CDN_BASE_URL/IMAGE_PATH are absent; that is acceptable for local/dev readiness if the blocker is explicit.
Do not run real Cloudflare/wrangler/aws commands on the host.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
schema/model review
Cloudflare readiness command review
domain readiness/activation guard review
HTTPS/proxy readiness review
WAF/rate-limit artifact review
cache-bypass artifact review
CDN/R2 ticket-image strategy review
ticket-image k6 guard review
safe env/secret boundary review
docs/release-boundary review
route-list/API contract review
test results
static check results
customer/back-office no-change review
release gates still open
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```
