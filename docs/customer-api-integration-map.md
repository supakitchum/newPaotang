# Customer API Integration Map

เอกสารนี้กำหนดวิธีเชื่อม `apps/customer` เข้ากับ `platform-api` แบบใหม่ โดย **คง UI flow เดิมทั้งหมด**

## Principle

```text
UI flow เดิมอยู่เหมือนเดิม
route เดิมอยู่เหมือนเดิม เว้นแต่มีคำสั่งเปลี่ยน
component interaction เดิมอยู่เหมือนเดิม
เปลี่ยนเฉพาะ API adapter/composables ให้เรียก platform-api endpoint ใหม่
```

ห้ามทำให้ `platform-api` กลายเป็น legacy endpoint copy ตามชื่อ API เดิม ถ้าชื่อ endpoint เดิมยังอยู่ใน code ระหว่าง transition ให้ถือเป็น implementation detail ใน adapter เท่านั้น

## Current Customer Project

```text
apps/customer
Nuxt 3.11.2
Axios plugin: apps/customer/plugins/axios.ts
Existing API composables:
  useAxios
  useAppInit
  useAuth
  useCart
  useLotteryReward
  useTopup
  useUserTickets
```

## Adapter Target

ให้สร้างหรือปรับ adapter/composables ใน `apps/customer` เพื่อ map ไปยัง API ใหม่:

```text
apps/customer existing UI
  -> customer API adapter/composables
  -> /api/v1 platform-api endpoints
```

API source of truth:

```text
docs/openapi.yaml
docs/api-conventions.md
```

## Existing Flow To New API Mapping

| Existing UI Action | Current Code Call | New platform-api Endpoint | Notes |
| --- | --- | --- | --- |
| app bootstrap | `GET /init` | `GET /public/site-config`, `GET /public/games/current`, `GET /customer/cart` when authenticated | Adapter combines responses into current init state shape |
| home reward summary | `GET /reward` | `GET /public/results/latest` | Adapter maps reward prizes to existing `rewards` array shape |
| full result | `GET /reward` | `GET /public/results/{game_id}` | Keep result UI; only data source changes |
| home news | `GET /news` | `GET /public/news` | Adapter maps `cover_url` to current `cover` if needed |
| browse lotteries | `GET /stores` or `GET /lotteries/guest` | `GET /public/stock/search?mode=random` | Auth state does not change UI flow; API still resolves tenant by host |
| search lotteries | `POST /lotteries/search` | `GET /public/stock/search?number=...` | Adapter converts `n1..n6/full_number` to `number` |
| search next page | `POST /offline/lotteries/search` | `GET /public/stock/search?cursor=...` | Adapter maps current seed/page state to API cursor |
| store list | `POST /stock-store` | `GET /public/stores?q=...` | Adapter maps pagination to current store state |
| store lotteries | `POST /lotteries/search` with `store_id` | `GET /public/stock/search?store_id=...&mode=browse` | Store name can come from store response or search meta |
| reserve lottery | `POST /lotteries/booking` | `POST /customer/reservations` | Adapter maps `token` to `local_stock_item_ids` |
| cancel booking | `POST /lotteries/cancel_booking` | `POST /customer/reservations/{reservation_id}/release` | Adapter must retain reservation id/token mapping |
| cart page | local cart state + init | `GET /customer/cart` | Server remains source of truth |
| wallet load | `GET /wallet` | `GET /customer/wallet` | Adapter maps Money object to numeric balance for existing UI |
| checkout payment | `POST /checkout` | `POST /customer/checkout` | Adapter maps existing `order_id` flow to reservation/order contract |
| success receipt | `GET /checkout/success` | `GET /customer/orders/{order_id}` | Adapter maps Order to receipt fields |
| tickets list | `GET /lotteries` | `GET /customer/tickets` | Adapter maps cursor/page metadata to existing pagination shape |
| ticket history/detail | ticket history/detail flow | `GET /customer/tickets/history`, `GET /customer/tickets/{ticket_id}` | Adapter maps TicketDetail to current ticket view state |
| topup overview/history | `GET /deposit` | `GET /customer/topups` | Adapter maps `bank`, `waiting`, `histories`, pagination |
| topup detail | `GET /deposit/{id}` | `GET /customer/topups/{topup_id}` | Adapter maps payment QR/message fields |
| create QR/bank topup | `POST /deposit` | `POST /customer/topups` | Adapter preserves current modal flow |
| create credit topup | `POST /payments/credit` | `POST /customer/topups/credit` | Adapter preserves minimum amount rule |
| cancel topup | `DELETE /deposit/{id}` | `DELETE /customer/topups/{topup_id}` | Adapter preserves confirm/cancel flow |
| ticket reward status | ticket/result detail flow | `GET /customer/tickets/{ticket_id}/reward-status` | Adapter maps reward status to existing ticket/result display |
| reward cashout claim | reward cashout flow | `POST /customer/reward-claims`, `GET /customer/reward-claims`, `GET /customer/reward-claims/{claim_id}` | Adapter preserves customer ticket flow while backend keeps tenant payout state |
| login | `POST /login` | `POST /customer/auth/login` | Adapter maps `token` and `user` |
| register | `POST /register` | `POST /customer/auth/register` | Adapter preserves current register page and maps token/user |
| auth me/refresh/logout | existing auth state helpers | `GET /customer/auth/me`, `POST /customer/auth/refresh`, `POST /customer/auth/logout` | Adapter keeps existing auth cookie/session behavior |
| profile | profile page calls | `GET /customer/profile`, `PATCH /customer/profile` | Adapter preserves current profile UI flow |
| LINE login URL | `POST /line/login` | `POST /customer/auth/line/login` | Adapter maps redirect URL |
| LINE callback | `GET /line/callback` | `GET /customer/auth/line/callback` | Adapter maps token/user/order continuation |

## Response Mapping Rules

The UI may keep using its current internal state shapes, but these shapes must be produced by the adapter, not by forcing `platform-api` to copy old endpoint names.

Examples:

```text
Money { amount, currency } -> numeric baht balance/total for existing UI
LocalStockItem.id -> existing ticket.token
LocalStockItem.full_number -> ticket.number/full_number
Reservation.expires_at -> cart exp/timer
Order.id -> checkout/success order_id
Ticket.image_url -> current ticket image display
CursorMeta.next_cursor -> current pagination seed/page wrapper
```

## Required Adapter Behavior

```text
inject Authorization bearer token from existing auth state
preserve Host-based tenant resolution
generate Idempotency-Key for reserve, release, checkout, topup create, credit topup
normalize API errors into current alert/modal states
keep existing loading, empty, success, failure UI behavior
never trust browser cart as source of truth after server refresh
never write Central Stock directly
```

## Migration Rule

Frontend may initially keep function names such as `fetchTopupInfo`, `handleBooking`, or `fetchReward`, but their internal HTTP calls must move to the new platform-api endpoints above.

Do not rename customer routes, redesign screens, or rewrite checkout/cart behavior as part of API integration.
