# Customer Responsive Receipt / Social OTP Contract QA

Date: 2026-10-01, Asia/Bangkok. Fresh validation/runtime observation: approximately 16:00-16:10 +07; final source/evidence preservation checks at 16:15 +07.
Agent: QA Tester. Recipient / Next Agent: **Coordinator only**.
Overall acceptance: **BLOCKED**. No implementation or contract-document fix is authorized or made.

## Task

Independently verify the corrected social phone-link contract, refresh read-only runtime/login preflight, and prepare real-acceptance prerequisites for the same milestone. Read the May continuity handoff first, then current root safety rules, October contract task/dispatch/decision, Orchestrator review/return, original QA report, role/protocol/runtime policy, and relevant contract/source files.

| Gate | Result | Reason |
| --- | --- | --- |
| QA-G01 | **FAIL** | Request/probe contract and controller top-level branches match, but valid empty-profile auth responses fail the referenced response schema. Two P2 contract discrepancies below. |
| QA-G02 | **BLOCKED** | Shared API/BO/customer/proxy remain stopped; login HTTP unavailable; approved credentials not supplied. |
| QA-G03 | **BLOCKED / NOT TESTED** | No authorized installed-device, real-provider/SMS, authenticated Nuxt or production-timing acceptance. Prerequisite matrix prepared. |
| Overall | **BLOCKED** | No gate waived and no release approval. |

## Defects

### CONTRACT-01 [P2]: Nullable Profile Fields Reject Valid Auth Sessions

The document declares [OpenAPI 3.1](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:1), but [CustomerProfile email](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14169), avatar_url at 14177 and preferred_locale at 14181 declare `type: string` plus `nullable: true`. Under the declared 3.1 / JSON Schema 2020-12 semantics, this does not add null to the permitted type. The production [profile serializer](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php:1483) emits null for absent email/locale/avatar, including supported members with no configured values.

Reproduction: run the QA controller/profile serializer fixture then the schema runner below. All five sparse-profile session responses (Google, Apple, Facebook, generic LINE and legacy LINE) fail CustomerSocialLinkPhoneResponse; their CustomerProfile validation separately reports `None is not of type 'string'`. Changing each of the three values independently to null in an otherwise schema-valid populated session also fails. Impact: schema-based consumers/contract tests reject a legitimate successful link/sign-in response. Full specification-structure validation alone does not detect this instance mismatch.

This follows the [OpenAPI 3.1 Schema Object semantics](https://spec.openapis.org/oas/v3.1.0.html#schema-object) and [JSON Schema type validation](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.1.1). No schema normalization or compatibility nullable extension was applied to make the test pass.

### CONTRACT-02 [P2]: Absent Reward Bank Serializes As An Undocumented Array

[CustomerProfile.reward_payout_bank_account](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14188) allows a CustomerBankAccount object or null only. The production [serializer](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php:1487) calls EncryptedJsonPayload::decrypt; its [empty legacy-value fallback](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Support/EncryptedJsonPayload.php:85) returns `[]`, serialized to a JSON array rather than null/object.

Reproduction: the sparse fixture invokes that actual serializer with no encrypted/legacy bank value, then passes through the actual public linkPhone controllers. The response schema rejects `user.reward_payout_bank_account: []` for all five routes. A separate otherwise populated session with only that field changed to [] also fails, so this is independent of CONTRACT-01. Impact: valid customers without a reward payout bank cannot satisfy the declared 200 auth branch.

Both discrepancies exist in the committed CustomerProfile schema too, confirmed by [committed schema evidence](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/committed-profile-schema.txt). They are newly exposed contract-verification findings, not attributed to a newly introduced implementation regression or the Coordinator's probe changes. Coordinator must decide the documentation/serializer ownership and correction scope. QA did not change either.

## Worktree / HEAD

```text
canonical worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: c8f130cdcc1a1addc3a7526597bd7a17107d574d
origin/develop after fresh git fetch origin: c8f130cdcc1a1addc3a7526597bd7a17107d574d
status: ## develop...origin/develop; known dirty delivery/docs and QA artifacts preserved
tracked application diff SHA-256:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
all tracked worktree diff SHA-256 before/after this follow-up:
c2e6aa3345f8e63c86ce05f773a573adcfa12dc400ac4bbf5034ce838d5f702d
```

Fresh fetch succeeded; canonical root, branch, HEAD/origin and git diff --check passed. No merge was run in this follow-up: current targeted task explicitly prohibits merging the dirty delivery and HEAD already equals origin. The earlier QA start gate recorded a no-op ff-only merge. No stash/reset/clean/revert/stage/commit/push. HEAD alone omits the pending application changes.

| Fingerprint | SHA-256 |
| --- | --- |
| Corrected docs/openapi.yaml | 7a6f6ec86df0cdfcd14a37489799553f7abafbc09c68e0b77e101f111558682f |
| Corrected docs/customer-api-integration-map.md | f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac |
| Original QA report | 20313844c6d61834fa36c7a7a95bce5650fb10d5911463fa6ac27995eeb17c5c |
| Original artifact manifest | b82d50ed38b59606be187cd5d70a6a4957a185a56a22d3a8c64e8a9f7bebc177 |
| Customer Nuxt, Flutter and BO logo files | ea10f0e865573c27c7c80dded181b9aa8a77690e1d8edd9cd237149f7b14ab1b |
| Flutter home_news_preloader.dart | d38fc9076ccf60330c8697b3771d6882398bef6f4759ba6651de23eaa8d06c32 |
| Flutter siamblend_receipt_logo.dart | 5510aae9f84df9dab109eb1e011d0c11c04c4ac419976018bd89efdd48494c7e |
| Flutter customer_ui_preview.dart | 9e333dd07685e3cc0cd4ff52a7f9e43e4713744281b1afbf7388efeb72779091 |

All dispatch fingerprints matched. Independently verified **269 original artifact checksums, zero mismatches**, including prior logs and source hashes. Original source-hashes.txt and final-source-hashes.txt are identical (file SHA 5df27ec831e800fdcf07b3bbb752e030fe8c8099c275e13e4a6d5d86f1a47204). [Fingerprint inventory](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/source-doc-evidence-hashes.txt) and [manifest verification](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/prior-manifest-verification.txt). The corrected docs match the current dispatch; prior application results are reused only for unchanged code, not as validation of those corrected docs.

## Scope Tested

### Newly Executed Validation

| Check | Result |
| --- | --- |
| Independent YAML parse / internal reference resolution | PASS; OpenAPI 3.1.0; 2,736 refs resolved. |
| Complete OpenAPI 3.1 specification validation | PASS; openapi-spec-validator reports zero errors. This is document conformance, not all runtime response validation. |
| Target schema meta-validation / endpoint refs / required fields/default | PASS; both endpoints point to the shared request and 200 union. |
| Minimal request, legacy blank fields/false terms, full new member, omitted existing_only/confirmation | Schema-valid. Conditional account-state business rules remain source/prior-test checks, not inferred from schema alone. |
| Missing universal fields, string existing_only, false/wrapped registration response, extra registration fields | Correctly schema-invalid. Both documented request examples schema-valid. |
| Public controllers and actual profile serializer | PASS; 20 fixture invocations / 60 exact status/top-level/body assertions. Four generic providers plus legacy LINE; session/registration branches; sparse/populated profiles. |
| Response/profile payload checks | FAIL; final 48 schema cases: 34 expectations matched, 14 failed. Five sparse sessions + five corresponding profile checks + four isolated field-value cases. These are overlapping observations of two discrepancies, not 14 distinct defects. |
| Read-only Docker inventory / unauthenticated login HTTP | Collected; login acceptance BLOCKED. |

Evidence: [coverage plan](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/coverage-plan.md), [controller log](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/controller-validation.log), [controller responses](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/controller-responses.json), [final schema log](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/schema-validation-isolated-values.log), [structured schema results](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/schema-results.json).

The first schema execution retained schema-validation.log with 44 cases / 10 failing expectations. A focused second run added four independent value-isolation cases; final results are 48 / 14. Do not sum repeated runs as distinct coverage. Both exits are 1 due to reproduced contract mismatches, not unavailable tools. full-openapi-errors.json is [].

Additional assertion reason: prior feature tests asserted branch fields but did not validate the actual production profile serializer's empty fields against the corrected 200 union. The new PHP script uses the real profile serializer and public controllers, mocked partner/link services and an in-memory Wallet query. Session scalar envelope is fictional and traced from issueSession; no actual token is issued. No Laravel application bootstrap, HTTP middleware, DB connection, migration or provider/SMS call. Application/vendor mounts are read-only and PHP network disabled. This does not claim fresh DB-backed endpoint acceptance.

### Source / Client Contract Trace

| Contract | Evidence / Disposition |
| --- | --- |
| Routes/providers | [routes/api.php](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/routes/api.php:129) registers legacy LINE and generic social. [Generic controller](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerSocialAuthController.php:130) delegates LINE to CustomerLineAuthService, others to CustomerSocialAuthService. |
| Actual top-level JSON | [Generic result](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerSocialAuthController.php:193) and [legacy result](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerLineAuthController.php:146) serialize resource itself with status, not a resource wrapper. New fixtures verify both branches. |
| Universal fields/default/fallback | [Generic service](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerSocialAuthService.php:303), [LINE service](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerLineAuthService.php:503): link_token/normalized phone/OTP always required; existing_only defaults false; omitted confirmation defaults to password. |
| New-member conditional validation | Generic 425 and LINE 626 return registration_required before consumption/creation when existingOnly is true. Otherwise new customers require nonblank first/last names, password >=6, matching supplied confirmation, accepted terms. Existing accounts bypass registrationErrors and never overwrite their profile/password from member fields. |
| OTP before account status | Generic 378-390 and LINE 579-589 validate before customer/identity lookup and suspended/inactive/conflict responses. [SmsOtpService](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/SmsOtp/Services/SmsOtpService.php:471) checks tenant, normalized phone, purpose, token hash, verified state, null consumed_at and verified_at TTL under transaction/lock. |
| Provider/link and account safeguards | Generic 357-376 and LINE 558-577 require tenant-bound pending/unconsumed/unexpired link token and matching provider; LINE permits legacy metadata without provider, rejects a populated non-LINE provider. Generic 403-424 / LINE 602-624 enforce suspension, active status and identity ownership. |
| Tokens consumed once / profile retained / activation | Generic 433-483 and LINE 634-696 consume OTP after guards, create only if no customer, link identity, consume link and update last_login_at; issueSession(activationRequired: true). [Auth session](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php:934) exposes activation and PIN flags. Replay/state protection has verified prior feature evidence. |
| Flutter probe / registration | [Repository](/Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter/lib/core/auth/auth_repository.dart:513) sends minimal existing_only true, returns null on registration_required without saving session; full member request at 545 omits existing_only and sends confirmation/terms. |
| Flutter form / PIN / redirect | [Screen](/Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter/lib/features/auth/presentation/line_auth_screens.dart:871) verifies register OTP, probes and goes to member step only when needed. At 956 it retains matching confirmation/names/password/terms checks. At 1028 it applies session and uses [safe redirect/PIN helper](/Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter/lib/core/navigation/customer_redirect.dart:19). Relative-local redirects only; external/protocol-relative/auth/social loop targets rejected by that helper. |
| Nuxt legacy LINE | [API adapter](/Users/supakit/WorkSpace/www/newPaotang/apps/customer/composables/usePlatformApi.ts:1055) calls legacy endpoint. [Form](/Users/supakit/WorkSpace/www/newPaotang/apps/customer/pages/line/link-phone.vue:199) verifies register OTP; initial probe includes blank member fields/false terms with existing_only true; registration_required retains tokens and moves to member form; full step submits false with matching confirmation/required names/minlength/terms. Local-relative redirect guard at 146 and PIN dispatch at 226 remain. |
| Integration map / docs | [Integration-map row](/Users/supakit/WorkSpace/www/newPaotang/docs/customer-api-integration-map.md:150) and [request schema](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14355) accurately describe probe, server-state-dependent fields, retries, backend-first release and separate real acceptance. [200 response union](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14423) is top-level but inherits the two CustomerProfile discrepancies. |

No new probe-flow prose/client discrepancy was confirmed. Schema-valid input is not evidence of valid OTP, current account state or successful provider authentication. Client confirmation validation was not weakened.

### Prior QA Evidence Reused, Not Rerun

| Previous result | Verified evidence and scope |
| --- | --- |
| API 42 passed / 353 assertions | Original api-validation.log. Minimal existing provider routes, new-phone nonconsumption/registration, OTP binding/purpose/expiry/consumption, suspension/conflict and provider checks; tests current source unchanged. |
| Independent API diagnostics 3 passed / 96 assertions | Original api-extra-diagnostics.log. Invalid OTP hides inactive/suspended/conflict states across four generic plus legacy LINE; inactive rejection preserves tokens, retry/replay; legacy cross-provider handoff rejects. |
| Flutter analyze + 173 focused regressions | Original flutter-validation.log; no analyzer issues. Its later first fixture failure is not final fixture result. |
| Final 27 QA fixture tests, receipt PNG/PDF/browser/dock/social/news | Original ui-matrix-validation.log and 269-entry manifest. Prior diagnostic evidence only, not fresh native/provider/authenticated Nuxt acceptance. |
| Flutter/Nuxt builds and configured Nuxt tests | Original build/legacy logs verified via manifest; not rebuilt for docs-only follow-up. |

Prior API effective configuration was testing/newpaotang_test with explicit overrides. No DB-backed tests or destructive setup were needed or executed this turn. Real provider/network delivery was not established by those earlier fixtures.

## Tools / Commands Run

All schema/PHP execution used a new isolated QA Compose project, not shared runtime service recovery. [Runner configuration](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/compose.qa.yaml). Tool dependencies installed only in disposable /tmp virtualenv, never application dependency/lock files. Pinned top-level versions and resolved transitive versions saved in validator-dependencies.txt.

```text
PHP: 8.4.24
Python: 3.14.7 (ephemeral Alpine packages)
openapi-spec-validator: 0.7.2
jsonschema: 4.23.0 (Draft 2020-12, formats checked where supported)
PyYAML: 6.0.2
schema runner image ID: sha256:828963118f6838ebdaf6b01b9b24d10c5dffe2f4aaf3ebca33d0d3f74366833e
schema runner digest: node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32
PHP runner image ID: sha256:d031ecc320ee2bb3a5495c5f94890903e3e19a31e72244bdf9f4f140d1ef6b18
PHP local image: newpaotang-platform-api; no repository digest available
```

Executed from canonical root:

```sh
git fetch origin
git status --short --branch
git rev-parse --show-toplevel
git rev-parse HEAD origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
shasum -a 256 -c ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-qa/artifact-manifest.sha256
shasum -a 256 -c ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/source-doc-evidence-hashes.txt
```

Reproduce only new isolated checks:

```sh
QA=ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/compose.qa.yaml
docker compose -p newpaotang-contract-qa -f "$QA" run --rm --no-deps controller
docker compose -p newpaotang-contract-qa -f "$QA" run --rm --no-deps schema
docker compose -p newpaotang-contract-qa -f "$QA" down
```

Controller exit 0; schema exit 1 for documented response mismatches. Temporary runners removed automatically; QA-only network removed by down without -v. No QA containers remain. No shared service was started, stopped, rebuilt or recreated. Runtime inventory used `docker compose -p newpaotang config --services`, ps --all, and selected inspect image/state/port/mount fields only, never environment/credential dumps. Curl commands below exited 7.

## Runtime Restore / Login Smoke

Prior QA: API, BO, customer, local proxy and worker/support services already stopped; disposable platform:smoke reported seeded-logins: failed. That legacy password check is preserved in the original runtime-smoke.log, not rerun and not evidence that approved current accounts are invalid.

Fresh read-only before/after: **API/BO/customer/proxy remain stopped**. Postgres, Valkey, reverb and both scrapers remain running (Postgres/Valkey/scrapers healthy); prior stopped worker/support services remain stopped. Selected image IDs, port bindings and mount contents unchanged; raw before/after diff only changes the iteration order of several mount entries, not their values. [Runtime inventory](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/runtime-inventory.txt), runtime-inventory-after.txt and runtime-inventory-diff.txt retain these observations.

| Required check | Current result |
| --- | --- |
| Runtime DB / destructive command | No DB connection/command/migration, no runtime writes or destructive test setup. newpaotang protected. |
| Seed result | NOT RUN; explicitly forbidden by scoped decision. No accounts/passwords recreated. |
| platform:smoke / seeded-logins | NOT RERUN; task permits read-only preflight, prior smoke writes cache probe. Prior seeded-logins: failed retained only as prior evidence. |
| Central admin login API | NOT TESTED / BLOCKED; API stopped and approved credentials missing. No auth/token attempt. |
| localhost:3100/login | Connection refused, curl exit 7, http_code=000; no HTTP response. |
| localhost:3100/admin/login | Connection refused, curl exit 7; redirect unavailable, not a verified redirect. |
| localhost:3000/ | Connection refused, curl exit 7. |
| BO restart/recreate | NOT RUN. Stopped runtime preserved. |
| DB/volumes/cache/settings/ports | No seed/reset/drop/flush/account/config/volume/port changes by QA. No restoration mutation needed or permitted. |

The customer container is built Flutter/nginx (`customer_flutter-customer-flutter-web`, image b6708f5c6d9b...), **not legacy Nuxt** and has no source bind. Inspect reports configured HostPort 3000 even though ps displays no active published port for the stopped container. It does not prove current local source is deployed or satisfy authenticated Nuxt success acceptance.

### Proposed Recovery / Login Scope For Coordinator Approval Only

1. Approve a preservation-first local recovery task and confirm intended source/runtime image identity and port plan. Required services for the current shared login path: platform-api (8000), back-office (3100), customer Flutter/nginx (configured 3000) and local-proxy (80). Existing Postgres 5432, Valkey 6379 and reverb 8080 are running; leave them/volumes intact. Workers/support/scrapers are not needed to resolve this login gate and must not be restarted as incidental recovery.
2. Before any authorized service change, capture selected config/mount/image/port/account metadata, arrange a recoverable data-preserving backup, and confirm the image/mounted source expected by acceptance. Start/recover only approved services in dependency order, with no reseed/reset/password rewrite/volume removal/cache flush or automatic build. Container recreation would require its own explicit scope if needed.
3. Provide a securely supplied approved active central/tenant admin test account and tenant host, expected redirect and permitted login-side effects (session/audit/last-login only). Verify HTTP, admin API and actual UI login under that authorization, without exposing credentials/tokens in artifacts. Missing credentials cannot be replaced by legacy seed/default passwords.
4. Legacy Nuxt acceptance separately needs an approved isolated/source-matched Nuxt runtime/URL, approved customer/PIN and safe existing order fixture; starting the built Flutter runtime does not provide that surface.

This proposal is **not authorization**. QA executed none of it.

## Risks / Not Tested

### QA-G03 Acceptance Prerequisites

All rows remain **BLOCKED / NOT TESTED**. Pending local source hash above is known; exact installed/served release hashes, device IDs, tenant/account/phone/provider configuration and acceptance authorization are missing for this task. Historical device names or prior screenshots are not approved current build evidence. Secrets, PIN, OTP and tokens must use secure channels, not this report.

| Criterion | Required device / build / source | Tenant / provider / approved account / safe fixture | Missing authorization / remaining action |
| --- | --- | --- | --- |
| iOS receipt share/save/safe areas/keyboard | Approved physical iOS device ID, OS/model, installed app version/build/package/signing and source/artifact hash; portrait/landscape/small display/large text | Exact tenant/API host, approved active customer/PIN, existing fictional or approved nonfinancial receipt/order; storage/share target | Device/build identity and account/order missing; authorize installation if needed and OS share/save/keyboard tests, without purchase. |
| Android receipt share/save/safe areas/keyboard | Approved physical Android ID, OS/model, installed version/build/package/signing and source/artifact hash; keyboard/safe insets/rotation/large text | Same tenant/customer/PIN/order and storage/share prerequisites | Current device/build identity and account/order missing; authorize any install and native share/save acceptance. |
| Real Google OTP linking | Exact installed/Web build and callback URI/source; provider return target matched | Tenant host and active Google client/signing/audience/callback configuration; approved social identity; controlled existing-phone account and new-phone account, approved SMS receiver; repeat/nonconsumption cases | Configuration/account/phones/build and explicit SMS/link/session-write authorization missing; no real provider exchange or SMS performed. |
| Real Apple OTP linking | Exact iOS/Web build/package/source and callback/deep-link target | Tenant Apple configuration/audience and approved identity; existing/new controlled phones/accounts; PIN; verified receiver | Same missing prerequisites; authorize real sign-in/SMS/linking and expected Apple email visibility before executing. |
| Real Facebook OTP linking | Exact installed/Web build and callback/source | Tenant active Facebook app/config/scopes/callback; approved identity and existing/new phones/accounts; SMS receiver/PIN | Missing configuration/account/phones/build/authorization; provider fixtures do not prove Graph/real OTP acceptance. |
| Real LINE OTP linking | Exact installed/Web build and callback/app-link/source; generic plus legacy paths where applicable | Active tenant LINE channel/provider/callback; approved LINE identity and existing/new controlled phones/accounts; receiver/PIN; identity ownership plan | Missing tenant/provider/account/phone/build/authorization; legacy/generic fixtures are not real LINE acceptance. |
| Authenticated legacy Nuxt success | Approved Nuxt-served URL/build and source/artifact hash, relevant desktop/mobile browsers; not root Flutter image | Tenant/API host, approved active customer/session/PIN; safe existing receipt/order with language/custom wallet/long content as needed | Approved Nuxt runtime, customer/order and authenticated-session authorization missing; no UI acceptance claimed from Nuxt build. |
| Production news timing | Explicit production tenant URL/release/source, device/browser/network/cache state, timestamped cold/warm runs and agreed timing budget | Approved production read-only content/feed/CDN fixture and tenant configuration; account if feed requires it | Production target/config/release/budget and measurement authorization missing; prior tiny-fixture 8ms/0ms timings cannot substitute. |

Other residual risks: delivery remains uncommitted and not proven deployed; no provider/native/runtime acceptance, install or release. Earlier npm installer advisories and build warnings remain prior observations, not an exploitability assessment or permission to upgrade dependencies. No new implementation regression is asserted from the two contract findings.

## Files Added

Only this report and the new artifact directory were added:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/**
```

Artifacts include QA-owned compose/script/coverage plan, selected source/doc/reference schemas, fictional controller responses, dependency/image versions, original manifest verification, schema/controller logs/results, read-only runtime/HTTP evidence, cleanup and final preservation/hash evidence. New artifact-manifest.sha256 indexes this directory only, including ignored log files; final-report.sha256 fingerprints this report. Original report/artifacts/manifest, application source, docs, Board, Coordinator decision and handoffs remain unchanged.

## Recommendation

Return CONTRACT-01/02 to Coordinator for an explicit correction decision; do not mark QA-G01 PASS because document/ref validation passes. The minimal-probe documentation itself is aligned. Keep overall acceptance BLOCKED; authorize recovery/login and real acceptance separately with the prerequisites above. QA must not implement the fix or start/reseed the runtime from this report.

## Next Agent

**Coordinator**. User must relay this report to Coordinator chat. No chat was opened or messaged automatically and no Backend/BO/Customer assignment was made.
