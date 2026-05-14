# 20260514 Lottery Image Central Ops ZIP Preview QA Report

## Result

PASS

No release-blocking defects were found for `lottery-image-central-ops-usability-zip-preview`.

## Scope Under Test

- QA task: `lottery-image-central-ops-zip-preview-qa`
- Clean QA worktree: `/Users/supakit/WorkSpace/www/newPaotang-zip-preview-qa`
- Shared report/artifact worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- QA worktree HEAD: `3217f3b6f595a21b7f47eeebde8c16cdf544a591`
- QA worktree `origin/develop`: `3217f3b6f595a21b7f47eeebde8c16cdf544a591`
- Backend implementation commit under test: `60f40d08d8956c131774e4e122536b819fa98888`
- BO implementation commit under test: `4ecc8f0c1dd291bb64e36610ea4a666ae2d60c9b`

Both implementation commits are present locally and contained by `origin/develop`.

## Start Gate

PASS

- Backend handoff found: `ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md`
- Backend handoff includes commit hash: `60f40d08d8956c131774e4e122536b819fa98888`
- BO handoff found: `ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md`
- BO handoff includes commit hash: `4ecc8f0c1dd291bb64e36610ea4a666ae2d60c9b`
- `git branch -r --contains` confirmed both commits are reachable from `origin/develop`.

## Artifacts

Created under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-central-ops-zip-preview-qa/
```

Key evidence files:

- `validation/git-diff-check.log`
- `validation/docker-compose-build-platform-bo.log`
- `validation/docker-compose-up-platform-bo.log`
- `validation/docker-compose-ps.log`
- `backend/phpunit-lottery-image-operations.log`
- `backend/phpunit-partner-branding.log`
- `backend/phpunit-central-game.log`
- `backend/readiness-json.log`
- `backend/pending-backgrounds-dry-run.log`
- `back-office/npm-lint.log`
- `back-office/npm-test.log`
- `back-office/npm-build.log`
- `back-office/structural-lottery-image-operations.log`
- `back-office/structural-lottery-branding.log`
- `back-office/browser-route-smoke-after-restart.json`
- `back-office/back-office-log-error-scan.log`
- `openapi/openapi-yaml-parse-docker-ruby.log`
- `scans/artifact-secret-scan.log`

## Validation Commands

All application runtime validation was run through Docker from the clean QA worktree with project name `newpaotang`.

| Command | Result | Notes |
| --- | --- | --- |
| `git diff --check` | PASS | No whitespace errors. |
| `docker compose -p newpaotang build platform-api back-office` | PASS | Images built successfully. |
| `docker compose -p newpaotang up -d postgres valkey platform-api back-office` | PASS | Required services started. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=LotteryImageOperationsTest` | PASS | Exit 0; PHPUnit reported 10 warnings, 185 assertions, no failures/errors. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest` | PASS | Exit 0; PHPUnit reported 1 warning, 24 assertions, no failures/errors. |
| `docker compose -p newpaotang run --rm platform-api php artisan test --filter=CentralGameTest` | PASS | Exit 0; PHPUnit reported 1 warning, 25 assertions, no failures/errors. |
| `docker compose -p newpaotang run --rm platform-api php artisan lottery-images:readiness --format=json` | PASS | Readiness JSON returned and redacted secret state. |
| `docker compose -p newpaotang run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run` | PASS | 0 ready / 0 dispatched for central and partner pending work. |
| `docker compose -p newpaotang run --rm back-office npm run lint` | PASS | Static BO checks passed. |
| `docker compose -p newpaotang run --rm back-office npm run test` | PASS | Static BO test checks passed. |
| `docker compose -p newpaotang run --rm back-office npm run build` | PASS | Build passed; warning for runtime-resolved `media-33.jpg` and Node deprecation notice. |
| `docker compose -p newpaotang run --rm back-office node scripts/check-lottery-image-operations.mjs` | PASS | `lottery image operations check passed`. |
| `docker compose -p newpaotang run --rm back-office node scripts/check-lottery-branding.mjs` | PASS | `lottery branding check passed`. |
| `docker run --rm -v /Users/supakit/WorkSpace/www/newPaotang-zip-preview-qa:/repo -w /repo ruby:3.3-alpine ruby -e "require 'yaml'; YAML.load_file('docs/openapi.yaml'); puts 'openapi yaml ok'"` | PASS | OpenAPI YAML parsed successfully. |

## Backend Evidence

PASS

`LotteryImageOperationsTest` covered central-only lottery image operations, PNG ZIP import, invalid/mixed ZIP rejection, generated full/thumb readiness registration, manual-number preview modes, no preview side effects, mix persistence, and pending asset retry regressions. The focused Docker run exited 0 with 185 assertions.

`PartnerLotteryBrandingAssetTest` covered central-only partner branding behavior and route-locked partner branding assets. The focused Docker run exited 0 with 24 assertions.

`CentralGameTest` passed for the focused central game route surface used by Games deep-link coverage. The focused Docker run exited 0 with 25 assertions.

Readiness command returned:

```text
configured=true
disk=lottery_images
disk_driver=local
cdn_base_url_present=true
queue_configured=true
runtime_webp_ready=true
secrets_redacted=true
production_ready=false
blocking_reasons=[object_storage_disk_not_s3_compatible, object_storage_bucket_missing, object_storage_region_missing]
required_queue_names=[stock-image-generation, stock-partner-image-generation]
```

The `production_ready=false` state is expected for local Docker because object storage rollout is out of scope for this QA task.

## Back Office Evidence

PASS

BO lint, test, build, and both focused structural scripts passed through Docker.

Structural checks confirmed:

- Lottery image ZIP import uses multipart `FormData`.
- Games row actions deep-link to `/admin/central/lottery-images?game_id={game_id}`.
- Query parameter `game_id` preselect behavior is represented.
- Game selection uses game identity while displaying game names.
- Preview supports `central_unbranded` default behavior and explicit `partner_branded` behavior.
- Partner-branded missing asset warning/fallback paths are represented.
- Partner branding workflow is route partner locked and exposes no partner selector/body override.
- Central navigation routes are used for the custom lottery image and partner branding workflows.

## Browser Route Smoke

PASS after BO service restart.

Routes exercised through the Codex in-app browser:

- `http://localhost:3100/admin/central/lottery-images?game_id=gam_lottery`
- `http://localhost:3100/admin/central/partners/partner_demo/lottery-branding`
- `http://localhost:3100/admin/tenant/dashboard`

Each route redirected to the login shell with the original path preserved in `redirect`, rendered `NewPaotang Back Office`, and showed no 500 or internal server error state.

Operational note: immediately after `npm run build`, the already-running Nuxt dev server showed a transient internal server error for `#internal/nuxt/paths`. Restarting only the `back-office` service cleared it, and the final route smoke plus log scan passed. This appears to be a dev-server artifact from rebuilding `.nuxt` while the service was running, not a product defect in the submitted implementation.

## Central-Only Visibility And Enforcement

PASS

Evidence comes from the backend permissioned feature tests, BO structural checks, and route smoke:

- New backend routes use central scope in the tested route surface.
- Tenant-scope ZIP import rejection is covered by `LotteryImageOperationsTest`.
- Partner branding preview uses the route `partner_id` as authoritative input.
- BO central routes are not exposed through tenant dashboard smoke without auth; protected deep links preserve redirect to login.
- BO structural checks verify central route wiring for lottery image operations and partner branding.

## ZIP Import Evidence

PASS

`LotteryImageOperationsTest` covered:

- Valid root-level PNG ZIP import.
- Tenant rejection.
- Non-PNG / wrong-count ZIP rejection.
- Generated source/full/thumb asset registration.
- Ordered background positions from sequential ZIP names.
- Readiness refresh after import behavior.

## Preview Mode And Side-Effect Evidence

PASS

`LotteryImageOperationsTest`, `PartnerLotteryBrandingAssetTest`, and BO structural checks covered:

- `central_unbranded` manual-number preview.
- Partner selection still defaulting to unbranded unless explicit partner mode is selected.
- Explicit `partner_branded` preview behavior.
- Partner-branded warning/fallback behavior when assets are missing.
- Partner branding preview locked to route partner.
- Body partner mismatch cannot override route partner.
- Preview actions create no stock rows.
- Preview actions create no permanent lottery image rows.
- Preview actions do not lock partner branding.

## OpenAPI

PASS

`docs/openapi.yaml` parsed successfully with a Dockerized Ruby YAML parser:

```text
openapi yaml ok
```

## Credential And Artifact Scan

PASS

The QA artifact scan returned no matches. The scan log is empty:

```text
0 bytes ai-agents/reports/artifacts/20260514-lottery-image-central-ops-zip-preview-qa/scans/artifact-secret-scan.log
```

No generated report/artifact required touching the known credential-bearing file:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Unrelated Dirty Files

The shared worktree `/Users/supakit/WorkSpace/www/newPaotang` was already dirty and behind `origin/develop` before this QA pass. It contains unrelated modified/staged/untracked files from other work, including back-office files, platform-api files, generated lottery image assets, Docker files, and prior QA artifacts.

Per guardrail, those unrelated files were not cleaned, reverted, staged, or committed. QA execution used the clean detached worktree `/Users/supakit/WorkSpace/www/newPaotang-zip-preview-qa` at `origin/develop`.

Known QA test side effect in the clean QA worktree:

```text
M apps/platform-api/.phpunit.result.cache
```

This cache file was left untouched.

## Defects

None.

## Residual Notes

- PHPUnit reports warning status for the focused backend tests, but all focused runs exited 0 and had no failures/errors.
- The BO build warning for `media-33.jpg` runtime resolution was already a known local asset warning in the BO handoff and did not fail the build.
- Authenticated browser UAT was not performed because no credentials were supplied in this QA task.

## Next Agent

Coordinator

Recommended action: accept this QA PASS and proceed with release/orchestration review for `lottery-image-central-ops-usability-zip-preview`.
