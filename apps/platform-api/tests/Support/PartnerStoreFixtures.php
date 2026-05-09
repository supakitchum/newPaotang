<?php

namespace Tests\Support;

use Illuminate\Support\Facades\DB;

trait PartnerStoreFixtures
{
    use CentralStockFixtures;

    protected function insertActivePartnerTenantWithDomain(
        string $partnerId = 'par_store',
        string $tenantId = 'ten_store',
        string $host = 'store.newpaotang.test',
    ): void {
        $this->insertActivePartnerTenant($partnerId, $tenantId);

        DB::table('partner_tenant_domains')->insert([
            'id' => 'dom_'.substr(sha1($tenantId.':'.$host), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'host' => $host,
            'type' => 'subdomain',
            'status' => 'active',
            'is_primary' => true,
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function createTenantSession(
        string $tenantId,
        string $partnerId,
        array $permissions,
        string $adminId = 'adm_tenant_store',
        string $email = 'tenant-store@example.test',
    ): array {
        $this->createAdmin($adminId, $email);
        $scopeId = 'scp_'.$adminId;
        $this->createAdminScope($scopeId, 'tenant', $tenantId, $partnerId);
        $this->assignRoleWithPermissions($adminId, $scopeId, 'tenant', $tenantId, $permissions, 'tenant_'.$adminId);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ]);
    }

    protected function issueCustomerToken(string $tenantId, string $customerId = 'cus_store'): string
    {
        $token = 'npa_ct_'.$customerId.'_token';

        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'phone' => '080'.substr(sha1($customerId), 0, 7),
            'name' => 'Customer '.$customerId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('customer_auth_sessions')->insert([
            'id' => 'cas_'.substr(sha1($token), 0, 20),
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'access_token_hash' => hash('sha256', $token),
            'access_expires_at' => now()->addHour(),
            'revoked_at' => null,
            'last_used_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $token;
    }

    /**
     * @return array<int, string>
     */
    protected function syncAllocatedStockToLocal(
        string $partnerId,
        string $tenantId,
        string $gameId,
        int $count = 3,
        string $allocationKey = 'allocation-sync-main',
        int $stockStart = 1,
        ?string $storeId = null,
    ): array {
        $quota = DB::table('partner_quotas')
            ->where('partner_id', $partnerId)
            ->where('game_id', $gameId)
            ->first();

        if ($quota === null) {
            $this->insertQuota('pqt_'.substr(sha1($partnerId.':'.$gameId), 0, 20), $partnerId, $gameId, $count + 10);
        } else {
            DB::table('partner_quotas')->where('id', $quota->id)->update([
                'quota_count' => max((int) $quota->quota_count, (int) $quota->allocated_count + $count + 10),
                'updated_at' => now(),
            ]);
        }

        $this->insertStockItems($gameId, $count, $stockStart);
        $keyHash = substr(sha1($allocationKey), 0, 10);
        $centralAdminId = 'adm_al_'.substr(sha1('alloc:'.$tenantId.':'.$allocationKey), 0, 19);
        $tenantAdminId = 'adm_sy_'.substr(sha1('sync:'.$tenantId.':'.$allocationKey), 0, 19);
        $central = $this->createCentralSession(['stock.allocate'], $centralAdminId, 'alloc-'.$tenantId.'-'.$keyHash.'@example.test');

        $allocation = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'requested_count' => $count,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => $allocationKey,
                'X-Request-Id' => 'req-'.$allocationKey,
            ])
            ->assertAccepted()
            ->json();

        if ($storeId !== null) {
            $this->attachStoreIdToAllocatedOutbox((string) $allocation['id'], $storeId);
        }

        $tenant = $this->createTenantSession($tenantId, $partnerId, ['stock.sync'], $tenantAdminId, 'sync-'.$tenantId.'-'.$keyHash.'@example.test');

        $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/stock-sync/batches', [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'sync-'.$allocationKey,
            ])
            ->assertAccepted()
            ->assertJsonPath('processed_count', $count);

        $localStock = DB::table('local_stock_items')
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId);

        if ($storeId !== null) {
            $localStock->where('store_id', $storeId);
        }

        return $localStock->orderBy('full_number')->pluck('id')->all();
    }

    private function attachStoreIdToAllocatedOutbox(string $allocationId, string $storeId): void
    {
        $outbox = DB::table('sync_outbox')
            ->where('event_type', 'stock.allocated.v1')
            ->where('aggregate_id', $allocationId)
            ->first();

        if ($outbox === null) {
            return;
        }

        $payload = json_decode((string) $outbox->payload_json, true);
        $payload = is_array($payload) ? $payload : [];
        $payload['store_id'] = $storeId;

        DB::table('sync_outbox')->where('id', $outbox->id)->update([
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);
    }

    protected function setTenantMaintenance(string $tenantId): void
    {
        DB::table('partner_tenant_settings')->insert([
            'id' => 'set_'.substr(sha1($tenantId), 0, 20),
            'tenant_id' => $tenantId,
            'site_name' => 'Tenant '.$tenantId,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => null,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => null,
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'maintenance_active' => true,
            'maintenance_mode' => 'full_site',
            'maintenance_message' => 'Maintenance',
            'maintenance_expected_end_at' => now()->addHour(),
            'maintenance_retry_after_seconds' => 300,
            'maintenance_allowed_routes_json' => null,
            'maintenance_blocked_route_patterns_json' => null,
            'api_base_url' => null,
            'realtime_url' => null,
            'asset_cdn_base_url' => null,
            'config_version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
