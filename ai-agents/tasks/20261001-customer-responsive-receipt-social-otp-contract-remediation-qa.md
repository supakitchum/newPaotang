# customer-responsive-receipt-social-otp-contract-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Confirm the four-field documentation correction under:

```text
ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-contract-remediation-decision.md
ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-remediation-orchestrator.md
```

Continue the same milestone. Coordinator corrected CONTRACT-01/02 in OpenAPI only; independently confirm them without assigning Backend/BO/Customer work. No chat has been started or messaged automatically.

## Objective

Verify the corrected CustomerProfile schema against established serializer output and the social phone-link response union. Report CONTRACT-01, CONTRACT-02 and QA-G01 independently; a QA-G01 PASS does not close overall acceptance while QA-G02/QA-G03 remain unresolved.

## Source Of Truth

- AGENTS.md; docs/docker-runtime-policy.md; ai-agents/workflow/handoff-protocol.md
- The Coordinator remediation decision and instruction above
- ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
- ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/compose.qa.yaml
- ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/validate_contract.py
- ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/controller_contract.php and controller-responses.json
- docs/openapi.yaml: CustomerProfile, CustomerBankAccount, social request/response schemas and both phone-link paths
- docs/customer-api-integration-map.md: social phone-link row
- apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php: customerProfile
- apps/platform-api/app/Support/EncryptedJsonPayload.php: decrypt/fallback behavior
- Both social/LINE controllers/services and customer clients referenced in the prior QA report
- ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/ (Coordinator file validation; not independent QA acceptance)

## Worktree Start Gate

Canonical worktree only: `/Users/supakit/WorkSpace/www/newPaotang`. Dispatch snapshot after fresh origin fetch:

```text
branch: develop
HEAD and origin/develop: c8f130cdcc1a1addc3a7526597bd7a17107d574d
status: dirty; intentional local delivery/docs/evidence preserved
tracked application diff SHA-256:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
corrected OpenAPI SHA-256:
0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5
unchanged integration map SHA-256:
f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac
prior contract QA report SHA-256:
163e46743a126d8ea74f3d1d20836738c2987876237e8990239efb011a8b7a87
```

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git rev-parse HEAD origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
shasum -a 256 docs/openapi.yaml docs/customer-api-integration-map.md ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md
```

Verify untracked customer logos, news preloader, receipt logo widget and preview hashes against the original QA report. Orchestrator checked they still match. Verify the prior contract QA manifest before reusing its controller/profile fixtures. At dispatch, all 31 prior contract QA and all 10 Coordinator remediation artifact checksums matched, with zero mismatches.

HEAD alone omits the local delivery. If baseline/source/doc hashes change, identify exact differences and return to Coordinator before reusing earlier evidence. No merge, stash, clean, reset, stage, commit or push. Root AGENTS.md overrides older automatic Git/runtime reseed examples.

## Scope

1. Full validation: independently validate OpenAPI 3.1 and resolve internal references using isolated Docker tooling. Use declared JSON Schema semantics without normalizing away type errors or applying a nullable compatibility extension. Report actual tools/versions, ref count and validation errors; Coordinator's 2,736-ref result is prior evidence, not a result to copy.
2. CONTRACT-01: verify `email`, `avatar_url`, and `preferred_locale` permit null and populated strings. Preserve email/URI format validation and reject inappropriate field types. Trace actual serializer output and check sparse/populated sessions for Google, Apple, Facebook, generic LINE and legacy LINE.
3. CONTRACT-02: verify configured CustomerBankAccount objects, null and empty array fit `reward_payout_bank_account`; nonempty arrays, scalars and incomplete bank objects remain invalid. Trace the actual decryption/empty-value fallback. Do not change serializer behavior, bank data, payout rules or clients.
4. Rerun the prior 48 schema cases against the current docs in a new QA-owned evidence directory. Add narrow positive/negative profile/array/format boundary checks. Coordinator's 48 + 8 successful file checks are not independent QA approval and repeated runs are not additional coverage.
5. Reuse prior controller/profile fixtures only after verifying unchanged source, hashes and provenance, and label those fixtures reused. Fresh network-disabled controller fixtures are allowed only if needed for provenance; no DB-backed tests or rebuilds are required.
6. Confirm minimal existing-phone probes, legacy blank-member/false-terms probes, complete registration and the top-level auth/registration-required union remain unchanged. Report any discrepancy with precise file/line evidence to Coordinator instead of fixing it.
7. Retain QA-G02/QA-G03 blockers and the prior report's recovery/acceptance prerequisites. Do not repeat unchanged runtime inventory or broad QA without new state/input that makes it necessary. This task adds no runtime, account, device, provider or production authorization.

## Out Of Scope

- Application/serializer/client/OpenAPI/integration-map fixes, blanket nullable migration or unrelated schema changes.
- Application dependencies/lockfiles, full Flutter/Nuxt build or suite reruns, DB-backed tests/migrations/destructive setup.
- Shared runtime start/recreate/recovery, DB seed/reset, account/password/cache/volume/configuration changes.
- Device installation, real SMS/account linking, purchases, credentials or deployment.
- Rewriting old FAIL reports/artifacts/manifests or Coordinator validation evidence; commit/push or a new milestone.

## File Ownership

Can add:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/**
```

All runner/script/fixture copies and new outputs belong in that new directory. Preserve application/docs, root Compose, Coordinator decision/instruction, previous QA reports/manifests and both prior artifact directories.

## Required Steps

1. Read sources, capture baseline/doc/untracked-source hashes and verify prior evidence before reuse.
2. Prepare a separate QA Compose runner/evidence path. Copy the prior validator/fictional fixtures as needed and change writable evidence mounts to the new directory. Never run either old Compose file unchanged: its `/evidence` mount points at protected prior outputs.
3. Run full specification/ref validation, the prior 48 cases, and independent narrow boundaries inside Docker. Keep application/docs/vendor mounts read-only and temporary validator dependencies outside app files. Preserve email/URI formats and JSON Schema type rules.
4. Compare results with real serializer/decryption behavior and prior network-disabled controller provenance. If a fresh controller fixture is necessary, keep `network_mode: none`, source/vendor read-only and no DB operations, with its output in the new evidence directory.
5. Record newly executed versus reused checks, individual defect/gate outcomes, preserved evidence and remaining acceptance. Return discrepancies to Coordinator only.

## Validation Commands

Schema/PHP execution must use Docker. Git/hashing/file inspection is permitted on the host. Do not add dependencies to the repository; use the existing validator versions/image choices from verified artifacts in a disposable QA runner and record their actual resolved versions/digests.

After QA creates its own `compose.qa.yaml` and redirects **all** outputs/mounts to the new evidence directory:

```sh
docker compose -p newpaotang-contract-remediation-qa -f ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/compose.qa.yaml run --rm --no-deps schema
```

An optional fresh network-disabled controller service may be run from that same new configuration only if needed for fixture provenance:

```sh
docker compose -p newpaotang-contract-remediation-qa -f ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/compose.qa.yaml run --rm --no-deps controller
```

Remove only QA-owned disposable resources after validation, without `-v`:

```sh
docker compose -p newpaotang-contract-remediation-qa -f ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/compose.qa.yaml down
git diff --check
```

Do not start root customer/API/BO services. The root customer image serves Flutter/nginx, not a Nuxt/SDK runner. No shared runtime preflight, DB command or migration is needed for this documentation correction. Do not report old controller/HTTP results as newly executed.

If inline code in a Compose command contains literal `$ref`, escape it as `$$ref` or move it into a QA-owned script to avoid Compose interpolation. Do not mistake a runner-configuration failure for a document defect; preserve first-attempt logs and distinguish the final rerun.

## Acceptance Criteria

- Independent full spec/ref validation and all prior 48 cases have evidence-backed results against the exact corrected doc hash.
- CONTRACT-01 admits null/populated fields while type and applicable email/URI format constraints remain enforced.
- CONTRACT-02 admits only configured objects, null or zero-element arrays; nonempty arrays/scalars/incomplete objects remain rejected by narrow negative checks.
- Five route sparse/populated session responses and unchanged request/response branches are covered, with reused versus fresh fixture provenance explicitly recorded.
- Original FAIL and Coordinator evidence remain unchanged; only new report/artifacts are added.
- CONTRACT-01/02 and QA-G01 receive independent PASS/FAIL/BLOCKED. QA-G02/QA-G03 remain visibly unresolved unless separately authorized evidence changes them; no overall PASS or release approval based solely on schema success.

## Handoff Requirements

Write:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa-report.md
```

Include worktree/branch/HEAD/origin, exact app/doc/untracked-source and evidence hashes, files added, executed versus reused cases, tool/image versions, commands/results, full spec/ref and instance/boundary distinctions, defects with file/line evidence, CONTRACT-01/02 and QA-G01 results, overall status, known risks and Next Agent.

Include `Runtime Restore / Login Smoke`: explain this scoped schema-only task did not change/restore shared runtime and why prior QA-G02 runtime/login limitations remain; retain QA-G03 prerequisite/NOT TESTED distinctions. Do not start services or reseed protected data to manufacture acceptance.

## Next Agent

Coordinator
