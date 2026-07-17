<?php

namespace App\Support;

final class RealtimeUrl
{
    public static function isAllowedOrEmpty(mixed $value): bool
    {
        if ($value === null) {
            return true;
        }

        if (! is_scalar($value)) {
            return false;
        }

        $url = trim((string) $value);

        return $url === '' || self::normalize($url) !== '';
    }

    public static function normalize(mixed $value): string
    {
        if (! is_scalar($value)) {
            return '';
        }

        $url = trim((string) $value);
        $parts = parse_url($url);

        if ($url === '' || ! is_array($parts)) {
            return '';
        }

        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = trim((string) ($parts['host'] ?? ''));
        $hasCredentials = trim((string) ($parts['user'] ?? '')) !== ''
            || trim((string) ($parts['pass'] ?? '')) !== '';
        $hasFragment = trim((string) ($parts['fragment'] ?? '')) !== '';

        if (! in_array($scheme, ['http', 'https', 'ws', 'wss'], true)
            || $host === ''
            || $hasCredentials
            || $hasFragment) {
            return '';
        }

        return $url;
    }

    public static function resolve(mixed $tenantValue, mixed $fallbackValue): string
    {
        $tenantUrl = self::normalize($tenantValue);

        return $tenantUrl !== '' ? $tenantUrl : self::normalize($fallbackValue);
    }
}
