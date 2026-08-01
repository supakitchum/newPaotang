<?php

namespace App\Modules\RewardRisk\Services;

class LotteryPrizeMatcher
{
    public function matches(string $fullNumber, string $prizeType, string $prizeNumber): bool
    {
        $type = strtolower(trim($prizeType));
        $number = trim($prizeNumber);

        if ($number === '' || str_starts_with($number, 'pending_')) {
            return false;
        }

        if (str_contains($type, 'front3')) {
            return substr($fullNumber, 0, 3) === $number;
        }

        if (str_contains($type, 'back3')) {
            return substr($fullNumber, -3) === $number;
        }

        if (str_contains($type, 'back2')) {
            return substr($fullNumber, -2) === $number;
        }

        return $fullNumber === $number;
    }
}
