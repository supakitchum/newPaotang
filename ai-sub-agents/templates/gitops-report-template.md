# <Task Key> GitOps Report

## Agent

```text
GitOps
```

## Coordinator Approval

```text
approval decision file:
approved scope:
QA report:
```

## Worktree / HEAD Before

```text
worktree:
branch:
start gate commands run:
HEAD:
origin/develop:
git status --short --branch:
dirty files before GitOps:
```

## Trigger Status

```text
trigger file:
status before GitOps:
status after GitOps:
status owner:
requested final status:
runner claim file:
heartbeat file:
```

## Commit / Push

```text
files staged:
commit hash:
commit message:
push target:
push result:
```

## Failure After Commit

```text
failure after local commit: Yes/No
failed command:
commit hash retained as evidence:
Coordinator decision required:
reset/revert/amend performed by GitOps: No
```

## Local Runtime DB Update

```text
DB update required: Yes/No
migration command:
result:
destructive command used: No
```

## Smoke Check

```text
commands:
result:
```

## Memory Updates

```text
memory file read:
memory file updated: Yes/No
summary:
```

## Final Worktree State

```text
git status --short --branch:
unrelated dirty files:
dirty files after GitOps:
```

## Blockers

## Next Agent

```text
Coordinator
```
