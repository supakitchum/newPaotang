# M10 Release-Gate Follow-up Planning Decision

Date: 2026-05-08
Agent: Coordinator

## Decision

Open a follow-up planning slice for M10 release-gate ownership.

The M10 backend/ops foundation passed local/dev QA, but QA explicitly did not approve staging, production, client delivery, full load execution, production observability, Cloudflare/CDN/R2 integration, migration rehearsal, license, dependency closure, scheduler workload registration, Horizon, or Reverb.

## Objective

Orchestrator must break the remaining M10 release gates into concrete implementation/QA slices with clear owners, scope, and acceptance criteria.

## Required Planning Areas

```text
Load-test fixtures, bearer tokens, thresholds, and full k6 execution
Production observability backend, metrics sink, dashboards, and alert channels
Cloudflare custom domain verification, HTTPS enforcement, WAF, rate limit, and CDN/R2 image strategy
Horizon dashboard and queue supervision
Reverb production deployment and scaling
Scheduler workload registration and operational runbook
Old-data migration scripts, rehearsal data, cutover plan, and rollback drill
Production secret management and env boundary
Meno license compliance before delivery
npm audit remediation and dependency production-readiness triage
Back-office hydration mismatch/stale-marker/menu metadata risks
```

## Constraints

- Do not claim production/staging/client approval until QA verifies the release gates.
- Use Docker only for package, build, test, migration, queue, scheduler, k6, and runtime commands.
- Preserve API contracts, customer flow, tenant isolation, and business rules unless a separate Coordinator decision approves changes.
- Do not move tenant logo/theme/payment/domain/feature configuration into env.
- Keep one product, one platform, one shared codebase/release train.

## Expected Orchestrator Output

Create a handoff and one or more tasks that identify:

```text
next target agent
write scope
source-of-truth docs
explicit commands/tests
required artifacts
QA acceptance criteria
release-gate boundary
risks carried forward
```

## Next Agent

Orchestrator
