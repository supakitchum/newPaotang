<?php

namespace App\Support;

final class CustomerNo
{
    public const RANDOM_LENGTH = 8;
    private const RANDOM_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    public static function prefix(?string $tenantCode, string $tenantId = ''): string
    {
        $source = trim((string) ($tenantCode ?: $tenantId));
        $prefix = strtoupper((string) preg_replace('/[^A-Za-z0-9]+/', '', $source));

        if ($prefix === '') {
            return 'TENANT';
        }

        return substr($prefix, 0, 48);
    }

    public static function generate(?string $tenantCode, string $tenantId = ''): string
    {
        return self::prefix($tenantCode, $tenantId).self::randomSuffix();
    }

    public static function randomSuffix(int $length = self::RANDOM_LENGTH): string
    {
        $suffix = '';
        $max = strlen(self::RANDOM_ALPHABET) - 1;

        for ($i = 0; $i < $length; $i++) {
            $suffix .= self::RANDOM_ALPHABET[random_int(0, $max)];
        }

        return $suffix;
    }

    public static function legacyMemberNo(string $customerId): string
    {
        return 'M'.strtoupper(substr(sha1($customerId), 0, 8));
    }

    public static function display(mixed $customerNo, string $customerId): string
    {
        $value = is_string($customerNo) ? trim($customerNo) : '';

        return $value !== '' ? $value : self::legacyMemberNo($customerId);
    }
}
