# customer-responsive-receipt-social-otp - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate the October 1 delivery described in:

```text
ai-agents/handoffs/20261001-customer-responsive-receipt-social-otp-orchestrator-handoff.md
```

The handoff requests Orchestrator -> QA Tester -> Coordinator. This brief prepares that next step; it does not start another agent or authorize release.

## Objective

Independently verify receipt layout/branding/export, purchase dock safe areas, Home news warmup, and social phone onboarding. Separate fixture evidence, installed-device evidence, and production acceptance. Do not repeat the delivery handoff's test counts as new QA results.

## Source Of Truth

- AGENTS.md: current safety rules take precedence over older workflow examples.
- ai-agents/handoffs/20261001-customer-responsive-receipt-social-otp-orchestrator-handoff.md
- ai-agents/rules/global-rules.md
- ai-agents/workflow/handoff-protocol.md
- ai-agents/roles/qa-tester.md
- docs/docker-runtime-policy.md
- docs/openapi.yaml
- docs/customer-api-integration-map.md
- apps/customer_flutter/README.md
- apps/customer_flutter/Dockerfile

## Worktree Start Gate

Use only `/Users/supakit/WorkSpace/www/newPaotang`. Observed on October 1 after fetching origin:

```text
branch: develop
HEAD: c8f130cdcc1a1addc3a7526597bd7a17107d574d
origin/develop: c8f130cdcc1a1addc3a7526597bd7a17107d574d
status: dirty; delivery and concurrent changes are not committed
```

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
```

Observed tracked application diff SHA-256:

```text
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
```

The hash excludes untracked files, including the new logos, news preloader, receipt logo widget, preview entry point, and screenshots. Record their hashes/inventory separately. Test the local delivery, not HEAD alone. A separate checkout of origin/develop does not contain these changes. If source changes during QA, record the new snapshot and rerun affected checks; never attribute results to an earlier snapshot.

Do not automatically merge over this dirty delivery, commit/push it, delete it, stash it, or revert it. If HEAD differs from origin/develop, stop and return the baseline issue to Coordinator. Any synchronization must preserve the delivery first.

## Contract Review Gate

An observed documentation conflict requires Coordinator review:

```text
CustomerSocialLinkPhoneRequest in docs/openapi.yaml requires
first_name, last_name, password, password_confirmation, and accepted_terms.
It does not document existing_only or registration_required.
The delivery implements a minimal existing_only probe and a new-phone response.
```

Do not choose a new API contract or amend OpenAPI/implementation yourself. Receipt, dock, and news QA may proceed. Existing social regression tests may supply diagnostic evidence, but social contract acceptance remains BLOCKED until Coordinator resolves the conflict. Report it explicitly rather than issuing an unconditional PASS.

## Scope And Acceptance Criteria

1. Receipt: at 320x568, 390x844, and 1440x900, scroll the full receipt while Save/View Tickets remain reachable above navigation. Check safe insets, compact heights, large text, and landscape on an available approved installed build. Check Kanit Save text, Thai primary-wallet labeling, English locale, and preservation of custom wallet names. Export PNG/PDF from fictional orders and inspect layout and branding; an on-screen screenshot alone does not prove export correctness.
2. Branding: Flutter success/history and legacy Nuxt success use the horizontal Siamblend logo without the old L6 mark. Compare both customer assets with the BO source. Expected SHA-256: `ea10f0e865573c27c7c80dded181b9aa8a77690e1d8edd9cd237149f7b14ab1b`. Do not edit BO assets.
3. Dock: Buy, search, buy-more, store, cart, and checkout surfaces reach the lower edge with and without a 34px simulated inset. Check keyboard behavior, navigation, and action reachability; no duplicated SafeArea gap or overlapping controls.
4. News: public loading starts during splash without delaying dismissal; at most six distinct covers warm up. Home prioritizes the first cover. Slow/failed later covers and a missing first cover do not block Home. Record cold/warm fixture or local timing separately from production CDN/API/storage timing.
5. Social diagnostics: inspect Google/Apple/Facebook generic endpoints and legacy LINE separately. Check phone/tenant/purpose/TTL binding, unconsumed OTP, replay, suspension/inactivity, identity conflict, wrong-provider LINE handoffs, and no account-status disclosure before OTP validation. Check retry behavior and PIN requirements. Pending Coordinator contract resolution, label evidence diagnostic, not final contract acceptance.
6. Social UI: Thai Kanit fonts, 320x568, 390x844, 768x1024, real safe areas and open keyboard do not overlap the header/form. Existing-phone fixture flow bypasses new-member fields; new-phone fixture flow retains full member/terms/PIN requirements. Fixture OTP is not SMS delivery evidence.
7. Real provider/OTP and installed iOS/Android acceptance require approved test accounts/phones and an approved build. Do not send real SMS, link real accounts, make purchases, install a new build, or deploy on the authority of this task. If prerequisites are unavailable, record NOT TESTED/BLOCKED and continue safe independent checks.

## Out Of Scope

- Implementation fixes, new business rules, contract approval, unrelated pending edits.
- Production release, backend/client rollout, signing credentials, real payment/SMS actions.
- Runtime DB resets/reseeding, shared cache flushes, stock/allocation changes.
- Automatic staging, commit, push, source cleanup, or another worktree.

## File Ownership

Can edit:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/**
apps/customer_flutter/test/** (focused test/fixture additions only)
apps/platform-api/tests/** (focused test/fixture additions only)
```

Must not edit application source, existing delivery artifacts/handoff, OpenAPI, runtime configuration, or another agent's changes. Route defects through the report with an owner recommendation.

## Required Steps

1. Read the sources, capture the local snapshot and pre-test runtime state, and write a coverage plan.
2. Record the contract conflict for Coordinator; keep affected acceptance blocked while checking independent UI behavior.
3. Verify effective `newpaotang_test` and `testing` inside the API container before DB-backed tests. `--env=testing` alone is insufficient.
4. Run focused regressions and isolated builds using Docker. Preserve runtime services, ports, data, accounts, settings, and source files.
5. Render current fixture widgets and capture your own responsive/export evidence. Existing seven screenshots are delivery evidence, not an independent rerun. Do not assume the handoff's localhost:18081 preview is live or current.
6. Complete Runtime Restore / Login Smoke without runtime reseeding/resetting. Restore only services actually changed by QA to their observed prior configuration, and record any blocker.
7. Write the report with results per criterion, exact source snapshot, commands, evidence, defects/owners, risks, and Next Agent: Coordinator.

## Validation Commands

Inspect Compose mounts before testing. These commands are examples to execute only after the start/safety gates; no application runtime may run on the host.

```sh
git diff --check
docker compose -p newpaotang config --services
docker compose -p newpaotang ps

# Bootstrap Laravel and check only non-secret effective configuration.
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap(); $db = config("database.connections.".config("database.default").".database"); echo "effective_db=".$db.PHP_EOL; echo "effective_env=".app()->environment().PHP_EOL; exit($db === "newpaotang_test" && app()->environment() === "testing" ? 0 : 1);'

# Run only after the preceding effective-config check passes. Recheck if config changes.
docker compose -p newpaotang run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --filter='CustomerSocialAuthServiceTest|CustomerSmsOtpTest'
```

The root `customer` service now builds Flutter and serves nginx. It cannot run `npm test`, Nuxt, or Flutter SDK commands. For legacy Nuxt, use the Node image from its Dockerfile in a separate Compose runner. Install/build only the temporary container copy, not the shared application or its dependency volumes:

```sh
docker compose -p newpaotang-customer-responsive-qa -f - run --rm --no-deps legacy-qa <<'YAML'
services:
  legacy-qa:
    image: node:22-alpine
    entrypoint: /bin/sh
    command:
      - -ec
      - |
        cp -a /source /tmp/customer-qa
        cd /tmp/customer-qa
        rm -rf node_modules .nuxt .output
        node --version
        npm ci
        npm test
        NUXT_BUILD_DIR=/tmp/customer-qa-nuxt npm run build
    volumes:
      - /Users/supakit/WorkSpace/www/newPaotang/apps/customer:/source:ro
YAML
```

Flutter's existing final images contain nginx, not the SDK. Use a disposable Docker Compose SDK runner based on the image already used in `apps/customer_flutter/Dockerfile`; do not run Flutter on the host or modify the existing web service. This runner copies read-only source into temporary container storage, has no runtime DB connection, and changes no host application files:

```sh
docker compose -p newpaotang-customer-responsive-qa -f - run --rm --no-deps flutter-qa <<'YAML'
services:
  flutter-qa:
    image: ghcr.io/cirruslabs/flutter:stable
    entrypoint: /bin/sh
    command:
      - -ec
      - |
        cp -a /source /tmp/customer-qa
        cd /tmp/customer-qa
        rm -rf .dart_tool build
        flutter --version
        flutter pub get
        flutter analyze --no-pub
        flutter test --no-pub --reporter expanded test/system_pages_test.dart test/social_auth_screens_test.dart test/auth_repository_test.dart test/app_splash_test.dart test/home_screen_test.dart test/buy_store_segment_tabs_test.dart test/checkout_screen_test.dart test/cart_grouping_test.dart test/news_repository_test.dart test/news_card_test.dart test/receipt_export_service_test.dart
        flutter build web --no-pub --dart-define-from-file=release/siamblend.runtime.json --output /tmp/customer-release-ui-check --no-wasm-dry-run --pwa-strategy=none
    volumes:
      - /Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter:/source:ro
YAML
```

Record resolved image digests and tool versions. Do not silently upgrade source/dependencies to make a runner pass. If a runner is unavailable or incompatible, report the tooling blocker. These runners do not preserve web output after removal or perform browser/native acceptance; a preview/evidence runner must use read-only application source and write artifacts only to the QA-owned directory, on an unused port. The existing localhost:3000 built Flutter runtime may serve an older image: its HTTP response is runtime smoke, not proof that the local delivery renders correctly.

## Runtime Restore / Login Smoke

The current AGENTS.md protections override older examples that automatically seed the runtime DB. Do not run `db:seed`, destructive migrations, reset commands, or shared cache clears as restoration. Missing accounts/data are a blocker to report, not permission to recreate them.

```sh
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
curl --max-time 5 -i -s http://localhost:3100/login
curl --max-time 5 -i -s http://localhost:3100/admin/login
curl --max-time 5 -i -s http://localhost:3000/
```

Record `seeded-logins`, authorized test admin login API status without logging credentials/tokens, `/login` status, and `/admin/login` redirect target. State whether BO was touched/restarted; do not recreate it unnecessarily. If the existing accounts differ from legacy seeded defaults, explain the limitation rather than seed them. No clean PASS if required checks or acceptance remain blocked. If no runtime commands were run, mark the section not applicable with the reason.

## Handoff Requirements

Write:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-qa-report.md
```

Include worktree/branch/HEAD/origin, local diff and untracked evidence, effective test DB, commands and observed results, screenshots/exports, contract conflict and Coordinator resolution if any, defects with owners, Runtime Restore / Login Smoke, NOT TESTED items, and PASS/FAIL/PASS WITH RISK/BLOCKED. Do not claim production readiness: the backend-first client release order and device/real-provider acceptance remain separate gates.

## Next Agent

Coordinator
