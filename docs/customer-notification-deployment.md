# Customer Notification Deployment

Last updated: 2026-07-21

This runbook covers production configuration for the customer notification
inbox and native push. The inbox, unread state, realtime refresh, and admin
send flow remain available when FCM is unavailable. Flutter Web does not use
browser push in this phase.

## Platform API And Worker

Use one Firebase project for the customer native application. Grant the
server service account only the Firebase Cloud Messaging permissions required
to send messages. Never commit its JSON key or store it in the application
database.

The production Kubernetes secret must provide:

- `FIREBASE_PROJECT_ID`: the Firebase project ID used by both native apps.
- `firebase-service-account.json`: the complete service-account JSON document.

Runtime configuration also exposes `CUSTOMER_PUSH_DEVICE_STALE_DAYS`. It
defaults to `270`, matching FCM's Android inactivity expiry window. Set a
tenant-independent operational threshold appropriate for the deployed apps,
or set `0` to disable proactive stale-device revocation.

`deploy/digitalocean/platform-api.yaml` mounts the JSON key read-only at
`/var/run/secrets/newpaotang/firebase-service-account.json` for the API and the
critical worker. `GOOGLE_APPLICATION_CREDENTIALS` points to that path, and the
critical worker consumes the `notification` queue.

After applying the secret and manifests, restart and verify both workloads:

```bash
kubectl -n newpaotang-prod rollout restart deployment/platform-api
kubectl -n newpaotang-prod rollout restart deployment/platform-api-worker-critical
kubectl -n newpaotang-prod rollout status deployment/platform-api
kubectl -n newpaotang-prod rollout status deployment/platform-api-worker-critical
```

Do not print the mounted JSON or FCM access tokens in deploy logs. Delivery
history stores only safe status and error codes. Transient provider/network
failures use bounded retries; missing provider configuration records a skipped
`provider_unavailable` delivery. `UNREGISTERED` and token-specific
`INVALID_ARGUMENT` revoke the device. A generic invalid message payload does
not revoke a valid token.

The application scheduler must run every minute. It invokes
`customer-notifications:recover-deliveries --limit=100`, which redispatches a
never-dispatched or retry-due delivery, recovers a worker left in `sending`
after its ten-minute lease, and resumes incomplete tenant news/activity
fan-outs. It also revokes up to 100 active push-device rows whose
`last_seen_at` is outside the configured inactivity window. Stale-device
cleanup never deletes the registration or inbox data, and a later client
registration reactivates that installation. The final update rechecks
`last_seen_at`, so a concurrent app registration wins over cleanup. Delivery
rows are claimed under a database lock and fan-out jobs are unique by
notification/cursor, so a delayed original job and a recovery job do not send
the same push concurrently. Confirm scheduler registration after a deploy
without printing secrets:

```bash
php artisan schedule:list | grep customer-notifications:recover-deliveries
```

For a controlled maintenance run, `--device-limit` bounds each stale-device
batch and `--device-stale-days` temporarily overrides configuration. Passing
`--device-stale-days=0` leaves device registrations unchanged.

## Android Build

Download `google-services.json` for the partner release application ID and
inject it at `apps/customer_flutter/android/app/google-services.json` only for
the build. The release build intentionally fails when that file is absent.
The file is ignored by git and must be removed from shared build workspaces
after the artifact is produced.

The Android Firebase application ID must match
`CUSTOMER_FLUTTER_APPLICATION_ID`. The manifest already declares Android 13
notification permission, the `customer_updates` channel, and the monochrome
notification icon.

Run the native preflight before the release build:

```bash
cd apps/customer_flutter
dart run tool/production_preflight.dart --target=android --check-files
flutter build appbundle --release
```

## iOS Build And APNs

Create an iOS Firebase application whose bundle ID matches
`PRODUCT_BUNDLE_IDENTIFIER`. Configure the APNs authentication key or
certificate in Firebase, and enable Push Notifications for the same App ID in
the Apple Developer portal and signing profile.

Keep `GoogleService-Info.plist` outside the repository and expose its absolute
path to Xcode:

```bash
export CUSTOMER_FLUTTER_FIREBASE_IOS_PLIST=/secure/customer/GoogleService-Info.plist
cd apps/customer_flutter
dart run tool/production_preflight.dart --target=ios --check-files
flutter build ipa --release
```

The Xcode build phase copies the plist into the application bundle and rejects
missing Firebase identifiers or a plist whose `BUNDLE_ID` differs from the
release bundle. `Runner.entitlements` supplies the environment-specific APNs
entitlement and `Info.plist` enables `remote-notification` background mode.

Set `CUSTOMER_FLUTTER_APS_ENVIRONMENT` to `development` for development
profiles and `production` for App Store/TestFlight profiles through the
release configuration or CI secret-backed xcconfig.

## Acceptance Matrix

Simulator and emulator runs can verify UI, permission flows, foreground local
notifications, mocked payloads, auth/PIN retention, and destination routing.
Production readiness still requires real FCM delivery on physical devices.

Verify separately on physical iOS and Android:

1. Permission accepted and denied without blocking the inbox.
2. Device registration after login and PIN unlock.
3. Foreground push appears locally and refreshes inbox/unread count.
4. Background push opens the exact allowlisted destination.
5. Terminated-app push opens through login/PIN when required.
6. FCM token refresh updates the same installation.
7. Explicit logout revokes the installation and the old account receives no
   subsequent push on that installation.
8. Read/read-all state synchronizes across two open customer sessions.
9. FCM outage leaves the business transaction and in-app notification intact,
   with retry/failure visible in tenant notification history.

Record device model, OS version, build number, Firebase project, permission
state, payload event key, expected route, actual route, delivery state, and
test timestamp. Do not mark native push production-ready until every physical
device case passes.
