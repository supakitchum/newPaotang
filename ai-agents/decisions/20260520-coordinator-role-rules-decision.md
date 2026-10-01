# Coordinator Role And Agent Rules Decision

## Date

2026-05-20

## Decision

Coordinator returns to board/gatekeeping mode as the default operating mode.

Normal work must follow:

```text
Coordinator -> Orchestrator -> Worker Agent -> QA Tester -> Coordinator
```

Coordinator must not implement code, run runtime operations, run migration/seed/reset/build/test commands, or open background/subagent work unless the user explicitly says `Hotfix` in that same turn.

For normal work, Coordinator writes the instruction into board/decision/task documentation and marks `Next Agent: Orchestrator`. The user sends that instruction to the Orchestrator chat.

## Required Gates

Before dispatching any new work, Coordinator must:

```text
1. sync canonical worktree /Users/supakit/WorkSpace/www/newPaotang
2. verify branch and HEAD against origin/develop
3. commit and push completed approved/hotfix work
4. write latest branch and commit hash in the board/handoff
5. identify Next Agent as Orchestrator
```

Every agent must use the canonical worktree unless Coordinator explicitly assigns another path in writing.

## QA / DB Rule

Destructive DB commands are allowed only against `newpaotang_test` with:

```text
APP_ENV=testing
DB_DATABASE=newpaotang_test
--env=testing
```

Runtime DB `newpaotang` must not be wiped or used as disposable QA data. Runtime writes require explicit user approval in the same turn, except non-destructive smoke/seed commands that are specified by Coordinator for runtime login verification.

## Base Lottery Source

Virtual stock base numbers must use:

```text
apps/platform-api/storage/app/public/number.json
```

Future agents must not revert to a generated `000000-999999` base source or replace this file without a new Coordinator decision or explicit user instruction.

## Next Agent

None. This is a coordinator rules update only.
