# QA Report

## Task

`20260508-m10-cloudflare-https-waf-cdn-r2`

Verdict: FAIL.

The Docker-local foundation mostly works and the required test suite is green, but QA found readiness-command defects in the safe output and release-boundary behavior. This report should go to Coordinator for review and routing decision.

## Scope Tested

- Docker runtime policy for backend tests, migrations, commands, and k6 inspection.
- Cloudflare readiness command and safe JSON output.
- Domain readiness schema/model and activation guard.
- WAF/rate-limit and cache-bypass templates.
- CDN/R2 ticket-image strategy and k6 prerequisite guard.
- Env/secret boundary.
- Docs/runbook release boundary.
- Route list/API drift check.
- Customer/back-office/source-of-truth drift review from `git status`.

Files inspected included:

- `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php`
- `apps/platform-api/app/Console/Commands/PlatformCloudflareReadinessCommand.php`
- `apps/platform-api/app/Models/PartnerTenantDomain.php`
- `apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php`
- `apps/platform-api/database/migrations/2026_05_08_000002_add_cloudflare_readiness_to_partner_tenant_domains.php`
- `apps/platform-api/tests/Feature/M10CloudflareHttpsWafCdnR2Test.php`
- `ops/m10/cloudflare-waf-rate-limit-rules.json`
- `ops/m10/cloudflare-cache-bypass-rules.json`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `load-tests/k6/ticket-image-cdn-spike.js`
- `scripts/platform-cloudflare-readiness.sh`
- `scripts/ticket-image-cdn-check.sh`
- `scripts/k6-run-baseline.sh`

Artifacts are under:

`ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-qa/`

## Commands Run

Docker/runtime commands:

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
docker compose run --rm -e CLOUDFLARE_ACCOUNT_ID=qa-acct-fake-redaction -e CLOUDFLARE_ZONE_ID=qa-zone-fake-redaction -e CLOUDFLARE_API_TOKEN=qa-token-fake-redaction -e CDN_BASE_URL=https://cdn.fake-redaction.test -e R2_ENDPOINT=https://r2.fake-redaction.test -e R2_BUCKET=qa-r2-bucket-fake-redaction -e R2_ACCESS_KEY_ID=qa-r2-access-key-id-fake-redaction -e R2_SECRET_ACCESS_KEY=qa-r2-secret-fake-redaction platform-api php artisan platform:cloudflare:readiness --format=json
```

Static/helper commands:

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

## Test Results

- `docker compose config --quiet`: PASS.
- `docker compose up -d postgres valkey platform-api`: PASS.
- `composer install`: PASS.
- `migrate:fresh --seed --env=testing`: PASS; new Cloudflare readiness migration applied.
- `M10CloudflareHttpsWafCdnR2Test`: PASS, 3 tests / 76 assertions.
- `M10K6LoadTestExecutionTest`: PASS, 1 test / 37 assertions.
- `M10DeploymentReadinessTest`: PASS, 5 tests / 94 assertions.
- `PartnerProvisioningTest`: PASS, 4 tests / 145 assertions.
- `TenantResolutionTest`: PASS, 5 tests / 11 assertions.
- `ConsoleCommandStructureTest`: PASS, 3 tests / 77 assertions.
- Full platform API suite: PASS, 129 tests / 3224 assertions.
- `route:list`: PASS, 199 routes; no Cloudflare HTTP route added.
- `platform:smoke`: PASS.
- Default `platform:cloudflare:readiness --format=json`: PASS command execution, expected `blocked_external`, `production_approved=false`, `external_cloudflare_calls_attempted=false`, `external_r2_calls_attempted=false`.
- k6 inspect for `ticket-image-cdn-spike.js`: PASS.
- `scripts/ticket-image-cdn-check.sh`: PASS helper behavior; it inspects through Docker and prints the expected blocker when `CDN_BASE_URL`/`IMAGE_PATH` are absent.
- WAF/cache JSON parse: PASS.

## Defects

### [P2] Readiness output exposes configured Cloudflare/R2 identifiers instead of presence-only safe output

Evidence:

- Code builds `redacted_config` from raw Cloudflare values at `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php:77`.
- Code builds `redacted_config` from raw CDN/R2 values at `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php:237`.
- QA fake-env probe output includes unredacted `zone_id` and `r2_access_key_id`:
  - `cloudflare-readiness-fake-env-redaction.raw.json:27`
  - `cloudflare-readiness-fake-env-redaction.raw.json:194`

Impact:

The QA task requires readiness output to redact sensitive fields and report credential presence booleans only. With configured values, the command currently emits raw `zone_id`, `cdn_base_url`, `r2_endpoint`, `r2_bucket`, and `r2_access_key_id`. Those fake values were intentionally supplied by QA, but the same output shape would expose real infrastructure identifiers if production-like env values were present.

Suggested owner if Coordinator accepts this defect: Backend Develop.

### [P2] Configured env values can make readiness report `ready_local` without real CDN image evidence

Evidence:

- `CloudflareReadinessService::ticketImageReadiness()` only checks `cdn_base_url`, `r2_endpoint`, and `r2_bucket` blockers at `apps/platform-api/app/Shared/Cloudflare/CloudflareReadinessService.php:215`.
- It reports `requires_explicit_image_path=true` but does not check any `IMAGE_PATH` or equivalent evidence before returning `configured_dry_run`.
- QA fake-env probe returned `fake_env_status=ready_local` and `fake_env_blockers=` in `json-command-summary.txt`.

Impact:

The task requires the ticket-image CDN guard to only claim CDN/R2 coverage when explicit `CDN_BASE_URL` and `IMAGE_PATH` exist, and the docs/runbook require a real ticket-image object path before coverage is claimed. The helper script behaves correctly, but the readiness report can become `ready_local` with credentials/placeholders alone and no image-path evidence. That weakens the release gate.

Suggested owner if Coordinator accepts this defect: Backend Develop.

## Risks / Not Tested

- Real Cloudflare API, DNS ownership, proxy, SSL, HTTPS enforcement, WAF deployment, cache-bypass deployment, R2 bucket, CDN object path, and CDN cache-hit evidence were not tested and are not approved.
- No Cloudflare CLI, wrangler, aws, or real vendor mutation was run.
- The default local readiness output correctly keeps `production_approved=false` and `blocked_external`, but configured-env behavior needs remediation before approval.
- The workspace has broad pre-existing dirty/untracked files, including customer/back-office/document/docs areas. I did not edit implementation, docs, tasks, handoffs, Board, ops, scripts, or app source during QA.
- `forbidden-scope-status.txt` shows existing customer/document/docs noise; no evidence in this QA pass ties those changes to my QA work.

## Recommendation

Coordinator review required.

Suggested remediation before QA re-test, if Coordinator decides to send this back for implementation:

- Remove raw Cloudflare/R2 identifier values from readiness JSON, or redact all config fields and keep only `configured` booleans.
- Keep blockers present until real ticket-image CDN evidence exists, including an explicit image path or equivalent non-secret proof.
- Add/adjust tests to cover fake configured env values and assert no raw `zone_id`, `r2_access_key_id`, bucket, endpoint, or CDN URL leaks where the contract says presence-only.

## Next Agent

Coordinator
