# Coordinator Handoff - Back Office P5 Tenant Price Rules Customers Typed Workflows QA Review

Date: 2026-05-11
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p5-tenant-price-rules-customers-typed-workflows`
Next Task: `back-office-p5-tenant-agent-quota-typed-workflows`

## Summary

QA returned PASS for the focused tenant price rules and customer/member typed workflows.

Coordinator promotes `tenant:price_rules` and `tenant:customers` to complete.

Official BO completion is now 45/56 menus, or 80.4%.

## Decision

See:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
```

## Accepted Complete Rows

```text
tenant:price_rules
tenant:customers
```

## Evidence Summary

QA verified:

```text
real tenant BO menu route for price rules
typed create/update price-rule modals
POST /admin/tenant/price-rules with tenant scope and idempotency
PATCH /admin/tenant/price-rules/{price_rule_id} with tenant scope and idempotency
DELETE /admin/tenant/price-rules/{price_rule_id} archive action with reason/context
price-rule list/detail/filter/cursor behavior
real tenant BO menu route for customers
Customer frontend not used
typed member create/update/status modals
POST /admin/tenant/members with tenant scope and idempotency
PATCH /admin/tenant/members/{member_id} with tenant scope and idempotency
POST /admin/tenant/members/{member_id}/status with reason/context and idempotency
password_hash absent from member create/detail/list evidence
```

## Coverage After This Decision

```text
45 / 56 complete = 80.4%
9 partial
2 api_gap
```

Remaining partial rows:

```text
central:partner_monitoring
central:partner_usage
tenant:agents
tenant:agent_quotas
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
tenant:seo_settings
```

API-gap rows remain:

```text
central:master_stock
tenant:commission_transactions
```

## Next Instruction For Orchestrator

Open the next BO implementation slice:

```text
back-office-p5-tenant-agent-quota-typed-workflows
```

Expected first owner:

```text
BO Develop
```

Required BO direction:

- Implement or surface typed workflows for `tenant:agents` and `tenant:agent_quotas`.
- For `tenant:agents`, cover typed create/update and the quota action from the existing APIs.
- For `tenant:agent_quotas`, cover typed quota fields and real quota workflow QA.
- Preserve existing list/detail API connections and tenant `X-Tenant-Id` behavior.
- Preserve existing idempotency handling for all write actions.
- Keep backend frozen unless BO proves the current OpenAPI/backend contract is insufficient and Coordinator approves a backend exception.
- After BO handoff, route to QA Tester for real tenant BO menu workflow QA before either row can be promoted.

## Guardrails

- Do not count route/catalog/menu presence as completion.
- Backend remains frozen except recorded API gaps or explicit Coordinator decisions.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.
- Use Docker-only validation for app/test commands.
- Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.
- Keep Orchestrator in the chain; Coordinator does not create QA/BO tasks directly.

## Next Agent

```text
Orchestrator
```
