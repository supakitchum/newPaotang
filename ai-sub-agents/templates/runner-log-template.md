# <Task Key> Runner Log

## Trigger

```text
trigger file:
target agent:
execution mode:
```

## Runner

```text
runner_id:
claim file:
heartbeat file:
agent registry:
```

## Dependency Check

```text
depends_on:
blocking_outputs:
result:
```

## Status Transitions

```text
PENDING -> RUNNING:
RUNNING -> DONE/BLOCKED:
```

## Spawn

```text
spawn tool:
agent id:
reuse decision:
resume decision:
spawn control command:
replacement spawn decision:
old agent id:
new agent id:
spawn prompt template:
```

## Polling

```text
poll interval seconds:
poll timestamps:
expected output path:
output found at:
protocol validation result:
```

## Output Validation

```text
expected output:
exists: Yes/No
protocol sections present: Yes/No
requested final status:
```

## Blocker / Timeout

```text
blocked: Yes/No
timeout: Yes/No
reason:
next agent:
```
