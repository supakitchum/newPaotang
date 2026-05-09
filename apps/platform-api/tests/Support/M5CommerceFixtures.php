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
        $localIds = $this->syncAllocatedStockToLocal($partnerId, $tenantId, $gameId, 2, 'alloc-'.$tenantId.'-'.$stockStart, $stockStart);

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
                'local_stock_item_ids' => [$localIds[0]],
            ], [
                'Idempotency-Key' => 'reserve-'.$tenantId,
            ])
            ->assertCreated()
            ->json();

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
}
