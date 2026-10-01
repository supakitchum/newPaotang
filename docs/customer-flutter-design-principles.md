# Customer App Design Principles for Flutter Migration

เอกสารนี้เป็นหลักการออกแบบและแนวทางย้ายหน้า `apps/customer` ไป Flutter โดยให้รักษาประสบการณ์ผู้ใช้เดิมของ customer storefront ให้มากที่สุด ไม่ใช่การออกแบบแอปใหม่จากศูนย์

## เป้าหมายหลัก

- ทำให้ customer app รู้สึกเหมือนแอปมือถือจริง: เต็มจอ, แตะง่าย, อ่านเร็ว, มี bottom navigation และ action dock ชัดเจน
- รักษา identity เดิมของระบบ: โทนฟ้า-เหลือง, font Kanit, blue hero, content sheet สีขาว, pill button และ card/list แบบเรียบ
- ย้าย logic โดยไม่เปลี่ยน business flow: browse lottery, cart reservation, checkout, tickets, results, wallet/topup, profile, reward claim, affiliate
- รักษา tenant isolation: ข้อมูล auth, cart, referral, site config และ API context ต้องไม่ปนกันข้าม tenant host
- รักษา customer-only scope: ห้ามเพิ่ม back-office/admin UX หรือ permission logic ใน customer app

## UX Personality

- เป็นแอปบริการทางการเงิน/สลากที่ต้องให้ความมั่นใจ ไม่ใช่ landing page
- UI ต้องเงียบ, ชัด, ใช้งานซ้ำได้เร็ว และเน้น action ที่ผู้ใช้ต้องทำต่อ
- ใช้ภาษาไทยเป็นหลัก น้ำเสียงสั้น ตรง อธิบายผลลัพธ์และข้อผิดพลาดให้เข้าใจง่าย
- ทุกหน้าที่เกี่ยวกับเงิน, สลาก, รางวัล หรือถอนเงิน ต้องลดความสับสนและมี confirmation/disabled/loading state ชัดเจน

## Visual Tokens

ใช้ token เหล่านี้เป็นฐานใน Flutter theme:

```dart
const appBlue = Color(0xFF087FF0);
const appBlueDark = Color(0xFF0067D9);
const appSky = Color(0xFF19B8EF);
const appYellow = Color(0xFFFFD10B);
const appInk = Color(0xFF242833);
const appMuted = Color(0xFF8A8F98);
const appBorder = Color(0xFFE8EBEF);
const appSoft = Color(0xFFF5F7FB);
```

- Font: ใช้ `Kanit` เป็น font หลักทั้งแอป
- Body background: `#FFFFFF`
- Soft page background: `#F4F6F8` หรือ `appSoft`
- Primary action: gradient ฟ้า `#149AF9 -> #0064D5`
- Disabled action: `#C6D3E3`
- Success/green action: `#77C827 -> #55B20E`
- Border: บาง, สีอ่อน, ไม่ทำให้หน้าแน่นเกินไป
- Shadow: ใช้เบา ๆ สำหรับ bottom nav, floating dock, important card

## Layout Architecture

ทุกหน้า customer ควรสร้างบน shell เดียวกัน:

```text
CustomerShell
  StatusBar / SafeArea top
  Scrollable content
    BlueHeader หรือ page-specific hero
    ContentSheet
      page content
  Floating PaymentDock เมื่อมี cart/reservation
  BottomNav เฉพาะหน้าหลักที่ต้องมี navigation
```

หลักการ:

- ใช้ mobile-first เต็มความสูงหน้าจอ
- รองรับ safe area ทั้งบนและล่าง
- Content หลักต้อง scroll ได้ แต่ bottom nav/payment dock ต้องคงตำแหน่ง
- ความกว้าง content บนจอใหญ่ควรจำกัดประมาณ `960px` หรือเทียบเท่า เพื่อไม่ให้ UI ยืดเกิน
- หน้า detail/form ใช้ `BlueHeader` ด้านบน แล้วให้ `ContentSheet` สีขาวซ้อนขึ้นมาด้วยมุมบนโค้ง
- หน้า list/operational ต้องเน้น scan: row, status, amount, date, action อยู่ใกล้กัน

## Core Components Mapping

| Nuxt Customer | Flutter Equivalent | หลักการ |
|---|---|---|
| `MobileShell.vue` | `CustomerShell` / `Scaffold` + `Stack` | คุม safe area, scroll, payment dock, bottom nav |
| `BlueHeader.vue` | `BlueHeader` widget | gradient hero, back button, title, optional search/action |
| `BottomNav.vue` | custom `BottomNavigationBar` | 3 tabs: Home, Tickets, Menu |
| `PaymentDock.vue` | `Positioned` bottom dock | แสดง cart count, amount, timer, CTA |
| `AppAlert.vue` | Snackbar/Dialog service | แสดง success/error/warning แบบ consistent |
| `PinKeypadScreen.vue` | PIN verification screen | ใช้ก่อนหน้าที่ sensitive เช่น affiliate |
| `WalletBalanceCard.vue` | balance card | แสดงยอด wallet พร้อม action ที่เกี่ยวข้อง |
| `LotteryItem.vue` | lottery row/card widget | แสดงเลข, ราคา, stock, selected state, reserve/release |
| `FilterPills.vue` | horizontal filter chips | filter/search state ต้องแตะง่าย |
| `SegmentTabs.vue` | segmented tabs | ใช้แบ่ง section ในหน้าเดียว |
| `TicketStub.vue` | ticket summary card | ใช้ใน tickets/history/claim |

## Header Pattern

`BlueHeader` เป็น signature สำคัญของ customer app:

- พื้นหลัง gradient ฟ้า พร้อม accent เหลือง/ฟ้าอ่อน
- ความสูงตามบริบท: หน้า simple ประมาณ `174-226px`, หน้า hero สำคัญมากกว่านั้น
- มี back button ด้านซ้ายเมื่อเป็น subpage
- title อยู่กลางหรือจัดใน content ตามรูปแบบเดิมของหน้า
- header ไม่ควรกลายเป็น app bar แบน ๆ แบบ Material default

## Content Sheet Pattern

`ContentSheet` คือพื้นที่หลักของหน้า:

- พื้นหลังขาว
- ซ้อนทับ hero ด้วย margin top ติดลบ
- มุมบนโค้งประมาณ `18-34px`
- padding แนวนอนประมาณ `18-24px`
- padding ล่างต้องเผื่อ bottom nav/payment dock และ safe area
- ถ้าเป็นหน้า list ที่ต้องติดกับ header ให้ใช้ variant `flush`

## Buttons and Controls

- Primary action ใช้ pill เต็มความกว้างหรือความกว้างตามบริบท สูงประมาณ `47px` ขึ้นไป
- ปุ่มสำคัญต้องมี disabled state และ loading state
- Icon button ใช้เฉพาะ action สั้น ๆ เช่น back, search, copy, remove
- Form fields ต้องสูงพอแตะง่าย มี label ชัด และ error ใต้ field
- Tabs/filter ใช้ chip/segmented control ไม่ใช้ dropdown ถ้าจำนวน option น้อย

## Navigation Principles

Bottom nav มี 3 หมวดหลักเท่านั้น:

- Home: หน้าแรก, ซื้อ/ค้นหาสลาก, ข่าว, กิจกรรม, ผลรางวัล
- Tickets: สลากของฉัน, ประวัติ, claim flow
- Menu: profile, wallet, topup, LINE, affiliate, settings/support

Route สำคัญที่ต้อง map เป็น Flutter navigation:

- `/` home
- `/buy`, `/buy/search`, `/buy/more`
- `/cart`, `/checkout`, `/success`
- `/tickets`, `/tickets/history`, `/tickets/view`, `/tickets/claim/:ticket_id`
- `/result`, `/result/full`, `/waiting-result`
- `/profile`, `/profile/reward-bank`, `/profile/auto-reward`, `/profile/line-notifications`
- `/my-wallet`, `/topup`, `/topup/history`
- `/affiliate`
- `/login`, `/register`, `/forgot-password`, `/reset-password`, `/pin`
- `/maintenance`, `/account-suspended`

Navigation guard ที่ต้องมีใน Flutter:

- App init/site config ก่อนเข้า app
- Auth guard สำหรับหน้าที่ต้อง login
- Maintenance/account suspended guard
- Referral capture จาก deep link หรือ initial URL ก่อน redirect
- Safe redirect หลัง login/register/LINE callback

## State and Data Principles

- แยก state ตาม tenant host หรือ tenant id เสมอ
- เก็บ auth token/customer profile ใน secure storage และ namespace ตาม tenant
- Cart/reservation ต้องมี server time, expiry และ timer ที่ sync กับ backend
- Referral code ต้องเก็บแบบ tenant-scoped, อายุ 30 วัน, last-click replacement, case-sensitive
- Site config เป็น source ของชื่อร้าน, theme metadata, SEO/web metadata และ tenant context
- หลีกเลี่ยง local mock ถ้า backend contract มีข้อมูลจริงอยู่แล้ว
- Money ต้อง format เป็น THB ด้วยทศนิยมตามบริบท และระวัง minor unit จาก API
- Realtime stock/result/price updates ต้องไม่ทำให้ UI กระพริบหรือ reset scroll โดยไม่จำเป็น

## API Contract Principles

- เรียก backend ผ่าน customer API contract เดิม ไม่สร้าง endpoint ใหม่ฝั่ง Flutter
- ส่ง tenant context ตาม host/base URL ที่ถูกต้อง
- Auth-required endpoint ต้องจัดการ `401` ด้วย login redirect/session clear
- Validation error ต้องแสดงข้อความจาก backend ถ้ามี
- Idempotent action เช่น register affiliate, payout, checkout/topup ควรส่ง idempotency key ตาม backend contract ถ้ามี
- Checkout ต้องรักษาลำดับเดิม: apply referral ก่อน checkout, ตรวจ cart/reservation, จ่ายเงิน, clear cart, ไป success

## Screen Design Rules

### Home / Buy

- เน้นค้นหาและเลือกสลากเร็ว
- Lottery item ต้องแสดงเลขชัดที่สุด, ราคา, availability, selected/in-cart state
- เมื่อเลือกสลากให้ feedback ทันที และ PaymentDock ต้องโผล่โดยไม่บัง content สำคัญ
- Stock sold/unavailable ต้องลด opacity หรือมี status ชัดเจน ห้ามให้ดูเหมือนกดซื้อได้

### Cart / Checkout

- Cart ต้องแสดง timer/reservation expiry เด่น
- ผู้ใช้ต้องเห็นจำนวน, ยอดรวม, รายการสลาก และ action ชำระเงินชัด
- Checkout action ต้อง disable ระหว่างจ่ายเงิน
- Error ต้องบอกว่าควรแก้ cart, login ใหม่, หรือ retry

### Tickets / Rewards

- Ticket list ต้อง scan ได้ด้วย draw date, status, prize/reward state
- Claim flow ต้องแยก step ชัด: ตรวจสิทธิ์, เลือกช่องทางรับเงิน, ยืนยัน
- Bank/wallet data ต้อง masked หรือแสดงเท่าที่จำเป็น

### Wallet / Topup

- Balance card เป็น focal point
- Topup method ต้องเลือกง่ายและแสดง instruction ตาม method
- History list ต้องมี amount, status, date, reference
- Pending payment/slip upload ต้องมี state ชัดเจน

### Profile / Menu

- Profile hero แสดงตัวตนและรหัสสมาชิก
- Menu list ใช้ row + icon + label + chevron
- Settings ที่มีผลกับบัญชีหรือเงินต้องแยกจาก informational links

### Affiliate

- ต้องเป็น customer-authenticated เท่านั้น
- ถ้าต้อง verify PIN ให้เข้า PIN screen ก่อน content
- แสดง code และ canonical link เป็น `/?ref=CODE` เท่านั้น
- ห้ามแสดง `/a/CODE` เป็น canonical link
- มี tab หรือ section แยก overview, withdraw, commissions, payouts
- Payout ต้องตรวจขั้นต่ำ, ยอดถอนได้, และบัญชีรับเงินก่อน submit

## Loading, Empty, Error States

ทุกหน้าต้องมีอย่างน้อย:

- Loading state ที่ไม่ทำให้ layout กระโดด
- Empty state พร้อม action ถ้ามีทางไปต่อ
- Error state ที่ retry ได้
- Disabled state สำหรับปุ่มที่ยังทำไม่ได้
- Success feedback หลัง action สำเร็จ

ข้อความควรสั้นและเฉพาะเจาะจง เช่น:

- `กำลังโหลดข้อมูล...`
- `ยังไม่มีรายการ`
- `กรุณาลองใหม่อีกครั้ง`
- `คัดลอกลิงก์แล้ว`
- `ยอดถอนได้ยังไม่ถึงขั้นต่ำ`

## Accessibility and Touch

- Touch target ขั้นต่ำประมาณ `44x44px`
- สี text ต้อง contrast พออ่านบนพื้นฟ้า/ขาว
- Icon-only button ต้องมี semantic label
- Form field ต้องมี label จริง ไม่ใช้ placeholder เป็น label หลัก
- ห้ามใช้ตัวอักษรเล็กเกินในข้อมูลสำคัญ เช่น amount, timer, status

## Internationalization

- รองรับ `th-TH` เป็น default และ `en-US` หากยังคงมี locale เดิม
- ห้าม hardcode copy ที่ควรถูกแปลใน widget ที่ reuse หลายหน้า
- วันที่/เวลาใช้ locale ไทยเมื่ออยู่ภาษาไทย
- เงินใช้ `THB` และ format ให้สม่ำเสมอ

## Flutter Implementation Guidance

- สร้าง design system ก่อนเริ่มย้ายหน้า: colors, text styles, spacing, radius, shadows, buttons, form fields
- สร้าง `CustomerShell`, `BlueHeader`, `ContentSheet`, `BottomNav`, `PaymentDock` ก่อนย้ายหน้าจริง
- ย้าย flow ทีละ vertical slice: auth -> app init -> home/buy -> cart/checkout -> tickets -> wallet -> profile -> affiliate
- ใช้ typed models สำหรับ API response อย่าพึ่ง map dynamic/raw JSON ไปทั่ว UI
- แยก service layer: `AuthService`, `CustomerApi`, `CartController`, `TenantConfigController`, `ReferralController`
- ใช้ state management ที่เลือกแล้วให้ consistent ทั้งแอป เช่น Riverpod/BLoC/Provider อย่างใดอย่างหนึ่ง
- Deep link ต้องรองรับ `?ref=CODE`, login redirect, LINE callback หรือ callback เทียบเท่า
- อย่าใช้ Material default theme ตรง ๆ จนเสีย identity ของ customer app

## Do Not

- ห้ามสร้าง landing page แทนหน้า app จริง
- ห้ามย้าย BO/admin component เข้ามาใน customer app
- ห้ามเปลี่ยน canonical referral link เป็น `/a/CODE`
- ห้ามแชร์ auth/cart/referral state ข้าม tenant
- ห้ามซ่อน checkout timer หรือ reservation expiry
- ห้ามทำปุ่มจ่ายเงิน/ถอนเงินที่กดซ้ำได้ระหว่าง loading
- ห้ามใช้ mock data ใน production flow เมื่อ API มี contract แล้ว
- ห้ามลบ empty/error state เพื่อลดงาน migration

## Migration Acceptance Checklist

ก่อนถือว่าหน้า customer ถูกย้ายสำเร็จ:

- หน้าทำงานใน mobile viewport และ tablet/desktop width โดย content ไม่ยืดเสียทรง
- Bottom nav, back navigation, safe area และ floating dock ไม่บัง content
- Auth guard และ redirect ทำงานเหมือนเดิม
- Tenant config และ tenant-scoped storage ไม่ปนข้าม tenant
- Cart reservation timer ตรงกับ backend/server time
- Checkout flow ไม่เปลี่ยนลำดับ business action
- Error/loading/empty states ครบ
- Copy ภาษาไทยยังเป็นธรรมชาติและไม่หลุด technical wording
- Affiliate/referral capture และ `/?ref=CODE` contract ยังถูกต้อง
- ไม่มี admin/back-office capability ใน customer app
