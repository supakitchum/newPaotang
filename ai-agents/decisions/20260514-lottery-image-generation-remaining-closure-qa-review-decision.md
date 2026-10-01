# Lottery Image Generation Remaining Closure QA Review Decision

Date: 2026-05-14
Owner: Coordinator
Task: `lottery-image-generation-remaining-closure`
Result: APPROVED AND EXPANDED

## Context

QA Tester completed focused backend QA for lottery image generation remaining closure.

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
```

Implementation under review:

```text
Backend implementation: 83881b1703a05b8fc476d627959a34bacc79b7be
Backend handoff: 70458f3
QA dispatch: 11f884c78c8f8b9daf19a3f21e886005eca3a362
```

## QA Result

QA result is PASS with no blocking findings.

Verified backend coverage includes:

```text
central-admin lottery image operations routes
background asset set registration/readiness behavior
odd/even/charity mix settings
pending asset retry API and command behavior
production storage/queue/runtime readiness output
GD/WebP runtime regression
existing lottery image, public stock, checkout, and partner branding regressions
OpenAPI YAML parse and endpoint/schema presence
credential/artifact scan
```

## Approved Scope

Coordinator approves the backend operations closure scope:

```text
GET /api/v1/admin/central/lottery-images/readiness
GET /api/v1/admin/central/lottery-images/background-asset-sets
PUT /api/v1/admin/central/lottery-images/background-asset-sets
PATCH /api/v1/admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET /api/v1/admin/central/lottery-images/mix
PUT /api/v1/admin/central/lottery-images/mix
POST /api/v1/admin/central/lottery-images/retry-pending
GET /api/v1/admin/central/lottery-images/production-readiness
```

No backend remediation is required for this QA slice.

## Expansion Decision

The current work pace is too small for the remaining surface area. Coordinator expands the next delivery phase into parallel workstreams.

Orchestrator must split the next phase into multiple independently-owned tasks instead of one narrow task:

```text
Lane A: BO lottery image operations management
Lane B: Customer/partner image display integration
Lane C: Production storage, queue, and deployment readiness closure
Lane D: End-to-end QA matrix and launch gate
```

Each lane must have its own task, handoff, validation requirements, and QA handoff. Agents may work in parallel when file ownership does not overlap.

## Lane A - BO Operations Management

Target agent:

```text
BO Develop
```

Scope:

```text
central lottery image readiness dashboard
background asset set list/create/update/retire workflow
upload/commit/select source/full/thumb platform assets
game-scoped odd/even/charity mix settings form
pending retry action with dry-run preview
production readiness panel with redacted storage/queue/runtime status
central-only route/menu/permission handling
empty/loading/error/locked/validation states
```

Required source API:

```text
GET/PUT/PATCH background-asset-sets
GET/PUT mix
GET readiness
POST retry-pending
GET production-readiness
POST central asset upload intent
POST central asset commit
```

## Lane B - Customer/Partner Image Display

Target agent:

```text
Customer Develop
```

Scope:

```text
show real image_url/image_thumb_url from public stock search
preserve image display through reservation/checkout/ticket surfaces
graceful fallback while image generation is pending_assets/failed/missing
avoid using central or partner branding management APIs from customer frontend
do API-driven validation first for any customer-sensitive CRUD or checkout path
```

This lane may start after Orchestrator confirms the current Customer API integration state and file ownership.

## Lane C - Production Ops Readiness

Target agent:

```text
Backend Develop
```

Scope:

```text
production-like S3/R2 configuration checklist
queue worker command/runbook readiness
readiness endpoint acceptance criteria for production_ready=true
safe credential redaction verification
object key/cache-control/CDN base URL verification
operator docs for retry, pending assets, and failure recovery
```

This lane must not commit real credentials.

## Lane D - End-To-End QA Launch Gate

Target agent:

```text
QA Tester
```

Scope after lanes A-C are ready:

```text
central uploads backgrounds
central sets mix
central generates stock images
pending assets stay pending until missing set types are ready
retry pending creates images after assets arrive
partner allocation/sync creates partner-branded images
public/customer stock and checkout surfaces show usable images
production readiness reports expected state under configured environment
```

## Next Agent

```text
Orchestrator
```

Orchestrator should create task briefs for all lanes and dispatch the first non-conflicting batch immediately.
