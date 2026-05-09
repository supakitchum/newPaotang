# M10 License Dependency BO Production Readiness QA Review Decision

Date: 2026-05-08
Agent: Coordinator

## Context

Coordinator reviewed the latest QA result for:

```text
20260508-m10-license-dependency-bo-production-readiness
```

Files reviewed:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-planning-orchestrator-handoff.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-qa-task-orchestrator-handoff.md
ai-agents/tasks/20260508-m10-license-dependency-bo-production-readiness-qa.md
docs/back-office-admin-foundation.md
apps/back-office/middleware/admin.global.ts
```

Latest QA verdict:

```text
FAIL - Coordinator review required
```

## Decision

Do not approve this slice.

Open a focused BO remediation for the P1 protected-route hard-refresh/deep-link regression.

## Blocking Defect

P1 - Valid authenticated admin sessions cannot hard-refresh or deep-link to protected admin pages.

QA reproduced that after successful central and tenant login:

```text
/admin/central/partners rendered login instead of Partners
/admin/tenant/maintenance rendered login instead of Tenant Maintenance
/admin/tenant/growth/agents rendered login instead of Agents
mobile hard navigation to /admin/tenant/maintenance rendered login
```

Primary source reference:

```text
apps/back-office/middleware/admin.global.ts:12-14
```

The current middleware redirects all server-side `/admin/**` requests to `/login` before the client can restore a valid session from `sessionStorage`.

## Coordinator Direction

BO remediation must preserve both requirements:

```text
valid authenticated sessions can hard-refresh and deep-link to protected central and tenant routes
stale marker or missing client session cannot expose protected content and must end at login without loops
```

The intended behavior is:

```text
no marker on SSR protected route -> redirect to /login?redirect=<target>
exact non-sensitive marker on SSR protected route -> render only a protected shell/restore placeholder, not route data
client guard restores sessionStorage, validates auth, aligns scope/tenant, then loads protected content
stale marker with no valid sessionStorage -> clear marker and redirect to /login?redirect=<target>
wrong scope or missing tenant access -> /admin/403
same-scope login redirect remains safe
```

Do not solve the issue by trusting the marker as authentication. The marker may only decide whether SSR can render a non-sensitive shell so the client can restore a real session.

## Required Remediation Scope

Target owner:

```text
BO Develop
```

Required changes:

```text
fix apps/back-office/middleware/admin.global.ts server-side protected-route behavior
keep protected content hidden until client readiness and authenticated session validation complete
ensure AdminOperationsPage and maintenance page do not perform protected API calls before client restore
preserve stale-marker cleanup and no protected-content leakage
align docs/back-office-admin-foundation.md with the accepted hard-refresh/deep-link behavior
extend apps/back-office/scripts/check.mjs or tests to guard marker-backed shell plus stale-marker redirect behavior
```

Out of scope for this focused remediation:

```text
backend menu category/icon implementation changes
maintenance bypass backend endpoint changes
Nuxt/Vue/Nitro/Vite broad dependency upgrade
Meno legal approval
staging, production, client delivery, or final M10 release approval
```

## QA Acceptance Criteria

QA must verify through Docker-only commands and browser evidence where available:

```text
central login reaches /admin/central/dashboard
central hard navigation to /admin/central/partners renders Partners, not login
tenant login reaches /admin/tenant/dashboard
tenant hard navigation to /admin/tenant/maintenance renders Tenant Maintenance, not login
tenant hard navigation to /admin/tenant/growth/agents renders Agents, not login
mobile 390x844 hard navigation to tenant maintenance renders protected maintenance page after valid login
stale marker without sessionStorage redirects to login and does not render protected content
unsafe/cross-scope redirects still fall back safely
browser logs contain no blocking runtime exception; hydration warnings are reported if present
back-office lint/test/build pass through Docker
relevant backend smoke/focused tests pass if BO depends on maintenance/menu endpoints
```

## Non-Blocking Items Carried Forward

These remain release blockers or Coordinator decisions but are not the cause of this QA failure:

```text
Meno original legal agreement remains absent
npm audit still reports 35 vulnerabilities including 1 critical
broad framework upgrade remains deferred until Coordinator approval
staging, production, external secret-management, Cloudflare/R2 production evidence, old-data migration evidence, cutover/rollback evidence, and final M10 approval remain closed
```

## Next Agent

Orchestrator
