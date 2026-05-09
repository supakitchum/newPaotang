# M10 Production Evidence Request List

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-production-external-readiness-closure-before-bo-backend
Status: Required external evidence is missing; M10 cannot be finalized yet.

## Boundary

This request list names the exact evidence needed to close M10 production/external readiness gates before any Back Office work resumes.

Do not place raw secrets, API tokens, private keys, bearer tokens, production customer data, database passwords, signed URLs, or sensitive production URLs in this repository. Evidence must be redacted and may reference secret-manager paths or provider artifact ids only.

## Accepted Evidence Formats

| Format | Rules |
| --- | --- |
| Redacted JSON | Booleans, ids, timestamps, status fields, and `[REDACTED]` placeholders only. |
| Secret-manager references | Reference names/paths only, no values. Include owner/system and rotation policy. |
| Runbook excerpt | Operator-approved excerpts without secrets or customer payloads. |
| Staging/production log summary | Timestamps, status, counts, and command names only; no payloads or credentials. |
| Provider readiness summary | Account/channel/provider status, webhook signature verification status, delivery status, and redacted ids. |
| Image/snapshot/release ids | Image tag/digest, snapshot ids, restore id, object metadata inventory id, and approval reference. |
| QA artifact summary | Docker command, environment name, threshold summary, pass/fail, and redacted inputs. |

## Evidence Requests

| Gate | Missing Evidence | Why It Blocks M10 Finalization | Expected Owner | Required Format | User Defer / Risk Decision |
| --- | --- | --- | --- | --- | --- |
| Horizon production supervision | Approved Horizon package/config, supervisors mapped to queue profiles, dashboard access policy, process manager, queue lag dashboard, restart/drain rehearsal | Current backend has only bounded local `queue:work --once`; no managed production queue supervision evidence | Coordinator/Ops | Redacted config summary, supervisor map, dashboard access policy, process manager reference, rehearsal notes | Can defer only if user accepts no Horizon production dashboard/supervision risk |
| Reverb production runtime | Reverb package/runtime profile, public websocket host, TLS, channel auth load test, scaling/pub-sub evidence, secret references | API auth endpoints exist, but no public websocket runtime is production-ready | Coordinator/Ops | Redacted runtime profile, TLS/public host verification, load-test summary, secret references | Can defer only if realtime public delivery is out of launch scope |
| Cloudflare account/zone/DNS/proxy | Account owner, zone owner, tenant DNS records, proxy enabled evidence per host | Public tenant launch requires Cloudflare/HTTPS path; local `.test` domains are not production evidence | Coordinator/Ops | Redacted Cloudflare zone summary and DNS/proxy verification table | Cannot claim public launch without this evidence |
| HTTPS/SSL enforcement | Full strict or equivalent origin cert evidence, HTTPS redirect sample, SSL readiness timestamps per custom domain | Plain HTTP/custom domain without SSL violates deployment rules | Coordinator/Ops | Redacted SSL mode/cert summary, redirect sample, domain readiness timestamps | Cannot claim public launch without this evidence |
| WAF/rate-limit/cache deployment | Deployed Cloudflare WAF/rate-limit/cache-bypass rule ids and sample checks | Current JSON files are templates only, not deployed rules | Coordinator/Ops | Redacted rule id list and sampled decision logs | Can defer only if user accepts edge protection/cache risk |
| R2/object storage | R2 bucket, endpoint, access policy, lifecycle, object verification, CDN policy | Ticket images must not be served by Laravel per request in production | Coordinator/Ops | Redacted R2/CDN readiness JSON, bucket policy summary, lifecycle summary | Cannot claim ticket-image production delivery without this evidence |
| Ticket-image CDN path | `CDN_BASE_URL` plus `IMAGE_PATH` or `TICKET_IMAGE_CDN_IMAGE_PATH` returning 200 through CDN/R2 with cache headers | k6 ticket-image scenario cannot run honestly without real CDN/object path | Coordinator/Ops / QA Tester | Redacted CDN host, redacted object path, HTTP 200/cache-control sample, k6 summary | Can defer only if ticket images are explicitly out of launch scope |
| Release-candidate k6 run | Approved target, redacted env, thresholds, summary artifacts for API scenarios and CDN scenario when in scope | Local fixture prep/script inspect is not production-equivalent performance evidence | QA Tester / Coordinator-Ops | Docker k6 command summary, threshold summary JSON, redacted inputs | Defer requires user acceptance of performance risk |
| Mail/password reset delivery | Provider account, sender policy, secret owner/reference, reset-link delivery QA | Admin password reset exists locally but cannot deliver production email | Coordinator/Ops | Provider readiness summary, secret refs, delivery QA summary | Can defer only if password reset delivery is not required for launch |
| Payment/topup providers | Provider activation credentials, webhook signature samples, callback URLs, settlement/reconciliation policy | Real payment/topup money movement cannot be approved from local stubs/contracts | Coordinator/Ops/Finance | Redacted provider readiness JSON, signature verification sample, reconciliation runbook | Cannot launch real payments without this evidence |
| LINE auth provider | LINE channel credentials reference, callback URL, token exchange evidence, account-linking/error policy | LINE routes are guarded locally but provider success is not implemented/verified with real credentials | Coordinator/Ops | Redacted LINE channel summary, callback verification, token exchange test summary | Can defer only if LINE login is explicitly out of launch scope |
| Production secret manager | Approved secret manager system/owner and references for app, provider, migration, R2/CDN, Reverb, Cloudflare | Committed placeholders are not secret management; raw secrets cannot be committed | Coordinator/Ops/Security | Secret-manager reference list with owner and rotation policy, no values | Cannot finalize production without external secret ownership |
| Old-data source inventory | Source systems, categories, tenant/partner identity mapping, credentials owner, reject policy signoff | Migration cannot be approved without knowing source data and mapping rules | Coordinator/Ops/Product | Redacted inventory and signed mapping summary | Defer requires user acceptance that migration is out of current release |
| Database snapshot/restore | Snapshot id, restore proof, migration version, post-restore health/smoke/readiness | Cutover/rollback cannot be safe without restore rehearsal | Coordinator/Ops | Snapshot id, restore run summary, post-restore command summary | Cannot approve migration/cutover without this evidence |
| Object-storage metadata snapshot | Ticket image key inventory, variants, prefix ownership, CDN metadata, repair plan | Ticket image/object rollback and migration cannot be verified | Coordinator/Ops | Metadata inventory id and summary counts; no signed URLs | Cannot approve ticket-image migration/rollback without evidence |
| Staging rehearsal | Staging dry-run/import/reject counts, smoke/readiness, Cloudflare/CDN/R2 checks | Local synthetic fixtures do not prove real environment readiness | Coordinator/Ops/QA Tester | Rehearsal log summary, reject counts, command list, approval reference | Defer requires explicit no-staging risk acceptance |
| Cutover | Release image tag/digest, cutover window approval, queue drain plan, abort criteria, monitoring checkpoint | No production change can proceed without image/window/drain/abort evidence | Coordinator/Ops | Release digest, approved window reference, queue plan, abort checklist | Cannot finalize release without this evidence |
| Rollback | Previous image tag/digest, DB compatibility note, rollback drill, object-storage repair plan, post-rollback checks | Release cannot be considered safe without rollback path | Coordinator/Ops | Previous digest, compatibility note, drill summary, smoke/readiness summary | Cannot finalize release without this evidence |
| QA after closure | QA report after all external evidence is supplied or deferrals are accepted | Current QA only approves backend local/dev deploy-readiness | QA Tester | QA report referencing evidence files and Docker validation | Required before Coordinator final decision |
| Coordinator final M10 decision | Explicit approval, accepted deferrals if any, Gate 5 instruction | Worker agent cannot approve final release or Gate 5 | Coordinator/User | Decision file and handoff | Required |
| Git boundary push | Commit/push evidence after Coordinator approval | Stage Gate 5 requires approved scope commit/push before BO phase | Coordinator/Orchestrator | Commit hash, branch, push result | Required before BO phase begins unless user overrides in writing |

## Current Evidence Found Locally

```text
backend full suite: 152 tests / 4140 assertions
route:list: 284 Laravel routes shown
OpenAPI/app parity: previously QA-confirmed 279 / 279 / 0 / 0
platform:smoke: passed after reseed
platform:runtime:readiness: blocked_external for Horizon/Reverb; queue/scheduler ready_local
platform:observability:report: ready_local
platform:alerts:check --dry-run: ok; no external delivery attempted
platform:cloudflare:readiness: blocked_external for Cloudflare/CDN/R2 prerequisites
platform:migration:rehearsal --dry-run: blocked_external for snapshots/cutover/rollback/secrets/old-data source
schedule:list: five scheduled workloads shown
queue:work --once: passed
load-tests:k6:prepare: passed for local/dev fixtures
k6 ticket-image-cdn-spike inspect: passed
```

## Current Evidence Not Found

```text
real Cloudflare account/zone/proxy/SSL/HTTPS evidence
real deployed Cloudflare WAF/rate-limit/cache rule evidence
real R2 bucket/object/CDN ticket-image evidence
real production-equivalent k6 summary
real mail provider delivery evidence
real payment/topup provider activation and webhook signature evidence
real LINE provider token exchange/account-linking evidence
approved external secret-manager references
real old-data source inventory and mapping signoff
real database snapshot and restore rehearsal evidence
real object-storage metadata snapshot evidence
staging rehearsal evidence
release image tag/digest and cutover approval
previous image tag/digest and rollback drill evidence
Coordinator final M10 decision
Gate 5 commit/push approval
```

## Conclusion

M10 cannot be finalized from the current workspace evidence. The next step is Coordinator/Ops/user evidence collection or explicit user acceptance of selected deferrals, followed by QA and Coordinator final decision.
