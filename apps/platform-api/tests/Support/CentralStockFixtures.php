<?php

namespace Tests\Support;

use Illuminate\Support\Facades\DB;

trait CentralStockFixtures
{
    use AdminAuthFixtures;

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function createCentralSession(
        array $permissions,
        string $adminId = 'adm_central_stock',
        string $email = 'central-stock@example.test',
    ): array {
        $this->createAdmin($adminId, $email);
        $this->createAdminScope('scp_'.$adminId, 'central');
        $this->assignRoleWithPermissions($adminId, 'scp_'.$adminId, 'central', null, $permissions, 'central_'.$adminId);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    protected function insertActivePartnerTenant(string $partnerId = 'par_stock', string $tenantId = 'ten_stock'): void
    {
        DB::table('partners')->insert([
            'id' => $partnerId,
            'code' => $partnerId,
            'name' => 'Partner '.$partnerId,
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => $tenantId,
            'partner_id' => $partnerId,
            'code' => $tenantId,
            'name' => 'Tenant '.$tenantId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function insertGame(string $gameId = 'gam_stock', string $status = 'open'): void
    {
        DB::table('games')->insert([
            'id' => $gameId,
            'code' => $gameId,
            'name' => 'Game '.$gameId,
            'draw_at' => now()->addDay(),
            'close_at' => now()->addHours(20),
            'closed_at' => null,
            'archived_at' => null,
            'status' => $status,
            'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function insertQuota(string $quotaId, string $partnerId, string $gameId, int $quotaCount): void
    {
        DB::table('partner_quotas')->insert([
            'id' => $quotaId,
            'partner_id' => $partnerId,
            'game_id' => $gameId,
            'quota_count' => $quotaCount,
            'allocated_count' => 0,
            'status' => 'active',
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function insertStockItems(string $gameId, int $count, int $start = 1): void
    {
        $rows = [];

        for ($number = $start; $number < $start + $count; $number++) {
            $fullNumber = str_pad((string) $number, 6, '0', STR_PAD_LEFT);
            $rows[] = [
                'id' => 'stk_'.substr(sha1($gameId.':'.$fullNumber), 0, 20),
                'game_id' => $gameId,
                'batch_id' => null,
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'status' => 'available',
                'partner_id' => null,
                'tenant_id' => null,
                'allocation_id' => null,
                'recall_reason' => null,
                'recalled_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        DB::table('stock_items')->insert($rows);
    }
}
