# Production Customer Notification Campaign: Missing Push After Device Re-registration

Date: 2026-08-06

Status: application defects identified from read-only production evidence. No application code, infrastructure, queue state, or production data was changed during this investigation.

Owner: Coordinator / application development

## Summary

The latest tenant-wide customer communication campaign was published and appeared in the customer's durable inbox, but no native push notification was sent.

The primary cause is a delivery lifecycle gap. The customer had no active push device when the campaign fan-out created the recipient. The customer registered an active device about six minutes later, but device registration does not create delivery rows for an existing recipient. As a result, Firebase Cloud Messaging was never called for this campaign.

A separate scheduling defect was also observed. A campaign created at approximately 15:55 Asia/Bangkok with a future scheduled time was stored as `09:00:00+07`, which was already in the past, and was published immediately. The current frontend and backend timezone contract can lose or reinterpret the submitted offset when Laravel persists the value.

## Affected Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Tenant: ten_2637f84274a214c56e63
Campaign: ccp_01KZB4HNKFCKC9YFAK10JX07QA
Notification: cnt_01KZB4HRX1D0G7F9K4SS7Z0536
Recipient: cnr_01KZB4HSBDSANCC17D8JXWZ4NM
Customer: cus_01KZ2TY7TMYBAS6DPQN2SMS9PD
Platform: iOS
App version: 0.1.0+1
```

No FCM token, token hash, Firebase credential, customer message content, or other secret is included in this report.

## User-Visible Symptoms

- The BO campaign is shown as published.
- The campaign is present in the customer's in-app notification inbox.
- The customer does not receive a native push notification.
- Delivery statistics contain zero delivery rows rather than a failed provider attempt.
- A scheduled campaign can publish immediately instead of waiting for the selected local time.

## Production Timeline

All timestamps below use Asia/Bangkok.

| Time | Event |
| --- | --- |
| 2026-08-05 17:17:57 | The customer app called `DELETE /api/v1/customer/notification-devices/{installation}` and the device was revoked during logout. |
| 2026-08-06 15:55:26 | Campaign `ccp_01KZB4HNKFCKC9YFAK10JX07QA` was created. |
| 2026-08-06 15:55:29 | The scheduler published the campaign, created its notification and recipient, and found no active device. No delivery row was created. |
| 2026-08-06 16:01:18 | The app requested current notification-device status. |
| 2026-08-06 16:01:21 | The app registered the iOS installation again; the API returned HTTP 201. |
| 2026-08-06 16:01:27 | The customer read the inbox notification, proving that the durable inbox path worked. |
| 2026-08-06 16:02:52 | A subsequent logout revoked the installation again. |
| 2026-08-06 16:03:16 | The app registered the installation again and it became active. |

Trace requests useful for ingress correlation:

```text
device registration: req_1786006881381257_6d7e431efdcc49f3
notification read:   req_1786006887492177_fb792856ec9b95da
```

## Evidence

### Campaign and inbox state

```text
campaign status: published
campaign scheduled_at: 2026-08-06 09:00:00+07
campaign published_at: 2026-08-06 15:55:29+07
campaign last_error_code: null
recipient count: 1
recipient read count: 1
delivery count: 0
delivery failures: 0
```

The recipient was created and later read, so campaign publication, fan-out, database persistence, inbox listing, and customer authentication were operational.

### Device state

The tenant currently has one active customer push-device record:

```text
device: cpd_01KZ2TYQJB80DB4Q4RNA1PN2B2
installation: install_1785728032160869_86c90d0d712c332f
platform: ios
device: iPhone13,4
last_seen_at: 2026-08-06 16:03:16+07
revoked_at: null
```

This active state was established after the campaign recipient was created. It therefore cannot produce a delivery under the current fan-out implementation.

### Queue and infrastructure state

```text
Redis queue notification ready: 0
Redis queue notification delayed: 0
Redis queue notification reserved: 0
critical workers ready: 2/2
notification jobs in failed_jobs: 0
```

The running critical workers use the same application revision that introduced the campaign feature. No API outage, worker restart loop, queue backlog, Firebase provider-auth error, or FCM `UNREGISTERED` response was involved in this incident.

## Confirmed Root Cause: Missing Delivery Backfill

The tenant fan-out flow creates one recipient per active customer and immediately calls `dispatchCreated()`:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:590`
- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:1173`

`queueRecipientDeliveries()` queries only devices whose `revoked_at` is null at that moment. If there are no active devices, the loop creates no `customer_notification_deliveries` rows and records no reason:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:1203`

`registerDevice()` later reactivates or creates the device but does not inspect recent unread recipients and does not create missing deliveries:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:250`

The scheduler recovery path can retry existing delivery rows and incomplete fan-outs, but it cannot recover a delivery row that was never created. Therefore this campaign remains inbox-only even after the device becomes active.

## Scheduling Defect: Timezone Offset Is Not Preserved End To End

The BO converts the browser-local `datetime-local` value to an ISO UTC instant:

- `apps/back-office/pages/admin/tenant/customer-notifications.vue:599`

```ts
new Date(form.scheduled_at).toISOString()
```

The API parses the timestamp with Carbon and assigns it directly to a `timestampTz` Eloquent attribute:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerCommunicationCampaignService.php:112`
- `apps/platform-api/database/migrations/2026_08_04_000001_create_customer_communication_campaigns.php:27`

The production row was stored as `2026-08-06 09:00:00+07`, while the campaign was created at 15:55 and published at 15:55. This means the persisted value was already due. The likely failure is that the incoming UTC clock value was formatted for SQL without first normalizing it to the application/database timezone, causing PostgreSQL to interpret `09:00` as Asia/Bangkok rather than as UTC.

This timezone mechanism should be confirmed with an API request capture or a focused integration test before implementation. The production timestamps already establish the behavioral defect: the selected future schedule did not remain a future instant after persistence.

## Required Remediation

### 1. Define and enforce the schedule contract

- Accept an offset-aware ISO-8601 instant from the BO.
- Normalize it to UTC in the API before validation and persistence.
- Preserve the instant when writing and reading `timestampTz`.
- Convert to the tenant or browser timezone only for display.
- Reject a schedule that becomes past or less than one minute ahead after normalization.
- Return the canonical instant in the API response so the BO can verify the saved schedule.

### 2. Recover push delivery after device registration

Add an idempotent, bounded backfill when a device becomes active. It should find eligible recent unread recipients for the same tenant and customer that do not already have a delivery for this device, then create and queue exactly one delivery per recipient/device pair.

The eligibility window must be explicit to avoid unexpectedly pushing stale inbox messages. A suggested default is 24 hours, configurable after product review. Exclude read, expired, cancelled, or otherwise ineligible notifications. Preserve the existing unique recipient/device constraint as the final duplicate guard.

An acceptable alternative is an explicit campaign policy such as `push_when_device_available_until`, processed by recovery jobs. Whichever design is chosen must make the no-device state durable instead of depending on a one-time query during fan-out.

### 3. Make the no-device outcome observable

- Record an explicit safe state such as `no_active_device` when a recipient has no eligible device.
- Show this state separately from provider failure and queue failure in BO campaign statistics.
- Add metrics for recipients, deliveries created, no-device recipients, sent, failed, and pending recovery.
- Do not create fake failed FCM attempts when Firebase was never called.

### 4. Keep replay controlled

Do not automatically replay every historical inbox notification after this fix. Existing campaigns should be resent only through a deliberate, audited replay action or by creating a new campaign. A replay must remain idempotent and must not duplicate delivery for devices that already received the notification.

## Required Tests

1. An active device at fan-out creates one queued delivery and sends it.
2. No active device at fan-out still creates the inbox recipient and records an observable `no_active_device` outcome.
3. Device registration inside the allowed recovery window creates exactly one missing delivery.
4. Repeated registration of the same installation does not duplicate a delivery.
5. A revoked device remains excluded.
6. Read, expired, cancelled, and out-of-window notifications are not backfilled.
7. A campaign scheduled for 16:00 Asia/Bangkok persists as the same instant and remains scheduled before 16:00.
8. An offset-aware timestamp round-trips through request, database, response, and scheduler without changing its instant.
9. A genuinely past schedule is rejected.
10. Queue recovery handles created deliveries without replaying already-sent notifications.

Run destructive or database-reset tests only against `newpaotang_test`. Never use the protected runtime database for test setup.

## Acceptance Criteria

- A future local schedule does not publish before the selected instant.
- A customer with an active device at fan-out receives exactly one native push.
- A customer who re-registers within the approved recovery window receives exactly one eligible missed push.
- Inbox delivery remains independent from native push availability.
- BO statistics explain `no_active_device` instead of silently reporting zero delivery rows.
- No provider call is reported when no delivery was created.
- No old campaign is replayed automatically during deployment.
- Focused backend, BO, scheduler, and timezone integration tests pass against `newpaotang_test`.

## Coordinator Task Prompt

```text
Fix the production customer-notification campaign delivery gap documented in:
docs/production-customer-notification-campaign-delivery-gap.md

Scope:
1. Normalize scheduled campaign timestamps as one canonical UTC instant end to end.
2. Add bounded and idempotent delivery recovery when an eligible customer device is registered after campaign fan-out.
3. Persist and expose an observable no_active_device outcome without misclassifying it as an FCM failure.
4. Add backend, scheduler, BO, and timezone tests listed in the report.

Constraints:
- Keep durable inbox behavior independent from native push.
- Do not replay historical campaigns automatically.
- Do not expose FCM tokens, token hashes, or credentials.
- Do not run destructive tests against the runtime or production database.
- Use APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing for destructive test setup.

Return the implementation to QA with migration impact, deployment order, rollback notes, and physical-device verification evidence.
```
