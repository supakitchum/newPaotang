# 20260508-m10-cloudflare-https-waf-cdn-r2 - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-production-observability-alerting` for local/dev readiness with accepted risks.

Open the next M10 release-gate slice:

```text
20260508-m10-cloudflare-https-waf-cdn-r2
```

Target Backend/Ops implementation first unless a safer ownership split is found. This slice must cover Cloudflare, HTTPS, WAF/rate-limit, custom-domain readiness, cache-bypass rules, CDN/R2 ticket-image strategy, and real ticket-image load-test prerequisites without claiming production approval unless QA can verify real infrastructure evidence.

## Objective

Implement verifiable Cloudflare/HTTPS/WAF/CDN/R2 readiness foundations for NewPaotang.

The goal is to make the release gate measurable through local/dev Docker validation and clear ops artifacts:

```text
custom domain and SSL readiness tracking
Cloudflare proxy/HTTPS enforcement readiness checks
WAF and tenant-aware rate-limit rule artifacts/runbook
payment/webhook cache-bypass rule artifacts/runbook
static asset and ticket-image CDN/R2 strategy
safe Cloudflare/R2 env and secret boundary
real ticket-image CDN load-test prerequisites and runner behavior
explicit blockers when real Cloudflare/R2 credentials/domains are unavailable
QA acceptance criteria for real or simulated evidence
```

This slice is not production approval. If real Cloudflare/R2 credentials, DNS zones, domains, or object-storage endpoints are unavailable in this workspace, implement safe dry-run/verifier behavior and document precise production blockers and owners.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-production-observability-alerting-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-production-observability-alerting-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-production-observability-alerting-qa-report.md`
- `ai-agents/decisions/20260508-m10-release-gate-follow-up-planning-decision.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-m10-release-gate-follow-up-planning-orchestrator-handoff.md`
- `ai-agents/decisions/20260508-m10-deployment-monitoring-load-test-approval-decision.md`
- `ai-agents/reports/20260508-m10-deployment-monitoring-load-test-qa-report.md`
- `ai-agents/decisions/20260508-m10-full-k6-load-test-execution-approval-decision.md`
- `ai-agents/reports/20260508-m10-full-k6-load-test-execution-qa-report.md`
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
- `load-tests/README.md`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `compose.yaml`
- `apps/platform-api/**`

## Scope

Implement a focused Backend/Ops slice for Cloudflare/HTTPS/WAF/CDN/R2 readiness.

Approved implementation scope:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
load-tests/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
```

Expected implementation areas:

```text
Cloudflare/domain readiness command or verifier, such as platform:cloudflare:readiness --format=json
custom-domain readiness storage or report using partner_tenant_domains verified_at/ssl_ready_at plus any needed additive fields
HTTPS/proxy readiness checks that do not activate domains without DNS/SSL/proxy evidence
WAF/rate-limit rule templates for tenant/public/API/payment/webhook paths
cache-bypass rule templates for payment/webhook and dynamic tenant routes
CDN/R2 ticket-image strategy and object key/URL policy
safe ticket image CDN prerequisite check for k6 ticket-image-cdn-spike.js
Docker-only helper scripts
ops artifacts under ops/m10/**
tests for readiness command output, domain activation guards, cache-rule artifacts, CDN/R2 env boundary, and ticket-image load-test guard behavior
```

Use the repo's existing Modular Monolith structure. Domain-owned services should live under `App\Modules\<Domain>\Services`; shared Cloudflare/CDN/R2 readiness primitives may live under `App\Shared` only when they are genuinely cross-cutting and documented.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement customer UI changes.
- Do not implement back-office UI changes.
- Do not change public customer flow.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, or business rules.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, or `document/**`.
- Do not claim staging, production, client delivery, Cloudflare production activation, DNS ownership, HTTPS enforcement, WAF enforcement, real R2 delivery, real CDN cache hit ratio, Horizon/Reverb, migration rehearsal, production secret management, Meno license, npm audit, or back-office production-readiness approval unless QA verifies real evidence.
- Do not call real Cloudflare APIs unless credentials and a safe non-production zone are explicitly present and documented. Prefer dry-run/verifier output when not present.
- Do not create or modify real DNS records, WAF rules, R2 buckets, SSL certificates, or production domains from this local task.
- Do not add external SDK dependencies or a second operational database without a Coordinator decision.
- Do not commit real Cloudflare tokens, account IDs tied to production, R2 access keys, secret keys, signed URLs, production URLs, bearer tokens, passwords, or private certificates.
- Do not move tenant logo/theme/payment/domain/feature config into env.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
apps/platform-api/.env.example
ops/m10/**
scripts/**
load-tests/**
docs/m10-deployment-monitoring-load-test.md
docs/backend-console-commands.md
docs/backend-architecture-compliance.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
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
compose.yaml unless a Docker-only helper profile is impossible without it
.github/** unless only adding Docker-only M10 Cloudflare/CDN validation to an existing M10 workflow
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, runtime, migration, queue, scheduler, k6, and readiness validation commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect current domain, provisioning, ticket image, webhook/payment, CDN env, and k6 ticket-image code before editing:

```text
partner_tenant_domains
PartnerTenantDomain
PartnerProvisioningService
Tenant resolution/site-config behavior
Ticket image_url and image_thumb_url fields
payment/topup webhook routes
load-tests/k6/ticket-image-cdn-spike.js
load-tests README and runner behavior
apps/platform-api/.env.example
```

5. Add a Cloudflare/CDN readiness service and Docker-runnable command, such as:

```text
php artisan platform:cloudflare:readiness --format=json
```

The command should output safe JSON that includes domain/DNS/SSL/proxy/HTTPS/cache/CDN/R2 readiness status, blockers, and `production_approved=false` unless real QA-verifiable evidence is present.

6. Implement custom-domain readiness guards or report logic:

```text
domain status must not become active until DNS ownership, SSL readiness, HTTPS requirement, and Cloudflare proxy expectations are satisfied or explicitly documented as local-only
verified_at and ssl_ready_at semantics must be preserved
custom domains should remain pending/suspended unless readiness criteria are met
```

Additive schema fields are allowed if needed, but do not break existing tenant resolution.

7. Add safe env placeholders in `.env.example` only for infrastructure-level config, for example:

```text
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_ZONE_ID
CLOUDFLARE_API_TOKEN
CLOUDFLARE_API_BASE_URL
CLOUDFLARE_DRY_RUN
CLOUDFLARE_PROXY_REQUIRED
CLOUDFLARE_HTTPS_REQUIRED
R2_ENDPOINT
R2_BUCKET
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
CDN_BASE_URL
TICKET_IMAGE_CDN_REQUIRED
```

Do not include real secrets and do not move tenant domains/features/theme/payment settings into env.

8. Add or update ops artifacts under `ops/m10/**`, for example:

```text
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/cloudflare-waf-rate-limit-rules.json
ops/m10/cloudflare-cache-bypass-rules.json
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
```

Artifacts must distinguish local/dry-run verification from real Cloudflare/R2 production activation.

9. Define WAF/rate-limit rules for:

```text
public tenant pages
public stock/search/result endpoints
customer auth/booking/checkout endpoints
admin/back-office endpoints
partner sync endpoints
payment/topup webhook endpoints
support/impersonation-sensitive endpoints
```

Rules may be JSON templates/runbooks. Do not attempt live WAF deployment without safe credentials and explicit evidence.

10. Define cache-bypass rules for:

```text
/api/**
/api/v1/webhooks/**
/api/v1/admin/**
payment/topup callbacks
tenant maintenance/dynamic pages
auth/session-protected routes
```

Static asset and ticket-image rules should prefer immutable cache where safe.

11. Define CDN/R2 ticket image strategy:

```text
DB stores image key/path or CDN URL policy, not base64
API/customer-facing responses should use CDN URL or signed CDN URL where applicable
ticket images should not proxy through Laravel for every request unless explicitly justified
cache headers should be long-lived for immutable images
private image behavior should use signed URL or equivalent documented strategy
```

Do not rewrite customer UI in this task.

12. Tighten or document `ticket-image-cdn-spike.js` runner behavior so the scenario only claims coverage when explicit CDN/R2 image env is supplied. Do not let normal API `BASE_URL` accidentally count as CDN/R2 coverage.
13. Add scripts for Docker-only readiness checks, such as:

```text
scripts/platform-cloudflare-readiness.sh
scripts/ticket-image-cdn-check.sh
```

Scripts must call Docker/Docker Compose internally and must not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, k6, wrangler, aws, or Cloudflare CLI commands on the host.

14. Update docs with commands, artifacts, release boundary, and remaining blockers.
15. Add tests for:

```text
Cloudflare readiness command registration/output shape
custom domain activation/readiness guard behavior
safe env boundary and no tenant config in env
WAF/cache rule artifact presence and parseability
ticket image CDN/R2 prerequisite checks
secret redaction in readiness output
no API route drift
```

16. Run Docker-only validation commands.
17. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Cloudflare/CDN readiness report command exists, emits safe JSON, and does not require real production credentials.
- Readiness output distinguishes local/dry-run status from real production approval.
- Custom domain readiness criteria are explicit and prevent or report unsafe activation before DNS/SSL/proxy/HTTPS criteria are satisfied.
- WAF/rate-limit rule artifacts exist and cover public, customer, admin, partner sync, payment/webhook, and support-sensitive surfaces.
- Cache-bypass rule artifacts exist and cover API, webhook/payment callbacks, admin/auth/session-protected routes, and tenant maintenance dynamic pages.
- CDN/R2 ticket image strategy exists and keeps ticket-image traffic off Laravel per-request proxying unless explicitly justified.
- `ticket-image-cdn-spike.js` or its runner only claims CDN/R2 coverage when explicit CDN/R2 image env is supplied.
- Safe env placeholders are infrastructure-only and include no real secrets.
- Existing tenant logo/theme/payment/domain/feature config remains database-owned.
- Existing partner/tenant/site config and tenant resolution tests still pass.
- Full platform-api tests pass.
- `platform:smoke` passes.
- No API contract drift, customer flow drift, back-office flow drift, permission drift, tenant isolation drift, or business-rule drift is introduced.
- Docs clearly state this slice is Cloudflare/CDN/R2 readiness, not staging/production/client-delivery approval.
- Gates kept separate remain open:

```text
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

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/k6/wrangler/aws/cloudflare commands.

Minimum required validation:

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

If you choose different command names, document the exact names and reason in the Backend handoff, and include equivalent Docker-only validation.

Useful static checks:

```sh
bash -n scripts/platform-cloudflare-readiness.sh
bash -n scripts/ticket-image-cdn-check.sh
jq empty ops/m10/cloudflare-waf-rate-limit-rules.json
jq empty ops/m10/cloudflare-cache-bypass-rules.json
rg -n "CLOUDFLARE|R2_|CDN_BASE_URL|TICKET_IMAGE_CDN" apps/platform-api/.env.example docs/m10-deployment-monitoring-load-test.md ops/m10 scripts apps/platform-api/app apps/platform-api/tests load-tests
rg -n "logo|theme|payment|domain|feature" apps/platform-api/.env.example
rg -n "cloudflare.*api.*token|secret_access_key|private_key|BEGIN CERTIFICATE|BEGIN PRIVATE KEY|Bearer " apps/platform-api docs ops/m10 scripts load-tests ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
```

Static check interpretation must distinguish safe placeholders from real secrets. Do not paste real secrets into the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md
```

Must include:

```text
what was done
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
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```
