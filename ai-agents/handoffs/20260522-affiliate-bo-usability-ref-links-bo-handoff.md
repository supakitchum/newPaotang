# 2026-05-22 Affiliate BO Usability + Referral Links BO Handoff

Task: affiliate-bo-usability-ref-links
Agent: BO Develop Agent
Next Agent: Orchestrator

## Baseline

- Start branch: develop
- Start commit: e6bc10cf741d343a496f5ec66d58754fcdaed632
- Backend implementation consumed: c060d1e875d93cf1ba7c7a1b9ce93066baf9c817
- Backend handoff consumed: 3b27043cc7753b7fe0d2fb8703396b121f40db0d

## Scope Completed

- Kept Affiliate/Growth resources available in the BO operations catalog.
- Reworked affiliate account, affiliate link, commission rule, and payout create/update workflows away from raw IDs and JSON inputs for normal operator use.
- Added tenant option sources for customers, affiliates, and affiliate programs and wired them into BO form/filter hydration.
- Removed editable generated affiliate code/referral URL fields from affiliate account/link forms.
- Displayed generated code and canonical referral URL as readonly/detail output using `canonical_url` with fallback to existing URL fields.
- Added curated detail-field rendering for Affiliate/Growth resources to avoid default raw object JSON dumps in normal detail views.
- Switched normal money entry for commission rule fixed amount and payouts to baht input while preserving minor-unit payload conversion.
- Added payout method/status/rule type enum selects and separate bank-account fields.
- Added structural guardrails for the affiliate BO usability contract.

## Files Changed

- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/scripts/check.mjs`
- `ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md`

## Validation

- `docker compose -p newpaotang run --rm back-office npm run lint` passed
- `docker compose -p newpaotang run --rm back-office npm run test` passed
- `docker compose -p newpaotang run --rm back-office npm run build` passed
- `git diff --check` passed
- The staged patch was also applied to a temporary clean worktree from baseline and passed the same Docker lint/test/build plus diff check.

Build note: Nuxt emitted the existing Node `DEP0180 fs.Stats constructor` deprecation warning, but the build completed with exit code 0.

## Dirty Worktree Notes

Pre-existing dirty files from other scopes remain unowned and were not intentionally staged, including customer and platform-api files. BO files with unrelated customer/wallet workflow edits were present before this task; only affiliate/growth scoped hunks were staged for this handoff.
