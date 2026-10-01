# Social Phone-Link Contract Remediation QA

Date: 2026-10-01, Asia/Bangkok. Independent validation completed approximately 16:50 +07.
Agent: QA Tester. Recipient / Next Agent: **Coordinator only**.
Overall acceptance: **BLOCKED**, not unconditional PASS or release approval.

## Task

Confirm Coordinator's four-field documentation correction for CONTRACT-01/02, independently rerunning the previous 48 schema cases and adding narrow boundaries. Continue the same milestone. Read the continuity handoff, root safety rules, current Board/task/dispatch/remediation decision, prior QA evidence and relevant schema/serializer/controller/client sources.

| Item | Independent result |
| --- | --- |
| CONTRACT-01 | **PASS: remediation confirmed** for email/avatar_url/preferred_locale null and populated-string values, preserved formats and invalid-type rejection. |
| CONTRACT-02 | **PASS: remediation confirmed** for complete bank objects, null and []; invalid nonempty arrays/scalars/incomplete objects rejected. |
| QA-G01 | **PASS within targeted contract scope**; corrected docs fit the verified unchanged fixtures and request/response branches. |
| QA-G02 | **BLOCKED, carried forward**; prior runtime/login evidence and recovery prerequisites unchanged by this scope, not freshly re-observed. |
| QA-G03 | **BLOCKED / NOT TESTED, carried forward**; native/provider/authenticated Nuxt/production prerequisites remain. |
| Overall acceptance | **BLOCKED** until remaining applicable gates and authorizations are resolved. |

This independent confirmation supersedes the previous QA-G01 FAIL for these two discrepancies only. The historical FAIL report/artifacts were not rewritten. No new defect was found in the exercised remediation cases.

## Worktree / HEAD

```text
canonical worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD and freshly fetched origin/develop:
c8f130cdcc1a1addc3a7526597bd7a17107d574d
status: ## develop...origin/develop; intentional dirty delivery/docs/evidence preserved
tracked application diff SHA-256, start/end:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
all tracked worktree diff SHA-256, start/end:
2d845d7dbe777939e87f00222aa942cb412f080ae11e7b98b640cfb80578e1ca
```

Fresh git fetch origin succeeded; canonical root/branch/HEAD/origin and git diff --check passed. HEAD alone does not contain the dirty delivery. No merge was performed: the current scoped task forbids merging this delivery and HEAD already equals origin. No stash/reset/clean/revert/stage/commit/push.

| Fingerprint | SHA-256 |
| --- | --- |
| Corrected docs/openapi.yaml | 0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5 |
| Unchanged integration map | f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac |
| Prior contract QA FAIL report | 163e46743a126d8ea74f3d1d20836738c2987876237e8990239efb011a8b7a87 |
| Original broad QA report | 20313844c6d61834fa36c7a7a95bce5650fb10d5911463fa6ac27995eeb17c5c |
| Prior contract QA 31-entry manifest | 818f33ec2ff411ac9a9763e16981af6ff05c230071ae8e8cd7c9a43e5714c1ab |
| Coordinator remediation 10-entry manifest | dc53ac683c3aa9e74ac601d61e0d970b8e412662f9eabbe70bc319238f033331 |
| Nuxt customer / Flutter / BO logo files | ea10f0e865573c27c7c80dded181b9aa8a77690e1d8edd9cd237149f7b14ab1b |
| Flutter home_news_preloader.dart | d38fc9076ccf60330c8697b3771d6882398bef6f4759ba6651de23eaa8d06c32 |
| Flutter siamblend_receipt_logo.dart | 5510aae9f84df9dab109eb1e011d0c11c04c4ac419976018bd89efdd48494c7e |
| Flutter customer_ui_preview.dart | 9e333dd07685e3cc0cd4ff52a7f9e43e4713744281b1afbf7388efeb72779091 |

All dispatch/source hashes matched before reuse. Independently checked **31 prior contract QA checksums and 10 Coordinator checksums, zero mismatches**, and the prior report's recorded checksum. [Exact fingerprint inventory](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/source-doc-evidence-hashes.txt). Final verification files record preservation; all tracked source/docs remain unchanged by QA.

## Scope Tested

### Newly Executed

| Check | Actual result |
| --- | --- |
| Independent YAML parse / internal refs | PASS: declared OpenAPI 3.1.0, 2,736 references resolved. |
| Complete OpenAPI 3.1 spec validation | PASS: zero errors; full-openapi-errors.json is []. This is specification conformance, separate from payload checks. |
| Unmodified prior 48 schema cases | PASS: 48 expectations matched, zero unexpected results against the corrected document. |
| Five-route response/profile corpus | Sparse and populated Google, Apple, Facebook, generic LINE and legacy LINE sessions pass the shared response union and profile schema; registration branches also pass. Validation is fresh; fixture JSON is reused. |
| Independent boundary matrix | PASS: 38 cases checked against both CustomerProfile and the social response union (76 schema evaluations); zero failing cases. Do not count those two evaluations as separate acceptance scenarios. |
| Correction/scope invariants | PASS: 16 checks including explicit null types, preserved email/URI formats, exact bank alternatives/maxItems, unchanged request/auth/registration/union schemas and other profile properties. |

The 38 boundary cases cover each corrected string field with null/populated-string positives and number/boolean/array/object negatives; invalid email/URI strings; configured/null/empty bank positives; nonempty arrays containing object/null/array/number; scalar string/number/boolean; empty/missing-required-field bank objects; wrong bank field types; and the optional string branch. Incomplete objects must still fail, not be admitted by the new empty-array alternative.

Evidence: [final execution log](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/schema-validation.log), [48-case results](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/schema-results.json), [boundary/scope results](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/boundary-results.json), [coverage plan](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/coverage-plan.md).

First attempt: full spec/refs and all 48 cases passed, but the boundary runner stopped on its explicit missing URI-format-checker guard. No boundary acceptance was claimed from that attempt. Added rfc3986-validator only to the disposable tool environment and reran successfully, exit 0. schema-validation-first-attempt.log is retained. This was a runner dependency limitation, not a document defect. Repeated runs are not extra coverage. The final runner asserts both email and URI checkers are present and verifies actual invalid-format rejection. jsonschema requires optional dependencies for URI checking; its email format is a sanity check, not proof of mailbox ownership/delivery or complete RFC validation. [Official validator format documentation](https://python-jsonschema.readthedocs.io/en/v4.23.0/validate/#validating-formats).

### Reused Fixture Provenance / Source Trace

Copied only after manifest/source verification, with byte-identical hashes:

```text
validate_contract.py: 5d167eae27fdec1c07991b429ec260058fbbe2cd75204a01bb8115befeafc871
controller-responses.json: 3badd1708850e29ba0504079ac7be60dd80362bda58f526c894f4b91ccc53f37
prior-target-schemas.json: 412130cdb23b394ce08fc7f7364dc222f08e5f5ed2b0649700d937680e8c12db
original controller_contract.php: 2765402a0588117eead41df0fe66d372018092911dbcea7a62071f85c238ce7c
original controller-validation.log: ac1d6c11f9067ed8b7fb7301453c6da34bcc3d2f543ec5539ac19e3f9e874843
```

The prior 20 invocations / 60 assertions used actual public controllers and the actual profile serializer with in-memory partner/link/Wallet substitutes, network disabled, app/vendor read-only. Their session scalar envelope and all accounts/tokens/bank values are fictional; no token was issued. **No fresh PHP/controller/HTTP/provider execution occurred here** because source and provenance were verified unchanged. Coordinator's 48+8 file checks are prior corroboration only, not this independent QA result. Earlier API/Flutter/Nuxt/build tests were not rerun or counted as new coverage.

| Contract / code | Confirmation |
| --- | --- |
| Null profile fields | [Corrected email](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14169), avatar_url at 14176 and preferred_locale at 14179 explicitly permit string/null. [Serializer](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php:1483) emits the checked null fallback values. |
| Unconfigured bank | [Schema](/Users/supakit/WorkSpace/www/newPaotang/docs/openapi.yaml:14185) retains configured-object/null and adds array maxItems 0. [Serializer](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php:1487) and [decryption fallback](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Support/EncryptedJsonPayload.php:85) emit []; unchanged bank normalization at CustomerAuthService:1145 stores nonblank string fields. |
| Minimal / legacy / full registration | Request required fields/default/examples unchanged; 48-case rerun covers minimal, blank members/false terms, full member request and omission fallback. Generic service at 308/314 and LINE at 508/514 retain confirmation/password fallback and existing_only false default. Business rules still depend on server account state; schema success is not fresh OTP/account validation. |
| Actual top-level response | [Generic controller](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerSocialAuthController.php:193) and [legacy LINE controller](/Users/supakit/WorkSpace/www/newPaotang/apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerLineAuthController.php:146) return resource itself. Existing response schemas/refs unchanged; wrapper/false registration negatives still reject. |
| Clients / PIN / safe redirect | [Flutter repository](/Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter/lib/core/auth/auth_repository.dart:513), [screen](/Users/supakit/WorkSpace/www/newPaotang/apps/customer_flutter/lib/features/auth/presentation/line_auth_screens.dart:1028) and [Nuxt form](/Users/supakit/WorkSpace/www/newPaotang/apps/customer/pages/line/link-phone.vue:199) remain unchanged. Probe/member steps, explicit client confirmation and session/PIN/redirect behavior are inherited verified source evidence, not newly executed UI acceptance. |
| Integration map / release | [Social phone-link row](/Users/supakit/WorkSpace/www/newPaotang/docs/customer-api-integration-map.md:150) unchanged and aligned. No backend-first release or native/provider acceptance gate is waived. |

## Commands / Tools

All schema execution ran in the **new** separate Compose project. The previous QA/Coordinator runners were never run unchanged. Root source/docs were read-only; only the new evidence directory was writable. Dependencies were installed under disposable /tmp, not application/vendor/lockfiles.

```text
Python 3.14.7
openapi-spec-validator 0.7.2
jsonschema 4.23.0 / Draft 2020-12 (no nullable compatibility extension)
PyYAML 6.0.2
rfc3986-validator 0.1.1
image ID: sha256:828963118f6838ebdaf6b01b9b24d10c5dffe2f4aaf3ebca33d0d3f74366833e
image digest: node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32
```

Resolved dependencies are recorded in validator-dependencies.txt; pinned image evidence in runner-image-digests.txt. Host execution was limited to Git, file inspection/copies/hashes, and Docker orchestration. Initial/final Git and evidence hash checks passed.

```sh
git fetch origin
git status --short --branch
git rev-parse --show-toplevel HEAD origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
shasum -a 256 -c ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/artifact-manifest.sha256
shasum -a 256 -c ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/artifact-manifest.sha256
QA=ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/compose.qa.yaml
docker compose -p newpaotang-contract-remediation-qa -f "$QA" run --rm --no-deps schema
docker compose -p newpaotang-contract-remediation-qa -f "$QA" down
```

Final schema command exit 0. Disposable runners removed automatically; removed only this QA project's network without -v. Project-filtered container check returned no remaining QA containers. No shared runtime/service or volume operation.

## Defects

No new actionable defect found in this four-field remediation and exercised boundary corpus. CONTRACT-01/02 independently confirmed resolved in documentation. This is not a blanket validation of every response schema, stored legacy value, provider network flow or runtime behavior.

## Runtime Restore / Login Smoke

**Not rerun / not restored:** this task is schema-only and explicitly adds no shared-runtime, DB/account or device authorization. No DB-backed test, migration, seed, cache smoke, build, source/runtime config change, service start/restart/recreate, login or browser session was performed. No destructive command or effective-DB check was needed because there was no DB execution; runtime newpaotang remained protected.

Carry forward the [prior runtime/login observations](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md:156): API/BO/customer/proxy were stopped at that observation; ports 3100/3000 refused connections; no admin API login/redirect acceptance or approved credentials; older seeded-logins: failed is not evidence that current approved accounts are invalid. These are **prior observations, not a fresh claim of current container/HTTP state**. Seed, platform:smoke, admin login and BO restart/recreation were NOT RUN here. QA-G02 remains unresolved rather than passed by schema success.

The [four-service recovery/login proposal](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md:176) remains a proposal for Coordinator approval only: preserve DB/volumes/credentials/config/images/ports, approve intended API/BO/customer/proxy recovery and approved account/session side effects, then verify actual HTTP/API/UI login. No permission to execute that proposal is inferred from this task. Root customer serves built Flutter/nginx, not authenticated legacy Nuxt.

## Risks / Not Tested

Retain the [complete QA-G03 prerequisite matrix](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md:187): installed iOS/Android receipt share/save/safe-area/keyboard; real Google/Apple/Facebook/LINE OTP linking; authenticated legacy Nuxt success; production news timing. Each still needs exact authorized device/build/source, tenant/provider/callback configuration, approved existing/new accounts/phone receivers/PIN, safe existing order fixture and operation-specific authorization. No new prerequisites were supplied. Unknown values remain missing; all those acceptance items stay NOT TESTED/BLOCKED. No installation, SMS/linking/purchase/credentials/deployment occurred.

Delivery/docs remain local and uncommitted; matching HEAD is not deployment/build identity. Full specification validation and reused fictional payloads are not runtime/native/provider acceptance. Earlier dependency warnings remain prior observations and are outside this correction; no application dependency upgrade or broad suite/build rerun was performed.

## Files Added

Only these owned outputs:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/**
```

The directory contains copied validator/fictional fixtures/old target schemas, new QA Compose/boundary script/coverage plan, fresh schema/results/dependency logs, retained first attempt, source/image/provenance hashes, prior manifest checks, cleanup/final preservation evidence, final-report.sha256 and artifact-manifest.sha256 including ignored logs. Application/docs/Board/root Compose/decisions/handoffs and previous reports/artifacts/manifests remain unchanged.

## Recommendation

Coordinator may record CONTRACT-01/02 confirmed and QA-G01 PASS for this scoped remediation. Keep the milestone and overall acceptance BLOCKED pending separately authorized QA-G02/QA-G03 work. Do not release, install, recover/reseed runtime, or assign worker implementation from schema success alone.

## Next Agent

**Coordinator**. User must relay this report to Coordinator chat. No chat was opened or messaged and no defect/work was routed directly to Backend/BO/Customer.
