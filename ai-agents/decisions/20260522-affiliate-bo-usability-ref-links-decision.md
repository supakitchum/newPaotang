# Affiliate BO Usability Ref Links Decision

## Decision

Open task `affiliate-bo-usability-ref-links`.

## Coordinator

Coordinator

## Date

2026-05-22

## Context

User wants the existing Affiliate system to be usable in Back Office, not just exposed as generic JSON/raw-ID operation pages. User also clarified that Affiliate must remain available in BO; only customer affiliates must not access BO.

Current observed state:

- Tenant Affiliate BO resources exist in the operations catalog.
- Several Affiliate/Growth BO forms still expose JSON fields or raw IDs for normal workflows.
- Affiliate customer self-service exists, but referral code/link policy needs product cleanup.
- Existing referral URL shape is `/a/{code}` and should move to shorter `/?ref={code}`.

## Product Decisions

```text
Affiliate code format: exactly 6 characters
Affiliate code charset: A-Z, a-z, 0-9
Affiliate code sensitivity: case-sensitive
Canonical referral link: storefront root query param, /?ref={CODE}
Attribution policy: last-click, 30-day TTL
```

## Required Behavior

When a customer opens a tenant storefront with `?ref=CODE`, the customer app must retain that ref for the current tenant for 30 days. If another valid-looking ref arrives later, it replaces the previous ref.

Backend must resolve the ref inside the same tenant only:

```text
1. active affiliate_links.code
2. fallback active affiliate_accounts.code
```

After the customer is known, such as after login/register or before checkout, backend must create or update a pending affiliate attribution for that tenant/customer using last-click semantics. Paid order commission calculation must continue to use affiliate attribution as the source of truth.

## Scope

In scope:

- Backend short code generation and canonical referral URL.
- Customer `?ref=` capture and submit/apply flow.
- BO Affiliate/Growth UI usability for normal create/update/detail workflows.
- Backend/BO/Customer tests and QA.

Out of scope:

- Affiliate tiering.
- New affiliate reporting dashboards.
- Changing reward payout logic.
- Allowing customer affiliate users into BO.

## Dirty Worktree Note

At decision creation, canonical worktree is on `develop` and HEAD matches `origin/develop`, but there are uncommitted implementation changes from prior Hotfix work. Orchestrator must run the start gate and must not overwrite or stage unrelated dirty work.

## Next Agent

Orchestrator
