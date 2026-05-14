# Lottery Image Generation Remaining Closure QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch QA Tester for:

```text
lottery-image-generation-remaining-closure
```

## Source

Backend handoff:

```text
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
```

Backend commits:

```text
83881b1703a05b8fc476d627959a34bacc79b7be
70458f3
```

Coordinator source:

```text
ai-agents/decisions/20260514-lottery-image-runtime-visual-composition-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-qa-review-coordinator-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260514-lottery-image-generation-remaining-closure-qa.md
```

No application implementation code was changed by Orchestrator.

## Backend Completion Summary

Backend reported implementation of:

```text
central-admin lottery image operations APIs
background asset set readiness management
game-scoped odd/even/charity mix settings
pending_assets retry API and command behavior
production object storage readiness with secrets redacted
queue/worker readiness
OpenAPI, ERD, lottery image docs, and backend console command docs
focused backend tests
```

New endpoints to validate:

```text
GET   /api/v1/admin/central/lottery-images/readiness
GET   /api/v1/admin/central/lottery-images/background-asset-sets
PUT   /api/v1/admin/central/lottery-images/background-asset-sets
PATCH /api/v1/admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET   /api/v1/admin/central/lottery-images/mix
PUT   /api/v1/admin/central/lottery-images/mix
POST  /api/v1/admin/central/lottery-images/retry-pending
GET   /api/v1/admin/central/lottery-images/production-readiness
```

## QA Focus

QA should verify:

```text
central-only security and tenant rejection
permission and Idempotency-Key enforcement
background asset validation/readiness
mix setting persistence and sum-to-100 validation
generation using persisted mix settings
pending_assets no-fallback behavior
retry behavior for central and partner pending rows
production readiness secret redaction
queue readiness details
GD/WebP runtime regression safety
existing lottery image, stock propagation, checkout, and public stock regressions
OpenAPI and docs correctness
credential/artifact scan
```

## Guardrails

```text
Do not edit apps/back-office/**
Do not edit apps/customer/**
Do not implement fixes in QA
Do not use real production S3/R2/CDN credentials
Do not expose secret values in QA artifacts
Do not mark the full product/ops scope closed
Use Docker-only application runtime commands
```

## Workspace Note

The shared worktree may contain unrelated dirty/untracked files from other agents.

QA must avoid cleaning, reverting, overwriting, staging, or committing unrelated files.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## QA Report Expected

```text
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
```

If artifacts are created:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-remaining-closure-qa/
```

## Next Agent

QA Tester
