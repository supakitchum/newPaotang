<?php

namespace App\Modules\Reward\Services;

class ThaiGovernmentLotteryRewardTemplate
{
    public const CURRENCY = 'THB';

    /**
     * @return array<string, array{count: int, digits: int, amount: int}>
     */
    public static function rules(): array
    {
        return [
            'first_prize' => ['count' => 1, 'digits' => 6, 'amount' => 6000000],
            'near_first_prize' => ['count' => 2, 'digits' => 6, 'amount' => 100000],
            'second_prize' => ['count' => 5, 'digits' => 6, 'amount' => 200000],
            'third_prize' => ['count' => 10, 'digits' => 6, 'amount' => 80000],
            'fourth_prize' => ['count' => 50, 'digits' => 6, 'amount' => 40000],
            'fifth_prize' => ['count' => 100, 'digits' => 6, 'amount' => 20000],
            'front3' => ['count' => 2, 'digits' => 3, 'amount' => 4000],
            'back3' => ['count' => 2, 'digits' => 3, 'amount' => 4000],
            'back2' => ['count' => 1, 'digits' => 2, 'amount' => 2000],
        ];
    }

    /**
     * @return array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}>
     */
    public static function draftPrizes(): array
    {
        $rows = [];

        foreach (self::rules() as $type => $rule) {
            for ($index = 1; $index <= $rule['count']; $index++) {
                $rows[] = [
                    'prize_type' => $type,
                    'prize_number' => self::pendingNumber($type, $index),
                    'amount' => [
                        'amount' => $rule['amount'],
                        'currency' => self::CURRENCY,
                    ],
                ];
            }
        }

        return $rows;
    }

    public static function pendingNumber(string $type, int $index): string
    {
        return 'pending_'.$type.'_'.str_pad((string) $index, 3, '0', STR_PAD_LEFT);
    }
}
