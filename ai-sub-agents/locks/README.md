# Locks

Lock files protect shared files from parallel edits.

Naming:

```text
YYYYMMDD-<task-key>-<agent>-lock.md
```

Use locks for shared `apps/back-office/**` files or any file Orchestrator marks as shared risk.

Status values:

```text
LOCKED
RELEASED
BLOCKED
```
