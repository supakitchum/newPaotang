<?php

namespace App\Support;

class ExternalCheckoutPayment
{
    private const TEMPLATE_PLACEHOLDERS = [
        'order_id',
        'reference',
        'amount',
        'amount_minor',
        'currency',
        'tenant_id',
        'customer_id',
        'callback_url',
    ];

    /**
     * @param array<string, mixed>|null $config
     * @return array{provider: string, redirect_url_template: string, label: string}|null
     */
    public static function resolve(bool $enabled, ?array $config): ?array
    {
        if (! $enabled) {
            return null;
        }

        $external = self::externalConfig($config);
        $provider = trim((string) ($external['provider'] ?? ''));
        $template = trim((string) (
            $external['redirect_url_template']
                ?? $external['redirectUrlTemplate']
                ?? $external['redirect_url']
                ?? $external['redirectUrl']
                ?? ''
        ));

        if ($provider === '' || ! self::isAllowedProvider($provider) || ! self::isAllowedTemplate($template)) {
            return null;
        }

        return [
            'provider' => $provider,
            'redirect_url_template' => $template,
            'label' => trim((string) (
                $external['label']
                    ?? $external['display_name']
                    ?? $external['displayName']
                    ?? $config['display_name']
                    ?? $config['displayName']
                    ?? ''
            )),
        ];
    }

    /**
     * @param array<string, mixed>|null $config
     * @return array<string, array<int, string>>
     */
    public static function validationErrors(bool $enabled, ?array $config): array
    {
        if (! $enabled) {
            return [];
        }

        $external = self::externalConfig($config);
        $provider = trim((string) ($external['provider'] ?? ''));
        $template = trim((string) (
            $external['redirect_url_template']
                ?? $external['redirectUrlTemplate']
                ?? $external['redirect_url']
                ?? $external['redirectUrl']
                ?? ''
        ));
        $errors = [];

        if ($provider === '') {
            $errors['config.checkout.external_payment.provider'][] = 'The external checkout provider is required.';
        } elseif (! self::isAllowedProvider($provider)) {
            $errors['config.checkout.external_payment.provider'][] = 'The external checkout provider may contain only letters, numbers, dots, underscores, and hyphens.';
        }

        if ($template === '') {
            $errors['config.checkout.external_payment.redirect_url_template'][] = 'The external checkout redirect URL template is required.';
        } elseif (! self::isAllowedTemplate($template)) {
            $errors['config.checkout.external_payment.redirect_url_template'][] = 'The external checkout redirect URL template must be an absolute HTTPS URL without credentials or fragments and must contain {order_id}.';
        }

        return $errors;
    }

    /**
     * @param array{provider: string, redirect_url_template: string, label: string} $configuration
     * @param array<string, scalar|null> $values
     */
    public static function redirectUrl(array $configuration, array $values): string
    {
        $replacements = [];
        foreach (self::TEMPLATE_PLACEHOLDERS as $placeholder) {
            $replacements['{'.$placeholder.'}'] = rawurlencode((string) ($values[$placeholder] ?? ''));
        }

        $url = strtr($configuration['redirect_url_template'], $replacements);

        return self::isAllowedResolvedUrl($url) ? $url : '';
    }

    /**
     * @param array<string, mixed>|null $config
     * @return array<string, mixed>
     */
    private static function externalConfig(?array $config): array
    {
        if (! is_array($config)) {
            return [];
        }

        $checkout = is_array($config['checkout'] ?? null) ? $config['checkout'] : [];
        $external = $checkout['external_payment'] ?? $checkout['externalPayment'] ?? [];

        return is_array($external) ? $external : [];
    }

    private static function isAllowedProvider(string $provider): bool
    {
        return preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,59}$/', $provider) === 1;
    }

    private static function isAllowedTemplate(string $template): bool
    {
        if (! str_contains($template, '{order_id}')) {
            return false;
        }

        $sample = $template;
        foreach (self::TEMPLATE_PLACEHOLDERS as $placeholder) {
            $sample = str_replace('{'.$placeholder.'}', 'sample', $sample);
        }

        return ! preg_match('/\{[^}]+\}/', $sample) && self::isAllowedResolvedUrl($sample);
    }

    private static function isAllowedResolvedUrl(string $url): bool
    {
        $parts = parse_url($url);

        return is_array($parts)
            && strtolower((string) ($parts['scheme'] ?? '')) === 'https'
            && trim((string) ($parts['host'] ?? '')) !== ''
            && ! isset($parts['user'])
            && ! isset($parts['pass'])
            && ! isset($parts['fragment']);
    }
}
