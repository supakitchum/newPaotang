# QA Report

## Task

`20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa`

Verdict: PASS WITH RISKS.

The remediation fixes the two accepted P2 blockers from Coordinator review: readiness output no longer exposes configured Cloudflare/R2 values, and configured CDN/R2 env without explicit ticket-image evidence remains blocked. One documentation mismatch remains in `load-tests/README.md`; Coordinator should decide whether to route that as follow-up before final approval.

Next Agent: Coordinator.

## Scope Tested

- Docker-only backend/runtime execution per project policy.
- Cloudflare readiness JSON redaction and release-boundary behavior.
- Ticket-image CDN/R2 evidence gate for missing image path, `IMAGE_PATH`, `TICKET_IMAGE_CDN_IMAGE_PATH`, and unrelated `BASE_URL`.
- k6 ticket-image prerequisite behavior.
- Smoke, route list, WAF/cache JSON, shell syntax, focused tests, and full platform API regression.
- Docs/runbook alignment for accepted image path env names.

Artifacts:

`ai-agents/reports/artifacts/20260508-m10-cloudflare-https-waf-cdn-r2-remediation-qa/`

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
docker compose run --rm [sanitized fake env] platform-api php artisan platform:cloudflare:readiness --format=json
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" -e CDN_BASE_URL="[sanitized]" -e IMAGE_PATH="[sanitized]" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" -e CDN_BASE_URL="[sanitized]" -e TICKET_IMAGE_CDN_IMAGE_PATH="[sanitized]" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

Static/helper commands:

```sh
git status --short
sh -n scripts/platform-cloudflare-readiness.sh
sh -n scripts/ticket-image-cdn-check.sh
sh -n scripts/k6-run-baseline.sh
jq empty ops/m10/cloudflare-waf-rate-limit-rules.json
jq empty ops/m10/cloudflare-cache-bypass-rules.json
scripts/ticket-image-cdn-check.sh
rg for remediation patterns, env config names, tenant-config leakage, and final fake-value leakage
```

## Test Results

- `docker compose config --quiet`: PASS.
- Script syntax and WAF/cache JSON parse: PASS.
- `M10CloudflareHttpsWafCdnR2Test`: PASS, 5 tests / 136 assertions.
- `M10K6LoadTestExecutionTest`: PASS, 1 test / 37 assertions.
- `M10DeploymentReadinessTest`: PASS, 5 tests / 94 assertions.
- `PartnerProvisioningTest`: PASS, 4 tests / 145 assertions.
- `TenantResolutionTest`: PASS, 5 tests / 11 assertions.
- `ConsoleCommandStructureTest`: PASS, 3 tests / 77 assertions.
- Full platform API suite: PASS, 131 tests / 3284 assertions.
- `route:list`: PASS, 199 routes.
- `platform:smoke`: PASS.
- Default readiness: PASS, `blocked_external`, `production_approved=false`, no external Cloudflare/R2 calls.
- Fake configured env without image evidence: PASS, remains `blocked_external`; blocker is `ticket_image_cdn_image_path_missing`.
- Fake configured env with `IMAGE_PATH`: PASS, image blocker absent; `ticket_image_object_path=true`; redacted output uses `[CONFIGURED]`; `production_approved=false`.
- Fake configured env with `TICKET_IMAGE_CDN_IMAGE_PATH`: PASS, same evidence behavior as `IMAGE_PATH`.
- Fake configured env with unrelated `BASE_URL` and no image evidence: PASS, remains blocked; `BASE_URL` does not satisfy ticket-image evidence.
- k6 inspect accepts both image path env names and ignores normal API `BASE_URL`: PASS.
- Raw fake-value leak checks for sanitized readiness artifacts: PASS, zero raw fake-value leaks.

## Findings

### [P3] `load-tests/README.md` still documents only `IMAGE_PATH` for ticket-image CDN coverage

Evidence:

- `load-tests/README.md:46` says the baseline runner needs `CDN_BASE_URL` and `IMAGE_PATH`.
- `load-tests/README.md:48` says CDN/R2 coverage is only claimable with explicit `CDN_BASE_URL` and `IMAGE_PATH`.
- Implementation and runtime validation now accept `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH`.

Impact:

The runtime and primary ops docs are aligned, but this README can mislead QA/Ops into thinking the new `TICKET_IMAGE_CDN_IMAGE_PATH` env is not accepted. This is documentation-only based on the retest; runtime behavior passed.

Suggested routing: Coordinator to decide whether to send a small docs cleanup task.

## Residual Risks / Not Tested

- Real Cloudflare API, DNS ownership, proxy, SSL, HTTPS enforcement, WAF deployment, cache-bypass deployment, R2 bucket, and real CDN object fetch were not tested or approved.
- No vendor mutation tools were run.
- Production/client delivery remains not approved; all readiness probes kept `production_approved=false`.
- The workspace is broadly dirty from other active work; QA only wrote this report and artifacts under the remediation QA artifact directory.

