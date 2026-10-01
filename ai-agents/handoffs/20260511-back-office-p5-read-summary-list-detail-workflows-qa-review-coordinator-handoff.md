# Coordinator Handoff - Back Office P5 Read Summary List Detail Workflows QA Review

Date: 2026-05-11
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p5-read-summary-list-detail-workflows`
Next Task: `back-office-p5-ticket-status-filter-remediation`

## Summary

QA returned a partial PASS for P5-A read/summary/list/detail workflows.

Coordinator promotes five rows to complete:

```text
central:dashboard
tenant:dashboard
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

`tenant:tickets` remains partial because QA found a P2 BO/catalog filter defect.

Official BO completion is now 41/56 menus, or 73.2%.

## Decision

See:

```text
ai-agents/decisions/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-decision.md
```

## Held Row

```text
tenant:tickets
```

Reason:

```text
The tenant tickets page lists API status active, but the BO status dropdown only offers open, pending, resolved, and closed.
```

QA already verified that ticket real-menu list/detail, tenant headers, hard refresh, and mobile detail rendering work. Do not promote the row until the filter contract mismatch is remediated and QA verifies it through the real BO menu.

## Next Instruction For Orchestrator

Open remediation task:

```text
back-office-p5-ticket-status-filter-remediation
```

Expected first owner:

```text
BO Develop
```

Required BO direction:

- Update `apps/back-office/composables/useAdminOperationsCatalog.ts` tenant ticket status filter options to align with the API-visible ticket status `active`.
- Preserve existing useful filters unless BO finds they are unsupported by the contract.
- Keep this as a BO/catalog fix; do not route to Backend unless BO proves the OpenAPI/backend contract is wrong.
- After BO handoff, route to QA Tester for focused real-menu verification of `/admin/tenant/tickets` filter behavior.

## Remaining Coverage

```text
41 / 56 complete = 73.2%
13 partial
2 api_gap
```

Remaining partial rows after this decision:

```text
central:games
central:partner_monitoring
central:partner_usage
tenant:price_rules
tenant:customers
tenant:tickets
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

## Guardrails

- Do not count route/catalog/menu presence as completion.
- Backend remains frozen except recorded API gaps.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.
- Use Docker-only validation for app/test commands.
- Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.
- Keep Orchestrator in the chain; Coordinator does not create QA/BO tasks directly.

## Next Agent

```text
Orchestrator
```
