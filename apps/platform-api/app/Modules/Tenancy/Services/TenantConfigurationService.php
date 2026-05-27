<?php

namespace App\Modules\Tenancy\Services;

use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantFeatureFlag;
use App\Models\PartnerTenantSetting;
use App\Models\PartnerTenantTheme;
use App\Models\PlatformSystemSetting;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Modules\Maintenance\Services\MaintenanceService;
use App\Shared\Tenancy\PartnerBoHostResolver;
use App\Shared\Tenancy\TenantHostNormalizer;
use App\Support\YoutubeLiveUrl;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TenantConfigurationService
{
    private const MAINTENANCE_MODES = [
        'full_site',
        'customer_web_only',
        'admin_only',
        'checkout_payment_only',
        'read_only',
        'scheduled',
    ];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MaintenanceService $maintenance,
        private readonly PartnerBoHostResolver $partnerBoHosts,
    ) {
    }

    /**
     * @return array{data?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function siteConfigForRequest(Request $request): array
    {
        $host = $this->normalizeHost((string) ($request->headers->get('Host') ?: $request->getHost()));
        $record = PartnerTenantDomain::query()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'partner_tenant_domains.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenant_domains.partner_id')
            ->whereIn('partner_tenant_domains.host', TenantHostNormalizer::variants($host))
            ->select([
                'partner_tenant_domains.id as domain_id',
                'partner_tenant_domains.host',
                'partner_tenant_domains.type as domain_type',
                'partner_tenant_domains.status as domain_status',
                'partner_tenants.id as tenant_id',
                'partner_tenants.partner_id',
                'partner_tenants.name as tenant_name',
                'partner_tenants.status as tenant_status',
                'partners.status as partner_status',
            ])
            ->first();

        if ($record === null) {
            return ['error' => ['status' => 404, 'code' => 'tenant_not_found', 'message' => 'Tenant domain was not found.']];
        }

        if ($record->domain_status !== config('platform.tenant_resolution.active_domain_status', 'active')) {
            return ['error' => ['status' => 409, 'code' => 'domain_not_active', 'message' => 'Tenant domain is not active.']];
        }

        if (
            $record->partner_status !== config('platform.tenant_resolution.active_partner_status', 'active')
            || ! in_array($record->tenant_status, ['active', 'maintenance'], true)
        ) {
            return ['error' => ['status' => 409, 'code' => 'tenant_inactive', 'message' => 'Tenant is not active.']];
        }

        return [
            'data' => $this->siteConfigResource($record),
        ];
    }

    /**
     * @return array{data?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function adminSiteConfigForRequest(Request $request): array
    {
        $resolved = $this->partnerBoHosts->resolve($request);

        if ($resolved['error'] !== null) {
            return ['error' => $resolved['error']];
        }

        $context = $resolved['context'];

        if ($context === null) {
            return [
                'data' => [
                    'mode' => 'central',
                    'partner' => null,
                    'tenant' => null,
                    'domain' => null,
                    'brand' => [
                        'logo_url' => null,
                        'favicon_url' => null,
                    ],
                    'site' => [
                        'display_name' => 'NewPaotang Back Office',
                    ],
                ],
            ];
        }

        $tenant = (object) [
            'id' => $context['tenant_id'],
            'partner_id' => $context['partner_id'],
            'name' => $context['tenant_name'],
        ];
        $settings = $this->settingsOrDefault($tenant);
        $theme = $this->themeOrDefault($tenant);
        $site = $this->sitePayload($settings);
        $displayName = $site['display_name'] ?: ($site['site_name'] ?: $context['tenant_name']);

        return [
            'data' => [
                'mode' => 'partner',
                'partner' => [
                    'id' => $context['partner_id'],
                    'code' => $context['partner_code'],
                    'name' => $context['partner_name'],
                ],
                'tenant' => [
                    'id' => $context['tenant_id'],
                    'code' => $context['tenant_code'],
                    'name' => $context['tenant_name'],
                ],
                'domain' => [
                    'storefront_host' => $context['storefront_host'],
                    'bo_host' => $context['bo_host'],
                ],
                'brand' => [
                    'logo_url' => $theme->logo_url,
                    'favicon_url' => $theme->favicon_url,
                ],
                'site' => [
                    'display_name' => $displayName,
                ],
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settingsForTenant(string $tenantId): ?array
    {
        $tenant = PartnerTenant::find($tenantId);

        if ($tenant === null) {
            return null;
        }

        $settings = $this->ensureSettings($tenant);

        return $this->settingsResource($tenant, $settings);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function themeForTenant(string $tenantId): ?array
    {
        $tenant = PartnerTenant::find($tenantId);

        if ($tenant === null) {
            return null;
        }

        $theme = $this->ensureTheme($tenant);

        return $this->themeResource($tenant, $theme);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateSettingsPayload(string $tenantId, array $payload): array
    {
        $errors = $this->tenantTamperErrors($tenantId, $payload);
        $updates = $this->settingsUpdates($payload);

        if (array_key_exists('site_name', $updates) && trim((string) $updates['site_name']) === '') {
            $errors['site_name'][] = 'The site_name field must be a non-empty string.';
        }

        if (array_key_exists('support_email', $updates)) {
            $email = trim((string) $updates['support_email']);

            if ($email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
                $errors['support_email'][] = 'The support_email field must be a valid email address.';
            }
        }

        if (array_key_exists('default_keywords_json', $updates) && ! is_array($updates['default_keywords_json'])) {
            $errors['default_keywords'][] = 'The default_keywords field must be an array of strings.';
        }

        foreach (['sitemap_enabled', 'robots_enabled', 'maintenance_active'] as $field) {
            if (array_key_exists($field, $updates) && ! is_bool($updates[$field])) {
                $errors[$field][] = 'The '.$field.' field must be true or false.';
            }
        }

        if (
            array_key_exists('maintenance_mode', $updates)
            && $updates['maintenance_mode'] !== null
            && ! in_array($updates['maintenance_mode'], self::MAINTENANCE_MODES, true)
        ) {
            $errors['maintenance_mode'][] = 'The maintenance_mode field is invalid.';
        }

        if (array_key_exists('waiting_result_youtube_url', $updates) && ! YoutubeLiveUrl::isAllowedOrEmpty($updates['waiting_result_youtube_url'])) {
            $errors['waiting_result_youtube_url'][] = 'The waiting_result_youtube_url field must be a valid YouTube URL.';
        }

        foreach (['maintenance_allowed_routes_json', 'maintenance_blocked_route_patterns_json'] as $field) {
            if (array_key_exists($field, $updates) && ! is_array($updates[$field])) {
                $errors[$field][] = 'The '.$field.' field must be an array of strings.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateThemePayload(string $tenantId, array $payload): array
    {
        $errors = $this->tenantTamperErrors($tenantId, $payload);
        $updates = $this->themeUpdates($payload);

        foreach (['primary_color', 'secondary_color', 'accent_color', 'background_color', 'text_color'] as $field) {
            if (
                array_key_exists($field, $updates)
                && (! is_string($updates[$field]) || preg_match('/^#[0-9a-fA-F]{6}$/', $updates[$field]) !== 1)
            ) {
                $errors[$field][] = 'The '.$field.' field must be a 6-digit hex color.';
            }
        }

        foreach (['logo_url', 'favicon_url', 'og_image_url'] as $field) {
            if (array_key_exists($field, $updates) && $updates[$field] !== null && trim((string) $updates[$field]) === '') {
                $errors[$field][] = 'The '.$field.' field must not be blank.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateSettings(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($tenantId, $payload, $actor, $request): ?array {
            $tenant = PartnerTenant::query()->where('id', $tenantId)->lockForUpdate()->first();

            if ($tenant === null) {
                return null;
            }

            $settings = $this->ensureSettings($tenant);
            $updates = $this->settingsUpdates($payload);

            if ($updates !== []) {
                $updates = $this->serializeSettingsUpdates($updates);
                $updates['config_version'] = ((int) $settings->config_version) + 1;
                $updates['updated_at'] = now();

                PartnerTenantSetting::query()->where('tenant_id', $tenantId)->update($updates);
            }

            $this->auditConfigChange($actor, $request, $tenant, 'tenant_settings', 'settings.updated', $payload);

            return $this->settingsForTenant($tenantId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateTheme(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($tenantId, $payload, $actor, $request): ?array {
            $tenant = PartnerTenant::query()->where('id', $tenantId)->lockForUpdate()->first();

            if ($tenant === null) {
                return null;
            }

            $theme = $this->ensureTheme($tenant);
            $updates = $this->themeUpdates($payload);

            if ($updates !== []) {
                $updates['config_version'] = ((int) $theme->config_version) + 1;
                $updates['updated_at'] = now();

                PartnerTenantTheme::query()->where('tenant_id', $tenantId)->update($updates);
            }

            $this->auditConfigChange($actor, $request, $tenant, 'tenant_theme', 'theme.updated', $payload);

            return $this->themeForTenant($tenantId);
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function siteConfigResource(object $record): array
    {
        $tenant = (object) [
            'id' => $record->tenant_id,
            'partner_id' => $record->partner_id,
            'name' => $record->tenant_name,
            'status' => $record->tenant_status,
        ];
        $settings = $this->settingsOrDefault($tenant);
        $theme = $this->themeOrDefault($tenant);
        $features = $this->featuresForTenant((string) $record->tenant_id);
        $host = (string) $record->host;

        return [
            'partner_id' => (string) $record->partner_id,
            'tenant_id' => (string) $record->tenant_id,
            'status' => (string) $record->tenant_status,
            'site' => $this->sitePayload($settings),
            'domain' => [
                'host' => $host,
                'canonical_url' => $this->canonicalUrl($host),
                'type' => (string) $record->domain_type,
                'status' => (string) $record->domain_status,
                'https_required' => true,
                'cloudflare_proxy_required' => true,
            ],
            'brand' => $this->brandPayload($theme),
            'theme' => $this->themePayload($theme),
            'features' => $features,
            'seo' => $this->seoPayload($settings, $host),
            'maintenance' => $this->maintenance->stateForTenant((string) $record->tenant_id, (string) $record->tenant_status),
            'api' => $this->apiPayload($settings),
            'live' => $this->livePayload($settings),
            'timestamps' => [
                'config_version' => max((int) $settings->config_version, (int) $theme->config_version),
                'updated_at' => max((string) $settings->updated_at, (string) $theme->updated_at),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function settingsResource(object $tenant, object $settings): array
    {
        $host = $this->primaryHost((string) $tenant->id);

        return [
            'id' => (string) $settings->id,
            'tenant_id' => (string) $tenant->id,
            'status' => (string) $tenant->status,
            'created_at' => $settings->created_at,
            'updated_at' => $settings->updated_at,
            'site' => $this->sitePayload($settings),
            'seo' => $this->seoPayload($settings, $host),
            'maintenance' => $this->maintenance->stateForTenant((string) $tenant->id, (string) $tenant->status),
            'api' => $this->apiPayload($settings),
            'live' => $this->livePayload($settings),
            'config_version' => (int) $settings->config_version,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function themeResource(object $tenant, object $theme): array
    {
        return [
            'id' => (string) $theme->id,
            'tenant_id' => (string) $tenant->id,
            'status' => (string) $tenant->status,
            'created_at' => $theme->created_at,
            'updated_at' => $theme->updated_at,
            'brand' => $this->brandPayload($theme),
            'theme' => $this->themePayload($theme),
            'config_version' => (int) $theme->config_version,
        ];
    }

    private function ensureSettings(object $tenant): object
    {
        $settings = PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();

        if ($settings !== null) {
            return $settings;
        }

        $now = now();

        PartnerTenantSetting::query()->create([
            'id' => $this->stableId('pts', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'site_name' => (string) $tenant->name,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => (string) $tenant->name,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => json_encode([], JSON_THROW_ON_ERROR),
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'maintenance_active' => false,
            'maintenance_mode' => null,
            'maintenance_message' => null,
            'maintenance_expected_end_at' => null,
            'maintenance_retry_after_seconds' => null,
            'maintenance_allowed_routes_json' => json_encode([], JSON_THROW_ON_ERROR),
            'maintenance_blocked_route_patterns_json' => json_encode([], JSON_THROW_ON_ERROR),
            'api_base_url' => '/api/v1',
            'realtime_url' => null,
            'asset_cdn_base_url' => $this->canonicalUrl($this->primaryHost((string) $tenant->id)),
            'waiting_result_youtube_url' => null,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();
    }

    private function ensureTheme(object $tenant): object
    {
        $theme = PartnerTenantTheme::query()->forTenant((string) $tenant->id)->first();

        if ($theme !== null) {
            return $theme;
        }

        $now = now();

        PartnerTenantTheme::query()->create([
            'id' => $this->stableId('ptt', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'logo_url' => null,
            'favicon_url' => null,
            'og_image_url' => null,
            'primary_color' => '#0F766E',
            'secondary_color' => '#2563EB',
            'accent_color' => '#F59E0B',
            'background_color' => '#FFFFFF',
            'text_color' => '#111827',
            'font_family' => 'Inter, sans-serif',
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantTheme::query()->forTenant((string) $tenant->id)->first();
    }

    private function settingsOrDefault(object $tenant): object
    {
        $settings = PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();

        if ($settings !== null) {
            return $settings;
        }

        $now = now();

        return (object) [
            'id' => $this->stableId('pts', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'site_name' => (string) $tenant->name,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => (string) $tenant->name,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => '[]',
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'maintenance_active' => false,
            'maintenance_mode' => null,
            'maintenance_message' => null,
            'maintenance_expected_end_at' => null,
            'maintenance_retry_after_seconds' => null,
            'maintenance_allowed_routes_json' => '[]',
            'maintenance_blocked_route_patterns_json' => '[]',
            'api_base_url' => '/api/v1',
            'realtime_url' => null,
            'asset_cdn_base_url' => $this->canonicalUrl($this->primaryHost((string) $tenant->id)),
            'waiting_result_youtube_url' => null,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    private function themeOrDefault(object $tenant): object
    {
        $theme = PartnerTenantTheme::query()->forTenant((string) $tenant->id)->first();

        if ($theme !== null) {
            return $theme;
        }

        $now = now();

        return (object) [
            'id' => $this->stableId('ptt', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'logo_url' => null,
            'favicon_url' => null,
            'og_image_url' => null,
            'primary_color' => '#0F766E',
            'secondary_color' => '#2563EB',
            'accent_color' => '#F59E0B',
            'background_color' => '#FFFFFF',
            'text_color' => '#111827',
            'font_family' => 'Inter, sans-serif',
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function settingsUpdates(array $payload): array
    {
        $updates = [];
        $site = is_array($payload['site'] ?? null) ? $payload['site'] : [];
        $seo = is_array($payload['seo'] ?? null) ? $payload['seo'] : [];
        $maintenance = is_array($payload['maintenance'] ?? null) ? $payload['maintenance'] : [];
        $api = is_array($payload['api'] ?? null) ? $payload['api'] : [];
        $live = is_array($payload['live'] ?? null) ? $payload['live'] : [];

        foreach (['site_name', 'display_name', 'locale', 'timezone', 'support_email', 'support_phone'] as $field) {
            if (array_key_exists($field, $payload) || array_key_exists($field, $site)) {
                $updates[$field] = $payload[$field] ?? $site[$field];
            }
        }

        foreach (['default_title', 'title_template', 'default_description', 'robots_default', 'sitemap_enabled', 'robots_enabled'] as $field) {
            if (array_key_exists($field, $payload) || array_key_exists($field, $seo)) {
                $updates[$field] = $payload[$field] ?? $seo[$field];
            }
        }

        if (array_key_exists('default_keywords', $payload) || array_key_exists('default_keywords', $seo)) {
            $updates['default_keywords_json'] = $payload['default_keywords'] ?? $seo['default_keywords'];
        }

        $maintenanceMap = [
            'active' => 'maintenance_active',
            'mode' => 'maintenance_mode',
            'message' => 'maintenance_message',
            'expected_end_at' => 'maintenance_expected_end_at',
            'retry_after_seconds' => 'maintenance_retry_after_seconds',
            'allowed_routes' => 'maintenance_allowed_routes_json',
            'blocked_route_patterns' => 'maintenance_blocked_route_patterns_json',
        ];

        foreach ($maintenanceMap as $input => $column) {
            if (array_key_exists($input, $maintenance)) {
                $updates[$column] = $maintenance[$input];
            }
        }

        foreach ($maintenanceMap as $input => $column) {
            if (array_key_exists($column, $payload)) {
                $updates[$column] = $payload[$column];
            } elseif (array_key_exists($input, $payload)) {
                $updates[$column] = $payload[$input];
            }
        }

        $apiMap = [
            'base_url' => 'api_base_url',
            'realtime_url' => 'realtime_url',
            'asset_cdn_base_url' => 'asset_cdn_base_url',
        ];

        foreach ($apiMap as $input => $column) {
            if (array_key_exists($input, $api)) {
                $updates[$column] = $api[$input];
            }
        }

        foreach ($apiMap as $input => $column) {
            if (array_key_exists($column, $payload)) {
                $updates[$column] = $payload[$column];
            } elseif (array_key_exists($input, $payload)) {
                $updates[$column] = $payload[$input];
            }
        }

        foreach (['waiting_result_youtube_url', 'youtube_live_url'] as $field) {
            if (array_key_exists($field, $live)) {
                $updates['waiting_result_youtube_url'] = $live[$field];
            } elseif (array_key_exists($field, $payload)) {
                $updates['waiting_result_youtube_url'] = $payload[$field];
            }
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function themeUpdates(array $payload): array
    {
        $updates = [];
        $brand = is_array($payload['brand'] ?? null) ? $payload['brand'] : [];
        $theme = is_array($payload['theme'] ?? null) ? $payload['theme'] : [];

        foreach (['logo_url', 'favicon_url', 'og_image_url'] as $field) {
            if (array_key_exists($field, $payload) || array_key_exists($field, $brand)) {
                $updates[$field] = $payload[$field] ?? $brand[$field];
            }
        }

        foreach (['primary_color', 'secondary_color', 'accent_color', 'background_color', 'text_color', 'font_family'] as $field) {
            if (array_key_exists($field, $payload) || array_key_exists($field, $theme)) {
                $updates[$field] = $payload[$field] ?? $theme[$field];
            }
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $updates
     * @return array<string, mixed>
     */
    private function serializeSettingsUpdates(array $updates): array
    {
        foreach (['default_keywords_json', 'maintenance_allowed_routes_json', 'maintenance_blocked_route_patterns_json'] as $jsonField) {
            if (array_key_exists($jsonField, $updates)) {
                $updates[$jsonField] = json_encode($this->normalizedStringList($updates[$jsonField]), JSON_THROW_ON_ERROR);
            }
        }

        return $updates;
    }

    /**
     * @return array<string, mixed>
     */
    private function sitePayload(object $settings): array
    {
        return [
            'site_name' => (string) $settings->site_name,
            'display_name' => $settings->display_name,
            'locale' => (string) $settings->locale,
            'timezone' => (string) $settings->timezone,
            'support_email' => $settings->support_email,
            'support_phone' => $settings->support_phone,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function brandPayload(object $theme): array
    {
        return [
            'logo_url' => $theme->logo_url,
            'favicon_url' => $theme->favicon_url,
            'og_image_url' => $theme->og_image_url,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function themePayload(object $theme): array
    {
        return [
            'primary_color' => (string) $theme->primary_color,
            'secondary_color' => (string) $theme->secondary_color,
            'accent_color' => (string) $theme->accent_color,
            'background_color' => (string) $theme->background_color,
            'text_color' => (string) $theme->text_color,
            'font_family' => (string) $theme->font_family,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function seoPayload(object $settings, string $host): array
    {
        return [
            'default_title' => $settings->default_title ?: $settings->site_name,
            'title_template' => $settings->title_template,
            'default_description' => $settings->default_description,
            'default_keywords' => $this->decodeJsonList($settings->default_keywords_json),
            'robots_default' => (string) $settings->robots_default,
            'canonical_base_url' => $this->canonicalUrl($host),
            'sitemap_enabled' => (bool) $settings->sitemap_enabled,
            'robots_enabled' => (bool) $settings->robots_enabled,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function maintenancePayload(object $settings, string $tenantStatus): array
    {
        $active = (bool) $settings->maintenance_active || $tenantStatus === 'maintenance';

        return [
            'active' => $active,
            'mode' => $settings->maintenance_mode,
            'message' => $settings->maintenance_message,
            'expected_end_at' => $settings->maintenance_expected_end_at,
            'retry_after_seconds' => $settings->maintenance_retry_after_seconds,
            'allowed_routes' => $this->decodeJsonList($settings->maintenance_allowed_routes_json),
            'blocked_route_patterns' => $this->decodeJsonList($settings->maintenance_blocked_route_patterns_json),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function apiPayload(object $settings): array
    {
        return [
            'base_url' => $settings->api_base_url,
            'realtime_url' => $settings->realtime_url,
            'asset_cdn_base_url' => $settings->asset_cdn_base_url,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function livePayload(object $settings): array
    {
        $centralUrl = $this->centralWaitingResultYoutubeUrl();
        $tenantUrl = trim((string) ($settings->waiting_result_youtube_url ?? ''));
        $resolvedUrl = $tenantUrl !== '' ? $tenantUrl : $centralUrl;

        return [
            'waiting_result_youtube_url' => $resolvedUrl,
            'waiting_result_youtube_embed_url' => YoutubeLiveUrl::embedUrl($resolvedUrl),
            'tenant_override_youtube_url' => $tenantUrl,
            'central_default_youtube_url' => $centralUrl,
            'source' => $tenantUrl !== '' ? 'tenant_override' : ($centralUrl !== '' ? 'central_default' : 'not_configured'),
        ];
    }

    private function centralWaitingResultYoutubeUrl(): string
    {
        $value = PlatformSystemSetting::query()
            ->where('key', 'waiting_result_youtube_url')
            ->where('status', 'active')
            ->first()
            ?->value_json;

        return is_string($value) ? trim($value) : '';
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function tenantTamperErrors(string $tenantId, array $payload): array
    {
        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            return [
                'tenant_id' => ['The tenant_id field must match the selected tenant.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditConfigChange(
        AdminSessionContext $actor,
        Request $request,
        object $tenant,
        string $targetType,
        string $changeType,
        array $payload,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: 'settings.changed',
            targetType: $targetType,
            targetId: (string) $tenant->id,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            tenantId: (string) $tenant->id,
            partnerId: (string) $tenant->partner_id,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @return array<string, bool>
     */
    private function featuresForTenant(string $tenantId): array
    {
        $features = [
            'affiliate' => false,
            'agent_network' => false,
            'topup_qr' => false,
            'topup_credit' => false,
            'cashback' => false,
            'reward_check' => true,
            'custom_theme' => true,
            'custom_domain' => false,
        ];

        $rows = PartnerTenantFeatureFlag::query()->forTenant($tenantId)->get(['feature_key', 'enabled']);

        foreach ($rows as $row) {
            $features[(string) $row->feature_key] = (bool) $row->enabled;
        }

        return $features;
    }

    private function primaryHost(string $tenantId): string
    {
        $host = PartnerTenantDomain::query()
            ->forTenant($tenantId)
            ->orderByDesc('is_primary')
            ->orderBy('host')
            ->value('host');

        if ($host !== null) {
            return (string) $host;
        }

        $tenantCode = PartnerTenant::whereKey($tenantId)->value('code');

        return ($tenantCode ?: $tenantId).'.newpaotang.test';
    }

    private function canonicalUrl(string $host): string
    {
        return 'https://'.$this->normalizeHost($host);
    }

    private function normalizeHost(string $host): string
    {
        return TenantHostNormalizer::normalize($host);
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @param mixed $value
     * @return array<int, string>
     */
    private function normalizedStringList(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $list = array_values(array_unique(array_filter(array_map(
            fn (mixed $item): string => is_string($item) ? trim($item) : '',
            $value,
        ), fn (string $item): bool => $item !== '')));

        sort($list);

        return $list;
    }

    /**
     * @param mixed $json
     * @return array<int, string>
     */
    private function decodeJsonList(mixed $json): array
    {
        if (is_array($json)) {
            return $this->normalizedStringList($json);
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $this->normalizedStringList($decoded) : [];
    }
}
