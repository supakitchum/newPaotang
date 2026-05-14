# Lottery Image Generation Expanded Delivery Coordinator Handoff

## Agent

Coordinator

## Task

Expand lottery image generation delivery after backend operations QA passed.

## Decision

Approved and expanded.

Decision file:

```text
ai-agents/decisions/20260514-lottery-image-generation-remaining-closure-qa-review-decision.md
```

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
```

QA artifacts:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-remaining-closure-qa/**
```

## Approved Backend Scope

Backend operations APIs and readiness behavior passed QA:

```text
readiness
background asset sets
mix settings
retry pending
production readiness
GD/WebP runtime regression
OpenAPI/docs coverage
security/permission/idempotency coverage
```

## User Direction

The user asked to make the work larger because the current pace is too slow.

```text
ช่วยขยายงานให้ใหญ่กว่านี้หน่อยตอนนี้ช้าเกิน
```

## Orchestrator Instruction

Create a larger next phase with multiple lane tasks. Do not dispatch a single small task.

Required lanes:

```text
Lane A: BO lottery image operations management
Lane B: Customer/partner image display integration
Lane C: Production storage, queue, and deployment readiness closure
Lane D: End-to-end QA launch gate
```

## Parallelization Guidance

Dispatch in parallel when file ownership is separate:

```text
BO Develop owns apps/back-office/** for Lane A
Customer Develop owns apps/customer/** for Lane B
Backend Develop owns docs/runtime/config/ops backend files for Lane C
QA Tester waits for relevant lane handoffs before launch-gate execution
```

Avoid overlapping writes to shared API docs unless Orchestrator assigns one lane as owner and others as readers.

## Lane A Acceptance

BO must provide central-only operations UI for:

```text
readiness dashboard
background asset set list/create/update/retire
source/full/thumb upload and commit
mix settings edit with sum-to-100 validation
retry pending dry-run and execute
production readiness redacted status
```

Validation should include real BO route workflow QA, not only build/lint/test.

## Lane B Acceptance

Customer must display backend image URLs in real user flows:

```text
stock search/list/card
reservation or checkout review
ticket/order confirmation surfaces if present
pending/missing/failed graceful fallback
```

Customer must not call central operations APIs.

## Lane C Acceptance

Backend/Ops must provide production-readiness closure without secrets:

```text
S3/R2/CDN config checklist
queue worker runbook
readiness endpoint expected production_ready=true criteria
failure/retry recovery runbook
redaction verification
```

## Lane D Acceptance

QA must validate the integrated journey:

```text
central background upload
mix setting
generation
pending/retry
partner-branded generation
customer image display
production readiness expected state
```

## Board Update

Set active task to:

```text
lottery-image-generation-expanded-delivery
```

## Next Agent

```text
Orchestrator
```
