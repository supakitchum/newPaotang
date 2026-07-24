# NewPaotang Support API

Isolated customer-support service for Customer Flutter and tenant Back Office.
This service owns its database, Valkey, queue workers, attachments, and Reverb
application. It must never connect directly to the Platform/Order database.

## Trust Boundary

```text
Customer Flutter / Back Office
  -> Platform token broker
  -> short-lived RS256 Support JWT (10 minutes)
  -> Support API / Support Reverb
  -> newpaotang_support + support-valkey

Support outbox
  -> HMAC-signed Platform internal ingress
  -> existing Customer Notification / FCM pipeline
```

- Platform brokers authenticate the existing Customer/Admin session and copy
  only tenant, actor, locale, display-name, member-code, and Support permission
  claims into the JWT.
- Support verifies the JWT with the Platform public key. It never queries
  Platform to authenticate a request.
- Support stores snapshots in `support_tenants` and `support_actors`; there are
  no cross-database foreign keys.
- Order, Cart, Checkout, and payment modules do not call Support.

## Databases

| Purpose | Database |
| --- | --- |
| Runtime | `newpaotang_support` |
| Automated tests | `newpaotang_support_test` |

Never run Support migrations against `newpaotang`. Do not run a runtime Support
migration until the owner explicitly requests that exact action in the current
turn.

Safe test example:

```sh
docker compose run --rm --no-deps \
  -e APP_ENV=testing \
  -e APP_URL=http://localhost \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=55433 \
  -e DB_DATABASE=newpaotang_support_test \
  -e DB_TEST_DATABASE=newpaotang_support_test \
  -e CACHE_STORE=array \
  -e QUEUE_CONNECTION=sync \
  -e BROADCAST_CONNECTION=null \
  support-api php artisan test --env=testing
```

## Runtime Components

- `support-api`: REST, signed attachment delivery, and Reverb authorization.
- `support-worker`: queue assignment and outbox delivery.
- `support-scheduler`: scheduled queue draining and outbox recovery.
- `support-reverb`: isolated realtime server/app key.
- `support-postgres`: Support records only.
- `support-valkey`: Support cache, queues, and broadcast coordination only.

Local opt-in profiles:

```sh
docker compose --profile worker --profile scheduler --profile realtime up -d \
  support-postgres support-valkey support-api support-worker \
  support-scheduler support-reverb
```

## Required Configuration

Support:

- `DB_DATABASE=newpaotang_support`
- `DB_TEST_DATABASE=newpaotang_support_test`
- `SUPPORT_JWT_PUBLIC_KEY_PATH`
- `REVERB_APP_ID`, `REVERB_APP_KEY`, `REVERB_APP_SECRET`
- `SUPPORT_CORS_ALLOWED_ORIGINS`
- `SUPPORT_CORS_ALLOWED_ORIGIN_PATTERNS`
- `SUPPORT_REVERB_ALLOWED_ORIGINS`
- `PLATFORM_NOTIFICATION_INGRESS_URL`
- `PLATFORM_SUPPORT_INGRESS_SECRET`
- private attachment disk credentials when not using local storage

Platform:

- `SUPPORT_API_URL`
- `SUPPORT_REALTIME_URL`, `SUPPORT_REALTIME_KEY`
- `SUPPORT_JWT_PRIVATE_KEY_PATH`
- `SUPPORT_JWT_ISSUER`, `SUPPORT_JWT_AUDIENCE`
- `SUPPORT_JWT_TTL_SECONDS=600`
- the same `PLATFORM_SUPPORT_INGRESS_SECRET`

Use an independently generated RSA key pair. Mount the private key into
Platform only and the public key into Support only. Rotate by deploying a
compatible public-key set or by allowing the previous key for at least the
10-minute token lifetime before removal.

## API Entry Points

Platform brokers:

- `POST /api/v1/customer/support-session`
- `POST /api/v1/admin/tenant/support-session`

Support Customer API:

- bootstrap, FAQ search/feedback, unread count
- ticket list/create/detail, message pagination/send/read
- close and one-time rating
- Support Reverb channel authorization

Support Admin API:

- My Tickets, Queue, All, Closed
- reply, mark waiting, close, assign
- availability/heartbeat/capacity
- agent, category, FAQ, settings, and report management

All Support domain mutation requests, including heartbeat and monotonic read
receipt updates, require `Idempotency-Key`. See `openapi.yaml` for the route
contract.

## Attachments

- JPEG, PNG, and WebP only.
- Defaults: four images per message and 8 MB per image; tenant settings can
  lower these limits.
- Images are decoded and re-encoded as WebP, stripping source metadata.
- Storage is private. Clients receive a short-lived signed download URL.
- Messages and attachments are immutable after creation.

## Runtime Content

Notification text defaults live in `config/support.php`. A tenant may override
localized text through:

```json
{
  "notifications": {
    "support.message.created": {
      "title": {"th-TH": "...", "en-US": "..."},
      "body": {"th-TH": "{message}", "en-US": "{message}"}
    }
  }
}
```

Supported variables are `{ticket_no}` and `{message}`. The Support outbox sends
localized maps to Platform, which owns Customer Notification and FCM delivery.

## Rollout

1. Provision Support Postgres, Valkey, private attachment storage, worker,
   scheduler, and Reverb independently from Platform/Order.
2. Install the Support schema in `newpaotang_support`.
3. Configure RSA and HMAC secrets; verify health and outbox delivery.
4. Deploy Platform brokers and RBAC.
5. Deploy Back Office and Customer Flutter.
6. Enable the `customer_support` tenant feature flag for an internal tenant.
7. Run queue/chat/notification/manual mobile acceptance.
8. Expand the feature flag tenant by tenant.

During failure testing, stop only Support DB/Valkey/worker/Reverb and verify
Order/Cart/Checkout remain available and do not gain Support latency.

The DOKS manifests are in `deploy/digitalocean-support/support-api.yaml`. The production
workflow builds the image on every deploy branch push but applies Support only
for a manually approved `deploy_support=true` run. Support schema migration is
separately gated by `run_support_migration=true`; neither gate should be opened
before the isolated database, Valkey, keys, storage, and origins are ready.
