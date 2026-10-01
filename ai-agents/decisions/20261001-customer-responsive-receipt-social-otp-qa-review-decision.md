# Customer Receipt, News, and Social OTP Coordinator Review

Date: 2026-10-01 (Asia/Bangkok)
Owner: Coordinator
Decision: **REVISE / acceptance remains BLOCKED**
Next Agent: **Orchestrator -> QA Tester -> Coordinator**

## Evidence and Baseline

- Current root `AGENTS.md` takes precedence over historical automatic commit/push and runtime reseed instructions.
- Reviewed the delivery handoff, October QA task/report, and Orchestrator's return handoff. The requested existing-phone behavior is already stated in the Coordinator delivery; this decision does not infer a new customer flow from diagnostic tests.
- Fresh `git fetch origin --prune` completed. Canonical worktree `/Users/supakit/WorkSpace/www/newPaotang`, branch `develop`; HEAD and origin/develop both `c8f130cdcc1a1addc3a7526597bd7a17107d574d`, ahead/behind `0/0`. No merge was needed.
- Tracked application diff SHA-256 remains `f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9`. Both customer logos and the three untracked Dart source/preview files match QA's recorded hashes.
- Independently checked the QA artifact manifest: **269 matched, zero mismatches**. QA report SHA-256 remains `20313844c6d61834fa36c7a7a95bce5650fb10d5911463fa6ac27995eeb17c5c`.
- Saved QA logs corroborate API 42 tests / 353 assertions plus 3 diagnostics / 96 assertions, Flutter 173 regressions plus the final 27 fixture tests, analyzer and builds. These are QA's results, not tests rerun by Coordinator. Representative compact receipt/social images were also inspected.

## QA-G01: Contract Decision and Documentation Correction

Confirm the existing delivered contract for the generic Google/Apple/Facebook/LINE endpoint and the legacy LINE endpoint:

1. Every request supplies `link_token`, `phone`, and a valid tenant/phone/register-purpose `otp_verification_token`.
2. Clients first submit `existing_only: true`. An active existing phone account links/signs in without member fields, preserving the stored profile/password and existing PIN/session activation requirements.
3. A new phone probe returns HTTP 200 `{ "registration_required": true }`, creates no customer/session, and consumes neither token. The full registration request follows with names, password/confirmation and terms, and `existing_only` omitted or false.
4. Creating a new customer still requires valid names/password and accepted terms. Existing services default an omitted password confirmation to the password; clients continue to collect/send confirmation. Documenting that existing fallback does not authorize weakening client validation.
5. OTP validity is checked before exposing account status. Tenant/phone/purpose/expiry/consumption, suspension/inactivity, identity ownership and provider matching remain enforced. Successful linking/registration consumes the tokens once.

Coordinator corrected `docs/openapi.yaml` and `docs/customer-api-integration-map.md` within documentation ownership. Both endpoint 200 responses now describe the auth-session/registration-required union. The request schema requires the universal fields and describes new-member requirements as dependent on server account state; it does not falsely reject the minimal existing-account request or legacy probes carrying blank member fields/false terms. No application behavior was edited.

The contract scope decision is resolved; **QA-G01 verification remains OPEN** until QA independently checks these documents against the unchanged services/controllers/clients. Diagnostic results alone do not close acceptance.

## QA-G02: Runtime / Account Validation Decision

- Treat the stopped shared API/BO/customer/proxy as a pre-existing runtime blocker based on QA's before/after evidence. Coordinator did not refresh live Docker/HTTP state in this review.
- Approve read-only local preflight in the follow-up QA scope: refresh service/image/port/mount state and unauthenticated login HTTP/redirect checks. Do not start/recreate stopped services on this instruction.
- `seeded-logins: failed` is not proof that current approved accounts are invalid. Retain that failed legacy check in the evidence; do not seed/reset the protected `newpaotang` database, recreate accounts, change passwords, or flush caches.
- If services remain stopped or approved credentials are unavailable, return the exact services needed and a data-preserving recovery/login plan to Coordinator. Any later execution must preserve source, images/configuration where possible, credentials, DB/volumes, ports and settings. No BO source change is assigned.
- **QA-G02 remains BLOCKED** until an approved runtime/login verification is actually performed. Schema/fixture success cannot substitute for it.

## QA-G03: Native / Real Provider / Production Acceptance Decision

- Keep native share/save, safe areas/keyboard, real Google/Apple/Facebook/LINE OTP linking, authenticated Nuxt success rendering, and production news timing explicitly unverified.
- Orchestrator/QA may prepare the acceptance matrix and prerequisite list: exact device/build/source snapshot, tenant, approved existing/new phone accounts, provider configuration and safe receipt/order fixture. Credentials/OTP/tokens must not enter reports.
- This continuation does not authorize installation, real SMS/account linking, purchases, credential creation, or production deployment. Return missing prerequisites to Coordinator instead of substituting fixture timing or browser markers for real acceptance.
- Release remains backend first, clients second, after applicable verification and explicit release authorization. No migration is required by this delivery.
- **QA-G03 remains BLOCKED / NOT TESTED**; no limitation is silently waived.

## Validation of This Review

- Parsed the edited OpenAPI YAML using Ruby's standard YAML reader as file inspection; **2,736 internal references resolved** and the targeted request/response structure checks passed. This is not a full OpenAPI/JSON Schema conformance test or HTTP acceptance.
- `git diff --check` passed after the contract and coordination edits. No application tests/builds, service operation, DB operation, install, staging, commit or push occurred in this Coordinator review.
- Application and original QA evidence are preserved. The delivery remains local/uncommitted; the remote HEAD is not a release snapshot.
- Corrected OpenAPI SHA-256: `7a6f6ec86df0cdfcd14a37489799553f7abafbc09c68e0b77e101f111558682f`; integration map SHA-256: `f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac`.

## Files Changed by Coordinator

```text
docs/openapi.yaml
docs/customer-api-integration-map.md
docs/coordinator-agent-handoff.md
ai-agents/BOARD.md
ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-qa-review-decision.md
ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-review-orchestrator.md
```

## Continuation

Continue the same active task through the board instruction:

`ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-contract-review-orchestrator.md`

No Backend/BO/Customer implementation task is needed for this documentation correction. Orchestrator routes the targeted review to QA Tester, then returns the report to Coordinator. User must send the board/task instruction to Orchestrator chat; no chat/subagent was opened or messaged. Do not close the milestone or report unconditional PASS while the applicable gates remain open.
