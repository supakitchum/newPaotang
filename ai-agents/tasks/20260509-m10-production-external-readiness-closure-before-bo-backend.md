# m10-production-external-readiness-closure-before-bo - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

The user instructed:

```text
finish M10 before starting Back Office
```

Coordinator recorded:

```text
ai-agents/decisions/20260509-m10-finish-before-bo-decision.md
ai-agents/handoffs/20260509-m10-finish-before-bo-coordinator-handoff.md
```

Open task:

```text
m10-production-external-readiness-closure-before-bo
```

Back Office remains deferred. Do not edit BO. Customer frontend remains frozen.

## Objective

Attempt to close M10 production/external readiness gates using real evidence. If real external evidence is unavailable, do not fabricate readiness; produce an exact blocker handoff with owners and evidence needed.

The handoff must clearly state one of:

```text
M10 can proceed to QA/final Coordinator decision
or
M10 cannot be finalized because these exact external evidence items are missing
```

## Source Of Truth

- `ai-agents/decisions/20260509-m10-finish-before-bo-decision.md`
- `ai-agents/handoffs/20260509-m10-finish-before-bo-coordinator-handoff.md`
- `ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md`
- `ai-agents/reports/20260509-m10-backend-only-deploy-ready-closeout-qa-report.md`
- `ai-agents/handoffs/20260509-m10-backend-only-deploy-ready-closeout-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/m10-backend-deploy-ready-closeout.md`
- `docs/m10-deployment-monitoring-load-test.md`
- `document/11_DEPLOYMENT_WHITE_LABEL.md`
- `ops/m10/backend-deploy-ready-blocker-matrix.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ops/m10/runtime-readiness.md`
- `ops/m10/runtime-hardening-readiness.md`
- `ops/m10/horizon-queue-supervision.md`
- `ops/m10/reverb-deployment-readiness.md`
- `ops/m10/cloudflare-https-waf-cdn-r2-readiness.md`
- `ops/m10/cloudflare-waf-rate-limit-rules.json`
- `ops/m10/cloudflare-cache-bypass-rules.json`
- `ops/m10/r2-ticket-image-strategy.md`
- `ops/m10/ticket-image-cdn-load-test-runbook.md`
- `ops/m10/production-secret-boundary.md`
- `ops/m10/observability-signal-inventory.md`
- `ops/m10/alert-channel-runbook.md`
- `ops/m10/old-data-migration-strategy.md`
- `ops/m10/migration-rehearsal-runbook.md`
- `ops/m10/migration-rehearsal-fixtures.md`
- `ops/m10/snapshot-requirements.md`
- `ops/m10/cutover-runbook.md`
- `ops/m10/rollback-drill-runbook.md`
- `apps/platform-api/**`
- `scripts/platform-*.sh`
- `load-tests/k6/**`

## Scope

Production/external readiness gate closure before BO.

Gates to close or leave explicitly blocked:

```text
Horizon production supervision and dashboard access policy
Reverb production runtime, TLS/public host, auth, and scaling evidence
Cloudflare DNS/proxy/SSL/HTTPS/WAF/cache evidence
R2/CDN ticket-image delivery evidence and measured image path readiness
mail provider credentials, secret ownership, and delivery policy
payment/topup provider credentials, webhook signatures, settlement, and reconciliation policy
LINE credentials, callback URL, token exchange, account-linking, and error policy
production secret-manager owner/system and non-committed secret references
real old-data source inventory and migration mapping signoff
database and object-storage snapshot/restore rehearsal evidence
staging rehearsal evidence
cutover window, release image tag/digest, queue drain plan, and abort criteria
rollback previous image tag/digest, backward compatibility note, and rollback drill evidence
release-gate ledger update
```

Expected outputs:

```text
ops/m10/backend-release-gate-ledger.md
ops/m10/backend-deploy-ready-blocker-matrix.md
ops/m10/m10-production-evidence-request-list.md
ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md
```

Use existing docs if already sufficient; otherwise update/create narrowly.

## Evidence Rules

Allowed evidence:

```text
Docker command output from this workspace
redacted provider readiness JSON
redacted secret-manager reference names
redacted Cloudflare/R2/CDN configuration presence evidence
staging rehearsal logs without secrets/customer payloads
release image tag/digest references
snapshot ids or restore evidence with no sensitive payloads
operator-approved runbook excerpts
```

Forbidden:

```text
raw secrets, tokens, API keys, private keys, bearer tokens, database passwords
production customer data
raw production URLs if sensitive
fake provider success
fabricated screenshots/logs/evidence
claims of production readiness without evidence
```

If evidence is unavailable, record:

```text
gate
missing evidence
why it blocks M10 finalization
expected owner
exact evidence format needed
whether user can explicitly defer/accept risk
```

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not dispatch BO Develop.
- Do not perform BO page/menu/visual/build/dependency/license/npm audit/deploy work.
- Do not change customer frontend flow.
- Do not change API paths, methods, schemas, or response semantics without Coordinator approval.
- Do not implement provider integrations unless already safely scoped and evidence-backed.
- Do not claim staging, production, client delivery, external secret management, Cloudflare/R2 readiness, mail/payment/LINE readiness, migration success, cutover, rollback, Gate 5, final M10 release, or new milestone approval without evidence.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, k6, build, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ops/m10/backend-release-gate-ledger.md
ops/m10/backend-deploy-ready-blocker-matrix.md
ops/m10/m10-production-evidence-request-list.md
docs/m10-backend-deploy-ready-closeout.md
docs/m10-deployment-monitoring-load-test.md
ops/m10/runtime-readiness.md
ops/m10/cloudflare-https-waf-cdn-r2-readiness.md
ops/m10/r2-ticket-image-strategy.md
ops/m10/production-secret-boundary.md
ops/m10/migration-rehearsal-runbook.md
ops/m10/cutover-runbook.md
ops/m10/rollback-drill-runbook.md
ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
apps/platform-api/** unless Coordinator approval is required and documented as a blocker instead
docs/openapi.yaml
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy and Code Agent Commit Rule.
3. Inspect `git status --short` before editing and preserve unrelated dirty changes.
4. Start from `ops/m10/backend-deploy-ready-blocker-matrix.md` and classify each gate:

```text
closed_with_evidence
ready_local_only
blocked_external
blocked_user_decision
defer_candidate_requires_user_acceptance
```

5. Search workspace for any real redacted external evidence already present. Do not infer evidence from placeholders.
6. Run Docker-only readiness commands to refresh local/dev evidence.
7. Update release-gate ledger and blocker matrix with closed/open evidence.
8. Create `ops/m10/m10-production-evidence-request-list.md` for all missing external evidence.
9. If all required evidence exists, state M10 can proceed to QA/final Coordinator review.
10. If evidence is missing, state M10 cannot be finalized and list exact blockers.
11. Confirm no BO/customer files were edited.
12. Stage and commit only this task scope after validation passes, following the Code Agent Commit Rule.
13. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- No BO/customer files are edited.
- No raw secrets or sensitive production data are committed or copied into handoff/docs.
- Every M10 finish criterion from Coordinator decision is classified.
- Release-gate ledger and blocker matrix are updated.
- Evidence request list exists for missing external blockers.
- Handoff clearly states whether M10 can be finalized or exactly why not.
- Backend Develop commits scoped changes after validation and records commit hash in handoff.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan/k6 commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend/external-readiness validation:

```sh
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose exec -T platform-api php artisan platform:smoke
docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json
docker compose exec -T platform-api php artisan platform:observability:report --format=json
docker compose exec -T platform-api php artisan platform:alerts:check --dry-run --format=json
docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json
docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan schedule:list
docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default
```

Optional Docker-only k6 evidence if environment is available:

```sh
docker compose run --rm platform-api php artisan load-tests:k6:prepare --base-url=http://host.docker.internal:8000 --tenant-host=k6-alpha.newpaotang.test
docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js
```

If production-equivalent target, CDN URL, or image path is unavailable, document blocker rather than running fake production k6.

Read-only host static review commands are allowed:

```sh
git status --short
rg -n "blocked_external|ready_local|production_approved|secret|Cloudflare|R2|CDN|Horizon|Reverb|mail|payment|LINE|snapshot|staging|cutover|rollback|Gate 5|final release" docs ops ai-agents/decisions ai-agents/handoffs
rg -n "CLOUDFLARE|R2_|CDN_|LINE_|MAIL_|PAYMENT|SECRET|TOKEN|PASSWORD|PRIVATE" . --glob '!vendor/**' --glob '!node_modules/**' --glob '!apps/back-office/**' --glob '!apps/customer/**'
```

Commit commands after validation:

```sh
git status --short
git add <scoped files only>
git commit -m "m10-production-external-readiness-closure-before-bo: record release evidence blockers"
git status --short
```

Do not push unless Coordinator or user explicitly asks in this task. Record commit hash in handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md
```

Must include:

```text
status: Ready for QA, or Blocked external evidence, or Coordinator/user decision required
commit hash
files changed and committed
unrelated dirty files left untouched
gate classification table
closed evidence list
open blocker list
production evidence request list summary
Docker validation commands and results
whether M10 can be finalized
known risks/not approved
next agent
```

Set next agent to:

```text
Orchestrator
```
