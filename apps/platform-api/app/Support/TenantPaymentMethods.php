<?php

namespace App\Support;

class TenantPaymentMethods
{
    public const QR = 'qr';
    public const CREDIT_CARD = 'credit_card';
    public const BANK_TRANSFER = 'bank_transfer';

    private const DEFAULTS = [
        self::QR => [
            'key' => self::QR,
            'label' => 'QR Code',
            'description' => 'Generate QR Code for wallet topup.',
            'enabled' => true,
            'sort_order' => 10,
        ],
        self::CREDIT_CARD => [
            'key' => self::CREDIT_CARD,
            'label' => 'Credit Card QR',
            'description' => 'Generate external provider QR for credit card topup.',
            'enabled' => true,
            'sort_order' => 20,
        ],
        self::BANK_TRANSFER => [
            'key' => self::BANK_TRANSFER,
            'label' => 'Bank Transfer',
            'description' => 'Customer transfers to the tenant bank account and uploads a slip.',
            'enabled' => true,
            'sort_order' => 30,
        ],
    ];

    /**
     * @return array<string, array<string, mixed>>
     */
    public static function defaults(): array
    {
        return self::DEFAULTS;
    }

    /**
     * @param array<string, mixed>|null $config
     * @return array<string, array<string, mixed>>
     */
    public static function normalize(?array $config): array
    {
        $configured = is_array($config['payment_methods'] ?? null) ? $config['payment_methods'] : [];
        $methods = [];

        foreach (self::DEFAULTS as $key => $default) {
            $raw = $configured[$key] ?? null;
            $methodConfig = is_array($raw) ? $raw : [];
            $enabledSource = array_key_exists('enabled', $methodConfig) ? $methodConfig['enabled'] : $raw;

            $methods[$key] = [
                'key' => $key,
                'label' => trim((string) ($methodConfig['label'] ?? '')) !== '' ? trim((string) $methodConfig['label']) : $default['label'],
                'description' => trim((string) ($methodConfig['description'] ?? '')) !== '' ? trim((string) $methodConfig['description']) : $default['description'],
                'enabled' => self::boolValue($enabledSource, (bool) $default['enabled']),
                'sort_order' => (int) ($methodConfig['sort_order'] ?? $default['sort_order']),
            ];
        }

        uasort($methods, fn (array $left, array $right): int => $left['sort_order'] <=> $right['sort_order']);

        return $methods;
    }

    /**
     * @param array<string, mixed>|null $config
     * @return array<int, string>
     */
    public static function enabledKeys(?array $config): array
    {
        return array_values(array_map(
            fn (array $method): string => (string) $method['key'],
            array_filter(self::normalize($config), fn (array $method): bool => (bool) $method['enabled']),
        ));
    }

    /**
     * @param array<string, mixed>|null $config
     */
    public static function isEnabled(?array $config, string $method): bool
    {
        $key = self::normalizeTopupChannel($method);
        $methods = self::normalize($config);

        return (bool) ($methods[$key]['enabled'] ?? false);
    }

    public static function normalizeTopupChannel(string $channel): string
    {
        return match ($channel) {
            'credit' => self::CREDIT_CARD,
            default => $channel,
        };
    }

    /**
     * @param array<string, mixed>|null $config
     * @return array<string, mixed>
     */
    public static function customerPayload(?array $config): array
    {
        $methods = array_values(self::normalize($config));

        return [
            'methods' => $methods,
            'enabled_methods' => array_values(array_map(
                fn (array $method): string => (string) $method['key'],
                array_filter($methods, fn (array $method): bool => (bool) $method['enabled']),
            )),
        ];
    }

    private static function boolValue(mixed $value, bool $fallback): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        if ($value === null || $value === '') {
            return $fallback;
        }

        $filtered = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

        return $filtered ?? $fallback;
    }
}
