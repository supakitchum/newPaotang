# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
m10-production-evidence-collection-before-final-qa
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | waiting_external_evidence | m10-production-evidence-collection-before-final-qa | ai-agents/handoffs/20260509-m10-production-evidence-collection-coordinator-handoff.md |
| Orchestrator | blocked | wait-for-production-evidence-before-final-qa | ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-blocked-coordinator-handoff.md |
| Backend Develop | blocked_external | m10-production-external-readiness-closure-before-bo | ai-agents/handoffs/20260509-m10-production-external-readiness-closure-before-bo-backend-handoff.md |
| BO Develop | deferred | phase-next-back-office-removed-from-main-plan | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | pending | evidence-verification-after-production-evidence | ai-agents/handoffs/20260509-m10-production-evidence-collection-coordinator-handoff.md |

## Open Questions

```text
User instructed to finish M10 before starting BO. Backend Develop completed production/external readiness classification in commit e1f28d4 and reported M10 cannot be finalized from workspace evidence. The active next step is Coordinator/Ops/User evidence collection using ops/m10/m10-production-evidence-request-list.md. Do not route final QA until redacted production evidence is available or the user explicitly accepts selected deferrals. Back-office work remains deferred; do not dispatch BO Develop and do not edit apps/back-office/**. Customer frontend is frozen unless Coordinator scopes a regression-only backend contract check. Backend-only local/dev deploy-readiness remains approved: OpenAPI/app route parity 279/279/0/0 and full backend Docker suite 152 tests / 4140 assertions.
```

## Latest Decision

```text
ai-agents/decisions/20260509-m10-production-evidence-collection-decision.md
```
