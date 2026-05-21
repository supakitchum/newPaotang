<?php

namespace Tests\Support;

use Illuminate\Support\Facades\DB;

trait M5CommerceFixtures
{
    use PartnerStoreFixtures;

    /**
     * @return array<string, mixed>
     */
    protected function prepareReservedCart(
        string $partnerId = 'par_m5',
        string $tenantId = 'ten_m5',
        string $host = 'm5.newpaotang.test',
        string $gameId = 'gam_m5',
        string $customerPhone = '0805550001',
        int $stockStart = 700001,
    ): array {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain($partnerId, $tenantId, $host);
        $this->insertGame($gameId, 'open');
        $this->insertVirtualCartSupply($partnerId, $tenantId, $gameId, $stockStart);

        $auth = $this->postJson('http://'.$host.'/api/v1/customer/auth/register', [
            'name' => 'M5 Customer',
            'phone' => $customerPhone,
            'email' => $customerPhone.'@example.test',
            'password' => 'customer-secret',
            'password_confirmation' => 'customer-secret',
        ], [
            'Idempotency-Key' => 'register-'.$tenantId,
        ])->assertCreated()->json();

        $reservation = $this->withToken($auth['token'])
            ->postJson('http://'.$host.'/api/v1/customer/reservations', [
                'game_id' => $gameId,
                'local_stock_item_ids' => [$this->firstVirtualStockRef($host, $gameId, $stockStart)],
            ], [
                'Idempotency-Key' => 'reserve-'.$tenantId,
            ])
            ->assertCreated()
            ->json();
        $localIds = array_values(array_map(
            fn (array $item): string => (string) $item['id'],
            $reservation['items'] ?? [],
        ));

        $walletId = DB::table('wallets')
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $auth['user']['id'])
            ->value('id');

        DB::table('wallets')->where('id', $walletId)->update([
            'balance_amount' => 100000,
            'updated_at' => now(),
        ]);
        DB::table('wallet_ledger')->insert([
            'id' => 'wle_seed_'.substr(sha1($walletId), 0, 16),
            'tenant_id' => $tenantId,
            'wallet_id' => $walletId,
            'customer_id' => $auth['user']['id'],
            'entry_type' => 'credit',
            'status' => 'posted',
            'amount' => 100000,
            'currency' => 'THB',
            'balance_after' => 100000,
            'reference_type' => 'test_seed',
            'reference_id' => $tenantId,
            'idempotency_key' => 'seed-'.$tenantId,
            'created_by_admin_id' => null,
            'metadata_json' => null,
            'posted_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'host' => $host,
            'game_id' => $gameId,
            'local_ids' => $localIds,
            'auth' => $auth,
            'reservation' => $reservation,
            'wallet_id' => $walletId,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function checkoutWallet(array $world, string $idempotencyKey = 'checkout-main'): array
    {
        return $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'wallet',
            ], [
                'Idempotency-Key' => $idempotencyKey,
                'X-Request-Id' => 'req-'.$idempotencyKey,
            ])
            ->assertCreated()
            ->json();
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function tenantAdmin(array $world, array $permissions, string $suffix = 'm5'): array
    {
        return $this->createTenantSession(
            $world['tenant_id'],
            $world['partner_id'],
            $permissions,
            'adm_'.substr($suffix, 0, 8).'_'.substr(sha1(implode(',', $permissions).$world['tenant_id']), 0, 8),
            $suffix.'-'.$world['tenant_id'].'@example.test',
        );
    }

    private function insertVirtualCartSupply(string $partnerId, string $tenantId, string $gameId, int $stockStart): void
    {
        $numbers = [
            str_pad((string) $stockStart, 6, '0', STR_PAD_LEFT),
            str_pad((string) ($stockStart + 1), 6, '0', STR_PAD_LEFT),
        ];
        $now = now();

        DB::table('base_lottery_numbers')->insert(array_map(fn (string $number): array => [
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'created_at' => $now,
            'updated_at' => $now,
        ], $numbers));

        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'm5-commerce-virtual-seed',
            'base_count' => count($numbers),
            'total_capacity' => count($numbers),
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => count($numbers),
            'allocation_percent_basis_points' => 10000,
            'allocated_count' => count($numbers),
            'recalled_count' => 0,
            'supply_layer_ids_json' => json_encode(['vsp_'.$gameId], JSON_THROW_ON_ERROR),
            'idempotency_key' => 'm5-commerce-virtual-'.$tenantId,
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId.':m5-commerce-virtual'),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function firstVirtualStockRef(string $host, string $gameId, int $stockStart): string
    {
        $number = str_pad((string) $stockStart, 6, '0', STR_PAD_LEFT);

        return (string) $this->getJson('http://'.$host.'/api/v1/public/stock/search?'.http_build_query([
            'game_id' => $gameId,
            'number' => $number,
            'limit' => 1,
        ]))
            ->assertOk()
            ->json('data.0.id');
    }
}
