# QA Report: M2 Partner Provisioning Core

Date: 2026-05-06
Agent: QA Tester
Task: `ai-agents/tasks/20260506-m2-partner-provisioning-core-qa.md`
Backend handoff: `ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md`
Decision: `ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md`

## Result

FAIL

The Docker validation suite passes, but QA found one acceptance-blocking issue: suspended partner tenants are marked suspended in provisioning tables, but tenant admin authentication/scope authorization still does not reject the suspended tenant or partner state.

## Findings

### Finding 1: Suspended partner tenants can still be selected as an admin tenant scope

Priority: P1

`PartnerProvisioningService::suspendPartner()` updates `partners`, `partner_tenants`, domains, and API clients to suspended states, but admin auth still builds selectable tenant scopes from `admin_user_roles` and `admin_scopes` without checking `partners.status` or `partner_tenants.status`. `RequireAdminScope` then only verifies the token scope and `X-Tenant-Id` match the session. As a result, a tenant owner role created during provisioning remains a valid login/session scope after partner suspension, which violates the acceptance requirement that suspend disables/suspends partner tenant access.

Evidence:
- `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php:346-349` suspends partner, tenant, domain, and active API clients.
- `apps/platform-api/app/Shared/Auth/AdminAuthService.php:220-252` loads tenant scopes without selecting or filtering tenant/partner status.
- `apps/platform-api/app/Shared/Auth/AdminAuthService.php:276-302` accepts the requested tenant scope by tenant id only.
- `apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php:32-38` accepts tenant requests when `X-Tenant-Id` matches the active session tenant only.

Recommended fix:
- Exclude inactive/suspended tenant scopes during login, refresh, and session resolution, or explicitly revoke/block tenant sessions when the partner is suspended.
- Add focused coverage proving owner login and existing tenant-session access are denied after `POST /admin/central/partners/{partner_id}/suspend`.

## Validation

Commands run through Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Results:
- `migrate:fresh --seed --env=testing`: PASS
- `PartnerProvisioning`: PASS, 4 tests, 127 assertions
- `SiteConfig`: PASS, 1 test, 44 assertions
- `TenantSettings`: PASS, 1 test, 25 assertions
- `PartnerApiClient`: PASS, 1 test, 27 assertions
- Full suite: PASS, 57 tests, 527 assertions

## Coverage Notes

Validated by source review and Docker tests:
- Central partner create/update/provision/suspend endpoints require the expected permissions and Idempotency-Key on writes.
- Partner type/status validation uses approved source-of-truth enums.
- Provisioning creates stable tenant/domain/config/runtime/admin-owner resources and repeated provisioning does not duplicate records.
- Owner login works after provisioning when `owner_password` is supplied.
- Partner API client responses omit `secret` and `secret_hash`, while storing only a hash.
- Public site-config resolves active hosts and returns safe unknown/inactive errors.
- Tenant settings/theme update is tenant scoped and rejects body tenant tampering.
- Audit redaction includes password/token/secret/hash/invite/invitation-style keys.

Open risk:
- Current focused tests assert suspended database state, but not denial of tenant owner login or denial of existing tenant admin sessions after suspension.

## Next Agent

Coordinator
