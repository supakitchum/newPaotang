# Social Phone-Link Contract Remediation QA Instruction

Date: 2026-10-01 (Asia/Bangkok)
Target Agent: Orchestrator
Active task: `customer-responsive-receipt-social-otp`
Next sequence: **Orchestrator -> QA Tester -> Coordinator**

User must send this instruction to Orchestrator chat. Prepare targeted QA confirmation for the Coordinator's four-field documentation correction. Do not dispatch a Backend/BO/Customer implementation task or treat this as a new milestone.

## Read

- `AGENTS.md`
- `ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-contract-remediation-decision.md`
- `ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-qa-report.md`
- `ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-qa/compose.qa.yaml` and `validate_contract.py`
- `docs/openapi.yaml`, `CustomerProfile` and the shared social request/200 response schemas
- Production profile serializer and `EncryptedJsonPayload` identified in the QA report
- `ai-agents/workflow/handoff-protocol.md` and `docs/docker-runtime-policy.md`

## Start Gate / Preservation

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git rev-parse --show-toplevel
git rev-parse HEAD origin/develop
git diff --check
git diff --binary -- apps/customer apps/customer_flutter apps/platform-api | shasum -a 256
shasum -a 256 docs/openapi.yaml docs/customer-api-integration-map.md
```

Expected branch develop; HEAD/origin `c8f130cdcc1a1addc3a7526597bd7a17107d574d`; application diff `f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9`; OpenAPI `0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5`; integration map `f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac`. Verify untracked source hashes against the original QA report as well.

The known dirty source is the delivery. If the baseline changes, return the exact difference to Coordinator before reusing prior evidence. No merge/stash/clean/reset/stage/commit/push; root AGENTS.md overrides older automatic examples.

## QA Scope

1. Validate the full OpenAPI 3.1 document and its internal references in an isolated Docker runner. Do not normalize away type errors or add dependencies to application lockfiles.
2. Independently verify CONTRACT-01: null and populated email/avatar/locale fit the documented response while email/URI format and valid string types remain enforced. Check sparse/populated sessions for Google, Apple, Facebook, generic LINE and legacy LINE.
3. Independently verify CONTRACT-02: configured bank objects, null and `[]` fit the response; nonempty arrays, scalars and incomplete bank objects remain rejected. Trace the real serializer/decryption fallback; no serializer change is part of this fix.
4. Rerun the prior 48 schema cases against current docs in a **new QA-owned evidence directory**. Copy runners/fixtures as needed; do not overwrite the original FAIL evidence, the Coordinator validation evidence, reports or manifests. Add narrow negative checks for the array/type boundary.
5. Reuse prior controller/profile fixtures only after confirming unchanged source/snapshot and clearly label them reused. A fresh network-disabled controller fixture is allowed if needed to confirm provenance. No DB-backed tests, Flutter/Nuxt rebuild, device install or shared-runtime recovery is needed for these document fixes.
6. Confirm minimal probe, legacy blank-member/false-terms probe, full registration and the top-level auth/registration union remain unchanged. Report any discrepancy to Coordinator; do not change docs/application code yourself.
7. Retain QA-G02 and QA-G03 blockers and the previously collected recovery/acceptance prerequisites. Do not repeat unchanged runtime inventory or broad QA unless new state/input makes it necessary. No service start/recreate, DB seed/reset, account/password rewrite, SMS/link/purchase/install/deploy authority is added.

All schema/PHP execution must be inside Docker. Use a separate project/evidence path with read-only source mounts. The root customer runtime serves built Flutter/nginx; it is not a Nuxt/SDK runner. No destructive commands or migrations are in scope.

## Ownership / Output

Orchestrator writes its specific QA task/dispatch/return handoff under `ai-agents/tasks` and `ai-agents/handoffs`. QA adds:

```text
ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa-report.md
ai-agents/reports/artifacts/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa/**
```

Record actual docs/application/untracked hashes, executed vs reused cases, tool/image versions, original evidence preservation, CONTRACT-01/02 and QA-G01 results, Runtime Restore / Login Smoke reason/limitations, QA-G02/QA-G03 state, file ownership and **Next Agent: Coordinator**. A QA-G01 PASS does not close overall acceptance while the other required gates remain unresolved.
