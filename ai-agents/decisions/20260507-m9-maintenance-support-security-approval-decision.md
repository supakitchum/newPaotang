# M9 Maintenance, Support Access, Security Hardening Approval Decision

## Context

Coordinator reviewed the completed M9 backend flow:

```text
ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md
ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
ai-agents/tasks/20260507-m9-maintenance-support-security-qa.md
ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md
```

QA result:

```text
PASS
```

No blocking defects were found.

## Decision

Approve M9 Maintenance, Support Access, Security Hardening backend foundation.

This approval covers the backend-only M9 scope. Customer UI and back-office UI implementation remain separate future work.

## Approved Scope

Approved backend scope:

```text
tenant-scoped maintenance settings/events/bypasses
maintenance admin APIs
maintenance mode route blocking for public/customer flows
site-config maintenance compatibility
maintenance.changed.v1 outbox/audit evidence
support access requests, approvals, revocation, impersonation start, elevated action logging, and session ending
short-lived support impersonation session foundation
support token hash-at-rest behavior
blocked sensitive support action middleware/evidence
CentralStockTest deterministic audit lookup hardening
backend M9 docs and architecture compliance updates
focused tests and full Docker regression validation
```

## Approved Endpoints

```text
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
GET /api/v1/admin/tenant/support-access
POST /api/v1/admin/tenant/support-access
GET /api/v1/admin/tenant/support-access/{support_access_id}
POST /api/v1/admin/tenant/support-access/{support_access_id}/approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate
POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions
POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session
```

## QA Evidence Reviewed

Coordinator reviewed Docker validation evidence:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=CentralStockTest: PASS, 1 test, 32 assertions
docker compose run --rm platform-api php artisan test --filter=Maintenance: PASS, 4 tests, 117 assertions
docker compose run --rm platform-api php artisan test --filter=SupportAccess: PASS, 1 test, 21 assertions
docker compose run --rm platform-api php artisan test --filter=Impersonation: PASS, 2 tests, 32 assertions
docker compose run --rm platform-api php artisan test --filter=Security: PASS, 1 test, 11 assertions
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch: PASS, 2 tests, 81 assertions
docker compose run --rm platform-api php artisan test --filter=Customer: PASS, 7 tests, 196 assertions
docker compose run --rm platform-api php artisan test: PASS, 107 tests, 1856 assertions
```

## Acceptance Confirmed

Coordinator accepts QA confirmation that:

```text
M9 migration is additive and non-destructive
required M9 models, services, controllers, middleware, validators, docs, and tests exist
maintenance is tenant-scoped and not global
site-config remains HTTP 200 and exposes maintenance.active=true during active maintenance
blocked public/customer routes return maintenance_active 503 with Retry-After where applicable
maintenance bypass does not trust raw user-supplied bypass headers
support access is tenant-scoped and rejects cross-tenant targets
support impersonation sessions are short-lived and revocable
support token material is hashed at rest and not exposed after initial issuance
sensitive actions are blocked, audited, and outboxed for support impersonation
permissions and idempotency are enforced on M9 admin mutation paths
Docker runtime policy was followed
no customer UI, back-office UI, route-breaking, OpenAPI-envelope, permission, tenant-scope, or business-rule regression was found
```

## Accepted Residual Risks

Accepted as non-blocking for this backend gate:

```text
broad admin_only back-office route blocking is deferred pending coordinated back-office route decisions
support impersonation is intentionally not a broad customer/admin login bypass; this slice approves the conservative session/evidence/blocking foundation
workspace state remains broadly dirty/untracked from multi-agent work, so exact ownership cannot be proven from git status alone
```

## Out Of Scope

This approval does not approve:

```text
customer UI changes
back-office UI implementation
broad back-office route blocking implementation
external ticket system integration
real customer/admin login-as impersonation UX
password reset, 2FA, bank account, provider, queue/Horizon, or worker redesign
M10 deployment/monitoring/load-test implementation
```

## Impact

M9 backend foundation is now approved. The project can move to the next Coordinator decision.

Possible next paths:

```text
Back-office UI implementation for approved admin APIs
M10 Deployment, Monitoring, Load Test, Migration
```

Coordinator should choose the next path explicitly before Orchestrator creates more tasks.

## Date

```text
2026-05-07
```

## Next Agent

```text
Coordinator
```
