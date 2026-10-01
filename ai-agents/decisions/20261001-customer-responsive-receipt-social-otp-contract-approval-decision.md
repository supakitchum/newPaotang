# Social Phone-Link Contract Remediation Approval

Date: 2026-10-01 (Asia/Bangkok)
Owner: Coordinator
Decision: **CONTRACT-01/02 resolved; QA-G01 PASS within targeted scope**
Overall milestone / release acceptance: **BLOCKED on QA-G02 / QA-G03**
Next Agent: **User** (runtime scope/account prerequisites), then Orchestrator if authorized

## Evidence Reviewed

- Independent report: `ai-agents/reports/20261001-customer-responsive-receipt-social-otp-contract-remediation-qa-report.md`.
- Report SHA-256: `14d207a9ba78551166c809557a0608a1a8389abe5528f257920b7154f84821ac`.
- Verified all **26 remediation QA artifact checksums**, the report checksum and source/document inventory; zero mismatches. Also verified all 31 prior contract QA and 10 Coordinator remediation artifact checksums.
- Saved final log and structured results agree: full OpenAPI validation zero errors; 2,736 internal refs; 48 schema expectations matched; 38 boundary cases passed (76 evaluations, not 76 distinct cases); all 16 scope invariants passed.
- Both email and URI format checkers were present on QA's final run. The earlier missing-format-checker attempt remains historical evidence; the successful final run supersedes it.
- QA freshly executed schema/boundary validation using byte-identical prior fictional controller fixtures. No fresh HTTP/controller/provider/device acceptance is inferred. No need to rerun those successful schema checks in this Coordinator review.

## Current Source Baseline

Canonical worktree `/Users/supakit/WorkSpace/www/newPaotang`, branch `develop`; fresh origin fetch completed; HEAD/origin both `c8f130cdcc1a1addc3a7526597bd7a17107d574d`. No merge needed.

```text
Tracked application diff SHA-256:
f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9
OpenAPI SHA-256:
0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5
Integration map SHA-256:
f321267f0b1560bd807aec4d2c4b224d005f50612075ff6ab844664d570d63ac
```

Untracked customer branding/source hashes match the QA inventory. Local application/docs/evidence remain uncommitted; HEAD alone is not the delivery or a deployed build identity. Current root AGENTS.md overrides historical automatic Git and runtime reseed instructions.

## Approval Scope

1. CONTRACT-01 is resolved: documented email/avatar_url/preferred_locale accept emitted nulls and valid strings, preserve formats, and reject invalid types.
2. CONTRACT-02 is resolved: configured bank objects, null and the existing `[]` fallback fit the schema; nonempty arrays, scalars and incomplete bank objects remain rejected.
3. Request/probe/default/member-validation/session/registration/PIN/redirect behavior and other response/profile schema properties remain unchanged.
4. Close **QA-G01 for these contract findings**. The earlier QA-G01 FAIL is superseded within this scope; preserve all historical reports/artifacts unchanged.

This approval is not blanket acceptance of all stored legacy values, response schemas, runtime behavior or real provider/native flows. No application/serializer/client change is required by this approval.

## Remaining Work and Authorization Boundary

**QA-G02:** Runtime/login is still BLOCKED. The latest remediation QA carried forward prior observations without rechecking runtime. To make the recovery proposal concrete, Coordinator subsequently read the four selected service states: API/BO/customer/proxy are still stopped, with the same old exit states. HTTP/authenticated login was not rechecked. This selected current-state check is distinct from QA's carried-forward observations.

Prepared a concrete preservation-first recovery/login instruction:

`ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-runtime-login-orchestrator.md`

It proposes starting only the existing local platform-api, back-office, customer and local-proxy containers after preservation/startup preflight, without build/recreation or DB/account/config changes. Authenticated login needs a securely supplied approved account and tenant host; allowed session/audit/last-login writes must be part of that authorization. The task is **pending human authorization, not dispatched or activated**. If image/mount/startup/source identity needs recreation/rebuild, return the exact revised scope to Coordinator first.

Checked installed `docker compose start --help` and simulated the selected scope with `docker compose --dry-run -p newpaotang start platform-api back-office customer local-proxy`. The simulation listed only those four starts and health waits for existing Postgres/Valkey. Selected `ps --all` afterwards confirmed all four remained stopped. The proxy source uses Docker DNS with variable upstreams; this proposal does not start support-api merely because it appears in Compose dependencies. Repeat the scoped dry-run at execution time and reject any unapproved start.

**QA-G03:** Native/device/provider/SMS/authenticated Nuxt/production news acceptance remains BLOCKED / NOT TESTED with the prior prerequisite matrix. No installation, SMS, real linking, purchase, credential creation or deployment is authorized by this contract approval. Backend-first release order remains in force.

No milestone closure or automatic commit/push. Continue the same active task.

## Files Changed / Validation

```text
ai-agents/BOARD.md
ai-agents/decisions/20261001-customer-responsive-receipt-social-otp-contract-approval-decision.md
ai-agents/tasks/20261001-customer-responsive-receipt-social-otp-runtime-login-orchestrator.md
docs/coordinator-agent-handoff.md
```

Read relevant Compose startup/image/mount/port declarations without exposing environment values. Also performed CLI help, a non-mutating start simulation and selected read-only service status inspection. The current source declares API serving, BO dev serving and built Flutter/nginx customer serving; starting that customer alone will not prove the pending source is installed or provide a legacy Nuxt surface. Existing container settings must be verified at authorized execution time.

`git diff --check` passed. Application/OpenAPI/integration-map hashes and QA evidence remained unchanged. No application/schema execution, DB/runtime/service operation, install, staging, commit or push was performed in this approval review. No chat or subagent was opened or messaged.
