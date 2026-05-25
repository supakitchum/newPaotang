# Worktree Start Gate

ทุก agent ต้องผ่าน worktree start gate ก่อนเริ่มงานที่ได้รับ

## Canonical Worktree

```text
/Users/supakit/WorkSpace/www/newPaotang
```

## Required Commands

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git status --short
git rev-parse HEAD
git rev-parse origin/develop
```

## Pass Conditions

```text
current path is canonical worktree
current branch is the branch required by task or develop by default
fast-forward merge succeeds
HEAD is current for the required base
dirty files are understood and classified before work starts
```

## Dirty Worktree Policy

ถ้า `git status --short` มีไฟล์ค้างก่อนเริ่มงาน:

```text
files outside task scope: record as unrelated dirty files and do not touch
files inside task scope but not created by current agent/task: stop and send blocker to Coordinator
untracked ai-sub-agents files for current task: allowed only if they are task/trigger/handoff/report/memory files owned by the current agent
unknown ownership: stop and ask Orchestrator/Coordinator
```

## Failure Policy

ถ้า command ใด fail:

```text
stop immediately
do not edit files
write blocker handoff/report
include command output summary
Next Agent: Coordinator
```

## Required Evidence

ทุก handoff/report ต้องบันทึก:

```text
worktree path
branch
start gate commands run
HEAD
origin/develop
dirty files before work
dirty files after work
```
