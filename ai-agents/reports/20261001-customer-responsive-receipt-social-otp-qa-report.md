# customer-responsive-receipt-social-otp QA Report

Date: 2026-10-01, Asia/Bangkok
Agent: QA Tester
Recipient / Next Agent: Coordinator only
Overall Result: **BLOCKED**

## Decision

Independent local regressions, builds, responsive fixtures, receipt exports, and social security diagnostics passed. This is not an unconditional acceptance or production-release approval. The social API contract remains unresolved, shared runtime/login smoke is blocked, and approved native-device/real-provider acceptance has not been performed.

No confirmed implementation defect was found in the exercised cases. The blockers and incomplete acceptance below must remain visible; successful automated tests do not close them.

## Blockers For Coordinator

| ID | Gate | Evidence / Impact | Owner Recommendation |
| --- | --- | --- | --- |
| QA-G01 | Social contract, acceptance blocked | [OpenAPI request schema](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14336) still requires all new-member fields and does not document `existing_only` / `registration_required`. [Generic service](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerSocialAuthService.php:314) and [LINE service](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerLineAuthService.php:514) implement the minimal probe. Diagnostic tests cannot decide the authoritative contract. | Coordinator: decide contract and route documentation/implementation work as appropriate. |
| QA-G02 | Runtime Restore / Login Smoke, blocked | API, BO, customer and proxy were stopped before QA and remain stopped. Ports 3000/3100 refused connections; the disposable API CLI smoke reported `seeded-logins: failed`. No authorized admin credentials were supplied. | Coordinator: approve a data-preserving runtime recovery/login-validation task and provide approved test accounts. |
| QA-G03 | Real acceptance, not tested | No approved installed build/account/phone was supplied for this task. Native safe areas/keyboard/share/save, real SMS and Google/Apple/Facebook/LINE linking, and production news timing remain unverified. | Coordinator: arrange prerequisites and authorize a separate acceptance pass. |

No implementation, OpenAPI, BO asset, runtime configuration, or delivery handoff was edited. No defects were sent directly to Backend/BO. No staging, commit, push, installation, purchase, real SMS, real account linking, or deployment was performed.

## Source Snapshot

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: c8f130cdcc1a1addc3a7526597bd7a17107d574d
origin/develop: c8f130cdcc1a1addc3a7526597bd7a17107d574d
tracked application diff SHA-256:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
```

Read the May continuity handoff first, then the current October QA task/dispatch and repository safety rules. The October task explicitly permits testing this known dirty local delivery. `git fetch origin` succeeded; `git status --short --branch` showed the expected dirty develop baseline; `git merge --ff-only origin/develop` returned `Already up to date`; `git rev-parse HEAD` matched the dispatch. No synchronization changed the source.

The tracked application hash and six source/branding hashes were identical at start and finish. [Start status](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/start-status.txt) and [final status](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/final-status.txt) matched before adding this report. QA additions are confined to the report and its artifact directory. This HEAD alone does not contain the uncommitted delivery.

Untracked source inventory, separately verified:

| File | SHA-256 |
| --- | --- |
| `apps/customer/public/brand/siamblend-horizontal-logo.png` | `ea10f0e865573c27c7c80dded181b9aa8a77690e1d8edd9cd237149f7b14ab1b` |
| `apps/customer_flutter/assets/branding/siamblend_horizontal_logo.png` | Same logo hash |
| `apps/customer_flutter/lib/shared/services/home_news_preloader.dart` | `d38fc9076ccf60330c8697b3771d6882398bef6f4759ba6651de23eaa8d06c32` |
| `apps/customer_flutter/lib/shared/widgets/siamblend_receipt_logo.dart` | `5510aae9f84df9dab109eb1e011d0c11c04c4ac419976018bd89efdd48494c7e` |
| `apps/customer_flutter/tool/customer_ui_preview.dart` | `9e333dd07685e3cc0cd4ff52a7f9e43e4713744281b1afbf7388efeb72779091` |

The BO source `apps/back-office/public/brand/siamblend-bo-logo.png` also matches the logo hash. [Final hash evidence](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/final-source-hashes.txt).

## Independent Results

| Check | Observed Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | Exit 0 at start and finish. |
| Effective API configuration inside Docker | PASS | `effective_db=newpaotang_test`, `effective_env=testing`; explicit environment overrides on every DB-backed test command. |
| Existing API regressions | PASS, diagnostic only | 42 tests / 353 assertions, 18.02s. |
| New independent API diagnostics | PASS, diagnostic only | 3 tests / 96 assertions, 3.02s, final rerun. |
| Flutter analyze | PASS | `No issues found`, 34.9s. |
| Existing focused Flutter regressions | PASS | 173 tests, independently executed, not copied from delivery counts. |
| Additional QA render/export/dock/social/news fixtures | PASS | 27 tests, final rerun; hit-test warnings made fatal. These include 9 receipt/news and 18 dock/social cases. Earlier reruns are not added again to this count. |
| Flutter production web build | PASS | `lib/main.dart`, Siamblend runtime defines; 57.2s compilation. |
| Flutter fixture web build | PASS | `tool/customer_ui_preview.dart`, 38.3s compilation; served on unused loopback port 18091. |
| Legacy Nuxt | PASS checks/build | `npm ci`, all five configured `npm test` scripts, Nuxt/Nitro production build, exit 0. Static-script checks are not authenticated browser acceptance. |
| Actual receipt export files | PASS, fixture scope | Eight PNG/PDF pairs produced through production image/PDF exporters. Every PDF rendered and inspected; one-page A4, no encryption/forms/JavaScript. OS share/save remains NOT TESTED. |

All app/test/build/render commands ran in Docker. Host commands were limited to Git, file inspection/hashing, port/HTTP checks, and supported browser UI automation. Application source mounts for SDK/Node runners were read-only; dependencies and compilation ran in temporary container copies. No dependency upgrade was made to the source lockfiles.

Tool versions: Flutter 3.44.0, framework `559ffa3f75`, Dart 3.12.0; Node 22.23.2, npm 10.9.8; Nuxt 3.11.2, Nitro 2.9.6; Poppler 25.12.0-r1. Flutter's cached image reports channel `[user-branch]` / unknown source; the resolved image is recorded, not assumed to be the current upstream stable release. [Runner image IDs/digests](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/runner-image-digests.txt).

## Acceptance Coverage

| Criterion | Status | Details / Remaining Limit |
| --- | --- | --- |
| Receipt responsive layout/actions | PASS local fixtures; native NOT TESTED | Fresh widget/browser evidence at 320x568, 390x844, 1440x900. Full receipt scroll retains fixed Save/View Tickets above navigation. Widget variants add 1.3 text scale and 844x390 landscape, with simulated top 47/bottom 34 insets. Installed OS acceptance is not inferred. |
| Fonts/wallet labels/exports | PASS local fixtures | Loaded real Kanit and MaterialIcons. Thai primary-wallet label, English `Primary wallet`, and `QA Travel Wallet` remain intact. Actual full receipt PNG/PDF includes reference, draw date, quantity, store, amount and logo. Share coordinator was replaced only to capture the production boundary key; production PNG/PDF exporters executed. |
| Branding | PASS Flutter/asset/source; Nuxt rendering NOT TESTED | Flutter success/history and both customer assets show the horizontal Siamblend logo, no L6 receipt mark. Nuxt success references the same asset and its build passes. No authenticated Nuxt success browser flow was executed. |
| Dock safe-area matrix | PASS simulated | Buy, search, buy-more, store, cart and checkout at 390x844, bottom inset 0 and 34. Dock geometry reaches full lower edge, buttons remain above inset. Search additionally tested with 260px simulated keyboard; action remains above keyboard. Existing navigation/cart/checkout regressions also pass. Native keyboard/navigation remains separate. |
| Home news | PASS fixture | Splash regressions verify fetch starts before dismissal and does not block it; Home prioritizes first cover and tolerates slow later/missing first covers. New fixture verifies six distinct non-empty URLs, no extra requests on warm repeat, and failed-cover completion. Latest in-process cold decode 8ms / warm cache 0ms; six cold requests, zero extra warm requests. These are tiny fake-image/cache timings, not production CDN/API/storage or device latency. |
| Social security diagnostics | PASS diagnostics; contract BLOCKED | Existing tests exercise Google/Apple/Facebook/LINE existing-phone linking and replay; Google/LINE phone/tenant/purpose/TTL/consumed-token guards, new-phone non-consumption, suspension and identity conflict. New diagnostics separately exercise all four generic routes plus legacy `/line/link-phone`: invalid OTP masks inactive/suspended/identity-conflict responses; inactive account rejects even with valid OTP, preserves tokens, succeeds after fixture activation, then rejects replay. Legacy LINE rejects a Google handoff without consuming OTP. No provider/SMS network delivery was exercised. |
| Social responsive UI | PASS diagnostic fixtures; contract BLOCKED | Thai Kanit at 320x568, 390x844, 768x1024 with 47/34 safe insets and 260px keyboard simulation. Existing phone bypasses member fields and reaches required PIN gate. New phone presents four fields/terms; empty fields and missing terms do not submit; completed fixture reaches PIN setup gate. Fixture PIN target is a route marker, not native PIN entry acceptance. |
| Native/provider/production acceptance | NOT TESTED | No approved build installation, native landscape/large text/share/save, real provider/SMS, real purchase, or production news timing. |

## Evidence

Artifact root: `/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/`

- [Coverage plan](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/coverage-plan.md), [Docker runner configuration](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/compose.qa.yaml).
- [API regressions](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/api-validation.log), [effective configuration](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/api-effective-config.log), [extra API diagnostics](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/api-extra-diagnostics.log).
- [Flutter analyze/regressions](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/flutter-validation.log), [builds](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/flutter-evidence-build.log), [final 27-test rerun](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/ui-matrix-validation.log), [Nuxt checks/build](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/legacy-validation.log).
- Fresh browser images `web-success-{320x568,390x844}-top/scrolled.jpg`, `web-success-1440x900-top.jpg`; View Tickets reached fixture `#/tickets`, recorded in `web-receipt-view-tickets.jpg`. Preview warning/error console log query returned no entries. Browser viewport was reset and QA tab closed.
- Receipt widget images `success-*-top/scrolled.png`, `history-390x844-th-top/scrolled.png`; exports `*-export.png`, `*-export.pdf`, and `*-export-pdf.png` raster evidence. Eight cases: three required sizes, compact large text, landscape, English, custom wallet and history.
- Dock images `dock-{buy,search,more,stores,cart,checkout}-inset{0,34}.png`; additional search keyboard images. Social images `social-{320x568,390x844,768x1024}-{new,existing}-phone/keyboard.png` and new-member top/bottom views.
- [News timing](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/news-fixture-timing.json), [PDF metadata/render log](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/pdf-validation.log), [artifact manifest](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/artifact-manifest.sha256).

The apparent custom-wallet PDF clipping in a reduced preview was not confirmed: the original-resolution render, extracted embedded image (1062x1746), and independent Cairo render all preserve the full name. It is not reported as a product defect.

QA fixtures are retained under artifacts, copied only into temporary containers. They are not changes to implementation or existing application tests. First-attempt logs remain for audit: Nuxt missing adjacent API path; Flutter news debug-client teardown; UI missing `localeTag` and a scroll-settling warning; API duplicate LINE identity fixture. Each was corrected in QA-owned files and rerun successfully. The first Flutter log therefore ends with a QA-fixture failure after the 173 existing tests had passed; use the final rerun log for fixture acceptance.

## Runtime Restore / Login Smoke

[Before state](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/runtime-before.txt) / [after state](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/runtime-after.txt): same shared services, images, ports and running/stopped states. Postgres, Valkey, reverb and scrapers remain running; API/BO/customer/proxy and previously stopped support services remain stopped. BO was not touched or restarted.

`exec platform-api` could not be used because that shared service was already stopped. Ran the existing non-destructive `platform:smoke` through a disposable `run --rm --no-deps` API container without starting it:

```text
app: ok
database: ok
cache: ok
queue: redis
monitoring-defaults: ok
base-lottery-numbers: ok
seeded-logins: failed
exit: 1
```

The seeded-login check reads legacy active usernames/password hashes; failure does not establish that approved current accounts are invalid. No accounts/passwords were recreated. Smoke writes only its own 10-second cache probe; no shared cache flush occurred.

| Runtime Check | Result |
| --- | --- |
| `http://localhost:3100/login` | Connection refused, curl exit 7; no HTTP status available. |
| `http://localhost:3100/admin/login` | Connection refused, curl exit 7; redirect target unavailable. |
| `http://localhost:3000/` | Connection refused, curl exit 7. |
| Authorized test admin login API | BLOCKED: shared API stopped and approved credentials unavailable; no login/token attempt. |
| Restoration | No shared service configuration was changed. QA loopback preview/container/network removed; browser tab closed and viewport reset. Disposable runners removed themselves. No runtime DB reseed/reset, volume deletion, stock/allocation rewrite, or destructive runtime migration. |

Evidence: `runtime-smoke.log`, `bo-login-http.txt`, `bo-admin-login-http.txt`, `customer-runtime-http.txt`, `qa-cleanup.log`.

## Commands / Reproduction

Run from the canonical workspace only. Resolved mounts/images are recorded in the runner configuration and digest evidence. API tests use the root Compose project and explicit protected test settings; SDK/Node/PDF runners use the separate QA project. The fixture preview was intentionally stopped after QA. The merge below records the initial no-op start gate; if HEAD differs from origin/develop, stop and return the baseline issue to Coordinator instead of merging over the dirty delivery.

```sh
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256

# Verify effective configuration before running DB-backed tests.
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap(); $db = config("database.connections.".config("database.default").".database"); echo "effective_db=".$db.PHP_EOL; echo "effective_env=".app()->environment().PHP_EOL; exit($db === "newpaotang_test" && app()->environment() === "testing" ? 0 : 1);'
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --do-not-cache-result --filter='CustomerSocialAuthServiceTest|CustomerSmsOtpTest'
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --do-not-cache-result /workspace/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/CustomerSocialQaDiagnosticsTest.php

QA=ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/compose.qa.yaml
docker compose -p newpaotang-customer-responsive-qa -f "$QA" run --rm --no-deps legacy-qa
docker compose -p newpaotang-customer-responsive-qa -f "$QA" run --rm --no-deps flutter-qa
docker compose -p newpaotang-customer-responsive-qa -f "$QA" run --rm --no-deps ui-qa
docker compose -p newpaotang-customer-responsive-qa -f "$QA" run --rm --no-deps pdf-qa
# Preview requires a free 18091 and the completed preview-web output.
docker compose -p newpaotang-customer-responsive-qa -f "$QA" up -d --no-deps preview
docker compose -p newpaotang-customer-responsive-qa -f "$QA" down

docker compose -p newpaotang run --rm --no-deps platform-api php artisan platform:smoke
curl --max-time 5 -i -sS http://localhost:3100/login
curl --max-time 5 -i -sS http://localhost:3100/admin/login
curl --max-time 5 -i -sS http://localhost:3000/
```

The original Flutter run executed analyze and the listed 173 tests before the first fixture attempt. A follow-up executed fixtures/builds only; the final runner config retains the full reproduction sequence. Do not sum repeated runs as additional coverage.

## Residual Risks

- Delivery remains local/uncommitted; remote HEAD is not evidence that these changes are deployed or present on devices.
- `npm ci` reported 52 dependency advisories (3 low, 12 moderate, 33 high, 4 critical). This was installer output, not an independent exploitability/security audit; no automatic audit fix or upgrade was performed. Nuxt also emitted the existing dependency deprecation/Browserslist and unresolved `/images/siamblend-loading.jpg` warnings. Build exit was 0. Coordinator should separately route any dependency/asset follow-up.
- Runtime login HTTP/redirect/admin acceptance is blocked, not passed by CLI test/build success.
- Simulated safe areas, keyboard, provider repositories and tiny image fixtures do not substitute for installed OS behavior, real accounts/SMS, storage/CDN latency, or authenticated production acceptance.
- No backend/client rollout occurred. Contract approval and the backend-first release sequence remain Coordinator gates.

## Next Agent

**Coordinator**: resolve QA-G01, route the existing runtime/login blocker without reseeding protected data, and arrange approved real-device/provider acceptance. No direct Backend/BO assignment is made by QA.
