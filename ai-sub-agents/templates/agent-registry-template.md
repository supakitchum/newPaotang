# <Task Key> <Role> Agent Registry

## Agent

```text
task_key:
role:
agent_id:
previous_agent_ids:
agent_type:
spawn_generation:
spawn_control: auto | spawn_new:<agent>
spawned_at:
last_used_at:
status: WARMING | IDLE_READY | ASSIGNED | BLOCKED | STALE | CLOSED
```

## Context

```text
current trigger:
current task:
expected output:
source decision:
memory file:
retained context summary:
```

## Reuse

```text
reuse allowed: Yes/No
resume allowed: Yes/No
first spawn allowed automatically: Yes/No
spawn_new command:
replacement spawn allowed without user decision: No
replacement decision required: Yes/No
replacement decision path:
last send_input at:
last resume at:
last spawn_new at:
```

## Close

```text
closed_at:
close reason:
replacement agent id:
replacement reason:
replacement approved by:
```

## Spawn History

| Generation | Agent ID | Spawned At | Spawn Control | Close Status | Notes |
| --- | --- | --- | --- | --- | --- |
|  |  |  | auto/spawn_new:<agent> |  |  |
