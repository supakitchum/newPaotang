<?php

namespace Tests\Support;

use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
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
        $prizes = $this->thaiGovernmentLotteryPrizes($prizeNumber ?? $world['ticket_number'], $world['ticket_number']);

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
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

    /**
     * @return array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}>
     */
    protected function thaiGovernmentLotteryPrizes(string $firstPrizeNumber, ?string $avoidTicketNumber = null): array
    {
        $rows = [];
        $avoidTicketNumber ??= $firstPrizeNumber;

        foreach (ThaiGovernmentLotteryRewardTemplate::rules() as $type => $rule) {
            for ($index = 1; $index <= $rule['count']; $index++) {
                $rows[] = [
                    'prize_type' => $type,
                    'prize_number' => $type === 'first_prize'
                        ? $firstPrizeNumber
                        : $this->safeThaiGovernmentLotteryPrizeNumber($type, $rule['digits'], $index, $avoidTicketNumber),
                    'amount' => [
                        'amount' => $rule['amount'],
                        'currency' => ThaiGovernmentLotteryRewardTemplate::CURRENCY,
                    ],
                ];
            }
        }

        return $rows;
    }

    private function safeThaiGovernmentLotteryPrizeNumber(string $type, int $digits, int $index, string $avoidTicketNumber): string
    {
        $base = match ($digits) {
            2 => 80,
            3 => 800,
            default => 800000,
        };
        $modulo = 10 ** $digits;

        for ($offset = 0; $offset < $modulo; $offset++) {
            $candidate = str_pad((string) (($base + $index + $offset) % $modulo), $digits, '0', STR_PAD_LEFT);

            if (! $this->prizeNumberMatchesTicketSegment($type, $candidate, $avoidTicketNumber)) {
                return $candidate;
            }
        }

        return str_pad((string) $index, $digits, '0', STR_PAD_LEFT);
    }

    private function prizeNumberMatchesTicketSegment(string $type, string $candidate, string $ticketNumber): bool
    {
        if ($type === 'front3') {
            return substr($ticketNumber, 0, 3) === $candidate;
        }

        if ($type === 'back3') {
            return substr($ticketNumber, -3) === $candidate;
        }

        if ($type === 'back2') {
            return substr($ticketNumber, -2) === $candidate;
        }

        return $ticketNumber === $candidate;
    }
}
