<?php

namespace App\Support;

class YoutubeLiveUrl
{
    public static function embedUrl(mixed $value): string
    {
        if (! is_string($value)) {
            return '';
        }

        $rawUrl = trim($value);

        if ($rawUrl === '') {
            return '';
        }

        $parts = parse_url($rawUrl);

        if (! is_array($parts)) {
            return '';
        }

        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = strtolower((string) ($parts['host'] ?? ''));
        $path = (string) ($parts['path'] ?? '');
        $query = (string) ($parts['query'] ?? '');

        if (! in_array($scheme, ['http', 'https'], true)) {
            return '';
        }

        $videoId = self::videoId($host, $path, $query);

        return preg_match('/^[A-Za-z0-9_-]{11}$/', $videoId) === 1
            ? 'https://www.youtube.com/embed/'.$videoId
            : '';
    }

    public static function isAllowedOrEmpty(mixed $value): bool
    {
        if ($value === null) {
            return true;
        }

        if (! is_scalar($value)) {
            return false;
        }

        $normalized = (string) $value;

        return trim($normalized) === '' || self::embedUrl($normalized) !== '';
    }

    private static function videoId(string $host, string $path, string $query): string
    {
        $segments = array_values(array_filter(explode('/', trim($path, '/')), fn (string $segment): bool => $segment !== ''));

        if (self::allowedHost($host, 'youtu.be')) {
            return (string) ($segments[0] ?? '');
        }

        if (! self::allowedHost($host, 'youtube.com') && ! self::allowedHost($host, 'youtube-nocookie.com')) {
            return '';
        }

        $route = (string) ($segments[0] ?? '');

        if ($route === 'watch') {
            parse_str($query, $params);

            return is_string($params['v'] ?? null) ? $params['v'] : '';
        }

        return in_array($route, ['embed', 'live', 'shorts', 'v'], true)
            ? (string) ($segments[1] ?? '')
            : '';
    }

    private static function allowedHost(string $host, string $domain): bool
    {
        return $host === $domain || str_ends_with($host, '.'.$domain);
    }
}
