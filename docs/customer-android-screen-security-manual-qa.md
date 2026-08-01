# Customer Android Screen Security Manual QA

ใช้รายการนี้สำหรับ owner-observed acceptance เท่านั้น ไม่ใช้ screenshot หรือ
screen-recording automation

## Preconditions

- Build Android Release ด้วย partner identifiers, signing key และ
  `android/app/google-services.json` จริงจาก deployment secrets
- Production bootstrap ยังส่ง screen-security config เพื่อรองรับ audit และ
  policy ข้าม platform แต่ Android ต้องป้องกันทั้งแอปแม้ config หรือ route
  transition ส่งคำสั่ง disable
- Login และผ่าน PIN แล้ว

## Required Checks

| Check | Action | Expected |
| --- | --- | --- |
| App-wide screenshot | เปิด Home, Login, `/my-wallet`, `/checkout` และ `/pin` แล้วกด screenshot | Android ปฏิเสธการจับภาพ หรือไฟล์ที่ได้ไม่แสดงเนื้อหาแอปทุกหน้า |
| Recent Apps | อยู่บนหน้าใดก็ได้แล้วเปิด Recent Apps | preview ไม่แสดงข้อมูลแอป; กลับเข้าแอปต้องผ่าน PIN/biometric ตาม lifecycle policy |
| Screen recording | เริ่มบันทึกจอก่อนเปิดแอป แล้วสลับหลายหน้า | วิดีโอไม่แสดงข้อมูลแอป; หาก Android 15 รายงานสถานะ `VISIBLE` แอปต้องแสดงข้อความไม่อนุญาต ล็อก session แล้วปิด task/process |
| Detected capture exit | บน Android/API ที่ส่ง screenshot หรือ recording callback ให้แอป | แสดงข้อความไม่อนุญาตตาม runtime language/tenant แล้วแอปหายจาก Recent Apps และต้องเปิด process ใหม่ |
| Public to sensitive | เปิด Home แล้วเข้า Wallet | protection ทำงานต่อเนื่อง ไม่มีช่วงที่ native flag ถูกถอด |
| Sensitive to public | ออกจาก Wallet กลับ Home | protection ยังคงทำงานและ Home ไม่ค้างดำหรือกดไม่ได้ |
| Background resume | อยู่บน Wallet, กด Home แล้วเปิดแอปอีกครั้ง | แอปกลับผ่าน PIN/biometric และ protection ยังทำงานหลัง resume |
| Cold start/deep link | ปิด process แล้วเปิด deep link ไปหน้า sensitive | ไม่มีเฟรมข้อมูล sensitive โผล่ก่อน PIN เพราะ native `FLAG_SECURE` ถูกตั้งก่อน Flutter เริ่ม |

## Device Matrix

- Android 11/API 30 หรือต่ำกว่า API 33: ตรวจ `FLAG_SECURE` และ Recent Apps
  fallback เท่านั้น ระบบไม่มี public callback จึงไม่สามารถสั่งแสดงข้อความหรือ
  ปิดแอปตาม capture attempt ที่ OS ไม่รายงานได้
- Android 13/API 33+: ตรวจ native Recent Apps screenshot blocking
- Android 14/API 34+: `Activity.ScreenCaptureCallback` จะไม่ถูกเรียกเมื่อ
  `FLAG_SECURE` ทำงานตาม Android contract; ต้องรักษาการบล็อกภาพไว้ก่อน
  behavior แจ้งเตือน/ปิดแอป
- Android 15/API 35+: หาก recording visibility callback คืน `VISIBLE`
  ให้ตรวจข้อความเตือน การล็อก session และการปิด task/process; หาก OS ไม่ส่ง
  callback ให้ยึดผลวิดีโอดำจาก `FLAG_SECURE` เป็น privacy acceptance

บันทึก device model, Android API, build version และผล Pass/Fail ของแต่ละแถว
ไว้ใน handoff ก่อน mark native screen-security goal complete

## Historical Route-Scoped Physical-Device Acceptance

วันที่ 27 ก.ค. 2026 ผู้ใช้อนุญาตให้รัน acceptance บนเครื่องจริงโดยตรง
จึงใช้ integration APK package แยก `com.siamblend.securitytest` และหน้าทดสอบ
สีสังเคราะห์ที่ไม่มีข้อมูลลูกค้า เปรียบเทียบ public กับ protected phase
บนเครื่องเดียวกัน

- Device: Xiaomi M2006C3LG
- Android: 11 / API 30
- Test build: debug `0.1.0`, target SDK 36
- Native route: `/my-wallet`; transition check: `/checkout`

| Check | Result | Evidence |
| --- | --- | --- |
| Public baseline | Pass | `adb screencap` แสดงหน้าทดสอบและแถบสีครบ |
| Sensitive screenshot | Pass | หลังเปิด protection คำสั่ง capture ไม่คืน app pixels; หลัง resume เห็นเพียงพื้นหลังระบบ ไม่เห็น synthetic protected content |
| Recent Apps | Pass | task preview เป็นแผงว่าง ไม่มีข้อความหรือแถบสีจาก protected screen |
| Screen recording | Pass | วิดีโอ 8 วินาทีเป็นพื้นดำในพื้นที่แอป เหลือเฉพาะ system bars |
| Background/resume | Pass | กลับเข้า Activity เดิมแล้ว capture ยังไม่เห็น app content และ native state probe ยังรายงาน `FLAG_SECURE`/recent protection เป็น active |
| Protected/public/protected | Pass | integration assertions ยืนยัน disable `/my-wallet` แล้วเปิด `/checkout` สามารถถอดและคืน native policy ได้ครบ |
| Integration completion | Pass | `flutter drive` จบ 5 tests ด้วย `All tests passed` |

หลังทดสอบถอน package แยกออกแล้ว และติดตั้ง `com.siamblend` แอปปกติกลับแบบ
in-place ด้วย production API/tenant host เดิม จึงไม่ลบ app data ของเครื่อง
ไม่แตะ runtime database ระหว่างการทดสอบ

Android 14/15 callback registration และ lifecycle ยังคงอ้างอิงผล emulator
API 35 ที่ผ่านก่อนหน้านี้ ส่วน final Release packaging ต้อง inject
`google-services.json` และ signing material จริงจาก deployment secrets;
ข้อจำกัดนี้ไม่กระทบผล native screen-protection บนเครื่องจริงข้างต้น

ผลวันที่ 27 ก.ค. เป็นหลักฐานของ policy เดิมแบบ route-scoped เท่านั้น และถูก
แทนที่ด้วย app-wide policy ตั้งแต่ 28 ก.ค. 2026 ห้ามใช้ public baseline
ที่ capture ได้เป็น expected result ของ build ปัจจุบัน

## App-Wide Native-State Verification

วันที่ 28 ก.ค. 2026 ติดตั้ง debug build ของแอปปกติ `com.siamblend` แบบ
in-place บน Xiaomi M2006C3LG Android 11/API 30 โดยใช้ production API origin
และ tenant host เดิม:

- native integration bridge ผ่านเคส enable, security event, disable และ
  re-enable โดยหลัง Flutter เรียก `disable` ค่า `screenSecurityActive`,
  `windowFlagSecure` และ recent-app protection ยังคง active
- หลังติดตั้ง entrypoint ปกติและปล่อยให้ Flutter โหลดเสร็จ
  `dumpsys window` รายงาน MainActivity เป็น
  `fl=LAYOUT_IN_SCREEN SECURE ...`
- ไม่มีการล้าง app data จึงรักษา session เดิมไว้
- ไม่ทำ screenshot หรือ screen-recording automation; ผลภาพจริงทุกหน้าตาม
  Required Checks ด้านบนยังเป็น owner-observed acceptance

## Detection And Forced-Exit Contract

ตั้งแต่ 28 ก.ค. 2026 callback screenshot/recording ที่ native Android ได้รับจะ
ทำงานแบบ idempotent: ส่ง `screen_security_exit_requested` ไป Flutter, แสดง
ข้อความจาก `overlay_title` ที่ Flutter ส่งมาตาม runtime localization (fallback
ภาษาอังกฤษ/ไทยอยู่ใน native resources), รอให้ข้อความปรากฏ แล้วเรียก
`finishAndRemoveTask()` และจบ process

ข้อจำกัดนี้เป็น platform contract ไม่ใช่ช่องว่างของ implementation:

- Android 14 ระบุว่า screenshot callback ไม่ทำงานบน Window ที่ตั้ง
  `FLAG_SECURE`
- Android ต่ำกว่า 14 ไม่มี public screenshot callback
- screen-recording visibility callback เริ่มใน Android 15

ดังนั้นห้ามถอด `FLAG_SECURE` เพื่อบังคับให้ callback ทำงาน เพราะ screenshot จะ
เกิดขึ้นก่อนแอปได้รับ event และอาจทำให้ข้อมูลลูกค้าหลุดได้
