# M10 Backend Deploy Ready Blocker Matrix

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-backend-only-deploy-ready-closeout-backend
Status: Backend local/dev deploy-readiness ready for QA; production blocked externally.

## Boundary

This matrix records backend-only deploy-readiness blockers for `apps/platform-api`. It is not a staging, production, client-delivery, Gate 5, or final release approval.

## Blocker Matrix

| Gate | Local/dev status | Production blocker | Required external evidence | Owner |
| --- | --- | --- | --- | --- |
| OpenAPI/app route parity | ready_local | None for backend parity | QA reconfirms 279/279/0/0 from Docker route JSON | QA Tester |
| Backend full suite | ready_local | None for local suite | QA reruns full Docker suite | QA Tester |
| Permission and tenant isolation | ready_local | None for backend-local enforcement | QA samples central, tenant, customer, partner-sync, support impersonation boundaries | QA Tester |
| Models/migrations/seeders | ready_local | destructive commands are local/test only | production migration plan and approved seed/first-admin policy | Coordinator/Ops |
| Request validation | ready_local | None for current backend scope | QA regression for validation-before-mutation/idempotency | QA Tester |
| Idempotency and audit | ready_local | None for current backend scope | QA verifies no raw secret persistence and conflict behavior | QA Tester |
| Outbox/inbox | ready_local | production worker supervision and replay runbooks | queue supervision, dead-letter handling, retry dashboards | Coordinator/Ops |
| Queue worker profiles | ready_local | production process manager/Horizon missing | managed worker profiles, queue lag dashboard, restart/drain evidence | Coordinator/Ops |
| Scheduler | ready_local | scheduler leader/SLO missing | single leader policy, production locks, missed schedule alerts | Coordinator/Ops |
| Horizon | blocked_external | package/config/supervisors/dashboard policy missing | approved Horizon package/config, access controls, process manager, queue dashboards | Coordinator/Ops |
| Reverb | blocked_external | package/runtime/TLS/public host/scaling missing | approved Reverb runtime, TLS host, auth load test, scaling evidence, secret manager | Coordinator/Ops |
| Backend Docker image | ready_local_with_external_supervision_blocker | production web server/process supervision not approved | image digest, process manager/orchestration config, runtime health policy | Coordinator/Ops |
| Smoke/readiness | ready_local | production seed-login behavior must be disabled or separately approved | production-safe smoke profile and credentials policy | Coordinator/Ops |
| Observability report | ready_local_with_external_followups | external APM/edge/CDN signals missing | Sentry/Grafana/Datadog/New Relic or approved equivalent; Cloudflare analytics | Coordinator/Ops |
| Alert channels | ready_local_with_external_followups | external delivery not configured | webhook/email/contact-point credentials, retry policy, delivery QA | Coordinator/Ops |
| Cloudflare DNS/proxy | blocked_external | account, zone, token, DNS/proxy evidence missing | zone ownership, DNS records, proxy enabled evidence per tenant host | Coordinator/Ops |
| HTTPS/SSL | blocked_external | SSL and HTTPS enforcement evidence missing | Full strict or equivalent origin cert, HTTPS redirect sample, domain readiness timestamps | Coordinator/Ops |
| WAF/rate-limit/cache | blocked_external | templates only, not deployed | deployed WAF/rate-limit/cache-bypass rules with sampled evidence | Coordinator/Ops |
| R2/object storage | blocked_external | endpoint, bucket, credentials, bucket policy missing | R2 bucket, endpoint, access policy, lifecycle, object verification | Coordinator/Ops |
| Ticket-image CDN | blocked_external | real CDN base URL and image path missing | `CDN_BASE_URL` and `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` returning 200 through CDN/R2 | Coordinator/Ops |
| k6 baseline scripts | ready_local_with_external_cdn_blocker | measured release-candidate run missing | Docker k6 run artifacts and thresholds from approved environment | QA Tester / Coordinator-Ops |
| Mail/password reset delivery | blocked_external | provider credentials/delivery policy missing | approved provider, secret owner, deliverability and reset-link policy | Coordinator/Ops |
| Payment/topup providers | blocked_external | provider activation credentials missing | provider credentials, webhook signatures, reconciliation, settlement policy | Coordinator/Ops |
| LINE auth | blocked_external | credentials/callback/token exchange/account-linking policy missing | LINE channel credentials, callback URL, token exchange, account-linking/error policy | Coordinator/Ops |
| Production secret manager | blocked_external | approved external secret store missing | secret owner/system, references for app, providers, migration, object storage | Coordinator/Ops |
| Old-data migration | blocked_external | real old-data source inventory and credentials missing | source inventory, mapping signoff, reject report policy, dry-run from snapshot | Coordinator/Ops |
| Database snapshots | blocked_external | real snapshot and restore rehearsal missing | snapshot id, restore proof, migration version, health/smoke after restore | Coordinator/Ops |
| Object-storage snapshots | blocked_external | metadata snapshot missing | ticket image key inventory, CDN policy metadata, prefix ownership map | Coordinator/Ops |
| Staging rehearsal | blocked_external | not executed | staging rehearsal log, reject counts, smoke/readiness evidence | Coordinator/Ops |
| Cutover | blocked_external | release tag/window/monitoring evidence missing | release image tag/digest, cutover window approval, queue drain plan, abort criteria | Coordinator/Ops |
| Rollback | blocked_external | previous tag and rollback drill missing | previous image tag/digest, backward compatibility note, rollback rehearsal evidence | Coordinator/Ops |
| Gate 5/final release | not_triggered | Coordinator approval required after blockers close | Coordinator decision, QA report, git boundary, push/release evidence | Coordinator/Orchestrator |

## External Blocker Summary

The backend package is ready for QA as a local/dev deploy-readiness closeout, but production remains blocked on:

```text
Horizon production supervision
Reverb production websocket runtime
Cloudflare DNS/proxy/SSL/HTTPS/WAF/cache evidence
R2/CDN ticket-image delivery and measured image load test
mail provider credentials and delivery policy
payment/topup provider credentials, signatures, settlement, and reconciliation
LINE credentials, callback, token exchange, and account-linking policy
production secret manager ownership and references
real old-data migration source and mapping signoff
database/object-storage snapshots and restore rehearsal
staging rehearsal
cutover and rollback drill evidence
Gate 5/final release approval
```

## Local Evidence Already Collected

```text
Full backend suite: 152 tests, 4140 assertions
OpenAPI/app route parity: 279/279/0/0
route:list: 284 Laravel routes shown
platform:smoke: passed after reseed
platform:runtime:readiness: passed with Horizon/Reverb external blockers
platform:observability:report: ready_local
platform:alerts:check --dry-run: ok
platform:cloudflare:readiness: blocked_external with redacted config and explicit blockers
platform:migration:rehearsal --dry-run: blocked_external with local strategy/fixtures ready
load-tests:k6:prepare: passed
Docker k6 inspect: passed for local scenario scripts and ticket-image CDN script
Focused M10 readiness tests: passed
```

## Not Approved

```text
staging deployment
production deployment
client delivery
Cloudflare/R2 activation
mail/payment/LINE provider activation
real migration/cutover/rollback
Gate 5
final M10 release
```
