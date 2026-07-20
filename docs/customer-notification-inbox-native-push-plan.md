# Customer Notification Inbox And Native Push Plan

Last updated: 2026-07-21

## Objective

Build one tenant-scoped customer notification system that is the source of
truth for:

- The in-app notification inbox on Flutter Web, iOS, and Android.
- The unread badge shown beside the wallet balance on Home.
- Realtime notification refresh while the customer app is open.
- Native push notifications on iOS and Android through Firebase Cloud
  Messaging (FCM).
- Direct notifications sent by a tenant admin to one customer in that tenant.

The inbox and read state must remain available even when native push is
disabled, denied by the customer, or temporarily unavailable.

## Locked Product Decisions

- Use Firebase Cloud Messaging for native push. FCM routes Apple delivery
  through APNs.
- Only tenant admins may send direct customer notifications, and only to
  customers belonging to their active tenant.
- Transactional and status-change events create notifications automatically.
- Publishing news or activities creates notifications only when the admin
  explicitly selects `notify_customers` for that publish action.
- Flutter Web receives the in-app inbox and realtime updates, but browser push
  is outside this phase.
- The server owns unread state. Delivering or displaying a push notification
  does not mark the notification as read.
- Opening an inbox item or its push notification marks the recipient row read
  before navigating to the allowed destination.

## Backend Architecture

Create a dedicated `CustomerNotifications` module in `apps/platform-api` and
use the existing transaction, queue, audit, idempotency, tenancy, and Reverb
patterns.

### Persistence

Use four tenant-scoped tables:

1. `customer_notifications`
   - One immutable notification message or campaign source.
   - Store `tenant_id`, `event_key`, category, localized title/body snapshot,
     safe action key and entity ID, subject type/ID, creator type/ID,
     deterministic `dedupe_key`, metadata JSON, and publish timestamps.
   - Do not store an arbitrary external URL as a customer action.

2. `customer_notification_recipients`
   - One row per notification/customer pair.
   - Store `notification_id`, `tenant_id`, `customer_id`, `read_at`,
     `created_at`, and `updated_at`.
   - Enforce one recipient row per notification and customer.
   - This table is the authoritative unread state across all devices.

3. `customer_push_devices`
   - Store one app installation per customer and tenant.
   - Include installation ID, platform, encrypted FCM token, keyed token hash,
     locale, app version, device metadata, `last_seen_at`, `revoked_at`, and
     timestamps.
   - Upsert token refreshes and revoke stale/invalid registrations.
   - A logout revokes the current installation without deleting inbox data.

4. `customer_notification_deliveries`
   - Track each recipient/device push attempt.
   - Include status, attempt count, provider message ID, safe provider error
     code, next retry time, sent/failed timestamps, and timestamps.
   - Never persist credentials or unredacted provider payloads.

Use ULIDs and indexes for tenant/customer unread queries, chronological cursor
pagination, deduplication, queued deliveries, and stale-device cleanup.

### Creation And Delivery

- Expose one notification service for domain services to call after their
  business transaction commits.
- Insert the message and recipient rows transactionally, then enqueue push
  delivery and broadcast `customer.notification.created` after commit.
- Fan out tenant-wide news/activity messages in bounded queue chunks. Do not
  create all recipients inside the publish HTTP request.
- Use the existing `notification` worker queue and bounded retry/backoff.
- FCM failure must never roll back order, topup, claim, content, wallet, or
  affiliate transactions.
- Send through FCM HTTP v1 using Application Default Credentials and
  `FIREBASE_PROJECT_ID`; credentials must come from deployment secrets.
- Treat `UNREGISTERED` and a token-specific valid-payload `INVALID_ARGUMENT`
  response as terminal and revoke that device registration.
- A missing provider configuration records `provider_unavailable` and leaves
  the in-app notification usable.

### Deduplication

Build the dedupe key from tenant, customer/audience, event key, subject,
business transition, and source event identifier.

- Retrying a job or replaying an idempotent business request must not create a
  second inbox row.
- A topup, refund, order, or affiliate event must suppress a lower-level wallet
  notification when both describe the same transaction.
- Ticket issuance that belongs to an order-paid transition is represented by
  one purchase notification, not one notification per ticket.
- Draw-result notifications are one per customer/game, not one per ticket.

## API Contracts

### Customer API

- `GET /customer/notifications`
  - Query: `status=all|unread`, optional category, cursor, and bounded limit.
  - Return flattened recipient/message resources ordered newest first.
  - Resource fields include ID, category, event key, title, body, icon key,
    safe action object, subject, `is_read`, `read_at`, and `created_at`.
- `GET /customer/notifications/unread-count`
  - Return the authoritative count for the authenticated customer and tenant.
- `PATCH /customer/notifications/{notification_id}/read`
  - Idempotently mark only the authenticated customer's recipient row read.
- `POST /customer/notifications/read-all`
  - Idempotently mark all current unread recipient rows read.
- `POST /customer/notification-devices`
  - Register or refresh the current installation and FCM token.
- `DELETE /customer/notification-devices/{installation_id}`
  - Revoke only the authenticated customer's matching installation.

Writes follow the repository's request ID and idempotency conventions. All
responses follow the existing customer API wrapper and error-copy patterns.

### Realtime

- Add private channel:
  `customer.tenant.{tenant_id}.customer.{customer_id}.notifications`.
- Add it to `CustomerRealtimeAuthService`'s strict allowlist.
- Broadcast `customer.notification.created` and
  `customer.notification.read` with minimal IDs/count data.
- Flutter refetches server state after receiving an event rather than trusting
  the event as a complete notification resource.

### Tenant Admin API

- `GET /admin/tenant/customer-notifications`
  - Search/filter sent messages and inspect recipient/delivery state.
- `POST /admin/tenant/customer-notifications`
  - Send immediately to one `customer_id` in the active tenant.
  - Accept localized title/body and a destination selected from a server
    allowlist; reject arbitrary URLs and cross-tenant customers.
- Add permissions `customer_notification.view` and
  `customer_notification.send` to default RBAC/menu seeding.
- Audit the sender, target customer, content fingerprint, destination, request
  ID, and outcome without logging provider tokens.
- Add `notify_customers` to news/activity publish requests. It only sends once
  for the relevant transition into an active published state. Ordinary edits
  to already-published content do not silently resend.

## Notification Event Catalog

Use server-side localized templates/snapshots and safe action mappings for the
following customer-facing events.

### Lottery And Orders

- Order waiting for payment when an external payment flow requires follow-up.
- Order paid and tickets issued.
- Order failed, cancelled, expired, or refunded.
- Official draw result published for a customer who owns tickets in that game.
- Winning result, with navigation to the relevant ticket/reward flow.

### Topup And Wallet

- Topup request submitted.
- Topup approved/succeeded, rejected, cancelled, expired, failed, or reversed.
- Manual wallet credit/debit or refund not already represented by a more
  specific notification.

### Reward And Activity Claims

- Reward claim submitted, approved, rejected, cancelled, or paid.
- Activity entry submitted.
- Activity result/award granted.
- Activity claim submitted, approved, rejected, cancelled, or paid.

### Content

- Newly published news when `notify_customers` is selected.
- Newly published activity when `notify_customers` is selected.
- The action opens the exact news/activity detail route.

### Affiliate

- Affiliate registration completed.
- Commission earned or made available.
- Payout submitted, approved, rejected, cancelled, or paid.

### Account And Security

- Password or PIN changed.
- Biometric device added or revoked.
- Account suspended or restored.
- Do not include credentials, OTPs, full account numbers, or sensitive amounts
  in the lock-screen push payload.

### Direct Admin Message

- Tenant admin sends a one-customer message from Back Office.
- Allowed destinations are server-defined keys such as Home, Wallet, Tickets,
  Topups, Reward Claims, Activity Claims, Affiliate, News detail, and Activity
  detail. `none` keeps the customer on the inbox.

## Flutter Customer Experience

### Home Bell And Badge

- Add a notification bell immediately beside the existing wallet balance in
  `_HomeFixedNavbar` without changing its blended runtime-theme background.
- Keep stable responsive dimensions so long tenant names, wallet values, bell,
  and badge cannot overlap.
- Show `1` through `99`, then `99+`; hide the badge when the count is zero.
- Guests may see the bell, but opening it follows the existing login/redirect
  flow. Do not expose customer unread data before authentication and PIN unlock.

### Notification Inbox

- Add `/notifications` to the Flutter router.
- Use the established secondary-page header and the same header/content gap as
  `reward-claims`.
- Render category icon, title, summary, localized relative/absolute time,
  unread indicator, and safe action behavior.
- Support initial loading, cursor pagination, refresh, empty, offline/error
  retry, optimistic read with rollback, and a `read all` command.
- Reading on one device must update other open sessions through realtime.

### Native Push Lifecycle

- Add `firebase_core`, `firebase_messaging`, and the existing-project-compatible
  local notification package for foreground presentation.
- Initialize Firebase only on Android/iOS. Web remains free of browser-push
  initialization in this phase.
- Request notification permission once per installation after successful login
  and PIN unlock; denial never blocks the inbox.
- Register the FCM token after authentication, listen for token refresh, and
  revoke the installation during explicit logout.
- Configure Android 13 notification permission and a stable high-importance
  channel. Configure iOS push capability, APNs integration, and remote
  notification background mode.
- Handle foreground, background, and terminated messages. Foreground messages
  refresh the inbox/count and display a native local notification.
- Handle both `getInitialMessage()` and `onMessageOpenedApp`.
- Validate notification action keys against the Flutter route map. If login or
  PIN is required, retain the pending destination and navigate only after the
  existing auth gate succeeds.

## Back Office Experience

- Add a dedicated tenant page named `Customer Notifications` rather than
  forcing the workflow into the generic operations form.
- Provide tenant-scoped customer search, selected-customer summary,
  Thai/English title and body fields, destination selector, send confirmation,
  and clear API errors.
- Show send history with creator, recipient, created time, read state, push
  delivery status, and safe failure reason.
- Add a `Send notification` action to the existing customer detail view with
  that customer preselected.
- Add `Notify customers` controls to the existing news and activity publishing
  UI. Keep it explicit and unchecked by default.

## Verification And Acceptance

### Backend

Run focused feature tests only against `newpaotang_test` and verify:

- Tenant/customer isolation and permission boundaries.
- Cursor pagination, unread count, read, and read-all behavior.
- Direct admin send and cross-tenant rejection.
- Idempotency, deduplication, chunked fan-out, queue retry, and invalid-token
  revocation.
- Automatic event coverage across orders, topups, wallet, rewards, activities,
  affiliate, content publish, and account/security transitions.
- Business writes succeed even if FCM is unavailable.

### Flutter And Back Office

- Add focused model/repository/controller tests for list/count/read state,
  device registration/token refresh, route mapping, and pending navigation
  through login/PIN.
- Mock FCM for foreground/background handler tests.
- Run `flutter analyze --no-pub`, focused Flutter tests, Back Office checks, and
  `git diff --check`.
- Use Simulator/Emulator for UI, permission, mocked/local notification, and
  navigation coverage.
- Final native acceptance requires physical iOS and Android tests for real FCM
  delivery in foreground, background, terminated, token refresh, permission
  denial, notification tap, and logout revocation.
- Do not add screenshot automation; visual inspection remains manual.

## Runtime And Safety Requirements

- Use one platform Firebase project for the customer native app. Tenant name,
  theme, icon, locale, and routes still resolve from runtime bootstrap/API.
- Inject `google-services.json`, `GoogleService-Info.plist`, APNs setup,
  `FIREBASE_PROJECT_ID`, and ADC service-account credentials through the
  build/deployment secret path. Do not hardcode them or store them in the
  runtime database.
- Do not touch runtime DB `newpaotang` unless explicitly instructed in the
  current turn. Database tests use `newpaotang_test` only.
- Do not fresh, wipe, or reset the runtime database.
- Preserve existing worktree changes and do not revert unrelated work.
- Do not clear the worktree, commit, push, or generate another prompt unless
  explicitly requested in that turn.
- This notification project does not expand biometric/native screen-security
  scope.

## Implementation Status (2026-07-21)

- Implemented and focused-verified: durable inbox/unread/read-all, private
  realtime refresh, Home bell badge, safe action routes, automatic domain
  event catalog, tenant-admin direct send/history, explicit news/activity
  publish opt-in, FCM HTTP v1 delivery tracking, Flutter native lifecycle,
  Android/iOS build wiring, OpenAPI, deployment manifests, and release
  preflight.
- Production hardening completed: one active customer owns each installation
  ID and refreshed FCM token, generic invalid payloads do not revoke valid
  devices, order/topup transitions preserve exact destinations/statuses, and
  internal order action keys are unavailable to tenant-admin direct sends.
- Inbox concurrency and queue recovery hardening completed: realtime events
  received during list loading are replayed, read/read-all rollback cannot
  overwrite a newer server list, and authoritative read responses win stale
  refreshes. Push delivery uses an atomic sending lease, scheduled recovery
  redispatches missed/retry-due deliveries and stale workers, and incomplete
  tenant news/activity fan-outs resume through cursor-unique jobs.
- Production topup writes now distinguish semantic approval, rejection, and
  cancellation from storage statuses, while the event-catalog contract covers
  every safe claim, affiliate, activity, security, order, topup, and wallet
  transition. Native registration also retries on app resume when APNs/FCM is
  temporarily unavailable, permission changes in OS settings, or token-refresh
  registration fails without escaping into the app lifecycle.
- External acceptance remains open: real FCM must pass on physical iOS and
  Android for foreground, background, terminated, permission denial, token
  refresh, notification tap through Login/PIN, and explicit logout revocation.
  The currently visible iPhone cannot be deployed from this host because no
  valid code-signing identity is installed, and no physical Android device is
  connected. Do not mark this plan complete until both matrices are observed.
