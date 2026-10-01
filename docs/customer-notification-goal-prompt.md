# Customer Notification Goal Prompt

Use the following prompt to start the implementation goal:

```text
/goal Goal:
ทำระบบ Customer Notification Inbox + Native Push ให้เสร็จพร้อมใช้งานจริงบน Flutter Web, iOS, Android และ Back Office โดยยึดแผนหลักที่ docs/customer-notification-inbox-native-push-plan.md

โปรเจกต์:
- Root: /Users/supakit/WorkSpace/www/newPaotang
- Branch: develop
- Flutter customer: apps/customer_flutter
- Backend API: apps/platform-api
- Back Office: apps/back-office
- แผนหลัก: docs/customer-notification-inbox-native-push-plan.md
- Flutter handoff: docs/customer-flutter-conversion-handoff.md
- API conventions: docs/api-conventions.md
- API contract: docs/openapi.yaml

เป้าหมาย:
1. เพิ่ม icon กระดิ่งข้างยอดเงินบน Home และ badge จำนวนแจ้งเตือนที่ยังไม่อ่าน
2. เพิ่มหน้า /notifications สำหรับดูรายการ, pagination, อ่านรายการ, อ่านทั้งหมด, empty/loading/error และเปิดปลายทางที่ถูกต้อง
3. ทำ unread/read state ให้ server เป็น source of truth และ sync ข้ามอุปกรณ์ผ่าน realtime
4. ทำ native push บน iOS/Android ผ่าน Firebase Cloud Messaging รองรับ foreground, background, terminated, permission, token refresh และ notification tap
5. เชื่อม notification อัตโนมัติกับ order/lottery, topup/wallet, reward claims, activity/claims, affiliate, news, account/security และ approval/status transitions ตาม event catalog ในแผน
6. เพิ่มช่องทางให้ tenant admin ส่ง notification ไปหาลูกค้ารายคนใน tenant เดียวกัน พร้อมประวัติ read/delivery
7. เพิ่ม checkbox ส่งแจ้งเตือนตอน publish ข่าวหรือกิจกรรม โดยไม่ส่งอัตโนมัติถ้าไม่ได้เลือก

ข้อกำหนดสำคัญ:
- อ่าน docs/customer-notification-inbox-native-push-plan.md ทั้งไฟล์ก่อนแก้โค้ด และถือเป็น source of truth
- ตรวจ current worktree และโค้ดจริงก่อนเริ่ม Preserve งานเดิมทั้งหมดและห้าม revert งานที่ไม่ได้ทำเอง
- ตอนเริ่มมี dirty worktree จาก native-security follow-up อยู่แล้ว ให้แยกขอบเขตและทำงานร่วมกับของเดิม ห้ามลบทิ้ง
- ห้ามแตะ runtime DB newpaotang ถ้าผู้ใช้ไม่ได้สั่ง runtime DB โดยตรงใน turn นั้น
- ถ้ารัน database tests ให้ใช้ newpaotang_test เท่านั้น และตรวจ effective DB ก่อนทุกครั้ง
- ห้าม fresh, wipe, reset หรือ destructive command กับ runtime DB
- ห้าม hardcode tenant, partner, endpoint, theme, Firebase credentials, provider, route หรือข้อความที่ควรมาจาก runtime config/localization
- Firebase/APNs/service-account config ต้องมาจาก build/deployment secrets; ถ้า credentials ยังไม่มี ให้ inbox/realtime ใช้งานได้ครบและรายงาน external blocker ของ push จริงอย่างตรงไปตรงมา
- Tenant admin ส่งได้เฉพาะลูกค้าใน active tenant และห้ามรับ arbitrary external URL เป็น notification action
- Notification/push failure ห้ามทำให้ business transaction หลักล้มเหลว
- ใช้ idempotency, deterministic dedupe, queue, after-commit, audit และ tenant scoping ตาม pattern ที่มีอยู่
- Web ทำ in-app inbox + realtime เท่านั้น ยังไม่ทำ browser push
- ไม่ทำ screenshot automation ผู้ใช้จะตรวจภาพเอง
- ไม่ขยายงาน biometric/native screen security ใน goal นี้
- ไม่ clear worktree, commit หรือ push เว้นแต่ผู้ใช้สั่งตรงๆใน turn นั้น

ลำดับการทำงาน:
1. สำรวจจุด dispatch/realtime/API/admin ที่มีอยู่และสรุป mapping กับ event catalog
2. ทำ migration, models, notification service, queue delivery, FCM HTTP v1 adapter และ customer/admin APIs
3. เชื่อม transactional/content/account events พร้อม dedupe และป้องกัน duplicate wallet/ticket notifications
4. ทำ Back Office tenant notification page, customer-detail action และ publish checkbox
5. ทำ Flutter repository/state/realtime, Home bell badge และหน้า Notifications
6. ทำ native Firebase lifecycle, permission, device registration, foreground presentation และ deferred route หลัง login/PIN
7. อัปเดต docs/openapi.yaml, docs/customer-api-integration-map.md, handoff และเอกสาร deployment/env ที่เกี่ยวข้อง
8. รัน focused verification ตามแผน โดยเน้นความถูกต้องของ tenancy, state, route, transaction safety และ native push lifecycle

Definition of done:
- Inbox, unread badge, read/read-all, realtime และ admin direct-send ใช้งานได้ครบโดยไม่พึ่ง FCM
- ทุก automatic event ที่กำหนดสร้างข้อความถูกคน ถูก tenant ไม่ซ้ำ และเปิด route ถูกต้อง
- iOS/Android register/refresh/revoke device token ได้ และ push tap ผ่าน auth/PIN gate ไปยังปลายทางได้
- ข่าว/กิจกรรมส่งเฉพาะเมื่อ admin เลือก notify_customers
- FCM unavailable ไม่กระทบธุรกรรมหลัก และมี delivery status/retry ที่ตรวจสอบได้
- Focused backend tests ผ่านบน newpaotang_test, Flutter analyze/tests ผ่าน, Back Office checks และ git diff --check ผ่าน
- Real FCM ต้อง verify บน physical iOS/Android ก่อน mark native push production-ready; ถ้าขาด credentials/device ให้รายงานเป็น blocker โดยไม่อ้างว่าเสร็จ
- อัปเดตเอกสาร handoff พร้อมสิ่งที่ทำ, test ที่รัน, blocker และ worktree status

ทำงานจริงให้ครบเป็น batch ใหญ่ ไม่หยุดแค่เสนอแผน และห้าม mark goal complete จนกว่า acceptance criteria ทั้งหมด รวมถึง real FCM บน physical iOS/Android จะผ่านจริง หากติด credentials หรืออุปกรณ์ให้รายงาน blocker และคง goal ไว้โดยทำส่วนอื่นที่เดินต่อได้ให้ครบก่อน
```
