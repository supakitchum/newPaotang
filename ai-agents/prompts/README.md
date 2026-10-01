# Agent Opening Prompts

ใช้ไฟล์เหล่านี้เป็น prompt แรกสำหรับเปิดแชท agent แยกตาม role

```text
open-chat-coordinator.md
open-chat-orchestrator.md
open-chat-backend-develop.md
open-chat-bo-develop.md
open-chat-customer-develop.md
open-chat-qa-tester.md
```

ลำดับแนะนำ:

```text
1. เปิด Coordinator ก่อน
2. ให้ Coordinator สรุปแผนและสั่ง Orchestrator
3. เปิด Orchestrator เพื่อแตกงานลง ai-agents/tasks
4. เปิด Backend Develop, BO Develop, Customer Develop ตาม task ที่ Orchestrator สร้าง
5. เปิด QA Tester เมื่อมี handoff จาก dev agent
6. ส่งผล QA กลับ Coordinator
```
