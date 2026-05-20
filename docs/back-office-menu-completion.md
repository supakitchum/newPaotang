# Back-office Menu Completion

Date: 2026-05-09

This inventory compares the RBAC menu seeded by `DefaultRbacMenuSeeder.php`, the current backend route registrations in `routes/api.php`, and the Back-office operations catalog. The BO app now overrides known backend fallback routes by `scope:code` before rendering sidebar links, so visible menu items no longer land on unrelated dashboard, settings, reports, partners, or agents fallback pages.

Status legend:

- `Complete`: dedicated route/page is wired to a documented and registered backend API.
- `Shared accepted`: the menu item intentionally lands on a broader operational page with matching actions or data.
- `Gap page`: the menu item lands on a dedicated BO route that explains the missing backend route instead of sending users to an unrelated fallback.

## Central Menu

| Menu code | Seeded route | BO route | Status | Notes |
| --- | --- | --- | --- | --- |
| central:dashboard | /admin/central/dashboard | /admin/central/dashboard | Complete | Dedicated dashboard page. |
| central:games | /admin/central/games | /admin/central/games | Complete | Catalog uses central games list/detail/actions. |
| central:rewards | /admin/central/rewards | /admin/central/rewards | Complete | Catalog uses central rewards list/detail/actions. |
| central:prize_checking | /admin/central/rewards | /admin/central/rewards | Shared accepted | Prize checking shares the rewards verification workflow. |
| central:stock_generation | /admin/central/stock | /admin/central/stock-generation | Shared accepted | Renamed to Stock Manager and consolidated as the single stock operations entry for generated supply, grouped stock counts, import/export, top-up progress, and stock actions. |
| central:partners | /admin/central/partners | /admin/central/partners | Complete | Catalog uses central partners list/detail/provision/suspend actions. |
| central:partner_provisioning | /admin/central/partners | /admin/central/partner-provisioning | Complete | Dedicated BO route backed by partners API and provisioning actions. |
| central:partner_quotas | /admin/central/partners | /admin/central/partner-quotas | Complete | Dedicated BO route backed by registered partner quota API. |
| central:partner_monitoring | /admin/central/partners | /admin/central/partner-monitoring | Complete | Catalog now calls registered partner monitoring list/detail APIs with `partner.monitoring.view`. |
| central:partner_usage | /admin/central/partners | /admin/central/partner-usage | Complete | Catalog now calls registered partner usage list/detail APIs with `partner.usage.view` and date filters for recent summaries. |
| central:allocations | /admin/central/allocations | /admin/central/allocations | Complete | Catalog uses central allocations list/detail/cancel action. |
| central:stock_recall | /admin/central/stock | /admin/central/stock | Shared accepted | Central stock page exposes recall action. |
| central:billing_plans | /admin/central/partners | /admin/central/billing-plans | Complete | Catalog now calls list/create/detail/update with `partner.billing.manage`; create payloads use idempotent JSON actions and detail PATCH uses the JSON editor. |
| central:alert_policies | /admin/central/partners | /admin/central/alert-policies | Complete | Catalog now calls list/create/detail/update with `partner.alert.manage`; create payloads use idempotent JSON actions and detail PATCH uses the JSON editor. |
| central:alert_events | /admin/central/partners | /admin/central/alert-events | Complete | Catalog now calls list/detail plus idempotent acknowledge/resolve actions with `partner.alert.view`/`partner.alert.manage`. |
| central:reports | /admin/central/reports | /admin/central/reports | Complete | Report index and report detail/export routes are catalog-backed. |
| central:settlement | /admin/central/settlements | /admin/central/settlements | Complete | Catalog uses settlement list/detail/approve action. |
| central:webhook_logs | /admin/central/audit-logs | /admin/central/webhook-logs | Complete | Catalog now calls registered list/detail with `audit.view`; backend redacts payload/response secret material. |
| central:audit_logs | /admin/central/audit-logs | /admin/central/audit-logs | Complete | Catalog uses central audit log list API. |
| central:admin_users | /admin/central/dashboard | /admin/central/admin-users | Complete | Dedicated BO route backed by central admin user list/detail API. |
| central:roles_permissions | /admin/central/dashboard | /admin/central/roles | Complete | Dedicated BO route backed by central role list API. |
| central:menu_management | /admin/central/dashboard | /admin/central/menu-management | Complete | Dedicated settings-style route uses GET/PUT menu management API. |
| central:system_settings | /admin/central/dashboard | /admin/central/system-settings | Complete | Settings-style route now uses registered GET/PATCH system settings API with idempotency validation on writes. |

## Tenant Menu

| Menu code | Seeded route | BO route | Status | Notes |
| --- | --- | --- | --- | --- |
| tenant:dashboard | /admin/tenant/dashboard | /admin/tenant/dashboard | Complete | Dedicated dashboard page. |
| tenant:local_stock | /admin/tenant/stock | /admin/tenant/stock | Complete | Catalog uses tenant stock list/detail/export API. |
| tenant:stock_sync | /admin/tenant/stock-sync | /admin/tenant/stock-sync | Complete | Catalog uses tenant stock sync batch APIs. |
| tenant:price_rules | /admin/tenant/settings | /admin/tenant/price-rules | Complete | Catalog now calls list/create/detail/update with tenant scoping, `price_rule.view`/`price_rule.manage`, and idempotency validation on writes. |
| tenant:reservations | /admin/tenant/reservations | /admin/tenant/reservations | Complete | Catalog uses reservations list/cancel API. |
| tenant:orders | /admin/tenant/orders | /admin/tenant/orders | Complete | Catalog uses orders list/detail/cancel/refund API. |
| tenant:customers | /admin/tenant/settings | /admin/tenant/customers | Complete | BO route remains `/admin/tenant/customers` while catalog calls registered `/admin/tenant/members` list/create/detail/update/status APIs with tenant isolation and customer permissions. |
| tenant:wallets | /admin/tenant/wallets | /admin/tenant/wallets | Complete | Catalog uses wallets list/detail/adjust API. |
| tenant:topups | /admin/tenant/topups | /admin/tenant/topups | Complete | Catalog uses topups list/detail/approve/reject/cancel API. |
| tenant:tickets | /admin/tenant/tickets | /admin/tenant/tickets | Complete | Catalog uses ticket list/detail API. |
| tenant:agents | /admin/tenant/growth/agents | /admin/tenant/growth/agents | Complete | Growth route uses documented `/admin/tenant/agents` API. |
| tenant:agent_quotas | /admin/tenant/growth/agents | /admin/tenant/growth/agent-quotas | Complete | Dedicated BO route uses agents API plus quota action. |
| tenant:payment_settings | /admin/tenant/payment-settings | /admin/tenant/payment-settings | Complete | Settings-style route uses payment settings API. |
| tenant:affiliate_programs | /admin/tenant/growth/affiliate-programs | /admin/tenant/growth/affiliate-programs | Complete | Growth route uses documented affiliate programs API. |
| tenant:affiliate_accounts | /admin/tenant/growth/affiliates | /admin/tenant/growth/affiliates | Complete | Growth route uses documented affiliates API. |
| tenant:affiliate_links | /admin/tenant/growth/affiliate-links | /admin/tenant/growth/affiliate-links | Complete | Growth route uses documented affiliate links API. |
| tenant:affiliate_attributions | /admin/tenant/growth/attributions | /admin/tenant/growth/attributions | Complete | Growth route uses documented affiliate attribution API. |
| tenant:commission_rules | /admin/tenant/growth/commission-rules | /admin/tenant/growth/commission-rules | Complete | Growth route uses documented commission rule API. |
| tenant:seo_settings | /admin/tenant/seo | /admin/tenant/seo | Complete | Settings-style route uses SEO defaults API. |
| tenant:maintenance | /admin/tenant/maintenance | /admin/tenant/maintenance | Complete | Dedicated maintenance page remains unchanged. |
| tenant:support_access_logs | /admin/tenant/support-access | /admin/tenant/support-access | Complete | Dedicated support access route remains unchanged. |
| tenant:commission_transactions | /admin/tenant/growth/commission-transactions | /admin/tenant/growth/commission-transactions | Complete | Growth route uses documented commission transaction list/approve API. |
| tenant:payouts | /admin/tenant/growth/payouts | /admin/tenant/growth/payouts | Complete | Growth route uses documented payout list/create/approve API. |
| tenant:reports | /admin/tenant/reports | /admin/tenant/reports | Complete | Report index and report detail/export routes are catalog-backed. |
| tenant:monitoring | /admin/tenant/reports | /admin/tenant/monitoring | Complete | Summary route now calls registered tenant monitoring read API with `monitoring.view` and active tenant isolation. |
| tenant:usage | /admin/tenant/reports | /admin/tenant/usage | Complete | Summary route now calls registered tenant usage read API with `usage.view`, active tenant isolation, and date filters. |
| tenant:sync_logs | /admin/tenant/sync-logs | /admin/tenant/sync-logs | Complete | Catalog uses tenant sync log list API. |
| tenant:audit_logs | /admin/tenant/audit-logs | /admin/tenant/audit-logs | Complete | Catalog uses tenant audit log list API. |
| tenant:admin_users | /admin/tenant/settings | /admin/tenant/admin-users | Complete | Dedicated BO route backed by tenant admin user list/detail API. |
| tenant:roles_permissions | /admin/tenant/settings | /admin/tenant/roles | Complete | Dedicated BO route backed by tenant role list API. |
| tenant:menu_management | /admin/tenant/settings | /admin/tenant/menu-management | Complete | Dedicated settings-style route uses GET/PUT menu management API. |
| tenant:settings | /admin/tenant/settings | /admin/tenant/settings | Complete | Settings-style route uses tenant settings API. |

## Remediation Summary

- `useAdminNavigation.ts` contains scoped route overrides for every seeded menu code that previously landed on an unrelated fallback.
- `useAdminOperationsCatalog.ts` now includes API-backed routes for admin users, roles, menu management, partner provisioning, partner quotas, agent quotas, and the backend-ready menu completion resources.
- The previously known OpenAPI-only backend route gaps for central partner monitoring, partner usage, billing plans, alert policies, alert events, system settings, webhook logs, tenant price rules, tenant members/customers, tenant monitoring, and tenant usage are now BO API-backed.
- `AdminOperationsPage.vue` keeps controlled `apiGap` handling for future gaps, supports PUT for menu management save flows, renders summary APIs, supports detail JSON PATCH where backend update routes exist, and supports JSON payload confirmation actions for create/status endpoints.
- `apps/back-office/scripts/check.mjs` verifies the route overrides, catalog entries, backend-ready snapshot paths, stale gap removal, API gap handling, and this inventory so fallback regressions are caught during BO lint/test.
