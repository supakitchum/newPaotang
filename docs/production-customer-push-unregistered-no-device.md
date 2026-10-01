# Production Customer Push: No Registered Device

Date: 2026-08-03

Status: root cause confirmed and permanent application remediation implemented locally. The runtime database and production infrastructure were not changed during remediation.

## Summary

The Siamblend partner back office reports `No registered device` after sending a customer notification, even though push notifications had worked earlier and the customer was actively using the app.

The notification and durable inbox paths are working. The push path has no active device because Firebase Cloud Messaging returned `UNREGISTERED` for the customer's only token. The Platform API correctly revoked that device. The customer app did not register a replacement token afterward.

## Affected Environment

```text
Kubernetes context: do-sgp1-lotto80
Namespace: newpaotang-prod
Platform API image: dbae6893e117
Database: lottery80
Tenant: ten_2637f84274a214c56e63
Partner domain: siamblend.com
Back-office domain: bo.siamblend.com
Customer: cus_01KZ2TY7TMYBAS6DPQN2SMS9PD
Platform: iOS
App version: 0.1.0+1
Device: iPhone13,4
```

## User-Visible Symptom

The notification is created successfully and appears in the customer's in-app inbox, but the BO push status is:

```text
No registered device
```

Affected BO page:

```text
https://bo.siamblend.com/admin/tenant/customer-notifications
```

## Production Timeline

All timestamps below use Asia/Bangkok.

```text
2026-08-03 10:33:52  Customer device registered with the Platform API
2026-08-03 12:20:11  Same installation registered/seen again
2026-08-03 16:11:46  Push delivery succeeded for account.biometric.added
2026-08-03 18:09:46  affiliate.registration.completed notification created
2026-08-03 18:09:47  FCM returned UNREGISTERED; delivery failed and device was revoked
2026-08-03 18:15:26  Later notification created with no active device delivery
2026-08-03 18:17:50  Admin direct message created with no active device delivery
2026-08-03 18:18:24  Customer read the direct message from the in-app inbox
2026-08-03 18:19:43  Customer continued using and reading the notification inbox
```

## Evidence

### API and worker health

- `POST /api/v1/admin/tenant/customer-notifications` returned HTTP 201.
- Customer notification list and unread-count endpoints returned HTTP 200.
- `SendCustomerPushNotificationJob` ran and completed for the 18:09 notification.
- Production pods were ready with zero restarts.
- No queue, provider-auth, API availability, or database error was found.

### Device state

The tenant has one push-device record:

```text
device id: cpd_01KZ2TYQJB80DB4Q4RNA1PN2B2
platform: ios
last_seen_at: 2026-08-03 12:20:11+07
revoked_at: 2026-08-03 18:09:47+07
```

Tenant device totals after the FCM failure:

```text
total: 1
active: 0
revoked: 1
```

No token, token hash, credential, service-account key, or encrypted value is included in this report.

### Delivery state

The earlier delivery succeeded:

```text
event_key: account.biometric.added
status: sent
attempts: 1
sent_at: 2026-08-03 16:11:46+07
```

The delivery that invalidated the device failed:

```text
event_key: affiliate.registration.completed
status: failed
attempts: 1
last_error_code: unregistered
failed_at: 2026-08-03 18:09:47+07
```

The 18:15 and 18:17 notifications have recipient rows but no delivery rows because the active-device query returned no records.

### Firebase project alignment

The following configurations all use the same Firebase project:

```text
iOS Firebase project: siamblend-dd187
Android Firebase project: siamblend-dd187
Platform API FCM project: siamblend-dd187
Mounted service-account project: siamblend-dd187
```

The service-account file is mounted and Application Default Credentials are available in the production API container. A prior push succeeded with the same server configuration. This rules out a project mismatch or missing provider credential as the cause of this incident.

## Root Cause

FCM returned `UNREGISTERED` for the only registered device token. This normally means the app instance token is no longer accepted by FCM, for example after token invalidation, app-instance reset, reinstall, or native messaging token rotation.

The backend behavior is intentional:

1. `FirebaseCloudMessagingClient` classifies the provider response as `unregistered`.
2. `CustomerNotificationService::processDelivery()` marks the delivery failed.
3. The same method sets `customer_push_devices.revoked_at` for a terminal token failure.
4. Future notifications find zero active devices and create no delivery rows.
5. The BO maps a zero-delivery summary to `not_registered`, displayed as `No registered device`.

Relevant backend files:

- `apps/platform-api/app/Modules/CustomerNotifications/Services/FirebaseCloudMessagingClient.php:64`
- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:773`
- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:1094`
- `apps/platform-api/app/Modules/CustomerNotifications/Services/CustomerNotificationService.php:1216`
- `apps/back-office/pages/admin/tenant/customer-notifications.vue:568`

## Client Recovery Gap

The customer app was still authenticated and active after the device was revoked, but it did not call:

```text
POST /api/v1/customer/notification-devices
```

after the 18:09 failure.

`CustomerPushLifecycleMonitor` caches the last registration signature and skips registration for 30 days when the installation, platform, locale, device context, and FCM token appear unchanged:

```dart
if (_registeredSignature == signature &&
    registrationAge != null &&
    !registrationAge.isNegative &&
    registrationAge < const Duration(days: 30)) {
  return;
}
```

Relevant client file:

- `apps/customer_flutter/lib/core/notifications/customer_push_lifecycle_monitor.dart:146`

This client-side cache has no knowledge that the server revoked the token. Resume and inbox activity therefore do not restore the device registration. Registration errors are also caught without telemetry, which makes native token and permission failures invisible in production diagnostics.

The exact external event that caused FCM to invalidate the token cannot be recovered from the current application data. The authoritative facts are that FCM returned `UNREGISTERED`, the token was revoked correctly, and no replacement registration followed.

## Immediate Recovery

For the affected customer device:

1. Log out of the customer app.
2. Log in again and complete the PIN/unlock flow.
3. Allow notifications if iOS requests permission.
4. Verify that the app calls `POST /api/v1/customer/notification-devices` and receives HTTP 201.
5. Send a test notification and confirm a new delivery reaches `sent`.

Logout invokes `FirebaseMessaging.deleteToken()`. The next authenticated registration should request and register a fresh FCM token.

Force-closing and reopening the app may re-register the device because the in-memory registration cache resets, but it may reuse the same invalid token. Logout/login is the stronger immediate recovery path.

Do not manually clear `revoked_at` in production. Re-activating an FCM-rejected token without obtaining a valid replacement would only cause the next delivery to fail again.

## Recommended Remediation

### Client

1. Add a server-readable device-registration status endpoint or include registration status in an authenticated bootstrap response.
2. When the current installation is missing or revoked, call `deleteToken()`, request a fresh FCM token, and register it.
3. Reconcile device registration more frequently than every 30 days, at least once per authenticated app session or with a shorter bounded interval.
4. Preserve token-refresh registration, but add retry/backoff and observable telemetry for permission, APNs-token, FCM-token, and API registration failures.
5. Do not silently swallow every registration exception without recording a safe error category.

### Backend

1. Keep terminal `UNREGISTERED` revocation behavior; it prevents repeated sends to invalid tokens.
2. Expose a safe current-installation status without returning tokens or token hashes.
3. Record a safe terminal-revocation reason such as `fcm_unregistered` and the revocation timestamp for diagnostics.
4. Consider exposing active-device state in the BO customer selector so an admin knows before sending that push delivery is unavailable.

## Required Tests

1. FCM `UNREGISTERED` marks the delivery failed and revokes the device.
2. A revoked installation is excluded from later delivery creation.
3. Client resume detects a server-revoked current installation and rotates/re-registers its token.
4. A new token for the same installation clears the revoked state and becomes the only active owner.
5. Logout deletes the local FCM token and revokes the server installation.
6. Login after logout registers a new token and receives a successful test push.
7. Registration failures emit safe telemetry without exposing FCM tokens or credentials.
8. The durable inbox remains available when push registration or delivery fails.

## Implemented Remediation

- Platform exposes `GET /api/v1/customer/notification-devices/{installation_id}/status` scoped to the authenticated tenant and customer. Missing and revoked rows return recovery state without any token or token hash.
- Terminal provider failures retain a safe reason such as `fcm_unregistered`; logout, stale cleanup, reassignment, and session replacement also retain diagnostic reasons.
- Flutter checks server state at the start of every unlocked app session and at a bounded 15-minute resume interval. A revoked installation deletes the local FCM token and refuses to reactivate it until Firebase returns a different token.
- Platform also rejects a registration that attempts to reactivate the same token hash on a revoked installation, closing the recovery race for older clients and delayed token rotation.
- Missing installations register the current token, active registrations refresh daily, and registration failures retry with bounded backoff. Diagnostics contain only a stage and exception type.
- Customer inbox and realtime behavior remain independent of native push availability.
- Production preflight now rejects a native release whose source no longer contains status reconciliation, token rotation, and retry wiring.

The database migration is non-destructive but must be deployed before the API image that writes `revoked_reason`. It was not executed against a runtime or production database as part of this work.

## Remediation Verification

- Platform `CustomerNotificationTest`: 24 tests, 282 assertions passed against `newpaotang_test`.
- Flutter customer notification lifecycle: 16 tests passed, including revoked-token rotation, retry diagnostics, logout ordering, and status parsing.
- Focused native Push production preflight: 2 tests passed.
- Focused Flutter analysis, PHP syntax checks, OpenAPI YAML parsing, and `git diff --check` passed.
- The full production-preflight suite still has four unrelated existing failures in account-deletion/support-link policy, system-chrome identity, iOS release-project guard, and a web theme-color expectation.
- `CustomerOpenApiContractTest` reaches the updated document but remains blocked by the unrelated existing missing specification for `POST /customer/auth/line/native`; the new Push status route itself is documented.

Run backend tests only against `newpaotang_test`. Do not run destructive database commands against the protected runtime or production database.

## Acceptance Criteria

- An FCM-invalidated token remains revoked and is not retried indefinitely.
- The active authenticated app detects that its current installation is revoked.
- The app obtains and registers a fresh token without requiring reinstall.
- The BO no longer shows `No registered device` after successful recovery registration.
- A post-recovery test notification creates a delivery row and reaches `sent`.
- Push-registration failures are diagnosable without logging sensitive token material.
- No manual production database update is required for normal recovery.

## Deployment Notes

The permanent fix is expected to require a customer Flutter release and a Platform API deployment if a device-status endpoint is added. No schema migration is strictly required for the core recovery flow; adding a persisted revocation reason would require a reviewed additive migration.

Production verification must not modify customer device records directly. Use the normal app registration flow and an explicitly approved test notification.
