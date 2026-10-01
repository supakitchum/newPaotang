# Social Phone-Link Contract QA Remediation Decision

Date: 2026-10-01 (Asia/Bangkok)
Owner: Coordinator
Decision: **Accept QA findings; correct documentation; independent QA confirmation pending**
Overall acceptance: **BLOCKED**
Next Agent: **Orchestrator -> QA Tester -> Coordinator**

## QA Review and Baseline

Reviewed `ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md` and its schema/controller/source evidence. QA-G01 is FAIL for two P2 discrepancies; request/probe behavior matches. QA-G02 and QA-G03 remain BLOCKED / NOT TESTED. Successful specification parsing from the prior review did not validate actual profile instances.

- Fresh origin fetch completed. Canonical worktree `/Users/supakit/WorkSpace/www/newPaotang`, branch `develop`; HEAD/origin both `c8f130cdcc1a1addc3a7526597bd7a17107d574d`.
- Application diff remains `f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9`.
- Verified all **31 contract QA artifact checksums**, zero mismatches, and the report's recorded SHA-256 `163e46743a126d8ea74f3d1d20836738c2987876237e8990239efb011a8b7a87`.
- Before remediation, OpenAPI matched QA's `7a6f6ec86df0cdfcd14a37489799553f7abafbc09c68e0b77e101f111558682f`; integration map matched `f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac`.

## Correction Scope

**CONTRACT-01:** In `CustomerProfile`, change only email, avatar_url and preferred_locale to `type: [string, "null"]`, removing their old nullable annotation. Preserve existing email/URI formats and the string branch. This describes nulls already emitted by `CustomerAuthService::customerProfile`.

**CONTRACT-02:** Preserve the CustomerBankAccount object and null alternatives and add `type: array, maxItems: 0` to reward_payout_bank_account. Document `[]` as the serializer's current unconfigured-bank value. Nonempty arrays remain invalid; this does not change bank data, encryption, payout rules or stored records.

OpenAPI 3.1 uses JSON Schema 2020-12 semantics; explicit type alternatives admit null, and maxItems limits the array branch to zero elements. Sources: [OpenAPI Schema Object](https://spec.openapis.org/oas/v3.1.0.html#schema-object), [JSON Schema type](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.1.1), [array maxItems](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.4.1).

Coordinator implements this correction within documentation ownership. Both findings predate the probe documentation change; choose accurate documentation of established output rather than changing the serializer or clients. CustomerProfile is shared by auth/profile responses, so its documented four-field correction applies wherever that schema is referenced. No blanket nullable migration, other response changes, dependency upgrade or application implementation is assigned.

Corrected OpenAPI SHA-256: `0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5`.

## Coordinator File Validation

Executed isolated Docker file/schema validation against the current document:

- Full OpenAPI 3.1 specification validation: **PASS, zero errors**; all **2,736 internal refs resolved**.
- Unmodified QA validator: **48 cases passed, zero unexpected results**, including all five sparse-profile route responses and their profile schemas.
- Additional boundary inspection: **8 checks passed**, including rejection of nonempty bank arrays, incomplete bank objects, scalars and invalid field types.
- These are Coordinator schema checks, not independent QA approval or fresh controller/HTTP executions. Fictional response fixtures were copied from QA; the application snapshot, copied fixture/script hashes and original QA report/31-entry manifest were verified unchanged. No controller, application, DB-backed tests or builds were rerun.
- The initial validation log is retained: its 48 cases passed but an extra boundary assertion failed because Docker Compose interpolated the inline `$ref` key. Escaped it as `$$ref` in the validation runner and reran; final process exit **0** with 48 cases plus 8 boundary checks. This was a runner-configuration error, not a document/application defect. Repeated runs are not additional coverage.
- Disposable schema containers removed themselves; the separate `newpaotang-contract-remediation-docs` network was removed without volume deletion. No shared service or DB operation occurred. `git diff --check` passed.

Evidence directory: `ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/`.

Reproduce the file validation only:

```sh
docker compose -p newpaotang-contract-remediation-docs -f ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/compose.validation.yaml run --rm --no-deps schema
docker compose -p newpaotang-contract-remediation-docs -f ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/compose.validation.yaml down
```

The existing evidence directory is Coordinator-owned; independent QA must use its own copy/output path to preserve these logs and manifests.

## Remaining Gates

- QA-G01: both document fixes require independent QA confirmation. Coordinator file validation is not that gate's approval.
- QA-G02: fresh QA confirms shared API/BO/customer/proxy stopped and login unavailable. Approved credentials remain missing. Preserve the runtime; the report's four-service recovery/login proposal is a reviewable proposal only, with no automatic start/recreate, reseed/reset, password/account rewrite or cache/volume change.
- QA-G03: retain native/provider/SMS/authenticated Nuxt/production-timing NOT TESTED. Device/build/tenant/account/phone prerequisites and authorization remain necessary for actual acceptance.
- Backend-first release remains required after applicable acceptance and explicit release authorization. Do not close the milestone, install, deploy, commit or push from this decision.

## Files Changed

```text
docs/openapi.yaml
docs/coordinator-agent-handoff.md
ai-agents/BOARD.md
ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-contract-remediation-decision.md
ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-remediation-orchestrator.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation/**
```

The integration map, original decisions, both QA reports/manifests and all application source are preserved. Root AGENTS.md overrides older automatic Git/runtime reseed examples.

## Continuation

Use `ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-remediation-orchestrator.md` for targeted independent QA confirmation of CONTRACT-01/02. Continue this same task through Orchestrator; no new implementation worker is needed. User must relay the instruction to Orchestrator chat. No chat/subagent is opened or messaged by Coordinator.
