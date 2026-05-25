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
            'customer_no' => strtoupper((string) preg_replace('/[^A-Za-z0-9]+/', '', $tenantId)).strtoupper(substr(sha1($customerId), 0, 8)),
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
        $this->insertStockItems($gameId, $count, $stockStart);
        $keyHash = substr(sha1($allocationKey), 0, 10);
        $allocationId = 'alc_'.substr(sha1($tenantId.':'.$allocationKey), 0, 20);
        $now = now();
        $storeId ??= $tenantId;
        $stockRows = DB::table('stock_items')
            ->where('game_id', $gameId)
            ->where('status', 'available')
            ->orderBy('full_number')
            ->limit($count)
            ->get(['id', 'full_number', 'front3', 'back3', 'back2'])
            ->all();

        DB::table('partner_stock_allocations')->insert([
            'id' => $allocationId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $count,
            'allocation_percent_basis_points' => null,
            'allocated_count' => count($stockRows),
            'recalled_count' => 0,
            'idempotency_key' => $allocationKey,
            'payload_hash' => hash('sha256', 'legacy-materialized-fixture:'.$allocationKey),
            'created_by_admin_id' => null,
            'reason' => 'legacy materialized fixture',
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('stock_items')->whereIn('id', array_map(fn (object $stock): string => (string) $stock->id, $stockRows))->update([
            'status' => 'allocated',
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'allocation_id' => $allocationId,
            'updated_at' => $now,
        ]);

        $allocationItems = [];
        $localItems = [];

        foreach ($stockRows as $stock) {
            $allocationItems[] = [
                'allocation_id' => $allocationId,
                'stock_item_id' => (string) $stock->id,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'allocated',
                'created_at' => $now,
                'updated_at' => $now,
            ];

            $localItems[] = [
                'id' => 'lsi_'.substr(sha1($tenantId.':'.$stock->id.':'.$keyHash), 0, 20),
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'store_id' => $storeId,
                'game_id' => $gameId,
                'stock_item_id' => (string) $stock->id,
                'allocation_id' => $allocationId,
                'full_number' => (string) $stock->full_number,
                'front3' => $stock->front3,
                'back3' => $stock->back3,
                'back2' => $stock->back2,
                'image_url' => null,
                'image_thumb_url' => null,
                'status' => 'available',
                'synced_at' => $now,
                'reserved_at' => null,
                'sold_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if ($allocationItems !== []) {
            DB::table('partner_stock_allocation_items')->insert($allocationItems);
            DB::table('local_stock_items')->insert($localItems);
        }

        return DB::table('local_stock_items')
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId)
            ->where('store_id', $storeId)
            ->orderBy('full_number')
            ->pluck('id')
            ->all();
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
