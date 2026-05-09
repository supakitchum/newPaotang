# M10 Production Evidence Collection Decision

Date: 2026-05-09
Agent: Coordinator

## Context

The user asked where to go next after the `m10-production-external-readiness-closure-before-bo` report.

Backend Develop completed the evidence classification package and reported:

```text
M10 cannot be finalized from the current workspace evidence.
Backend local/dev deploy-readiness remains validated.
Production/external gates still need real redacted evidence or explicit Coordinator/user risk acceptance.
```

The latest Backend commit is:

```text
e1f28d4 m10-production-external-readiness-closure-before-bo: record release evidence blockers
```

## Decision

The next path is production/external evidence collection.

Do not defer production gates yet. Do not start Back Office yet. Do not route final QA yet.

Current active task:

```text
m10-production-evidence-collection-before-final-qa
```

The team must collect redacted evidence for the blockers listed in:

```text
ops/m10/m10-production-evidence-request-list.md
```

After evidence is provided, Orchestrator must create a QA evidence-verification task. If evidence cannot be provided for a gate, Coordinator must ask the user for an explicit defer/risk acceptance decision before QA.

## Required Evidence Groups

Collect redacted evidence for:

```text
Horizon production supervision and dashboard access policy
Reverb production runtime, TLS/public host, auth load, and scaling evidence
Cloudflare DNS/proxy/SSL/HTTPS/WAF/cache deployment evidence
R2/object-storage and ticket-image CDN delivery evidence
production-equivalent k6 run evidence
mail provider credentials, secret owner, reset-link delivery evidence
payment/topup provider activation, webhook signatures, settlement, and reconciliation evidence
LINE channel credentials, callback URL, token exchange, account-linking, and error policy evidence
approved production secret-manager owner/system/references
real old-data source inventory and migration mapping signoff
database and object-storage snapshot/restore evidence
staging rehearsal evidence
cutover release image/window/queue drain/abort/monitoring evidence
rollback previous image/DB compatibility/drill/object repair evidence
```

## Evidence Rules

Allowed:

```text
redacted JSON
secret-manager reference names or paths without values
operator-approved runbook excerpts
staging/production log summaries without secrets or payloads
provider readiness summaries with redacted ids
image tags/digests, snapshot ids, restore ids, approval references
QA artifact summaries with redacted inputs
```

Forbidden:

```text
raw secrets
API tokens
private keys
bearer tokens
database passwords
production customer data
signed URLs
sensitive production URLs
fabricated provider success
fabricated production readiness
```

## Frozen Scope

```text
Do not dispatch BO Develop.
Do not edit apps/back-office/**.
Do not edit apps/customer/** unless Coordinator explicitly scopes a regression-only backend contract check.
Do not claim M10 final completion until QA verifies the collected evidence and Coordinator writes a final M10 decision.
```

## Next Agent

Coordinator/Ops/User evidence collection, then Orchestrator after evidence is available.

