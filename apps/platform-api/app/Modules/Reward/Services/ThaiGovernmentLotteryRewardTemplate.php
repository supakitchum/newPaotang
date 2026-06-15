<?php

namespace App\Modules\Reward\Services;

class ThaiGovernmentLotteryRewardTemplate
{
    public const CURRENCY = 'THB';
    private const MINOR_UNITS_PER_BAHT = 100;
    private const BAHT_AMOUNTS = [
        'first_prize' => 6000000,
        'near_first_prize' => 100000,
        'second_prize' => 200000,
        'third_prize' => 80000,
        'fourth_prize' => 40000,
        'fifth_prize' => 20000,
        'front3' => 4000,
        'back3' => 4000,
        'back2' => 2000,
    ];

    /**
     * @return array<string, array{count: int, digits: int, amount: int}>
     */
    public static function rules(): array
    {
        return [
            'first_prize' => ['count' => 1, 'digits' => 6, 'amount' => self::minorAmount('first_prize')],
            'near_first_prize' => ['count' => 2, 'digits' => 6, 'amount' => self::minorAmount('near_first_prize')],
            'second_prize' => ['count' => 5, 'digits' => 6, 'amount' => self::minorAmount('second_prize')],
            'third_prize' => ['count' => 10, 'digits' => 6, 'amount' => self::minorAmount('third_prize')],
            'fourth_prize' => ['count' => 50, 'digits' => 6, 'amount' => self::minorAmount('fourth_prize')],
            'fifth_prize' => ['count' => 100, 'digits' => 6, 'amount' => self::minorAmount('fifth_prize')],
            'front3' => ['count' => 2, 'digits' => 3, 'amount' => self::minorAmount('front3')],
            'back3' => ['count' => 2, 'digits' => 3, 'amount' => self::minorAmount('back3')],
            'back2' => ['count' => 1, 'digits' => 2, 'amount' => self::minorAmount('back2')],
        ];
    }

    public static function legacyBahtAmount(string $type): ?int
    {
        return self::BAHT_AMOUNTS[$type] ?? null;
    }

    public static function normalizeStoredMinorAmount(string $type, int $amount, string $currency = self::CURRENCY): int
    {
        $legacyBahtAmount = self::legacyBahtAmount($type);

        if ($currency === self::CURRENCY && $legacyBahtAmount !== null && $amount === $legacyBahtAmount) {
            return self::minorAmount($type);
        }

        return $amount;
    }

    private static function minorAmount(string $type): int
    {
        return (self::BAHT_AMOUNTS[$type] ?? 0) * self::MINOR_UNITS_PER_BAHT;
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
