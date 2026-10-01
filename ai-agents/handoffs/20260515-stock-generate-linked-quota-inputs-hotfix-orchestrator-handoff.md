# Stock Generate Linked Quota Inputs Hotfix Orchestrator Handoff

## Agent

Orchestrator

## Task

Break down Coordinator instruction:

```text
stock-generate-linked-quota-inputs-hotfix
```

## What Was Done

Created task briefs in Coordinator-required order:

```text
1. BO Develop - stock-generate-linked-quota-inputs-hotfix-bo
2. QA Tester - stock-generate-linked-quota-inputs-hotfix-qa
```

Backend was not dispatched because Coordinator explicitly expects a BO-only hotfix unless BO discovers that the current backend/list API lacks a reliable current draw/current game marker.

## Files Changed

```text
ai-agents/tasks/20260515-stock-generate-linked-quota-inputs-hotfix-bo.md
ai-agents/tasks/20260515-stock-generate-linked-quota-inputs-hotfix-qa.md
ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-orchestrator-handoff.md
ai-agents/BOARD.md
```

No application implementation files were changed by Orchestrator.

## Validation

Orchestrator-only validation:

```text
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
read ai-agents/BOARD.md
read ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-decision.md
read ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-coordinator-handoff.md
read docs/docker-runtime-policy.md
confirmed Docker-only validation commands are written in each task
confirmed QA task includes test database isolation and runtime restore/login smoke requirements
```

No app test/build command was run because Orchestrator must not implement or validate app code directly.

## Known Risks

```text
If BO cannot identify a reliable current draw/current game marker, BO must stop and handoff blocker to Orchestrator before QA.
QA must validate real authenticated BO behavior, not only static checks.
QA must use newpaotang_test for destructive DB commands and must not wipe runtime DB newpaotang.
```

## Questions For Coordinator

```text
None
```

## Next Agent

```text
BO Develop
```
