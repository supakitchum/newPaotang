# Task: Affiliate BO Usability Ref Links

## Role

Orchestrator

## Coordinator Instruction

รับงาน `affiliate-bo-usability-ref-links` จาก Coordinator board.

อ่านก่อนแตกงาน:

- `ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/handoff-protocol.md`
- `docs/docker-runtime-policy.md`

## Required Start Gate

ทุก agent ต้องเริ่มจาก canonical worktree:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

ถ้า command ใด fail, worktree dirty แบบไม่เกี่ยวข้องกับ scope, หรือ HEAD ไม่ตรง `origin/develop` ให้หยุดและส่ง blocker กลับ Coordinator.

Known dirty implementation files may exist from prior Hotfix work. Do not stage, revert, or overwrite unrelated dirty files. If dirty files overlap this task, read them carefully and work with them only if they are part of the intended current state.

Known artifact that must not be staged:

```text
apps/platform-api/.phpunit.result.cache
```

## Goal

ทำให้ระบบ Affiliate ที่มีอยู่ใช้งานจริงใน BO และทำ referral flow ใหม่ให้ใช้ short code + `/?ref=CODE` ได้จริงจนถึง commission attribution.

## Product Rules

```text
Affiliate code: exactly 6 characters
Charset: A-Z, a-z, 0-9
Case-sensitive: yes
Canonical referral URL: tenant storefront root with /?ref={CODE}
Attribution policy: last-click with 30-day TTL
Customer affiliates must not gain BO access
Affiliate BO resources must remain available
```

## Orchestrator Plan

แตกงานเป็น:

1. Backend Develop
   - Change affiliate account/link code generation to unique 6-character Base62 per tenant.
   - Customer self-register and BO create affiliate must ignore user/admin-supplied code and generate server-side.
   - Generate canonical affiliate link URLs from tenant storefront host as `/?ref={CODE}`; stop creating `/a/{CODE}` links.
   - Keep legacy `/a/{CODE}` data tolerable in reads, but responses should expose canonical URL.
   - Add/apply referral attribution flow for customer context: resolve ref inside tenant, create/update pending attribution with last-click 30-day TTL.
   - Ensure paid order commission calculation still uses affiliate attribution.
   - Add feature tests for code format, canonical URL, ref attribution, cross-tenant/inactive rejection, and commission creation.
2. BO Develop
   - Keep existing Affiliate/Growth BO menus/resources.
   - Improve normal workflows for Affiliates, Affiliate Links, Affiliate Attributions, Commission Rules, Commission Transactions, and Payouts.
   - Detail views must not display raw JSON object dumps.
   - Create/update forms must avoid JSON fields for normal operator input.
   - Use baht input for money, select for payout method/status/rule type, and separate fields for bank account data.
   - Add option sources or practical selectors for customers, affiliates, and affiliate programs so operators do not have to copy raw IDs when avoidable.
   - Remove editable code/url fields where backend now generates them.
   - Add/adjust BO checks and run Docker BO validation.
3. Customer Develop
   - Capture `?ref=CODE` on storefront routes and store it tenant-scoped for 30 days.
   - Use last-click behavior when a new ref appears.
   - Submit/apply stored ref after login/register or before checkout so backend can create/update attribution.
   - Ensure `/affiliate` displays server-provided 6-character code and `/?ref=` link.
   - Add/adjust customer checks and run Docker customer validation.
4. QA Tester
   - Validate Backend + BO + Customer together.
   - Browser QA customer `/?ref=CODE`, login/register/checkout attribution path where fixtures allow.
   - Browser QA BO create/update/detail usability.
   - Confirm customer affiliate account cannot access BO.
   - Use test DB for destructive setup and run runtime restore/login smoke per protocol.

## Constraints

- Do not remove Affiliate from BO.
- Do not allow customer-authenticated affiliate users to access BO/admin APIs.
- Do not introduce `/a/{CODE}` as a new canonical route.
- Do not change reward payout rules or sale price rules.
- Do not run destructive DB commands against runtime DB `newpaotang`.
- Destructive DB tests must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- Every implementation agent must commit and push scoped changes after validation.

## Acceptance Criteria

- Affiliate account/link codes are generated as 6-character Base62 and are unique per tenant.
- Referral links shown to customer/BO use `/?ref=CODE`.
- `?ref=CODE` resolves only within the current tenant and creates/updates pending attribution using last-click 30-day policy.
- Paid order commission calculation can convert the new attribution into commission transactions.
- BO Affiliate/Growth pages are usable without raw JSON for normal workflows.
- BO details do not show JSON dumps for Affiliate/Growth resources.
- Customer `/affiliate` shows the new short code/link.
- Backend tests pass in test DB.
- BO and Customer tests/builds pass in Docker.
- QA report is created and returns to Coordinator.

## Next Agent

Orchestrator
