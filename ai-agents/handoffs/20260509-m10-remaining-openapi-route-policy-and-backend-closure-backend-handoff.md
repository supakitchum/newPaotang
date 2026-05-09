# 20260509-m10-remaining-openapi-route-policy-and-backend-closure - Backend Develop Handoff

Status: Ready for QA
Next Agent: Orchestrator

## What Was Done

- Read the required Backend Develop rules, Docker runtime policy, task prompt, OpenAPI contract, permission/event/ERD/status docs, prior M10 decision/handoff/report, and M10 ops docs.
- Recomputed route parity before implementation: OpenAPI 279, app 241, missing 38, undocumented 0.
- Classified all 38 remaining OpenAPI route gaps.
- Implemented 27 safe/guarded backend routes in `apps/platform-api`.
- Recomputed route parity after implementation: OpenAPI 279, app 268, missing 11, undocumented 0.
- Preserved high-risk admin security and LINE provider routes as unregistered blockers until Coordinator/security/provider policy is approved.
- Updated M10 backend completion doc and backend release gate ledger.

## Backend Files Changed

- `apps/platform-api/routes/api.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/database/migrations/2026_05_09_000002_create_remaining_openapi_route_closure_tables.php`
- `apps/platform-api/app/Models/PlatformAsset.php`
- `apps/platform-api/app/Models/TenantPaymentSetting.php`
- `apps/platform-api/app/Models/TenantPaymentChannel.php`
- `apps/platform-api/app/Models/PartnerTenantSeoSetting.php`
- `apps/platform-api/app/Models/PartnerTenantSeoPage.php`
- `apps/platform-api/app/Models/PartnerTenantRedirect.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/AssetController.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantPaymentSettingsController.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/TenantSeoController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AssetService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/TenantPaymentSettingsService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/TenantSeoService.php`
- `apps/platform-api/app/Modules/PublicSite/Http/Controllers/PublicContentController.php`
- `apps/platform-api/app/Modules/PublicSite/Services/PublicContentService.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerRealtimeController.php`
- `apps/platform-api/app/Modules/Auth/Services/CustomerRealtimeAuthService.php`
- `apps/platform-api/tests/Feature/M10RemainingOpenApiRouteClosureTest.php`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`

No `apps/back-office/**` or `apps/customer/**` files were edited.

## API Endpoints Implemented

Central admin:

- `POST /admin/central/assets/uploads`
- `GET /admin/central/assets/{asset_id}`
- `POST /admin/central/assets/{asset_id}/commit`

Tenant admin:

- `POST /admin/tenant/assets/uploads`
- `GET /admin/tenant/assets/{asset_id}`
- `POST /admin/tenant/assets/{asset_id}/commit`
- `GET /admin/tenant/payment-settings`
- `PATCH /admin/tenant/payment-settings`
- `GET /admin/tenant/payment-channels`
- `POST /admin/tenant/payment-channels`
- `GET /admin/tenant/payment-channels/{payment_channel_id}`
- `PATCH /admin/tenant/payment-channels/{payment_channel_id}`
- `DELETE /admin/tenant/payment-channels/{payment_channel_id}`
- `GET /admin/tenant/seo`
- `PATCH /admin/tenant/seo`
- `GET /admin/tenant/seo/pages`
- `POST /admin/tenant/seo/pages`
- `PATCH /admin/tenant/seo/pages/{page_id}`
- `DELETE /admin/tenant/seo/pages/{page_id}`
- `GET /admin/tenant/redirects`
- `POST /admin/tenant/redirects`
- `PATCH /admin/tenant/redirects/{redirect_id}`
- `DELETE /admin/tenant/redirects/{redirect_id}`

Public/customer:

- `GET /public/seo/page`
- `GET /public/news`
- `GET /public/stores`
- `POST /customer/realtime/auth`

## Route-By-Route Closure Table

| Route | Classification | Persistence/security/external dependency | Test evidence |
| --- | --- | --- | --- |
| `POST /admin/central/assets/uploads` | implemented guarded local/dev | `platform_assets`, central `asset.manage`, idempotency, audit; no R2 presign; returns `production_storage_ready=false` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/central/assets/{asset_id}` | implemented guarded local/dev | `platform_assets`, central `asset.manage`; central assets must have null tenant_id | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/central/assets/{asset_id}/commit` | implemented guarded local/dev | `platform_assets`, central `asset.manage`, idempotency, audit; local/dev metadata commit only | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/tenant/assets/uploads` | implemented guarded local/dev | `platform_assets`, tenant `asset.manage`, tenant scope, idempotency, audit; no R2 presign | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/assets/{asset_id}` | implemented guarded local/dev | `platform_assets`, tenant `asset.manage`, tenant-owned asset lookup | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/tenant/assets/{asset_id}/commit` | implemented guarded local/dev | `platform_assets`, tenant `asset.manage`, tenant scope, idempotency, audit; local/dev metadata commit only | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/payment-settings` | implemented now | `tenant_payment_settings`, tenant `payment_settings.view`; provider readiness remains false | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `PATCH /admin/tenant/payment-settings` | implemented now | `tenant_payment_settings`, tenant `payment_settings.manage`, idempotency, audit, secret redaction | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/payment-channels` | implemented now | `tenant_payment_channels`, tenant `payment_settings.view` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/tenant/payment-channels` | implemented now | `tenant_payment_channels`, tenant `payment_settings.manage`, idempotency, audit, secret redaction | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/payment-channels/{payment_channel_id}` | implemented now | tenant-scoped `tenant_payment_channels`, tenant `payment_settings.view` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `PATCH /admin/tenant/payment-channels/{payment_channel_id}` | implemented now | tenant-scoped `tenant_payment_channels`, tenant `payment_settings.manage`, idempotency, audit, secret redaction | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `DELETE /admin/tenant/payment-channels/{payment_channel_id}` | implemented now | tenant-scoped archive to `tenant_payment_channels.status=archived`, idempotency, audit | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /public/seo/page` | implemented now | host-resolved tenant context plus `partner_tenant_seo_settings/pages` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /public/news` | implemented guarded local/dev | host-resolved tenant context; returns empty data with `content_source_status=not_configured` until content source is approved | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /public/stores` | implemented now | host-resolved tenant context; derives stores from `local_stock_items.store_id` with available stock | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/seo` | implemented now | `partner_tenant_seo_settings`, tenant `seo.view` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `PATCH /admin/tenant/seo` | implemented now | `partner_tenant_seo_settings`, tenant `seo.update`, idempotency, audit `seo.changed` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/seo/pages` | implemented now | `partner_tenant_seo_pages`, tenant `seo.view` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/tenant/seo/pages` | implemented now | `partner_tenant_seo_pages`, tenant `seo.update`, idempotency, audit `seo.changed` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `PATCH /admin/tenant/seo/pages/{page_id}` | implemented now | tenant-scoped `partner_tenant_seo_pages`, tenant `seo.update`, idempotency, audit | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `DELETE /admin/tenant/seo/pages/{page_id}` | implemented now | tenant-scoped delete from `partner_tenant_seo_pages`, tenant `seo.update`, idempotency, audit | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `GET /admin/tenant/redirects` | implemented now | `partner_tenant_redirects`, tenant `seo.view` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /admin/tenant/redirects` | implemented now | `partner_tenant_redirects`, tenant `seo.redirect.manage`, idempotency, audit `seo.changed` | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `PATCH /admin/tenant/redirects/{redirect_id}` | implemented now | tenant-scoped `partner_tenant_redirects`, tenant `seo.redirect.manage`, idempotency, audit | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `DELETE /admin/tenant/redirects/{redirect_id}` | implemented now | tenant-scoped delete from `partner_tenant_redirects`, tenant `seo.redirect.manage`, idempotency, audit | `M10RemainingOpenApiRouteClosureTest`, full suite |
| `POST /auth/admin/password/forgot` | security/provider policy required | Needs reset token hashing, expiry, replay, mail/provider policy, audit, enumeration-safe responses | Not implemented by design |
| `POST /auth/admin/password/reset` | security/provider policy required | Needs hashed reset tokens, password policy, session revocation, audit, replay protection | Not implemented by design |
| `POST /auth/admin/password/change` | security/provider policy required | Needs credential lifecycle policy, current-password verification, session revocation decision, audit | Not implemented by design |
| `GET /auth/admin/2fa` | security/provider policy required | Needs 2FA state/storage contract and recovery-code policy | Not implemented by design |
| `DELETE /auth/admin/2fa` | security/provider policy required | Needs disable verification/recovery policy, audit, idempotency | Not implemented by design |
| `POST /auth/admin/2fa/setup` | security/provider policy required | Needs TOTP secret generation/storage policy and recovery-code handling | Not implemented by design |
| `POST /auth/admin/2fa/enable` | security/provider policy required | Needs TOTP verification, hashed secrets/recovery codes, replay protection | Not implemented by design |
| `POST /auth/admin/2fa/recovery-codes` | security/provider policy required | Needs recovery-code hashing/rotation/display-once policy | Not implemented by design |
| `POST /auth/admin/2fa/verify` | security/provider policy required | Needs challenge-token lifecycle, expiry, replay protection, audit | Not implemented by design |
| `POST /customer/auth/line/login` | security/provider policy required | Needs LINE credentials, state storage, callback URL, account linking policy | Not implemented by design |
| `GET /customer/auth/line/callback` | security/provider policy required | Needs LINE token exchange/profile verification, account linking, state validation | Not implemented by design |
| `POST /customer/realtime/auth` | implemented guarded local/dev | customer bearer auth, tenant host isolation, customer-owned channel allowlist, HMAC signature; returns `production_realtime_ready=false` | `M10RemainingOpenApiRouteClosureTest`, `CustomerAuthTest`, full suite |

## Permissions/Tenant Checks Enforced

- Central assets: `asset.manage`, active central admin scope, null tenant asset records.
- Tenant assets: `asset.manage`, active tenant admin scope, matching `X-Tenant-Id`, tenant-owned asset lookup.
- Tenant payment settings/channels: `payment_settings.view` and `payment_settings.manage`, tenant-scoped records, idempotent writes, audit logs, no raw secret persistence/response.
- Tenant SEO/pages/redirects: `seo.view`, `seo.update`, and `seo.redirect.manage`, tenant-scoped records, idempotent writes, audit logs.
- Public SEO/news/stores: active tenant host resolution, no admin/customer tenant bypass.
- Customer realtime auth: authenticated customer session must belong to request host tenant; requested channel must match tenant/customer allowlist.

## Permission/Event/ERD/Status Parity Findings

- New persistence follows ERD-backed domains for assets, payment settings/channels, SEO pages, and redirects.
- New tables have concrete Eloquent models and passed `BackendModelComplianceTest`.
- New admin writes audit through `AuditLogger`.
- `seo.changed` is used for SEO and redirect changes per `docs/permissions.md`.
- Payment provider and asset storage statuses intentionally preserve `blocked_external` / `production_*_ready=false` boundaries.
- No new outbox/inbox domain events were introduced in this slice.

## Commands/Tests Run

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=M10RemainingOpenApiRouteClosureTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=M10CloudflareHttpsWafCdnR2Test
docker compose run --rm platform-api php artisan test --filter=M10HorizonReverbSchedulerHardeningTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

Results:

- `M10RemainingOpenApiRouteClosureTest`: 5 tests, 101 assertions, passed.
- `BackendModelComplianceTest`: 7 tests, 1276 assertions, passed.
- `AdminAuthTest`: 9 tests, 78 assertions, passed.
- `CustomerAuthTest`: 2 tests, 40 assertions, passed.
- `AdminOperationsTest`: 7 tests, 95 assertions, passed.
- `M10CloudflareHttpsWafCdnR2Test`: 5 tests, 136 assertions, passed.
- `M10HorizonReverbSchedulerHardeningTest`: 4 tests, 68 assertions, passed.
- Full backend suite: 146 tests, 3904 assertions, passed.
- `route:list`: passed, 273 Laravel routes shown.
- `platform:smoke`: passed after reseeding runtime state.

Static route parity:

```text
Before: OPENAPI_ROUTES=279 APP_ROUTES=241 MISSING_IN_APP=38 UNDOCUMENTED_IN_APP=0
After:  OPENAPI_ROUTES=279 APP_ROUTES=268 MISSING_IN_APP=11 UNDOCUMENTED_IN_APP=0
```

## Known Risks / Questions

- Asset upload intent and commit are intentionally local/dev metadata only. Production R2/CDN presign, object verification, bucket policy, and lifecycle decisions remain Coordinator/Ops-owned.
- Payment settings/channels persist safe config only. External provider activation, credential source, webhook secret policy, and production readiness remain Coordinator/Ops-owned.
- Public news has no approved content/source-of-truth persistence. The route is registered and safely returns an empty list with `content_source_status=not_configured`.
- Customer realtime auth signs only scoped channels. Reverb public runtime, TLS, scaling, and package/supervision readiness remain Coordinator/Ops-owned.
- Admin password lifecycle and 2FA should not be sent to QA as implementation work until Coordinator/Security approves the policy.
- LINE auth should not be implemented until LINE provider credentials, state/callback, and account-linking policy are approved.

## Next Agent

Orchestrator

Recommended next step: send implemented/classified backend slice to QA Tester, and separately route the remaining 11 blocked OpenAPI routes to Coordinator/Security/Ops for policy decisions before implementation.
