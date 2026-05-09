<?php

namespace App\Shared\Cloudflare;

use App\Models\PartnerTenantDomain;

class CloudflareReadinessService
{
    /**
     * @return array<string, mixed>
     */
    public function report(): array
    {
        $domains = $this->domainReadiness();
        $cloudflare = $this->cloudflareEnvironment();
        $cache = $this->cacheReadiness();
        $ticketImages = $this->ticketImageReadiness();
        $blockers = $this->blockers($cloudflare, $domains, $cache, $ticketImages);

        return [
            'status' => $blockers === [] ? 'ready_local' : 'blocked_external',
            'generated_at' => now()->toISOString(),
            'production_approved' => false,
            'boundary' => [
                'local_dev_verifiable' => true,
                'dry_run' => (bool) config('platform.cloudflare.dry_run', true),
                'external_cloudflare_calls_attempted' => false,
                'external_r2_calls_attempted' => false,
                'staging_approved' => false,
                'production_approved' => false,
                'client_delivery_approved' => false,
            ],
            'cloudflare' => $cloudflare,
            'domains' => $domains,
            'cache' => $cache,
            'cdn_r2_ticket_images' => $ticketImages,
            'blockers' => $blockers,
            'docker_validation_commands' => [
                'docker compose exec platform-api php artisan platform:cloudflare:readiness --format=json',
                'docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js',
                'docker run --rm -v "$PWD/load-tests/k6:/scripts:ro" -e CDN_BASE_URL="<cdn-base-url>" -e IMAGE_PATH="<ticket-image-object-path>" grafana/k6:latest inspect /scripts/ticket-image-cdn-spike.js',
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function cloudflareEnvironment(): array
    {
        $configured = [
            'account_id' => trim((string) config('platform.cloudflare.account_id')) !== '',
            'zone_id' => trim((string) config('platform.cloudflare.zone_id')) !== '',
            'api_token' => trim((string) config('platform.cloudflare.api_token')) !== '',
            'api_base_url' => trim((string) config('platform.cloudflare.api_base_url')) !== '',
        ];

        $blockers = [];

        foreach (['account_id', 'zone_id', 'api_token'] as $key) {
            if (! $configured[$key]) {
                $blockers[] = 'cloudflare_'.$key.'_missing';
            }
        }

        return [
            'status' => $blockers === [] ? 'configured_dry_run' : 'missing_credentials',
            'dry_run' => (bool) config('platform.cloudflare.dry_run', true),
            'proxy_required' => (bool) config('platform.cloudflare.proxy_required', true),
            'https_required' => (bool) config('platform.cloudflare.https_required', true),
            'configured' => $configured,
            'redacted_config' => [
                'account_id' => $this->configuredPlaceholder($configured['account_id']),
                'zone_id' => $this->configuredPlaceholder($configured['zone_id']),
                'api_token' => $this->configuredPlaceholder($configured['api_token'], sensitive: true),
                'api_base_url' => $this->configuredPlaceholder($configured['api_base_url']),
            ],
            'blockers' => $blockers,
            'note' => 'This verifier does not call or mutate Cloudflare. Real DNS, SSL, proxy, WAF, and cache evidence must be supplied by QA/Ops before production approval.',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function domainReadiness(): array
    {
        $rows = PartnerTenantDomain::query()
            ->orderBy('host')
            ->get()
            ->all();

        $domains = array_map(fn (object $domain): array => $this->domainResource($domain), $rows);
        $unsafeActive = array_values(array_filter($domains, fn (array $domain): bool => $domain['unsafe_active']));
        $customPending = array_values(array_filter($domains, fn (array $domain): bool => $domain['type'] === 'custom_domain' && ! $domain['can_activate']));

        return [
            'status' => $unsafeActive === [] ? 'guarded' : 'unsafe_active_detected',
            'total' => count($domains),
            'active' => count(array_filter($domains, fn (array $domain): bool => $domain['status'] === 'active')),
            'custom_domains' => count(array_filter($domains, fn (array $domain): bool => $domain['type'] === 'custom_domain')),
            'custom_pending' => count($customPending),
            'unsafe_active' => count($unsafeActive),
            'items' => $domains,
            'blockers' => array_values(array_unique(array_merge(
                ...array_map(fn (array $domain): array => $domain['blockers'], $domains),
            ))),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function domainResource(object $domain): array
    {
        $host = (string) $domain->host;
        $customDomain = (string) $domain->type === 'custom_domain';
        $localOnly = ! $customDomain && $this->isLocalOnlyHost($host);
        $dnsReady = $domain->verified_at !== null && ($domain->dns_verified_at !== null || ! $customDomain);
        $sslReady = $domain->ssl_ready_at !== null;
        $proxyRequired = (bool) config('platform.cloudflare.proxy_required', true);
        $httpsRequired = (bool) config('platform.cloudflare.https_required', true);
        $proxyReady = ! $proxyRequired || $domain->cloudflare_proxy_verified_at !== null || $localOnly;
        $httpsReady = ! $httpsRequired || $domain->https_enforced_at !== null || $localOnly;
        $canActivate = $dnsReady && $sslReady && $proxyReady && $httpsReady;
        $blockers = [];

        if (! $dnsReady) {
            $blockers[] = 'domain_dns_or_ownership_not_verified';
        }

        if (! $sslReady) {
            $blockers[] = 'domain_ssl_not_ready';
        }

        if (! $proxyReady) {
            $blockers[] = 'cloudflare_proxy_not_verified';
        }

        if (! $httpsReady) {
            $blockers[] = 'https_enforcement_not_verified';
        }

        return [
            'id' => (string) $domain->id,
            'partner_id' => (string) $domain->partner_id,
            'tenant_id' => (string) $domain->tenant_id,
            'host' => $host,
            'type' => (string) $domain->type,
            'status' => (string) $domain->status,
            'is_primary' => (bool) $domain->is_primary,
            'local_only' => $localOnly,
            'readiness' => [
                'dns_ownership_verified' => $dnsReady,
                'ssl_ready' => $sslReady,
                'cloudflare_proxy_required' => $proxyRequired,
                'cloudflare_proxy_verified' => $proxyReady,
                'https_required' => $httpsRequired,
                'https_enforced' => $httpsReady,
                'can_activate' => $canActivate,
            ],
            'timestamps' => [
                'verified_at' => $domain->verified_at?->toISOString(),
                'ssl_ready_at' => $domain->ssl_ready_at?->toISOString(),
                'dns_verified_at' => $domain->dns_verified_at?->toISOString(),
                'cloudflare_proxy_verified_at' => $domain->cloudflare_proxy_verified_at?->toISOString(),
                'https_enforced_at' => $domain->https_enforced_at?->toISOString(),
                'cloudflare_readiness_checked_at' => $domain->cloudflare_readiness_checked_at?->toISOString(),
            ],
            'can_activate' => $canActivate,
            'unsafe_active' => (string) $domain->status === 'active' && ! $canActivate,
            'blockers' => $blockers,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function cacheReadiness(): array
    {
        $waf = $this->jsonArtifact('ops/m10/cloudflare-waf-rate-limit-rules.json');
        $cache = $this->jsonArtifact('ops/m10/cloudflare-cache-bypass-rules.json');

        return [
            'status' => $waf['valid'] && $cache['valid'] ? 'artifacts_ready_local' : 'artifacts_missing_or_invalid',
            'waf_rate_limit_rules' => $waf,
            'cache_bypass_rules' => $cache,
            'blockers' => array_values(array_filter([
                $waf['valid'] ? null : 'waf_rate_limit_artifact_missing_or_invalid',
                $cache['valid'] ? null : 'cache_bypass_artifact_missing_or_invalid',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function ticketImageReadiness(): array
    {
        $configured = [
            'cdn_base_url' => trim((string) config('platform.ticket_images.cdn_base_url')) !== '',
            'r2_endpoint' => trim((string) config('platform.ticket_images.r2_endpoint')) !== '',
            'r2_bucket' => trim((string) config('platform.ticket_images.r2_bucket')) !== '',
            'r2_access_key_id' => trim((string) config('platform.ticket_images.r2_access_key_id')) !== '',
            'r2_secret_access_key' => trim((string) config('platform.ticket_images.r2_secret_access_key')) !== '',
            'ticket_image_object_path' => trim((string) config('platform.ticket_images.image_path')) !== '',
        ];
        $cdnRequired = (bool) config('platform.ticket_images.cdn_required', true);
        $blockers = [];

        if ($cdnRequired && ! $configured['cdn_base_url']) {
            $blockers[] = 'cdn_base_url_missing';
        }

        if ($cdnRequired && (! $configured['r2_endpoint'] || ! $configured['r2_bucket'])) {
            $blockers[] = 'r2_endpoint_or_bucket_missing';
        }

        if (! $configured['ticket_image_object_path']) {
            $blockers[] = 'ticket_image_cdn_image_path_missing';
        }

        return [
            'status' => $this->ticketImageStatus($blockers),
            'cdn_required' => $cdnRequired,
            'configured' => $configured,
            'k6_prerequisites' => [
                'requires_explicit_cdn_base_url' => true,
                'requires_explicit_image_path' => true,
                'image_path_evidence_present' => $configured['ticket_image_object_path'],
                'accepted_image_path_env' => 'IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH',
                'base_url_fallback_allowed' => false,
            ],
            'storage_policy' => [
                'database_policy' => 'Store ticket image key/path or CDN URL policy, never base64 payloads.',
                'delivery_policy' => 'Serve ticket images from CDN/R2 or signed CDN URLs; do not proxy each request through Laravel.',
                'cache_policy' => 'Use long-lived immutable cache headers for immutable ticket image objects.',
            ],
            'redacted_config' => [
                'cdn_base_url' => $this->configuredPlaceholder($configured['cdn_base_url']),
                'r2_endpoint' => $this->configuredPlaceholder($configured['r2_endpoint']),
                'r2_bucket' => $this->configuredPlaceholder($configured['r2_bucket']),
                'r2_access_key_id' => $this->configuredPlaceholder($configured['r2_access_key_id'], sensitive: true),
                'r2_secret_access_key' => $this->configuredPlaceholder($configured['r2_secret_access_key'], sensitive: true),
                'ticket_image_object_path' => $this->configuredPlaceholder($configured['ticket_image_object_path']),
            ],
            'blockers' => $blockers,
        ];
    }

    /**
     * @param array<string, mixed> $cloudflare
     * @param array<string, mixed> $domains
     * @param array<string, mixed> $cache
     * @param array<string, mixed> $ticketImages
     * @return array<int, string>
     */
    private function blockers(array $cloudflare, array $domains, array $cache, array $ticketImages): array
    {
        $blockers = array_merge(
            $cloudflare['blockers'],
            $cache['blockers'],
            $ticketImages['blockers'],
        );

        if ((int) $domains['unsafe_active'] > 0) {
            $blockers[] = 'unsafe_active_domain_detected';
        }

        if ((int) $domains['custom_domains'] > 0 && (int) $domains['custom_pending'] > 0) {
            $blockers[] = 'custom_domain_readiness_pending';
        }

        return array_values(array_unique($blockers));
    }

    /**
     * @return array<string, mixed>
     */
    private function jsonArtifact(string $relativePath): array
    {
        $path = $this->workspacePath($relativePath);

        if (! is_file($path)) {
            return [
                'path' => $relativePath,
                'exists' => false,
                'valid' => false,
                'rule_count' => 0,
            ];
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        return [
            'path' => $relativePath,
            'exists' => true,
            'valid' => is_array($decoded),
            'rule_count' => is_array($decoded['rules'] ?? null) ? count($decoded['rules']) : 0,
            'categories' => is_array($decoded['rules'] ?? null)
                ? array_values(array_unique(array_map(fn (array $rule): string => (string) ($rule['category'] ?? 'uncategorized'), $decoded['rules'])))
                : [],
        ];
    }

    private function workspacePath(string $relativePath): string
    {
        $roots = array_filter([
            env('WORKSPACE_ROOT'),
            '/workspace',
            dirname(base_path(), 2),
        ]);

        foreach ($roots as $root) {
            $path = rtrim((string) $root, '/').'/'.$relativePath;

            if (file_exists($path)) {
                return $path;
            }
        }

        return dirname(base_path(), 2).'/'.$relativePath;
    }

    private function isLocalOnlyHost(string $host): bool
    {
        return str_ends_with($host, '.test')
            || str_ends_with($host, '.localhost')
            || $host === 'localhost'
            || $host === '127.0.0.1';
    }

    private function configuredPlaceholder(bool $configured, bool $sensitive = false): ?string
    {
        if (! $configured) {
            return null;
        }

        return $sensitive ? '[REDACTED]' : '[CONFIGURED]';
    }

    /**
     * @param array<int, string> $blockers
     */
    private function ticketImageStatus(array $blockers): string
    {
        if ($blockers === []) {
            return 'configured_dry_run';
        }

        if ($blockers === ['ticket_image_cdn_image_path_missing']) {
            return 'missing_ticket_image_evidence';
        }

        return 'missing_cdn_or_r2_prerequisites';
    }
}
