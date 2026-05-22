# affiliate-bo-usability-ref-links - BO Develop

## Target Agent

BO Develop

## Coordinator / Orchestrator Context

Implement Back Office usability improvements for:

```text
affiliate-bo-usability-ref-links
```

Do not start until Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
```

Backend handoff/commit to consume:

```text
backend implementation: c060d1e875d93cf1ba7c7a1b9ce93066baf9c817
backend handoff: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
```

## Canonical Worktree Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

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

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or new unknown dirty files overlap BO scope.

Known BO dirty files at Orchestrator dispatch:

```text
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStatusBadge.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
apps/back-office/components/AdminCustomerDetail.vue
apps/back-office/components/AdminWalletDetail.vue
```

Do not revert or overwrite these. Inspect and work with overlapping changes only if they are part of the intended current state. Stage only files in BO scope that you intentionally own for this task.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260522-affiliate-bo-usability-ref-links-decision.md
ai-agents/tasks/20260522-affiliate-bo-usability-ref-links-backend.md
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/admin-dashboard-template-guidelines.md
docs/openapi.yaml
```

## BO Scope

BO Develop owns:

```text
apps/back-office/**
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md
```

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
```

## Required BO Behavior

Keep Affiliate/Growth BO resources available. Do not remove Affiliate from BO.

Improve normal workflows for:

```text
Affiliates
Affiliate Links
Affiliate Attributions
Commission Rules
Commission Transactions
Payouts
```

Usability requirements:

```text
Detail views must not display raw JSON object dumps for normal operator fields.
Create/update forms must avoid JSON fields for normal operator input.
Use baht input for money fields.
Use selects for payout method, payout status, rule type, and similar enum-like fields.
Use separate fields for bank account data instead of raw JSON where practical.
Add option sources or practical selectors for customers, affiliates, and affiliate programs so operators avoid copying raw IDs when practical.
Remove editable code/url fields where backend generates affiliate codes and canonical /?ref= links.
Show server-generated affiliate code/referral URL as read-only output where useful.
Use the backend canonical URL /?ref={CODE} as the primary referral link display.
Do not show legacy /a/{CODE} as the primary referral link; legacy data may appear only as historical/secondary context if needed.
Preserve existing admin authorization behavior.
```

Out of scope:

```text
backend logic changes
customer frontend changes
new affiliate reporting dashboards
reward payout rule changes
sale price rule changes
```

## Required Validation

Use Docker only:

```sh
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
git diff --check
```

Add or update BO structural checks where useful for:

```text
no raw JSON field for normal Affiliate/Growth forms
generated code/url fields are not editable
baht/enum/bank-account form fields are present
Affiliate/Growth resources remain available in operations catalog
```

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-bo-handoff.md
```

Include:

```text
backend handoff/commit consumed
worktree path
branch
HEAD and origin/develop at start/end
commit hash pushed
files changed
dirty files consumed vs left untouched
validation commands/results
known risks/blockers
Next Agent: Orchestrator
```

Commit and push scoped BO changes and the handoff.

## Next Agent

Orchestrator
