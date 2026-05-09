# M10 License Dependency BO Protected Deeplink Remediation QA Review Decision

Date: 2026-05-08
Agent: Coordinator

## Context

Coordinator reviewed the focused QA result for:

```text
20260508-m10-license-dependency-bo-protected-deeplink-remediation
```

Files reviewed:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-planning-orchestrator-handoff.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-task-orchestrator-handoff.md
ai-agents/tasks/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa.md
apps/back-office/layouts/admin.vue
apps/back-office/assets/css/admin-foundation.css
```

Latest QA verdict:

```text
FAIL - Coordinator review required
```

## Decision

Do not approve this remediation as clean yet.

The original P1 protected hard-refresh/deep-link defect is closed by QA evidence, but a required mobile acceptance check now fails.

Open a focused BO remediation for the mobile layout overflow.

## Closed From Prior P1

QA confirmed the main P1 behavior is fixed:

```text
central login reaches /admin/central/dashboard
central hard navigate and reload to /admin/central/partners renders Partners, not login or restore shell
tenant login reaches /admin/tenant/dashboard
tenant hard navigate and reload to /admin/tenant/maintenance renders Tenant Maintenance, not login or restore shell
tenant hard navigate and reload to /admin/tenant/growth/agents renders Agents, not login or restore shell
no-marker SSR redirects to login
exact marker SSR returns restore shell only
invalid marker clears and redirects
browser logs captured no warnings/errors in the tested flows
```

Docker guardrails passed:

```text
back-office npm run lint: PASS
back-office npm run test: PASS
back-office npm run build: PASS
AdminAuthTest: PASS, 9 tests / 78 assertions
AdminMenuTest: PASS, 5 tests / 26 assertions
MaintenanceTest: PASS, 2 tests / 52 assertions
maintenance bypass route list: PASS
```

## Blocking Defect

P2 - Mobile tenant maintenance overflows horizontally after a valid hard refresh.

QA evidence:

```text
390x844 viewport
valid tenant session
hard navigate/reload /admin/tenant/maintenance
Tenant Maintenance renders, but the viewport is shifted/clipped horizontally
```

Source areas cited by QA:

```text
apps/back-office/layouts/admin.vue:6
apps/back-office/assets/css/admin-foundation.css:90-110
```

Artifacts:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.txt
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.png
```

## Required Remediation Scope

Target owner:

```text
BO Develop
```

Open task:

```text
20260508-m10-license-dependency-bo-mobile-overflow-remediation
```

Required changes:

```text
fix mobile layout/sidebar/main-content offset so /admin/tenant/maintenance fits 390x844 after valid hard refresh
verify the fix does not regress desktop admin layout
verify protected deep-link behavior remains fixed for central Partners, tenant Maintenance, and tenant Agents
verify stale marker still does not leak protected content
add or extend BO static guardrails for mobile no-overflow shell behavior where practical
update docs/back-office-admin-foundation.md only if the layout contract changes
```

Out of scope:

```text
backend menu category/icon contract changes
maintenance bypass backend endpoint changes
Meno legal approval
npm audit remediation or broad framework upgrade
BO menu completion work
staging, production, client delivery, or final M10 release approval
```

## QA Acceptance Criteria

QA must verify:

```text
390x844 valid tenant hard refresh to /admin/tenant/maintenance renders without horizontal overflow
central valid hard refresh to /admin/central/partners still renders Partners
tenant valid hard refresh to /admin/tenant/growth/agents still renders Agents
stale marker/no session still ends at login without protected content leak
desktop central and tenant shells remain usable
BO lint/test/build pass through Docker
backend focused checks pass if the BO page depends on backend maintenance/menu endpoints
```

## Next Planning Note

After this mobile overflow remediation passes QA, Coordinator should open a separate BO menu completion slice. Current BO still has many menu items routed to generic/catalog pages or grouped fallback routes, so menu-by-menu completion should be tracked separately from this M10 protected-route fix.

## Release Gates Still Closed

```text
Meno license compliance
npm audit remediation or approved deferral
staging
production
client delivery
external secret management
Cloudflare/R2 production evidence
old-data migration evidence
cutover/rollback evidence
final M10 release approval
```

## Next Agent

Orchestrator
