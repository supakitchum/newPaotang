# 20260508-m10-cloudflare-https-waf-cdn-r2-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator returned `20260508-m10-cloudflare-https-waf-cdn-r2` to Backend after QA found two P2 blockers:

```text
readiness JSON leaks configured Cloudflare/R2 identifiers instead of presence-only safe output
configured Cloudflare/R2 env can report ready_local without explicit ticket-image object evidence
```

Backend Develop reports remediation is complete. Re-test this focused remediation and route the result back to Coordinator.

## Objective

Verify that Backend remediated the Cloudflare/CDN/R2 readiness blockers without broadening scope:

```text
platform:cloudflare:readiness JSON must not emit raw configured Cloudflare/R2/CDN/ticket-image identifiers
readiness output must use presence booleans or constant placeholders such as [CONFIGURED] and [REDACTED]
ticket-image CDN/R2 readiness must remain blocked until explicit ticket-image object evidence exists
CDN/R2 placeholder credentials alone must not produce ready_local
normal API BASE_URL must not satisfy ticket-image CDN/R2 readiness
explicit IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH may remove only the image-evidence blocker
production_approved must remain false
no external Cloudflare/R2 calls or mutations may occur
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-cloudflare-https-waf-cdn-r2-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-qa-report.md`
- `ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/json-command-summary.txt`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-backend-handoff.md`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-backend.md`
- `ai-agents/handoffs/20260508-m10-cloudflare-https-waf-cdn-r2-backend-handoff.md`
- `ai-agents/tasks/20260508-m10-cloudflare-https-waf-cdn-r2-qa.md`
- `docs/docker-runtime-policy.md`
- `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php`
- `apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/.env.example`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `scripts/platform-cloudflare-readiness.sh`
- `scripts/ticket-image-cdn-check.sh`
- `scripts/k6-run-baseline.sh`
- `load-tests/README.md`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `ops/m10/cloudflare-waf-rate-limit-rules.json`
- `ops/m10/cloudflare-cache-bypass-rules.json`
- `docs/m10-deployment-monitoring-load-test.md`

## Scope

Perform focused QA re-test for the Backend remediation.

Inspect at minimum:

```text
apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php
apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php
apps/platform-api/config/platform.php
apps/platform-api/.env.example
apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php
scripts/platform-cloudflare-readiness.sh
scripts/ticket-image-cdn-check.sh
scripts/k6-run-baseline.sh
load-tests/README.md
load-tests/k6/ticket-image-cdn-spike.js
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/r2-ticket-image-strategy.md
ops/m10/ticket-image-cdn-load-test-runbook.md
ops/m10/cloudflare-waf-rate-limit-rules.json
ops/m10/cloudflare-cache-bypass-rules.json
docs/m10-deployment-monitoring-load-test.md
```

Re-test must include:

```text
default readiness output
fake configured Cloudflare/R2/CDN env without image evidence
fake configured Cloudflare/R2/CDN env with IMAGE_PATH
fake configured Cloudflare/R2/CDN env with TICKET_IMAGE_CDN_IMAGE_PATH
fake configured Cloudflare/R2/CDN env with BASE_URL but no image evidence
Docker regression tests
route/smoke guardrails
k6 inspect and helper guardrails
docs/runbook wording alignment
secret/no-raw-value checks
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, ops, scripts, load-tests, or Board.
- Do not change API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, back-office flow, or business rules.
- Do not approve staging, production, client delivery, Cloudflare production activation, DNS ownership, HTTPS enforcement, WAF/rate-limit deployment, cache-bypass deployment, real R2 delivery, real CDN cache-hit ratio, Horizon/Reverb, migration rehearsal, production secret management, Meno license, npm audit, or back-office production-readiness gates.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, Cloudflare CLI, wrangler, aws, or runtime commands on the host machine.
- Do not copy real Cloudflare tokens, account IDs tied to production, R2 keys, signed URLs, bearer tokens, private certificates, production URLs, or other secrets into QA reports/artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md and ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa/**
```

If a defect requires implementation, docs, schema, command, readiness logic, Cloudflare/R2 artifact, secret boundary, k6 guard, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, test, migration, queue, scheduler, k6, Cloudflare, wrangler, aws, and runtime commands.
3. Inspect `git status --short` and separate this remediation from unrelated dirty workspace noise.
4. Review Backend remediation handoff for:

```text
files changed
redaction approach
ticket-image evidence/blocker approach
readiness JSON behavior for default env
readiness JSON behavior for fake configured env without image evidence
readiness JSON behavior for fake configured env with explicit image evidence
confirmation that raw fake identifiers do not appear in readiness output
Docker validation
known risks
```

5. Verify readiness output redaction. The following fake values must not appear raw in any readiness JSON output or QA artifact:

```text
qa-acct-fake-redaction
qa-zone-fake-redaction
qa-token-fake-redaction
https://api.cloudflare.fake-redaction.test/client/v4
https://cdn.fake-redaction.test
https://r2.fake-redaction.test
qa-r2-bucket-fake-redaction
qa-r2-access-key-id-fake-redaction
qa-r2-secret-fake-redaction
/tickets/qa-redaction-safe.png
/tickets/qa-redaction-safe-alt.png
https://api.fake-redaction.test
```

6. Verify the output uses safe fields only:

```text
cloudflare.configured.* booleans
cloudflare.redacted_config.* as [CONFIGURED], [REDACTED], or null
cdn_r2_ticket_images.configured.* booleans
cdn_r2_ticket_images.redacted_config.* as [CONFIGURED], [REDACTED], or null
```

7. Verify fake configured env without image evidence:

```text
status is blocked_external
cdn_r2_ticket_images.status is missing_ticket_image_evidence or equivalent explicit blocked status
blockers include ticket_image_cdn_image_path_missing
production_approved is false
external_cloudflare_calls_attempted is false
external_r2_calls_attempted is false
raw fake values are absent
```

8. Verify fake configured env with `IMAGE_PATH=/tickets/qa-redaction-safe.png`:

```text
ticket_image_cdn_image_path_missing is absent
cdn_r2_ticket_images.configured.ticket_image_object_path is true
cdn_r2_ticket_images.redacted_config.ticket_image_object_path is [CONFIGURED]
raw image path is absent
status may be ready_local for local dry-run only
production_approved remains false
external_cloudflare_calls_attempted remains false
external_r2_calls_attempted remains false
```

9. Verify fake configured env with `TICKET_IMAGE_CDN_IMAGE_PATH=/tickets/qa-redaction-safe-alt.png` behaves like `IMAGE_PATH`.
10. Verify fake configured env with `BASE_URL=https://api.fake-redaction.test` but no image evidence remains blocked and does not expose the `BASE_URL`.
11. Verify k6 and helper behavior:

```text
ticket-image-cdn-spike.js accepts IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
ticket-image-cdn-spike.js intentionally ignores normal API BASE_URL
scripts/ticket-image-cdn-check.sh prints a blocker and exits 0 when CDN_BASE_URL/image evidence is missing
scripts/k6-run-baseline.sh skips ticket-image-cdn-spike unless CDN_BASE_URL plus IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH exists
```

12. Verify docs/runbooks are aligned. Fail or record a defect if docs still say only `IMAGE_PATH` is accepted where the implementation accepts `TICKET_IMAGE_CDN_IMAGE_PATH` too, unless the wording is intentionally scoped and not misleading.
13. Verify previous green evidence still holds:

```text
custom-domain activation guard still requires DNS/SSL/proxy/HTTPS evidence
WAF/rate-limit JSON parses
cache-bypass JSON parses
no Cloudflare HTTP API route is added
platform:smoke still passes
full platform-api suite still passes
```

14. Capture or summarize safe command output under:

```text
ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa/**
```

Do not copy secrets into artifacts. Redact any sensitive-looking values.

15. Write QA report to:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- `M10CloudflareHttpsWafCdnR2Test` passes and includes remediation coverage.
- Full platform-api test suite passes.
- `route:list` passes and shows no Cloudflare HTTP route or public API drift attributable to this remediation.
- `platform:smoke` passes.
- Default `platform:cloudflare:readiness --format=json` passes and remains safe.
- Fake configured env without image evidence remains `blocked_external`.
- Fake configured env without image evidence includes `ticket_image_cdn_image_path_missing`.
- Fake configured env without image evidence does not expose raw Cloudflare/R2/CDN values.
- Fake configured env with `IMAGE_PATH` removes only the image-path blocker and does not expose the image path.
- Fake configured env with `TICKET_IMAGE_CDN_IMAGE_PATH` removes only the image-path blocker and does not expose the image path.
- `BASE_URL` alone cannot satisfy ticket-image CDN/R2 evidence and does not appear raw in readiness output.
- Readiness output reports booleans/placeholders only for configured infrastructure values.
- `production_approved=false` remains true in all local/dry-run probes.
- `external_cloudflare_calls_attempted=false` and `external_r2_calls_attempted=false` remain true in all probes.
- k6 ticket-image script passes Docker inspect.
- Ticket-image helper/check refuses to claim coverage without explicit CDN URL plus image evidence.
- Docs/runbooks align with the `IMAGE_PATH` / `TICKET_IMAGE_CDN_IMAGE_PATH` evidence contract.
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
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" -e CDN_BASE_URL=https://cdn.fake-redaction.test -e IMAGE_PATH=/tickets/qa-redaction-safe.png grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" -e CDN_BASE_URL=https://cdn.fake-redaction.test -e TICKET_IMAGE_CDN_IMAGE_PATH=/tickets/qa-redaction-safe-alt.png grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

Required readiness probes:

```sh
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CLOUDFLARE_API_BASE_URL=https://api.cloudflare.fake-redaction.test/client/v4 -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CLOUDFLARE_API_BASE_URL=https://api.cloudflare.fake-redaction.test/client/v4 -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction -e IMAGE_PATH=/tickets/qa-redaction-safe.png platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CLOUDFLARE_API_BASE_URL=https://api.cloudflare.fake-redaction.test/client/v4 -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction -e TICKET_IMAGE_CDN_IMAGE_PATH=/tickets/qa-redaction-safe-alt.png platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm -e BASE_URL=https://api.fake-redaction.test -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CLOUDFLARE_API_BASE_URL=https://api.cloudflare.fake-redaction.test/client/v4 -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction platform-api php artisan platform:cloudflare:readiness --format=json
```

Required helper/static validation:

```sh
git status --short
sh -n scripts/platform-cloudflare-readiness.sh
sh -n scripts/ticket-image-cdn-check.sh
sh -n scripts/k6-run-baseline.sh
jq empty ops/m10/cloudflare-waf-rate-limit-rules.json
jq empty ops/m10/cloudflare-cache-bypass-rules.json
scripts/ticket-image-cdn-check.sh
rg -n "TICKET_IMAGE_CDN_IMAGE_PATH|IMAGE_PATH|CDN_BASE_URL|BASE_URL is intentionally ignored|ticket_image_cdn_image_path_missing|\\[CONFIGURED\\]|\\[REDACTED\\]" apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php apps/platform-api/config/platform.php apps/platform-api/.env.example apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php scripts load-tests ops/m10 docs/m10-deployment-monitoring-load-test.md
rg -n "logo|theme|payment|domain|feature" apps/platform-api/.env.example
rg -n "qa-acct-fake-redaction|qa-zone-fake-redaction|qa-token-fake-redaction|cdn.fake-redaction.test|r2.fake-redaction.test|qa-r2-bucket-fake-redaction|qa-r2-access-key-id-fake-redaction|qa-r2-secret-fake-redaction|qa-redaction-safe|api.fake-redaction.test" ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md
```

Interpretation notes:

```text
The final rg for fake values should return no matches after QA writes redacted artifacts/report. If it returns matches because QA intentionally records the forbidden-value checklist, redact those values and re-run.
Secret scans may match safe placeholders, env names, docs examples, and k6 variable names. QA must distinguish placeholders/redacted output from real secret leakage.
scripts/ticket-image-cdn-check.sh may print a blocker and exit 0 when CDN_BASE_URL/image evidence is absent; that is acceptable for local/dev readiness if the blocker is explicit.
Do not run real Cloudflare/wrangler/aws commands on the host.
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
remediation summary
redaction/safe-output review
fake configured env without image evidence result
fake configured env with IMAGE_PATH result
fake configured env with TICKET_IMAGE_CDN_IMAGE_PATH result
fake configured env with BASE_URL-only result
raw fake value leakage check
ticket-image k6/helper guard review
docs/runbook alignment review
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
