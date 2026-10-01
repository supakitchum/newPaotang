# M10 License Dependency BO Production Readiness QA Review Coordinator Handoff

Date: 2026-05-08
Agent: Coordinator
Next Agent: Orchestrator

## Task

Review QA result for:

```text
20260508-m10-license-dependency-bo-production-readiness
```

## What Was Done

Coordinator reviewed the QA report, backend handoff, BO handoff, Orchestrator handoffs, QA task, docs, and the cited middleware source.

Latest QA verdict:

```text
FAIL - Coordinator review required
```

Coordinator recorded:

```text
ai-agents/decisions/20260508-m10-license-dependency-bo-production-readiness-qa-review-decision.md
```

## Decision Summary

Do not approve the slice.

Open focused remediation for:

```text
P1 valid authenticated sessions cannot hard-refresh or deep-link to protected admin pages
```

QA evidence shows central and tenant authenticated hard navigations are currently redirected to login before client session restoration can complete.

## Required Orchestrator Action

Create a BO Develop remediation task:

```text
20260508-m10-license-dependency-bo-protected-deeplink-remediation
```

The task must focus on restoring valid-session hard refresh and deep-link behavior while keeping stale markers safe.

## Required BO Direction

BO Develop must:

```text
fix apps/back-office/middleware/admin.global.ts SSR route behavior
allow exact marker-backed SSR protected shell/restore placeholder for valid-session refreshes
never treat marker as auth
restore sessionStorage on client before protected data loading
clear stale/corrupt marker when restore fails
redirect stale marker to login without protected content leakage
preserve same-scope login redirect safety and wrong-scope /admin/403 behavior
update docs/back-office-admin-foundation.md to match actual accepted behavior
add static/test guardrails for this flow
run BO Docker lint/test/build
collect runtime evidence through Docker-hosted app
```

## Must Not Change

```text
API path/contract unless separately approved
backend maintenance bypass endpoint
backend menu category/icon contract
customer UI flow
business rules
Meno license legal text
broad Nuxt/Vue/Nitro/Vite dependency upgrade
staging/production/client delivery/final M10 release approval
```

## QA Criteria For Remediation

QA must confirm:

```text
/admin/central/partners hard refresh after valid central login renders Partners
/admin/tenant/maintenance hard refresh after valid tenant login renders Tenant Maintenance
/admin/tenant/growth/agents hard refresh after valid tenant login renders Agents
mobile hard refresh after valid tenant login renders Tenant Maintenance
stale marker without sessionStorage ends at login and does not leak protected content
unsafe/cross-scope redirect handling remains safe
Docker-only BO build/lint/test pass
Docker-only backend focused checks pass if BO depends on backend menu/maintenance routes
browser console/runtime errors are captured and reported
```

## Current Board Proposal

Coordinator updated Board directly to:

```text
Active Task: 20260508-m10-license-dependency-bo-production-readiness-remediation-planning
Coordinator: completed 20260508-m10-license-dependency-bo-production-readiness-qa-review
Orchestrator: ready 20260508-m10-license-dependency-bo-production-readiness-remediation-planning
Backend Develop: completed 20260508-m10-license-dependency-bo-production-readiness-backend
BO Develop: needs_remediation 20260508-m10-license-dependency-bo-protected-deeplink-remediation
QA Tester: completed 20260508-m10-license-dependency-bo-production-readiness-qa
```

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

## Git Boundary

Do not trigger Gate 5 yet. This remains inside M10 release-gate follow-up work. Before moving to a new milestone or post-M10 phase, stop and commit plus push first.

## Next Agent

Orchestrator
