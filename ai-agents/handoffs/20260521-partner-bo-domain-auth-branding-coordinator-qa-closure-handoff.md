# Partner BO Domain Auth Branding - Coordinator QA Closure Handoff

## Date

2026-05-21

## From

Coordinator

## To

User

## Worktree

```text
/Users/supakit/WorkSpace/www/newPaotang
```

## Task

```text
partner-bo-domain-auth-branding
```

## Coordinator Result

QA returned PASS for Backend and Back Office delivery.

## QA Report

```text
ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md
```

## Scope Verified By QA

```text
Partner BO host bo.{storefront_host} resolves admin site config.
Partner BO login is tenant-only and can infer tenant from host without tenant_id.
Partner BO rejects central scope and cross-partner login.
Partner BO /auth/admin/me exposes only the matching tenant scope.
Partner BO blocks central dashboard/deep links and allows tenant dashboard.
Central host login keeps existing central scope behavior.
Back Office partner login hides scope, Tenant ID, and Partner ID controls.
Back Office partner login shows tenant display name and tenant-only marker.
BO same-origin /api/v1 proxy reaches platform-api with partner host resolution.
1 Partner = 1 Tenant guard/provisioning tests pass on testing DB.
```

## Commands Reported Passing

```text
git diff --check
platform-api migrate:fresh --seed on newpaotang_test only
platform-api AdminAuthTest|AdminMenuTest|BootstrapSeederTest on newpaotang_test
platform-api PartnerProvisioningTest on newpaotang_test
back-office npm run lint
back-office npm run test
back-office npm run build
runtime db:seed --no-interaction
runtime platform:smoke
runtime central admin login API smoke
```

## Coordinator Caveats

```text
Runtime DB has pending migrations, including 2026_05_21_000001_guard_partner_tenants_one_tenant_per_partner. QA validated migrations on newpaotang_test only.
Local customer service blocks alpha.newpaotang.test through Vite allowedHosts, so storefront browser proxy evidence was limited to platform-api Host-header site-config evidence.
Seeded runtime tenant theme logo_url is null, so partner BO browser evidence shows tenant display name plus fallback logo; backend feature coverage validates non-null logo propagation.
Known dirty file apps/platform-api/.phpunit.result.cache remains unstaged runtime/test noise.
```

## Decision

```text
Coordinator accepts QA PASS recommendation. No implementation defect is open for this task.
```

## Next Agent

```text
User
```
