# Orchestrator Task Template

ใช้ไฟล์นี้เป็น template เมื่อ Orchestrator แตกงานให้ agent อื่น ให้ copy โครงสร้างด้านล่างไปสร้างไฟล์ใหม่ใน `ai-agents/tasks/`

# <Task Key> - <Target Agent>

## Target Agent

Backend Develop | BO Develop | Customer Develop | QA Tester

## Coordinator Instruction

<สรุปคำสั่งจาก Coordinator>

## Objective

<เป้าหมายที่ต้องทำให้เสร็จ>

## Source Of Truth

- docs/openapi.yaml
- <เพิ่มไฟล์ที่เกี่ยวข้อง>

## Scope

<สิ่งที่ต้องทำ>

## Out Of Scope

<สิ่งที่ห้ามทำ>

## File Ownership

Can edit:

```text
<path>
```

Must not edit:

```text
<path>
```

## Required Steps

1. <step>
2. <step>
3. <step>

## Acceptance Criteria

- <criteria>
- <criteria>

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

```sh
docker compose exec <service> <command>
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
next agent
```
