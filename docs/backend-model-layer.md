# Backend Model Layer

## Conventions

Backend models live under `App\Models`.

Shared conventions:

```text
BaseModel: string primary key, non-incrementing, no global unguarding
BasePivotModel: composite-key pivot rows, non-incrementing, no single id key, no global unguarding
BelongsToTenant: explicit scopeForTenant($query, string $tenantId) and tenant() relationship
```

Tenant isolation is explicit. Models do not use global tenant scopes because central admin drill-down, report jobs, settlement jobs, sync workers, and cross-tenant platform operations need controlled cross-tenant reads.

## Eloquent Query Policy

All application-source reads and writes in `apps/platform-api/app/**` use imported Eloquent model classes. Fully qualified model calls such as `\App\Models\SomeModel::...` are forbidden in app source; import the model and call the short class name.

Use direct static model calls for short direct queries:

```text
SomeModel::find($id)
SomeModel::whereKey($id)->exists()
SomeModel::where('status', 'active')->count()
SomeModel::firstWhere('code', $code)
```

Keep `Model::query()` when an explicit builder start is clearer or needed for conditional filters, joins, scopes, pagination/cursor flows, locks, bulk writes, query factories, and model-class maps. `DB::transaction(...)` remains allowed for transaction boundaries, but `DB::table(...)`, `DB::raw(...)` table shortcuts, and `->from(...)` table shortcuts are forbidden in app source.

Lock-protected and bulk paths still use model builders:

```text
SomeModel::query()->where(...)->lockForUpdate()
SomeModel::query()->insert([...])
SomeModel::query()->insertOrIgnore([...])
SomeModel::query()->where(...)->update([...])
SomeModel::query()->where(...)->delete()
```

Every concrete model declares an explicit non-empty `protected $fillable = [...]`. `BaseModel` and `BasePivotModel` intentionally do not declare `protected $guarded = []`; strict mass-assignment diagnostics are enabled outside production with `Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction())`.

## Inventory

| Table | Model | Classification | Tenant Rule |
| --- | --- | --- | --- |
| partners | Partner | domain model | partner scoped |
| partner_tenants | PartnerTenant | domain model | `scopeForTenant` maps to `id` |
| partner_tenant_domains | PartnerTenantDomain | domain model | `scopeForTenant` |
| admin_users | AdminUser | domain model | scope via RBAC |
| admin_user_invitations | AdminUserInvitation | one-time admin activation token hash | scope and nullable tenant snapshot |
| admin_scopes | AdminScope | domain model | nullable `tenant_id`, `scopeForTenant` |
| roles | Role | domain model | nullable `tenant_id`, `scopeForTenant` |
| permissions | Permission | domain model | scope_type only |
| admin_menus | AdminMenu | domain model with presentation metadata (`category`, `icon`) | scope_type only |
| audit_logs | AuditLog | domain model | nullable `tenant_id`, `scopeForTenant` |
| admin_auth_sessions | AdminAuthSession | domain model | nullable `tenant_id`, `scopeForTenant` |
| partner_tenant_settings | PartnerTenantSetting | domain model | `scopeForTenant` |
| partner_tenant_themes | PartnerTenantTheme | domain model | `scopeForTenant` |
| partner_tenant_feature_flags | PartnerTenantFeatureFlag | domain model | `scopeForTenant` |
| partner_tenant_deployment_profiles | PartnerTenantDeploymentProfile | domain model | `scopeForTenant` |
| partner_monitoring_profiles | PartnerMonitoringProfile | domain model | partner scoped |
| partner_usage_meters | PartnerUsageMeter | domain model | partner scoped |
| partner_alert_policies | PartnerAlertPolicy | domain model | partner scoped |
| partner_health_checks | PartnerHealthCheck | domain model | nullable `tenant_id`, `scopeForTenant` |
| partner_usage_events | PartnerUsageEvent | observability usage sink | nullable `tenant_id`, `scopeForTenant` |
| partner_daily_usage_summaries | PartnerDailyUsageSummary | observability daily summary | nullable `tenant_id`, `scopeForTenant` |
| partner_alert_events | PartnerAlertEvent | observability alert event | nullable `tenant_id`, `scopeForTenant` |
| partner_billing_plan_bindings | PartnerBillingPlanBinding | domain model | partner scoped |
| partner_api_clients | PartnerApiClient | domain model | partner scoped |
| games | Game | domain model | central game |
| stock_generation_batches | StockGenerationBatch | domain model | game scoped |
| partner_quotas | PartnerQuota | domain model | partner/game scoped |
| partner_stock_allocations | PartnerStockAllocation | domain model | `scopeForTenant` |
| partner_stock_allocation_items | PartnerStockAllocationItem | pivot domain model | `scopeForTenant` |
| stock_items | StockItem | domain model | nullable allocation `tenant_id`, `scopeForTenant` |
| sync_outbox | SyncOutbox | sync domain model | nullable `tenant_id`, `scopeForTenant` |
| customers | Customer | domain model | `scopeForTenant` |
| customer_auth_sessions | CustomerAuthSession | domain model | `scopeForTenant` |
| local_stock_items | LocalStockItem | domain model | `scopeForTenant` |
| stock_sync_batches | StockSyncBatch | domain model | `scopeForTenant` |
| sync_inbox | SyncInbox | sync domain model | nullable `tenant_id`, `scopeForTenant` |
| stock_reservations | StockReservation | domain model | `scopeForTenant` |
| stock_reservation_items | StockReservationItem | pivot domain model | `scopeForTenant` |
| tenant_stock_export_jobs | TenantStockExportJob | export job model | `scopeForTenant` |
| idempotency_keys | IdempotencyKey | idempotency model | nullable `tenant_id`, `scopeForTenant` |
| wallets | Wallet | domain model | `scopeForTenant` |
| orders | Order | domain model | `scopeForTenant` |
| tickets | Ticket | domain model | `scopeForTenant` |
| order_items | OrderItem | domain model | `scopeForTenant` |
| wallet_ledger | WalletLedger | domain model | `scopeForTenant` |
| payments | Payment | domain model | `scopeForTenant` |
| topup_requests | TopupRequest | domain model | `scopeForTenant` |
| webhook_callbacks | WebhookCallback | webhook model | provider/domain scoped |
| reward_results | RewardResult | domain model | game scoped |
| reward_prizes | RewardPrize | domain model | reward/game scoped |
| reward_check_batches | RewardCheckBatch | worker model | reward/game scoped |
| reward_check_items | RewardCheckItem | worker model | nullable `tenant_id`, `scopeForTenant` |
| winning_tickets | WinningTicket | domain model | `scopeForTenant` |
| reward_publish_logs | RewardPublishLog | audit model | reward/game scoped |
| reward_claims | RewardClaim | domain model | `scopeForTenant` |
| tenant_reward_risk_settings | TenantRewardRiskSetting | reward risk runtime setting | `scopeForTenant` by `tenant_id` |
| reward_risk_runs | RewardRiskRun | read-only assessment run | `scopeForTenant` by `tenant_id` |
| reward_risk_findings | RewardRiskFinding | threshold finding | `scopeForTenant` by `tenant_id` |
| reward_risk_finding_tickets | RewardRiskFindingTicket | assessment evidence | `scopeForTenant` by `tenant_id` |
| agents | Agent | domain model | `scopeForTenant` |
| agent_quotas | AgentQuota | domain model | `scopeForTenant` |
| affiliate_accounts | AffiliateAccount | domain model | `scopeForTenant` |
| affiliate_programs | AffiliateProgram | domain model | `scopeForTenant` |
| affiliate_links | AffiliateLink | domain model | `scopeForTenant` |
| affiliate_attributions | AffiliateAttribution | domain model | `scopeForTenant` |
| commission_rules | CommissionRule | domain model | `scopeForTenant` |
| commission_transactions | CommissionTransaction | domain model | `scopeForTenant` |
| affiliate_payouts | AffiliatePayout | domain model | `scopeForTenant` |
| report_export_jobs | ReportExportJob | report/export model | nullable `tenant_id`, `scopeForTenant` |
| partner_settlements | PartnerSettlement | settlement model | `scopeForTenant` |
| partner_tenant_maintenance_settings | PartnerTenantMaintenanceSetting | maintenance model | `scopeForTenant` |
| partner_tenant_maintenance_events | PartnerTenantMaintenanceEvent | maintenance event model | `scopeForTenant` |
| partner_tenant_maintenance_bypasses | PartnerTenantMaintenanceBypass | maintenance bypass model | `scopeForTenant` |
| support_access_requests | SupportAccessRequest | support access model | `scopeForTenant` |
| support_access_approvals | SupportAccessApproval | support approval model | `scopeForTenant` |
| support_impersonation_sessions | SupportImpersonationSession | support impersonation model | `scopeForTenant` |
| support_impersonation_events | SupportImpersonationEvent | support impersonation event model | `scopeForTenant` |
| support_impersonation_blocked_actions | SupportImpersonationBlockedAction | blocked sensitive action model | `scopeForTenant` |
| role_permissions | RolePermission | pivot domain model | role/permission scoped |
| admin_user_roles | AdminUserRole | pivot domain model | admin/scope scoped |
| role_menus | RoleMenu | pivot domain model | role/menu scoped |
| admin_permission_cache_versions | AdminPermissionCacheVersion | RBAC cache support model | admin/scope scoped |
| cache | none | Laravel runtime table | framework-owned |
| cache_locks | none | Laravel runtime table | framework-owned |
| jobs | none | Laravel queue table | framework-owned |
| failed_jobs | none | Laravel queue table | framework-owned |

## Core Relationships

Core relationships are represented for:

```text
partner -> tenants/domains/api clients/quotas/allocations/settlements
tenant -> domains/settings/theme/customers/orders/wallets/agents/affiliates/report jobs/settlements
tenant -> maintenance settings/events/bypasses/support access requests/impersonation sessions/blocked actions
order -> items/tickets/payments/commission transactions
wallet -> ledger entries/topups/reward claims
reward result -> prizes/check batches/winning tickets/publish logs
reward risk setting -> runs -> findings -> ticket/winning-ticket evidence
affiliate account -> links/attributions/commission transactions/payouts
commission transaction -> affiliate account/order/rule/original reversal chain
RBAC pivots -> admin user roles, role permissions, role menus, permission cache versions
```

## Cloudflare Domain Readiness

`partner_tenant_domains` preserves the original readiness timestamps:

```text
verified_at
ssl_ready_at
```

M10 Cloudflare/CDN readiness adds nullable evidence fields without changing tenant resolution contracts:

```text
dns_verified_at
cloudflare_proxy_verified_at
https_enforced_at
cloudflare_readiness_checked_at
```

Custom domains must not become `active` until DNS ownership, SSL readiness, Cloudflare proxy expectations, and HTTPS enforcement are satisfied. Local `.test` subdomains may remain active for Docker/local QA and are reported as local-only by `platform:cloudflare:readiness`.
