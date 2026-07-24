# NewPaotang Permission And Menu Matrix

NewPaotang uses one RBAC and menu engine with separate central and tenant scopes. Role names are never enough for authorization. Backend checks must include scope, permission, and tenant/partner constraints.

## Scope Model

```text
central scope -> platform-wide central operations
tenant scope -> one partner tenant only
```

Permission cache keys must include:

```text
admin_user_id
scope_type
scope_id
tenant_id when scope_type = tenant
role_version
permission_cache_version
```

Default is deny unless permission is explicitly granted.

## Permission Naming Convention

Permission codes use lowercase snake/dot notation:

```text
resource.action
resource.sub_resource.action
```

Action names should come from this shared vocabulary when possible:

```text
view
create
update
delete
manage
approve
publish
verify
export
sync
cancel
schedule
bypass
impersonate_customer
impersonate_admin
elevated_action
audit
```

Permission scope is not encoded in the code string. Scope is enforced by RBAC context:

```text
central + stock.allocate
tenant + stock.sync
```

Do not authorize by role name alone. Do not create tenant-specific permission names such as `tenant_a.stock.view`.

## Central Roles

```text
super_admin
admin
stock_manager
partner_manager
finance
support
auditor
```

## Central Permissions

| Code | Description |
| --- | --- |
| dashboard.view | View central dashboard |
| game.view | View games |
| game.create | Create games |
| game.update | Update games |
| game.close | Close games |
| game.reward | Manage game reward state |
| reward.view | View reward results |
| reward.create | Record reward results |
| reward.verify | Verify reward summaries |
| reward.publish | Publish rewards |
| reward.correct | Correct published rewards through correction flow |
| reward.audit | View reward audit |
| stock.view | View master stock |
| stock.generate | Generate/import master stock |
| stock.allocate | Allocate stock to partners |
| stock.recall | Recall allocated stock |
| stock.export | Export stock data |
| partner.view | View partners |
| partner.create | Create partners |
| partner.update | Update partners |
| partner.suspend | Suspend partners |
| partner.api.manage | Manage partner API clients |
| partner.quota.manage | Manage partner quotas |
| partner.provision | Provision partner tenant defaults |
| partner.monitoring.view | View partner monitoring profile and health |
| partner.monitoring.manage | Manage partner monitoring profile |
| partner.usage.view | View partner usage meters |
| partner.usage.manage | Manage partner usage meters and limits |
| partner.billing.view | View partner billing bindings |
| partner.billing.manage | Manage partner billing plans and bindings |
| partner.alert.view | View partner alert policies and events |
| partner.alert.manage | Manage partner alert policies and event states |
| settlement.view | View settlements |
| settlement.approve | Approve settlements |
| report.view | View central reports |
| admin_user.manage | Manage central admin users |
| role.manage | Manage central roles |
| menu.manage | Manage central menus |
| audit.view | View central audit logs |
| system.settings.manage | Manage platform settings |
| asset.manage | Manage central asset upload intents |
| support_access.audit | View support access audits |
```

## Central Menu

| Menu Key | Required Permission |
| --- | --- |
| dashboard | dashboard.view |
| games | game.view |
| rewards | reward.view |
| prize_checking | reward.view |
| master_stock | stock.view |
| stock_generation | stock.generate |
| partners | partner.view |
| partner_provisioning | partner.provision |
| partner_quotas | partner.quota.manage |
| partner_monitoring | partner.monitoring.view |
| partner_usage | partner.usage.view |
| allocations | stock.allocate |
| billing_plans | partner.billing.manage |
| alert_policies | partner.alert.manage |
| alert_events | partner.alert.view |
| reports | report.view |
| settlement | settlement.view |
| webhook_logs | audit.view |
| audit_logs | audit.view |
| admin_users | admin_user.manage |
| roles_permissions | role.manage |
| menu_management | menu.manage |
| system_settings | system.settings.manage |

## Tenant Roles

```text
owner
admin
stock_staff
finance
support
agent_manager
affiliate_manager
auditor
```

## Tenant Permissions

| Code | Description |
| --- | --- |
| dashboard.view | View tenant dashboard |
| stock.view | View tenant-local stock |
| stock.sync | Run or view stock sync |
| stock.export | Export tenant stock |
| reservation.view | View reservations |
| reservation.cancel | Cancel reservations |
| order.view | View orders |
| order.update | Update orders |
| order.cancel | Cancel orders |
| order.refund | Refund orders |
| customer.view | View customers |
| customer.create | Create customers |
| customer.update | Update customers |
| customer.suspend | Suspend or disable customers |
| wallet.view | View wallets |
| wallet.adjust | Adjust wallet through audited ledger flow |
| topup.view | View topups |
| topup.approve | Approve topups |
| topup.reject | Reject topups |
| topup.cancel | Cancel topups |
| ticket.view | View tickets |
| reward_claim.view | View reward cashout claims |
| reward_claim.approve | Approve reward cashout claims |
| reward_claim.reject | Reject reward cashout claims |
| reward_claim.pay | Pay reward cashout claims |
| agent.view | View agents |
| agent.create | Create agents |
| agent.update | Update agents |
| agent.quota.manage | Manage agent quotas |
| price_rule.view | View tenant price rules |
| price_rule.manage | Manage tenant price rules |
| payment_settings.view | View tenant payment settings and channels |
| payment_settings.manage | Manage tenant payment settings and channels |
| affiliate.view | View affiliate data |
| affiliate.create | Create affiliate records |
| affiliate.update | Update affiliate records |
| affiliate_program.view | View affiliate programs |
| affiliate_program.manage | Manage affiliate programs |
| affiliate_link.view | View affiliate links |
| affiliate_link.manage | Manage affiliate links |
| affiliate_attribution.view | View affiliate attributions |
| commission.view | View commissions |
| commission.approve | Approve commissions |
| commission_rule.view | View commission rules |
| commission_rule.manage | Manage commission rules |
| payout.manage | Manage payouts |
| report.view | View tenant reports |
| monitoring.view | View tenant monitoring and health |
| usage.view | View tenant usage meters |
| sync_log.view | View sync logs |
| seo.view | View SEO settings |
| seo.update | Update SEO settings |
| seo.redirect.manage | Manage tenant redirects |
| maintenance.view | View maintenance settings |
| maintenance.update | Update maintenance settings |
| maintenance.schedule | Schedule maintenance |
| maintenance.bypass | Bypass maintenance |
| support_access.request | Request support access |
| support_access.approve | Approve support access |
| support_access.impersonate_customer | Impersonate customer with limits |
| support_access.impersonate_admin | Impersonate tenant admin with approval |
| support_access.elevated_action | Request or use elevated support action |
| support_access.audit | View support access audit |
| admin_user.manage | Manage tenant admin users |
| role.manage | Manage tenant roles |
| menu.manage | Manage tenant menus |
| settings.view | View tenant settings |
| settings.manage | Manage tenant settings |
| asset.manage | Manage tenant asset upload intents |
| audit.view | View tenant audit logs |
```

## Tenant Menu

| Menu Key | Required Permission |
| --- | --- |
| dashboard | dashboard.view |
| local_stock | stock.view |
| stock_sync | stock.sync |
| price_rules | price_rule.view |
| reservations | reservation.view |
| orders | order.view |
| customers | customer.view |
| wallets | wallet.view |
| topups | topup.view |
| tickets | ticket.view |
| agents | agent.view |
| agent_quotas | agent.quota.manage |
| payment_settings | payment_settings.view |
| affiliate_programs | affiliate_program.view |
| affiliate_accounts | affiliate.view |
| affiliate_links | affiliate_link.view |
| affiliate_attributions | affiliate_attribution.view |
| commission_rules | commission_rule.view |
| seo_settings | seo.view |
| maintenance | maintenance.view |
| support_access_logs | support_access.audit |
| commission_transactions | commission.view |
| payouts | payout.manage |
| reports | report.view |
| monitoring | monitoring.view |
| usage | usage.view |
| sync_logs | sync_log.view |
| audit_logs | audit.view |
| admin_users | admin_user.manage |
| roles_permissions | role.manage |
| menu_management | menu.manage |
| settings | settings.view |

## Back-office API Permission Mapping

| API | Scope | Required Permission |
| --- | --- | --- |
| `GET /admin/central/dashboard/summary` | central | dashboard.view |
| `GET /admin/central/menu` | central | authenticated central scope |
| `POST /admin/central/realtime/auth` | central | authenticated central scope; stock generation channels require stock.generate; stock table channels require stock.view |
| `GET /admin/central/menu-management` | central | menu.manage |
| `PUT /admin/central/menu-management` | central | menu.manage |
| `GET /admin/central/admin-users` | central | admin_user.manage |
| `POST /admin/central/admin-users` | central | admin_user.manage |
| `GET /admin/central/admin-users/{admin_user_id}` | central | admin_user.manage |
| `PATCH /admin/central/admin-users/{admin_user_id}` | central | admin_user.manage |
| `DELETE /admin/central/admin-users/{admin_user_id}` | central | admin_user.manage |
| `GET /admin/central/roles` | central | role.manage |
| `POST /admin/central/roles` | central | role.manage |
| `PATCH /admin/central/roles/{role_id}` | central | role.manage |
| `DELETE /admin/central/roles/{role_id}` | central | role.manage |
| `GET /admin/central/partners` | central | partner.view |
| `POST /admin/central/partners` | central | partner.create |
| `GET /admin/central/partners/{partner_id}` | central | partner.view |
| `PATCH /admin/central/partners/{partner_id}` | central | partner.update |
| `PATCH /admin/central/partners/{partner_id}/profile` | central | partner.update |
| `POST /admin/central/partners/{partner_id}/provision` | central | partner.provision |
| `POST /admin/central/partners/{partner_id}/suspend` | central | partner.suspend |
| `GET /admin/central/partner-quotas` | central | partner.quota.manage |
| `POST /admin/central/partner-quotas` (retired write: `retired_flow`) | central | partner.quota.manage |
| `PATCH /admin/central/partner-quotas/{quota_id}` (retired write: `retired_flow`) | central | partner.quota.manage |
| `GET /admin/central/partner-api-clients` | central | partner.api.manage |
| `POST /admin/central/partner-api-clients` | central | partner.api.manage |
| `PATCH /admin/central/partner-api-clients/{client_id}` | central | partner.api.manage |
| `DELETE /admin/central/partner-api-clients/{client_id}` | central | partner.api.manage |
| `GET /admin/central/stock` | central | stock.view |
| `GET /admin/central/stock/summary` | central | stock.view OR stock.generate |
| `GET /admin/central/stock/{game_id}/numbers/{full_number}` | central | stock.view |
| `GET /admin/central/stock/patterns` | central | stock.view |
| `GET /admin/central/stock/limit-overrides` | central | stock.view |
| `GET /admin/central/stock/settings` | central | stock.generate |
| `PATCH /admin/central/stock/settings` | central | stock.generate |
| `PUT /admin/central/stock/limit-settings` | central | stock.generate |
| `PUT /admin/central/stock/limit-overrides` | central | stock.generate |
| `POST /admin/central/stock/imports` | central | stock.generate |
| `POST /admin/central/stock/generate` | central | stock.generate |
| `GET /admin/central/stock/generation-batches` | central | stock.generate |
| `GET /admin/central/stock/generation-batches/{batch_id}` | central | stock.generate |
| `POST /admin/central/stock/exports` | central | stock.export |
| `POST /admin/central/stock/{stock_item_id}/recall` | central | stock.recall |
| `GET /admin/central/games` | central | game.view |
| `POST /admin/central/games` | central | game.create |
| `GET /admin/central/games/{game_id}` | central | game.view |
| `PATCH /admin/central/games/{game_id}` | central | game.update |
| `POST /admin/central/games/{game_id}/close` | central | game.close |
| `POST /admin/central/games/{game_id}/archive` | central | game.update |
| `GET /admin/central/allocations` | central | stock.allocate |
| `GET /admin/central/allocation-options/partners` | central | stock.allocate |
| `GET /admin/central/allocation-options/tenants` | central | stock.allocate |
| `GET /admin/central/allocation-options/games` | central | stock.allocate |
| `POST /admin/central/allocations` | central | stock.allocate |
| `PUT /admin/central/allocations/partner-percent` | central | stock.allocate |
| `GET /admin/central/allocations/{allocation_id}` | central | stock.allocate |
| `POST /admin/central/allocations/{allocation_id}/recall-all` | central | stock.allocate |
| `POST /admin/central/allocations/{allocation_id}/redistribute` | central | stock.allocate |
| `POST /admin/central/allocations/{allocation_id}/cancel` | central | stock.allocate |
| `GET /admin/central/rewards` | central | reward.view |
| `POST /admin/central/rewards` | central | reward.create |
| `GET /admin/central/rewards/{reward_result_id}` | central | reward.view |
| `PATCH /admin/central/rewards/{reward_result_id}` | central | reward.create |
| `GET /admin/central/rewards/{reward_result_id}/check-batches` | central | reward.audit |
| `POST /admin/central/rewards/{reward_result_id}/verify` | central | reward.verify |
| `POST /admin/central/rewards/{reward_result_id}/publish` | central | reward.publish |
| `POST /admin/central/rewards/{reward_result_id}/correct` | central | reward.correct |
| `GET /admin/central/settlements` | central | settlement.view |
| `GET /admin/central/settlements/{settlement_id}` | central | settlement.view |
| `POST /admin/central/settlements/{settlement_id}/approve` | central | settlement.approve |
| `GET /admin/central/partner-monitoring` | central | partner.monitoring.view |
| `GET /admin/central/partner-monitoring/{monitoring_profile_id}` | central | partner.monitoring.view |
| `PATCH /admin/central/partner-monitoring/{monitoring_profile_id}` | central | partner.monitoring.manage |
| `GET /admin/central/partner-usage` | central | partner.usage.view |
| `GET /admin/central/partner-usage/{usage_meter_id}` | central | partner.usage.view |
| `PATCH /admin/central/partner-usage/{usage_meter_id}` | central | partner.usage.manage |
| `GET /admin/central/billing-plans` | central | partner.billing.view |
| `POST /admin/central/billing-plans` | central | partner.billing.manage |
| `GET /admin/central/billing-plans/{billing_plan_id}` | central | partner.billing.view |
| `PATCH /admin/central/billing-plans/{billing_plan_id}` | central | partner.billing.manage |
| `GET /admin/central/billing-bindings` | central | partner.billing.view |
| `GET /admin/central/billing-bindings/{billing_binding_id}` | central | partner.billing.view |
| `PATCH /admin/central/billing-bindings/{billing_binding_id}` | central | partner.billing.manage |
| `GET /admin/central/alert-policies` | central | partner.alert.view |
| `POST /admin/central/alert-policies` | central | partner.alert.manage |
| `GET /admin/central/alert-policies/{alert_policy_id}` | central | partner.alert.view |
| `PATCH /admin/central/alert-policies/{alert_policy_id}` | central | partner.alert.manage |
| `GET /admin/central/alert-events` | central | partner.alert.view |
| `GET /admin/central/alert-events/{alert_event_id}` | central | partner.alert.view |
| `POST /admin/central/alert-events/{alert_event_id}/acknowledge` | central | partner.alert.manage |
| `POST /admin/central/alert-events/{alert_event_id}/resolve` | central | partner.alert.manage |
| `GET /admin/central/system-settings` | central | system.settings.manage |
| `PATCH /admin/central/system-settings` | central | system.settings.manage |
| `POST /admin/central/assets/uploads` | central | asset.manage |
| `GET /admin/central/assets/{asset_id}` | central | asset.manage |
| `POST /admin/central/assets/{asset_id}/commit` | central | asset.manage |
| `GET /admin/central/export-jobs/{export_job_id}` | central | matching export source permission |
| `GET /admin/central/export-jobs/{export_job_id}/download` | central | matching export source permission |
| `GET /admin/central/webhook-logs` | central | audit.view |
| `GET /admin/central/webhook-logs/{webhook_log_id}` | central | audit.view |
| `GET /admin/central/audit-logs` | central | audit.view |
| `GET /admin/central/sync-logs` | central | audit.view |
| `GET /admin/central/sale-price-rules` | central | price_rule.view |
| `POST /admin/central/sale-price-rules` | central | price_rule.manage |
| `GET /admin/central/sale-price-rules/{sale_price_rule_id}` | central | price_rule.view |
| `PATCH /admin/central/sale-price-rules/{sale_price_rule_id}` | central | price_rule.manage |
| `GET /admin/tenant/admin-users` | tenant | admin_user.manage |
| `POST /admin/tenant/admin-users` | tenant | admin_user.manage |
| `GET /admin/tenant/admin-users/{admin_user_id}` | tenant | admin_user.manage |
| `PATCH /admin/tenant/admin-users/{admin_user_id}` | tenant | admin_user.manage |
| `DELETE /admin/tenant/admin-users/{admin_user_id}` | tenant | admin_user.manage |
| `GET /admin/tenant/roles` | tenant | role.manage |
| `POST /admin/tenant/roles` | tenant | role.manage |
| `PATCH /admin/tenant/roles/{role_id}` | tenant | role.manage |
| `DELETE /admin/tenant/roles/{role_id}` | tenant | role.manage |
| `GET /admin/tenant/menu` | tenant | authenticated tenant scope |
| `POST /admin/tenant/realtime/auth` | tenant | authenticated tenant scope |
| `GET /admin/tenant/menu-management` | tenant | menu.manage |
| `PUT /admin/tenant/menu-management` | tenant | menu.manage |
| `GET /admin/tenant/dashboard/summary` | tenant | dashboard.view |
| `GET /admin/tenant/members` | tenant | customer.view |
| `POST /admin/tenant/members` | tenant | customer.create |
| `GET /admin/tenant/members/{member_id}` | tenant | customer.view |
| `PATCH /admin/tenant/members/{member_id}` | tenant | customer.update |
| `POST /admin/tenant/members/{member_id}/status` | tenant | customer.suspend |
| `GET /admin/tenant/orders` | tenant | order.view |
| `GET /admin/tenant/orders/{order_id}` | tenant | order.view |
| `PATCH /admin/tenant/orders/{order_id}` | tenant | order.update |
| `POST /admin/tenant/orders/{order_id}/cancel` | tenant | order.cancel |
| `POST /admin/tenant/orders/{order_id}/refund` | tenant | order.refund |
| `GET /admin/tenant/tickets` | tenant | ticket.view |
| `GET /admin/tenant/tickets/{ticket_id}` | tenant | ticket.view |
| `GET /admin/tenant/stock` | tenant | stock.view |
| `GET /admin/tenant/stock/{stock_item_id}` | tenant | stock.view |
| `POST /admin/tenant/stock/exports` | tenant | stock.export |
| `GET /admin/tenant/stock-sync/batches` | tenant | stock.sync |
| `POST /admin/tenant/stock-sync/batches` | tenant | stock.sync |
| `GET /admin/tenant/stock-sync/batches/{batch_id}` | tenant | stock.sync |
| `GET /admin/tenant/price-rules` | tenant | price_rule.view |
| `POST /admin/tenant/price-rules` | tenant | price_rule.manage |
| `GET /admin/tenant/price-rules/{price_rule_id}` | tenant | price_rule.view |
| `PATCH /admin/tenant/price-rules/{price_rule_id}` | tenant | price_rule.manage |
| `DELETE /admin/tenant/price-rules/{price_rule_id}` | tenant | price_rule.manage |
| `GET /admin/tenant/sale-price-rules` | tenant | price_rule.view |
| `POST /admin/tenant/sale-price-rules` | tenant | price_rule.manage |
| `GET /admin/tenant/sale-price-rules/{sale_price_rule_id}` | tenant | price_rule.view |
| `PATCH /admin/tenant/sale-price-rules/{sale_price_rule_id}` | tenant | price_rule.manage |
| `GET /admin/tenant/topups` | tenant | topup.view |
| `GET /admin/tenant/topups/{topup_id}` | tenant | topup.view |
| `POST /admin/tenant/topups/{topup_id}/approve` | tenant | topup.approve |
| `POST /admin/tenant/topups/{topup_id}/reject` | tenant | topup.reject |
| `POST /admin/tenant/topups/{topup_id}/cancel` | tenant | topup.cancel |
| `GET /admin/tenant/reward-claims` | tenant | reward_claim.view |
| `GET /admin/tenant/reward-claims/{claim_id}` | tenant | reward_claim.view |
| `POST /admin/tenant/reward-claims/{claim_id}/approve` | tenant | reward_claim.approve |
| `POST /admin/tenant/reward-claims/{claim_id}/reject` | tenant | reward_claim.reject |
| `POST /admin/tenant/reward-claims/{claim_id}/pay` | tenant | reward_claim.pay |
| `GET /admin/tenant/reservations` | tenant | reservation.view |
| `POST /admin/tenant/reservations/{reservation_id}/cancel` | tenant | reservation.cancel |
| `GET /admin/tenant/wallets` | tenant | wallet.view |
| `GET /admin/tenant/wallets/{wallet_id}` | tenant | wallet.view |
| `GET /admin/tenant/wallets/{wallet_id}/ledger` | tenant | wallet.view |
| `PATCH /admin/tenant/wallets/{wallet_id}/adjust` | tenant | wallet.adjust |
| `GET /admin/tenant/agents` | tenant | agent.view |
| `POST /admin/tenant/agents` | tenant | agent.create |
| `GET /admin/tenant/agents/{agent_id}` | tenant | agent.view |
| `PATCH /admin/tenant/agents/{agent_id}` | tenant | agent.update |
| `PATCH /admin/tenant/agents/{agent_id}/quotas` | tenant | agent.quota.manage |
| `GET /admin/tenant/affiliate-programs` | tenant | affiliate_program.view |
| `POST /admin/tenant/affiliate-programs` | tenant | affiliate_program.manage |
| `GET /admin/tenant/affiliate-programs/{affiliate_program_id}` | tenant | affiliate_program.view |
| `PATCH /admin/tenant/affiliate-programs/{affiliate_program_id}` | tenant | affiliate_program.manage |
| `DELETE /admin/tenant/affiliate-programs/{affiliate_program_id}` | tenant | affiliate_program.manage |
| `GET /admin/tenant/affiliate-links` | tenant | affiliate_link.view |
| `POST /admin/tenant/affiliate-links` | tenant | affiliate_link.manage |
| `GET /admin/tenant/affiliate-links/{affiliate_link_id}` | tenant | affiliate_link.view |
| `PATCH /admin/tenant/affiliate-links/{affiliate_link_id}` | tenant | affiliate_link.manage |
| `DELETE /admin/tenant/affiliate-links/{affiliate_link_id}` | tenant | affiliate_link.manage |
| `GET /admin/tenant/affiliate-attributions` | tenant | affiliate_attribution.view |
| `GET /admin/tenant/affiliate-attributions/{attribution_id}` | tenant | affiliate_attribution.view |
| `GET /admin/tenant/affiliates` | tenant | affiliate.view |
| `POST /admin/tenant/affiliates` | tenant | affiliate.create |
| `GET /admin/tenant/affiliates/{affiliate_id}` | tenant | affiliate.view |
| `PATCH /admin/tenant/affiliates/{affiliate_id}` | tenant | affiliate.update |
| `GET /admin/tenant/commission-rules` | tenant | commission_rule.view |
| `POST /admin/tenant/commission-rules` | tenant | commission_rule.manage |
| `GET /admin/tenant/commission-rules/{commission_rule_id}` | tenant | commission_rule.view |
| `PATCH /admin/tenant/commission-rules/{commission_rule_id}` | tenant | commission_rule.manage |
| `DELETE /admin/tenant/commission-rules/{commission_rule_id}` | tenant | commission_rule.manage |
| `GET /admin/tenant/commission-transactions` | tenant | commission.view |
| `POST /admin/tenant/commission-transactions/{commission_id}/approve` | tenant | commission.approve |
| `GET /admin/tenant/payouts` | tenant | payout.manage |
| `POST /admin/tenant/payouts` | tenant | payout.manage |
| `POST /admin/tenant/payouts/{payout_id}/approve` | tenant | payout.manage |
| `POST /admin/tenant/payouts/{payout_id}/reject` | tenant | payout.manage |
| `GET /admin/tenant/monitoring` | tenant | monitoring.view |
| `GET /admin/tenant/usage` | tenant | usage.view |
| `GET /admin/tenant/audit-logs` | tenant | audit.view |
| `GET /admin/tenant/sync-logs` | tenant | sync_log.view |
| `GET /admin/tenant/reports/{report_key}` | tenant | report.view |
| `POST /admin/tenant/reports/{report_key}/exports` | tenant | report.view |
| `GET /admin/tenant/settings` | tenant | settings.view |
| `PATCH /admin/tenant/settings` | tenant | settings.manage |
| `GET /admin/tenant/theme` | tenant | settings.view |
| `PATCH /admin/tenant/theme` | tenant | settings.manage |
| `POST /admin/tenant/assets/uploads` | tenant | asset.manage |
| `GET /admin/tenant/assets/{asset_id}` | tenant | asset.manage |
| `POST /admin/tenant/assets/{asset_id}/commit` | tenant | asset.manage |
| `GET /admin/tenant/export-jobs/{export_job_id}` | tenant | matching export source permission |
| `GET /admin/tenant/export-jobs/{export_job_id}/download` | tenant | matching export source permission |
| `GET /admin/tenant/payment-settings` | tenant | payment_settings.view |
| `PATCH /admin/tenant/payment-settings` | tenant | payment_settings.manage |
| `GET /admin/tenant/payment-channels` | tenant | payment_settings.view |
| `POST /admin/tenant/payment-channels` | tenant | payment_settings.manage |
| `GET /admin/tenant/payment-channels/{payment_channel_id}` | tenant | payment_settings.view |
| `PATCH /admin/tenant/payment-channels/{payment_channel_id}` | tenant | payment_settings.manage |
| `DELETE /admin/tenant/payment-channels/{payment_channel_id}` | tenant | payment_settings.manage |
| `GET /admin/tenant/seo` | tenant | seo.view |
| `PATCH /admin/tenant/seo` | tenant | seo.update |
| `GET /admin/tenant/seo/pages` | tenant | seo.view |
| `POST /admin/tenant/seo/pages` | tenant | seo.update |
| `PATCH /admin/tenant/seo/pages/{page_id}` | tenant | seo.update |
| `DELETE /admin/tenant/seo/pages/{page_id}` | tenant | seo.update |
| `GET /admin/tenant/redirects` | tenant | seo.view |
| `POST /admin/tenant/redirects` | tenant | seo.redirect.manage |
| `PATCH /admin/tenant/redirects/{redirect_id}` | tenant | seo.redirect.manage |
| `DELETE /admin/tenant/redirects/{redirect_id}` | tenant | seo.redirect.manage |
| `GET /admin/tenant/domains` | tenant | settings.view |
| `POST /admin/tenant/domains` | tenant | settings.manage |
| `GET /admin/tenant/domains/{domain_id}` | tenant | settings.view |
| `PATCH /admin/tenant/domains/{domain_id}` | tenant | settings.manage |
| `DELETE /admin/tenant/domains/{domain_id}` | tenant | settings.manage |
| `POST /admin/tenant/domains/{domain_id}/verify` | tenant | settings.manage |
| `GET /admin/tenant/maintenance` | tenant | maintenance.view |
| `PUT /admin/tenant/maintenance` | tenant | maintenance.update |
| `GET /admin/tenant/maintenance/events` | tenant | maintenance.view |
| `GET /admin/tenant/maintenance/bypasses` | tenant | maintenance.bypass |
| `POST /admin/tenant/maintenance/bypasses` | tenant | maintenance.bypass |
| `DELETE /admin/tenant/maintenance/bypasses/{bypass_id}` | tenant | maintenance.bypass |
| `GET /admin/tenant/support-access` | tenant | support_access.audit |
| `POST /admin/tenant/support-access` | tenant | support_access.request |
| `GET /admin/tenant/support-access/{support_access_id}` | tenant | support_access.audit |
| `POST /admin/tenant/support-access/{support_access_id}/approve` | tenant | support_access.approve |
| `POST /admin/tenant/support-access/{support_access_id}/revoke` | tenant | support_access.approve |
| `POST /admin/tenant/support-access/{support_access_id}/impersonate` | tenant | support_access.impersonate_customer / support_access.impersonate_admin |
| `POST /admin/tenant/support-access/{support_access_id}/elevated-actions` | tenant | support_access.elevated_action |
| `POST /admin/tenant/support-access/{support_access_id}/end-session` | tenant | support_access.audit |
| `GET /admin/central/reports/{report_key}` | central | report.view |
| `POST /admin/central/reports/{report_key}/exports` | central | report.view |

## Critical Audit Actions

```text
admin.login
role.changed
permission.changed
menu.changed
stock.allocated
stock.recalled
wallet.adjusted
topup.approved
commission.approved
partner.suspended
settings.changed
seo.changed
maintenance.enabled
maintenance.disabled
maintenance.updated
reward.published
permission_cache.invalidated
admin_impersonation.started
admin_impersonation.ended
support_access.requested
support_access.approved
support_access.denied
support_impersonation.action_blocked
```

## Blocked During Support Impersonation By Default

```text
change_password
change_2fa
change_bank_account
wallet_adjust
withdraw
payout_approve
topup_approve
checkout_payment
permission_change
role_change
delete_user
export_sensitive_data
```
