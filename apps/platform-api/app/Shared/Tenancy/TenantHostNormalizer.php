<?php

namespace App\Shared\Tenancy;

final class TenantHostNormalizer
{
    public static function normalize(string $host): string
    {
        $raw = self::rawHost($host);

        if ($raw === '') {
            return '';
        }

        $ascii = self::toAscii($raw);

        return strtolower($ascii !== '' ? $ascii : $raw);
    }

    /**
     * @return array<int, string>
     */
    public static function variants(string $host): array
    {
        $raw = self::rawHost($host);
        $ascii = self::normalize($host);
        $unicode = self::toUnicode($ascii);

        return array_values(array_unique(array_filter([
            $ascii,
            $raw,
            $unicode,
        ], fn (string $value): bool => $value !== '')));
    }

    private static function rawHost(string $host): string
    {
        $value = trim($host);

        if ($value === '') {
            return '';
        }

        if (str_contains($value, '://')) {
            $parsedHost = parse_url($value, PHP_URL_HOST);
            $value = is_string($parsedHost) ? $parsedHost : $value;
        }

        $value = explode('/', $value)[0];
        $value = preg_replace('/:\d+$/', '', $value) ?? $value;

        return strtolower(rtrim($value, '.'));
    }

    private static function toAscii(string $host): string
    {
        if (! function_exists('idn_to_ascii')) {
            return $host;
        }

        $ascii = idn_to_ascii(
            $host,
            defined('IDNA_DEFAULT') ? IDNA_DEFAULT : 0,
            defined('INTL_IDNA_VARIANT_UTS46') ? INTL_IDNA_VARIANT_UTS46 : 1,
        );

        return is_string($ascii) ? strtolower($ascii) : $host;
    }

    private static function toUnicode(string $host): string
    {
        if (! function_exists('idn_to_utf8')) {
            return $host;
        }

        $unicode = idn_to_utf8(
            $host,
            defined('IDNA_DEFAULT') ? IDNA_DEFAULT : 0,
            defined('INTL_IDNA_VARIANT_UTS46') ? INTL_IDNA_VARIANT_UTS46 : 1,
        );

        return is_string($unicode) ? strtolower($unicode) : $host;
    }
}
