<?php

namespace App\Modules\Auth\Passkeys;

use App\Models\PartnerTenant;
use App\Models\PartnerTenantFeatureFlag;
use App\Models\PartnerTenantSetting;
use Illuminate\Support\Facades\Config;

class CustomerPasskeyConfiguration
{
    /**
     * @param array<string, mixed> $tenant
     * @return array{
     *   enabled: bool,
     *   tenant_id: string,
     *   rp_id: string,
     *   rp_name: string,
     *   allowed_origins: list<string>,
     *   timeout: int,
     *   challenge_ttl_seconds: int,
     *   max_per_customer: int
     * }
     */
    public function resolve(array $tenant): array
    {
        $tenantId = trim((string) ($tenant['tenant_id'] ?? ''));
        $rpId = $this->normalizeHost((string) ($tenant['host'] ?? ''));
        $enabled = $this->enabledForTenant($tenantId);

        if ($tenantId === '' || $rpId === '') {
            $enabled = false;
        }

        return [
            'enabled' => $enabled,
            'tenant_id' => $tenantId,
            'rp_id' => $rpId,
            'rp_name' => $this->relyingPartyName($tenantId, $rpId),
            'allowed_origins' => $this->allowedOrigins($rpId),
            'timeout' => max(1, (int) config('passkeys.timeout', 60000)),
            'challenge_ttl_seconds' => max(
                60,
                (int) config('passkeys.customer.challenge_ttl_seconds', 300),
            ),
            'max_per_customer' => max(
                1,
                (int) config('passkeys.customer.max_per_customer', 10),
            ),
        ];
    }

    /**
     * @param array{rp_id: string, allowed_origins: list<string>, timeout: int} $configuration
     */
    public function apply(array $configuration): void
    {
        Config::set('passkeys.relying_party_id', $configuration['rp_id']);
        Config::set('passkeys.allowed_origins', $configuration['allowed_origins']);
        Config::set('passkeys.timeout', $configuration['timeout']);
    }

    /**
     * @return list<string>
     */
    public function iosAppIds(): array
    {
        return $this->stringList(config('passkeys.customer.ios_app_ids', []));
    }

    /**
     * @return array{package_name: string, sha256_cert_fingerprints: list<string>}|null
     */
    public function androidApp(): ?array
    {
        $packageName = trim((string) config('passkeys.customer.android.package_name', ''));
        $fingerprints = array_values(array_filter(array_map(
            fn (string $value): string => $this->normalizeFingerprint($value),
            $this->stringList(config('passkeys.customer.android.sha256_cert_fingerprints', [])),
        )));

        if ($packageName === '' || $fingerprints === []) {
            return null;
        }

        return [
            'package_name' => $packageName,
            'sha256_cert_fingerprints' => $fingerprints,
        ];
    }

    private function enabledForTenant(string $tenantId): bool
    {
        if ($tenantId === '') {
            return false;
        }

        $configured = PartnerTenantFeatureFlag::query()
            ->where('tenant_id', $tenantId)
            ->where('feature_key', 'passkey_login')
            ->value('enabled');

        return $configured === null
            ? (bool) config('passkeys.customer.enabled_default', true)
            : (bool) $configured;
    }

    private function relyingPartyName(string $tenantId, string $fallback): string
    {
        $setting = PartnerTenantSetting::query()
            ->where('tenant_id', $tenantId)
            ->first(['display_name', 'site_name']);
        $tenantName = PartnerTenant::query()->whereKey($tenantId)->value('name');

        foreach ([$setting?->display_name, $setting?->site_name, $tenantName, $fallback] as $value) {
            $name = trim((string) $value);
            if ($name !== '') {
                return mb_substr($name, 0, 120);
            }
        }

        return $fallback;
    }

    /**
     * @return list<string>
     */
    private function allowedOrigins(string $rpId): array
    {
        if ($rpId === '') {
            return [];
        }

        $origins = ['https://'.$rpId];

        if ($this->isLocalHost($rpId)) {
            $origins[] = 'http://'.$rpId;
        }

        foreach ($this->stringList(config('passkeys.customer.additional_allowed_origins', [])) as $origin) {
            if ($this->allowedConfiguredOrigin($origin, $rpId)) {
                $origins[] = $origin;
            }
        }

        foreach ($this->androidOrigins() as $origin) {
            $origins[] = $origin;
        }

        return array_values(array_unique($origins));
    }

    /**
     * @return list<string>
     */
    private function androidOrigins(): array
    {
        $app = $this->androidApp();
        if ($app === null) {
            return [];
        }

        $origins = [];
        foreach ($app['sha256_cert_fingerprints'] as $fingerprint) {
            $bytes = hex2bin(str_replace(':', '', $fingerprint));
            if ($bytes === false) {
                continue;
            }
            $origins[] = 'android:apk-key-hash:'.rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
        }

        return $origins;
    }

    private function allowedConfiguredOrigin(string $origin, string $rpId): bool
    {
        $origin = trim($origin);
        if ($origin === '') {
            return false;
        }

        if (str_starts_with($origin, 'android:apk-key-hash:')) {
            return preg_match('/^android:apk-key-hash:[A-Za-z0-9_-]{20,}$/', $origin) === 1;
        }

        $scheme = strtolower((string) parse_url($origin, PHP_URL_SCHEME));
        $host = $this->normalizeHost((string) parse_url($origin, PHP_URL_HOST));
        if ($host === '' || ($host !== $rpId && ! str_ends_with($host, '.'.$rpId))) {
            return false;
        }

        return $scheme === 'https' || ($scheme === 'http' && $this->isLocalHost($host));
    }

    private function normalizeHost(string $value): string
    {
        $host = strtolower(trim($value));
        if (str_contains($host, '://')) {
            $host = (string) parse_url($host, PHP_URL_HOST);
        }
        $host = trim(explode(':', $host, 2)[0], ". \t\n\r\0\x0B");

        return preg_match('/^[a-z0-9.-]{1,253}$/', $host) === 1 ? $host : '';
    }

    private function isLocalHost(string $host): bool
    {
        return $host === 'localhost'
            || str_ends_with($host, '.localhost')
            || filter_var($host, FILTER_VALIDATE_IP) !== false;
    }

    private function normalizeFingerprint(string $value): string
    {
        $hex = strtoupper(preg_replace('/[^A-Fa-f0-9]/', '', $value) ?? '');
        if (strlen($hex) !== 64) {
            return '';
        }

        return implode(':', str_split($hex, 2));
    }

    /**
     * @return list<string>
     */
    private function stringList(mixed $value): array
    {
        if (is_string($value)) {
            $value = explode(',', $value);
        }

        if (! is_array($value)) {
            return [];
        }

        return array_values(array_filter(array_map(
            static fn (mixed $item): string => trim((string) $item),
            $value,
        )));
    }
}
