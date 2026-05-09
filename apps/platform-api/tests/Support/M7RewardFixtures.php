<?php

namespace Tests\Support;

use Illuminate\Support\Facades\DB;

trait M7RewardFixtures
{
    use M5CommerceFixtures;

    /**
     * @return array<string, mixed>
     */
    protected function prepareRewardWorld(
        string $partnerId = 'par_reward',
        string $tenantId = 'ten_reward',
        string $host = 'reward.m7.test',
        string $gameId = 'gam_reward',
        string $customerPhone = '0807008000',
        int $stockStart = 790001,
    ): array {
        $world = $this->prepareReservedCart($partnerId, $tenantId, $host, $gameId, $customerPhone, $stockStart);
        $order = $this->checkoutWallet($world, 'reward-checkout-'.$tenantId);

        DB::table('games')->where('id', $gameId)->update([
            'status' => 'closed',
            'closed_at' => now(),
            'updated_at' => now(),
        ]);

        $world['order'] = $order;
        $world['ticket_id'] = $order['tickets'][0]['id'];
        $world['ticket_number'] = $order['tickets'][0]['full_number'];

        return $world;
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    protected function centralRewardAdmin(array $permissions, string $suffix = 'reward'): array
    {
        $adminId = 'adm_rw_'.substr($suffix, 0, 8).'_'.substr(sha1(implode(',', $permissions).$suffix), 0, 8);

        return $this->createCentralSession($permissions, $adminId, $suffix.'-central@example.test');
    }

    /**
     * @return array<string, mixed>
     */
    protected function publishReward(array $world, ?string $prizeNumber = null, string $keySuffix = 'main'): array
    {
        $admin = $this->centralRewardAdmin([
            'reward.view',
            'reward.create',
            'reward.verify',
            'reward.publish',
            'reward.correct',
            'reward.audit',
        ], 'reward-'.$keySuffix);

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => [[
                    'prize_type' => 'first_prize',
                    'prize_number' => $prizeNumber ?? $world['ticket_number'],
                    'amount' => ['amount' => 1000000, 'currency' => 'THB'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-'.$keySuffix,
            ])
            ->assertAccepted()
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/verify', [
                'reason' => 'summary checked',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-verify-'.$keySuffix,
            ])
            ->assertOk();

        return $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/publish', [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-publish-'.$keySuffix,
            ])
            ->assertOk()
            ->json();
    }
}
