# QA Report

## Task

`20260508-m10-full-k6-load-test-execution`

QA verdict: `PASS WITH RISKS`

## Scope Tested

Validated the local/dev M10 full k6 execution slice against the QA task, Backend handoff, M10 release-gate planning docs, Docker runtime policy, OpenAPI Partner Sync paths, k6 scripts, helper scripts, and platform-api regression suite.

Inspected key files:

```text
apps/platform-api/app/Console/Commands/PrepareK6BaselineCommand.php
apps/platform-api/app/Modules/Partner/Http/Controllers/PartnerSyncController.php
apps/platform-api/app/Modules/Partner/Services/PartnerSyncService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
apps/platform-api/tests/Feature/M10K6LoadTestExecutionTest.php
load-tests/k6/*.js
load-tests/k6/lib/profile.js
load-tests/README.md
load-tests/results/.gitignore
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
docs/m10-deployment-monitoring-load-test.md
docs/openapi.yaml
ops/m10/runtime-readiness.md
```

Artifacts are under:

```text
ai-agents/reports/artifacts/20260508-m10-full-k6-load-test-execution-qa/
```

Generated token/env files were not copied into QA artifacts. Only a redacted env-key artifact and redacted k6 summary metrics were saved.

## Commands Run

All runtime/package/Artisan/test/k6 commands were Docker-only:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=M10K6LoadTestExecutionTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test --filter=M10
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker run --rm grafana/k6:latest version
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect <7 scripts>
scripts/k6-prepare-baseline-fixtures.sh
scripts/k6-run-baseline.sh
```

Static checks included `git status --short`, `git check-ignore`, secret/token scans over tracked source-like paths, Partner Sync/OpenAPI path scans, and release-boundary doc scans.

## Test Results

Platform validation:

```text
docker compose config --quiet: PASS
docker compose up -d postgres valkey platform-api: PASS
composer install: PASS
migrate:fresh --seed --env=testing: PASS
M10K6LoadTestExecutionTest: PASS, 1 test / 37 assertions
ConsoleCommandStructureTest: PASS, 3 tests / 67 assertions
php artisan test --filter=M10: PASS, 6 tests / 131 assertions
full platform-api suite: PASS, 121 tests / 2998 assertions
platform:smoke after reseed: PASS
route:list: PASS, 199 routes; Partner Sync routes present
```

k6 validation:

```text
grafana/k6 version: PASS
k6 inspect for all 7 scripts: PASS
fixture generation helper: PASS
baseline runner: PASS for 6 API-backed scenarios
ticket-image-cdn-spike: skipped with blocker artifact
```

Latest QA k6 run:

```text
load-tests/results/20260508T072215Z
```

Smoke metrics from the QA run:

| Scenario | Checks | p95 | http_req_failed |
| --- | ---: | ---: | ---: |
| `customer-stock-search` | 20/20 | 52.10 ms | 0% |
| `concurrent-booking-same-stock` | 6/6 | 62.76 ms | 0% |
| `checkout-wallet-consistency` | 6/6 | 72.14 ms | 0% |
| `partner-tenant-burst-sync` | 85/85 | 47.76 ms | 0% |
| `reward-publish-spike` | 38/38 | 41.15 ms | 0% |
| `reward-checking-queue-chunk` | 6/6 | 57.25 ms | 0% |

Ticket image skipped artifact:

```text
status: skipped
reason: Local/dev baseline has no Cloudflare CDN/R2 ticket image path. Set CDN_BASE_URL and IMAGE_PATH to run this scenario.
```

## Review Findings

No blocking defects found.

Traceability finding:

```text
expected handoff by original backend task: ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-handoff.md
actual active handoff: ai-agents/handoffs/20260508-m10-full-k6-load-test-execution-backend-develop-handoff.md
severity: P3 traceability only
```

## Fixture / Secret Handling

PASS WITH RISKS.

`load-tests:k6:prepare` is registered and reproducible. It writes both:

```text
load-tests/results/k6-baseline-env.json
load-tests/results/k6-baseline.env
```

The fixture command refuses production, writes generated bearer tokens only into ignored runtime artifacts, and tests assert database token storage uses hashes rather than storing the plaintext partner token.

`load-tests/results/.gitignore` ignores generated env, JSON, summary, and skipped artifacts. `git check-ignore` confirmed the QA-generated env/json/summary/skipped artifacts are ignored.

Secret scan found only safe placeholders/template variable names in scripts/docs/handoff. No generated bearer token pattern was found in QA artifacts.

## Partner Sync Review

PASS.

`docs/openapi.yaml` already contains:

```text
/partner-sync/allocations
/partner-sync/events
```

`apps/platform-api/routes/api.php` exposes:

```text
GET /api/v1/partner-sync/allocations
POST /api/v1/partner-sync/events
```

Implementation enforces bearer token lookup against `partner_api_clients.secret_hash`, required `X-Partner-Id` and `X-Tenant-Id`, active partner, tenant ownership/status, event partner/tenant header matching, Idempotency-Key validation on event submit, and duplicate event de-dupe through `sync_inbox.event_id`. Focused tests cover successful event submit, duplicate submit, and tenant mismatch rejection.

## Docs / Release Boundary

PASS.

Docs clearly state this is local/dev readiness only and not staging, production, or client-delivery approval. Release gates still open:

```text
production observability and alert channels
Cloudflare HTTPS/WAF/rate-limit/CDN/R2 integration
real CDN/R2 ticket image load test
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

## Risks / Not Tested

- Workspace remains broadly dirty/untracked from prior multi-agent work. `apps/customer/**`, `apps/back-office/**`, `document/**`, `compose.yaml`, `load-tests/**`, `ops/**`, `scripts/**`, and many ai-agent files are dirty/untracked. QA did not find evidence tying forbidden customer/back-office/document drift to this QA execution, but git status alone cannot prove attribution.
- `load-tests/results/.gitignore` correctly ignores generated artifacts, but because the whole `load-tests/**` tree is still untracked in this workspace snapshot, `git status --short -- load-tests/results` shows the directory due to the untracked `.gitignore`; `git status --ignored` separately shows generated env/summary files as ignored.
- `release-candidate` profile is wired and inspected, but was not executed. This is correct for local/dev QA and remains a staging/load-test-environment gate.
- `ticket-image-cdn-spike.js` was skipped locally as expected. CDN/R2 image performance is not verified.
- `scripts/k6-run-baseline.sh` will run `ticket-image-cdn-spike.js` when `IMAGE_PATH` is set and either `CDN_BASE_URL` or `BASE_URL` is set. The default generated fixture leaves `IMAGE_PATH` empty, so QA baseline correctly skips it. Before closing the CDN/R2 gate, Coordinator may want Backend to tighten this guard to require explicit CDN/R2 env rather than the normal API `BASE_URL` fallback.

## Recommendation

Coordinator can accept this slice as local/dev k6 execution readiness with the risks above. Do not treat it as staging, production, CDN/R2, or client-delivery approval. Route the remaining M10 release gates as separate slices.

## Next Agent

Coordinator
