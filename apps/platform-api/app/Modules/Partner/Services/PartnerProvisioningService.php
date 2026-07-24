<?php

namespace App\Modules\Partner\Services;

use App\Models\AdminMenu;
use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminScope;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\Partner;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerApiClient;
use App\Models\PartnerBillingPlanBinding;
use App\Models\PartnerHealthCheck;
use App\Models\PartnerMonitoringProfile;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDeploymentProfile;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantFeatureFlag;
use App\Models\PartnerTenantSetting;
use App\Models\PartnerTenantTheme;
use App\Models\PartnerUsageMeter;
use App\Models\Permission;
use App\Models\Role;
use App\Models\RoleMenu;
use App\Models\RolePermission;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Observability\ObservabilityCatalog;
use App\Shared\Tenancy\TenantHostNormalizer;
use App\Support\RealtimeUrl;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class PartnerProvisioningService
{
    private const PARTNER_TYPES = ['partner_store', 'agent_network', 'white_label', 'api_partner', 'internal'];
    private const PARTNER_STATUSES = ['draft', 'active', 'suspended', 'closed'];
    private const TENANT_STATUSES = ['provisioning', 'active', 'maintenance', 'suspended', 'closed'];
    private const DOMAIN_TYPES = ['subdomain', 'custom_domain'];
    private const DOMAIN_STATUSES = ['pending_verification', 'active', 'failed', 'disabled', 'suspended'];
    private const API_CLIENT_STATUSES = ['active', 'suspended', 'revoked'];
    private const PROFILE_SECTIONS = ['partner', 'tenant', 'domain', 'settings', 'theme', 'owner'];
    private const CUSTOMER_PRIMARY_COLOR = '#087FF0';
    private const CUSTOMER_SECONDARY_COLOR = '#19B8EF';
    private const CUSTOMER_ACCENT_COLOR = '#FFD10B';
    private const CUSTOMER_TEXT_COLOR = '#242833';
    private const CUSTOMER_FONT_FAMILY = 'Kanit';
    private const MAINTENANCE_MODES = [
        'full_site',
        'customer_web_only',
        'admin_only',
        'checkout_payment_only',
        'read_only',
        'scheduled',
    ];
    private const MAX_PERCENT_BASIS_POINTS = 10000;

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPartners(array $queryParams): array
    {
        $query = Partner::query()->orderBy('code');

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = strtolower(trim((string) $queryParams['q']));
            $query->where(function ($nested) use ($q): void {
                $nested->whereRaw('LOWER(code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(name) like ?', ['%'.$q.'%']);
            });
        }

        $rows = $query->limit($this->limit($queryParams['limit'] ?? null))->get()->all();

        return [
            'data' => array_map(fn (object $partner): array => $this->partnerResource($partner), $rows),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findPartner(string $partnerId): ?array
    {
        $partner = Partner::find($partnerId);

        return $partner === null ? null : $this->partnerResource($partner);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validatePartnerPayload(array $payload, bool $creating): array
    {
        $errors = [];

        if ($creating || array_key_exists('code', $payload)) {
            $code = trim((string) ($payload['code'] ?? ''));

            if ($code === '' || ! preg_match('/^[a-z0-9][a-z0-9_-]*$/', $code)) {
                $errors['code'][] = 'The code field must use lowercase letters, numbers, underscores, or hyphens.';
            }
        }

        if ($creating || array_key_exists('name', $payload)) {
            $name = trim((string) ($payload['name'] ?? ''));

            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
        }

        if (array_key_exists('type', $payload) && ! in_array($payload['type'], self::PARTNER_TYPES, true)) {
            $errors['type'][] = 'The type field is invalid.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::PARTNER_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('stock_percent', $payload) || array_key_exists('stock_percent_basis_points', $payload)) {
            $basisPoints = $this->percentBasisPointsFrom($payload['stock_percent'] ?? null, $payload['stock_percent_basis_points'] ?? null);

            if ($basisPoints === null || $basisPoints < 0 || $basisPoints > self::MAX_PERCENT_BASIS_POINTS) {
                $errors['stock_percent'][] = 'The stock_percent field must be between 0 and 100.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function partnerConflictErrors(array $payload, ?string $ignorePartnerId = null): array
    {
        if (! array_key_exists('code', $payload)) {
            return [];
        }

        $code = trim((string) $payload['code']);

        if ($code === '') {
            return [];
        }

        $query = Partner::query()->where('code', $code);

        if ($ignorePartnerId !== null) {
            $query->where('id', '!=', $ignorePartnerId);
        }

        return $query->exists()
            ? ['code' => ['The partner code already exists.']]
            : [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createPartner(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $partnerId = 'par_'.Str::ulid()->toBase32();
            $now = now();

            Partner::query()->create([
                'id' => $partnerId,
                'code' => trim((string) $payload['code']),
                'name' => trim((string) $payload['name']),
                'type' => $payload['type'] ?? 'partner_store',
                'status' => $payload['status'] ?? 'draft',
                'stock_percent_basis_points' => $this->percentBasisPointsFrom($payload['stock_percent'] ?? null, $payload['stock_percent_basis_points'] ?? null) ?? 0,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->auditPartnerChange($actor, $request, $partnerId, 'created', $payload);

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updatePartner(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $updates = ['updated_at' => now()];

            foreach (['code', 'name', 'type', 'status'] as $field) {
                if (array_key_exists($field, $payload)) {
                    $updates[$field] = is_string($payload[$field]) ? trim($payload[$field]) : $payload[$field];
                }
            }

            if (array_key_exists('stock_percent', $payload) || array_key_exists('stock_percent_basis_points', $payload)) {
                $updates['stock_percent_basis_points'] = $this->percentBasisPointsFrom($payload['stock_percent'] ?? null, $payload['stock_percent_basis_points'] ?? null) ?? 0;
            }

            Partner::query()->where('id', $partnerId)->update($updates);

            if (array_key_exists('name', $updates)) {
                PartnerTenant::query()
                    ->where('partner_id', $partnerId)
                    ->update([
                        'name' => $updates['name'],
                        'updated_at' => $updates['updated_at'],
                    ]);
            }

            $this->auditPartnerChange($actor, $request, $partnerId, 'updated', $payload);

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validatePartnerTenantProfilePayload(string $partnerId, array $payload): array
    {
        $section = trim((string) ($payload['section'] ?? ''));

        if (! in_array($section, self::PROFILE_SECTIONS, true)) {
            return [
                'section' => ['The section field must be one of partner, tenant, domain, settings, theme, or owner.'],
            ];
        }

        if (! is_array($payload[$section] ?? null)) {
            return [
                $section => ['The '.$section.' field must be an object.'],
            ];
        }

        $sectionPayload = $payload[$section];

        return match ($section) {
            'partner' => $this->validatePartnerPayload($sectionPayload, false),
            'tenant' => $this->validateTenantProfilePayload($sectionPayload),
            'domain' => $this->validateDomainProfilePayload($partnerId, $sectionPayload),
            'settings' => $this->validateSettingsProfilePayload($sectionPayload),
            'theme' => $this->validateThemeProfilePayload($sectionPayload),
            'owner' => $this->validateOwnerProfilePayload($sectionPayload),
        };
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function partnerTenantProfileConflictErrors(string $partnerId, array $payload): array
    {
        $section = trim((string) ($payload['section'] ?? ''));
        $sectionPayload = is_array($payload[$section] ?? null) ? $payload[$section] : [];

        if ($section === 'partner') {
            return $this->partnerConflictErrors($sectionPayload, $partnerId);
        }

        $tenantId = PartnerTenant::query()
            ->where('partner_id', $partnerId)
            ->orderBy('code')
            ->value('id');

        if ($section === 'tenant' && array_key_exists('code', $sectionPayload)) {
            $tenantCode = trim((string) $sectionPayload['code']);

            if (
                $tenantCode !== ''
                && PartnerTenant::query()
                    ->where('code', $tenantCode)
                    ->when($tenantId !== null, fn ($query) => $query->where('id', '!=', $tenantId))
                    ->exists()
            ) {
                return ['code' => ['The tenant code already exists.']];
            }
        }

        if ($section === 'domain' && array_key_exists('host', $sectionPayload)) {
            $host = $this->normalizeHost((string) $sectionPayload['host']);

            if (
                $host !== ''
                && PartnerTenantDomain::query()
                    ->whereIn('host', TenantHostNormalizer::variants($host))
                    ->where('partner_id', '!=', $partnerId)
                    ->exists()
            ) {
                return ['host' => ['The domain host already exists.']];
            }
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updatePartnerTenantProfile(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $section = trim((string) $payload['section']);
            $sectionPayload = $payload[$section];
            $now = now();

            if ($section === 'partner') {
                $this->applyPartnerProfileUpdates($partnerId, $sectionPayload, $now);
                $this->auditPartnerChange($actor, $request, $partnerId, 'profile.partner.updated', $payload);

                return $this->findPartner($partnerId);
            }

            $tenant = PartnerTenant::query()
                ->where('partner_id', $partnerId)
                ->orderBy('code')
                ->lockForUpdate()
                ->first();

            if ($tenant === null) {
                return null;
            }

            match ($section) {
                'tenant' => $this->applyTenantProfileUpdates($tenant, $sectionPayload, $now),
                'domain' => $this->applyDomainProfileUpdates($partnerId, $tenant, $sectionPayload, $now),
                'settings' => $this->applySettingsProfileUpdates($tenant, $sectionPayload, $now),
                'theme' => $this->applyThemeProfileUpdates($tenant, $sectionPayload, $now),
                'owner' => $this->ensureTenantScopeAndOwner($partnerId, (string) $tenant->id, (string) $tenant->name, $sectionPayload, $now),
                default => null,
            };

            $this->auditPartnerChange($actor, $request, $partnerId, 'profile.'.$section.'.updated', $payload);

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validateTenantProfilePayload(array $payload): array
    {
        $errors = [];

        if (array_key_exists('code', $payload)) {
            $code = trim((string) $payload['code']);

            if ($code === '' || ! preg_match('/^[a-z0-9][a-z0-9_-]*$/', $code)) {
                $errors['code'][] = 'The tenant code must use lowercase letters, numbers, underscores, or hyphens.';
            }
        }

        if (array_key_exists('name', $payload) && trim((string) $payload['name']) === '') {
            $errors['name'][] = 'The tenant name field is required.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::TENANT_STATUSES, true)) {
            $errors['status'][] = 'The tenant status field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validateDomainProfilePayload(string $partnerId, array $payload): array
    {
        $errors = [];

        if (! PartnerTenantDomain::query()->where('partner_id', $partnerId)->exists() && ! array_key_exists('host', $payload)) {
            $errors['host'][] = 'The host field is required when this partner has no domain yet.';
        }

        if (array_key_exists('host', $payload) && $this->normalizeHost((string) $payload['host']) === '') {
            $errors['host'][] = 'The host field must be a non-empty host name.';
        }

        if (array_key_exists('type', $payload) && ! in_array($payload['type'], self::DOMAIN_TYPES, true)) {
            $errors['type'][] = 'The domain type field is invalid.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::DOMAIN_STATUSES, true)) {
            $errors['status'][] = 'The domain status field is invalid.';
        }

        if (array_key_exists('is_primary', $payload) && ! is_bool($payload['is_primary'])) {
            $errors['is_primary'][] = 'The is_primary field must be true or false.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validateSettingsProfilePayload(array $payload): array
    {
        $errors = [];
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

        if (array_key_exists('support_url', $updates) && ! $this->isAllowedHttpsUrlOrEmpty($updates['support_url'])) {
            $errors['support_url'][] = 'The support_url field must be a valid HTTPS URL.';
        }

        foreach (['lottery_product_label' => 32, 'ticket_image_watermark' => 64] as $field => $maxLength) {
            if (! array_key_exists($field, $updates) || $updates[$field] === null || $updates[$field] === '') {
                continue;
            }

            if (! is_string($updates[$field]) || mb_strlen(trim($updates[$field])) > $maxLength) {
                $errors[$field][] = 'The '.$field.' field must be a string with at most '.$maxLength.' characters.';
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

        if (array_key_exists('terms_content', $updates) && $updates['terms_content'] !== null && ! is_string($updates['terms_content'])) {
            $errors['terms_content'][] = 'The terms_content field must be text.';
        }

        if (array_key_exists('realtime_url', $updates) && ! RealtimeUrl::isAllowedOrEmpty($updates['realtime_url'])) {
            $errors['realtime_url'][] = 'The realtime_url field must be an absolute http, https, ws, or wss URL without credentials or fragments.';
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
    private function validateThemeProfilePayload(array $payload): array
    {
        $errors = [];
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
     * @return array<string, array<int, string>>
     */
    private function validateOwnerProfilePayload(array $payload): array
    {
        $errors = [];

        if (! array_key_exists('owner_email', $payload) || filter_var((string) $payload['owner_email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['owner_email'][] = 'The owner_email field must be a valid email address.';
        }

        if (array_key_exists('owner_name', $payload) && trim((string) $payload['owner_name']) === '') {
            $errors['owner_name'][] = 'The owner_name field must not be blank.';
        }

        if (array_key_exists('owner_password', $payload) && $payload['owner_password'] !== null && $payload['owner_password'] !== '' && strlen((string) $payload['owner_password']) < 8) {
            $errors['owner_password'][] = 'The owner_password field must be at least 8 characters.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function applyPartnerProfileUpdates(string $partnerId, array $payload, mixed $now): void
    {
        $updates = ['updated_at' => $now];

        foreach (['code', 'name', 'type', 'status'] as $field) {
            if (array_key_exists($field, $payload)) {
                $updates[$field] = is_string($payload[$field]) ? trim($payload[$field]) : $payload[$field];
            }
        }

        if (array_key_exists('stock_percent', $payload) || array_key_exists('stock_percent_basis_points', $payload)) {
            $updates['stock_percent_basis_points'] = $this->percentBasisPointsFrom($payload['stock_percent'] ?? null, $payload['stock_percent_basis_points'] ?? null) ?? 0;
        }

        Partner::query()->where('id', $partnerId)->update($updates);

        if (array_key_exists('name', $updates)) {
            PartnerTenant::query()
                ->where('partner_id', $partnerId)
                ->update([
                    'name' => $updates['name'],
                    'updated_at' => $now,
                ]);
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function applyTenantProfileUpdates(object $tenant, array $payload, mixed $now): void
    {
        $updates = ['updated_at' => $now];

        foreach (['code', 'name', 'status'] as $field) {
            if (array_key_exists($field, $payload)) {
                $updates[$field] = is_string($payload[$field]) ? trim($payload[$field]) : $payload[$field];
            }
        }

        PartnerTenant::query()->where('id', $tenant->id)->update($updates);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function applyDomainProfileUpdates(string $partnerId, object $tenant, array $payload, mixed $now): void
    {
        $domain = PartnerTenantDomain::query()
            ->where('tenant_id', $tenant->id)
            ->orderByDesc('is_primary')
            ->orderBy('host')
            ->lockForUpdate()
            ->first();
        $host = array_key_exists('host', $payload)
            ? $this->normalizeHost((string) $payload['host'])
            : (string) $domain?->host;
        $isPrimary = array_key_exists('is_primary', $payload)
            ? (bool) $payload['is_primary']
            : (bool) ($domain?->is_primary ?? true);

        if ($isPrimary) {
            PartnerTenantDomain::query()
                ->where('tenant_id', $tenant->id)
                ->update(['is_primary' => false, 'updated_at' => $now]);
        }

        $values = [
            'partner_id' => $partnerId,
            'tenant_id' => (string) $tenant->id,
            'host' => $host,
            'type' => $payload['type'] ?? ($domain?->type ?? 'subdomain'),
            'status' => $payload['status'] ?? ($domain?->status ?? 'active'),
            'is_primary' => $isPrimary,
            'updated_at' => $now,
        ];

        if ($domain === null) {
            PartnerTenantDomain::query()->insert(array_merge($values, [
                'id' => $this->stableId('dom', $host),
                'created_at' => $now,
            ]));

            return;
        }

        PartnerTenantDomain::query()->where('id', $domain->id)->update($values);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function applySettingsProfileUpdates(object $tenant, array $payload, mixed $now): void
    {
        $settings = $this->ensureProfileSettings($tenant, $now);
        $updates = $this->settingsUpdates($payload);

        if ($updates === []) {
            return;
        }

        $updates = $this->serializeSettingsUpdates($updates);
        $updates['config_version'] = ((int) $settings->config_version) + 1;
        $updates['updated_at'] = $now;

        PartnerTenantSetting::query()->where('tenant_id', $tenant->id)->update($updates);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function applyThemeProfileUpdates(object $tenant, array $payload, mixed $now): void
    {
        $theme = $this->ensureProfileTheme($tenant, $now);
        $updates = $this->themeUpdates($payload);

        if ($updates === []) {
            return;
        }

        $updates['config_version'] = ((int) $theme->config_version) + 1;
        $updates['updated_at'] = $now;

        PartnerTenantTheme::query()->where('tenant_id', $tenant->id)->update($updates);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateProvisionPayload(array $payload): array
    {
        $errors = [];

        if (! array_key_exists('owner_email', $payload) || filter_var((string) $payload['owner_email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['owner_email'][] = 'The owner_email field must be a valid email address.';
        }

        if (array_key_exists('tenant_code', $payload)) {
            $tenantCode = trim((string) $payload['tenant_code']);

            if ($tenantCode === '' || ! preg_match('/^[a-z0-9][a-z0-9_-]*$/', $tenantCode)) {
                $errors['tenant_code'][] = 'The tenant_code field must use lowercase letters, numbers, underscores, or hyphens.';
            }
        }

        if (array_key_exists('tenant_status', $payload) && ! in_array($payload['tenant_status'], self::TENANT_STATUSES, true)) {
            $errors['tenant_status'][] = 'The tenant_status field is invalid.';
        }

        if (array_key_exists('domain_type', $payload) && ! in_array($payload['domain_type'], self::DOMAIN_TYPES, true)) {
            $errors['domain_type'][] = 'The domain_type field is invalid.';
        }

        if (array_key_exists('domain_host', $payload) && $this->normalizeHost((string) $payload['domain_host']) === '') {
            $errors['domain_host'][] = 'The domain_host field must be a non-empty host name.';
        }

        if (array_key_exists('owner_password', $payload) && strlen((string) $payload['owner_password']) < 8) {
            $errors['owner_password'][] = 'The owner_password field must be at least 8 characters.';
        }

        if (array_key_exists('features', $payload) && ! is_array($payload['features'])) {
            $errors['features'][] = 'The features field must be an object of boolean values.';
        } elseif (is_array($payload['features'] ?? null)) {
            foreach ($payload['features'] as $featureKey => $enabled) {
                if (! is_string($featureKey) || $featureKey === '' || ! is_bool($enabled)) {
                    $errors['features'][] = 'The features field must be an object of boolean values.';
                    break;
                }
            }
        }

        if (array_key_exists('deployment_mode', $payload) && ! in_array($payload['deployment_mode'], ['shared', 'dedicated_runtime', 'dedicated_resource_pool'], true)) {
            $errors['deployment_mode'][] = 'The deployment_mode field is invalid.';
        }

        if (array_key_exists('realtime_url', $payload) && ! RealtimeUrl::isAllowedOrEmpty($payload['realtime_url'])) {
            $errors['realtime_url'][] = 'The realtime_url field must be an absolute http, https, ws, or wss URL without credentials or fragments.';
        }

        if (array_key_exists('support_url', $payload) && ! $this->isAllowedHttpsUrlOrEmpty($payload['support_url'])) {
            $errors['support_url'][] = 'The support_url field must be a valid HTTPS URL.';
        }

        foreach (['lottery_product_label' => 32, 'ticket_image_watermark' => 64] as $field => $maxLength) {
            if (! array_key_exists($field, $payload) || $payload[$field] === null || $payload[$field] === '') {
                continue;
            }

            if (! is_string($payload[$field]) || mb_strlen(trim($payload[$field])) > $maxLength) {
                $errors[$field][] = 'The '.$field.' field must be a string with at most '.$maxLength.' characters.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function provisionConflictErrors(string $partnerId, array $payload): array
    {
        $partner = Partner::find($partnerId);

        if ($partner === null) {
            return [];
        }

        $tenantId = $this->tenantIdFor($partnerId, $payload);
        $tenantCode = trim((string) ($payload['tenant_code'] ?? $partner->code));
        $domainHost = $this->normalizeHost((string) ($payload['domain_host'] ?? $tenantCode.'.newpaotang.test'));
        $errors = [];

        $existingTenantId = PartnerTenant::where('partner_id', $partnerId)
            ->where('id', '!=', $tenantId)
            ->orderBy('id')
            ->value('id');

        if ($existingTenantId !== null) {
            $errors['partner_id'][] = 'The partner already has a tenant and cannot be provisioned with another tenant.';
        }

        $tenantCodeConflict = PartnerTenant::where('code', $tenantCode)
            ->where('id', '!=', $tenantId)
            ->exists();

        if ($tenantCodeConflict) {
            $errors['tenant_code'][] = 'The tenant_code field conflicts with an existing tenant.';
        }

        $domainConflict = PartnerTenantDomain::whereIn('host', TenantHostNormalizer::variants($domainHost))
            ->where('tenant_id', '!=', $tenantId)
            ->exists();

        if ($domainConflict) {
            $errors['domain_host'][] = 'The domain_host field conflicts with an existing tenant domain.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function provisionPartner(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $tenantId = $this->tenantIdFor($partnerId, $payload);
            $tenantCode = trim((string) ($payload['tenant_code'] ?? $partner->code));
            $tenantName = trim((string) ($payload['tenant_name'] ?? $partner->name));
            $domainHost = $this->normalizeHost((string) ($payload['domain_host'] ?? $tenantCode.'.newpaotang.test'));
            $domainId = $this->stableId('dom', $domainHost);
            $now = now();

            Partner::query()->where('id', $partnerId)->update([
                'status' => 'active',
                'updated_at' => $now,
            ]);

            $this->updateOrInsert(
                'partner_tenants',
                ['id' => $tenantId],
                [
                    'partner_id' => $partnerId,
                    'code' => $tenantCode,
                    'name' => $tenantName,
                    'status' => $payload['tenant_status'] ?? 'active',
                ],
                $now,
            );

            $this->upsertDomain($domainId, $partnerId, $tenantId, $domainHost, $payload, $now);
            $this->ensureTenantScopeAndOwner($partnerId, $tenantId, $tenantName, $payload, $now);
            $this->ensureTenantConfig($tenantId, $tenantName, $domainHost, $payload, $now);
            $this->ensureRuntimeDefaults($partnerId, $tenantId, $payload, $now);

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'central',
                action: 'partner.provisioned',
                targetType: 'partner',
                targetId: $partnerId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'payload' => $payload,
                    'tenant_id' => $tenantId,
                    'domain_host' => $domainHost,
                ],
                partnerId: $partnerId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function suspendPartner(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $now = now();

            Partner::query()->where('id', $partnerId)->update(['status' => 'suspended', 'updated_at' => $now]);
            PartnerTenant::query()->where('partner_id', $partnerId)->update(['status' => 'suspended', 'updated_at' => $now]);
            PartnerTenantDomain::query()->where('partner_id', $partnerId)->update(['status' => 'suspended', 'updated_at' => $now]);
            PartnerApiClient::query()->where('partner_id', $partnerId)->where('status', 'active')->update(['status' => 'suspended', 'updated_at' => $now]);
            PartnerTenantDeploymentProfile::query()
                ->whereIn('tenant_id', PartnerTenant::query()->where('partner_id', $partnerId)->select('id'))
                ->update(['status' => 'suspended', 'updated_at' => $now]);
            PartnerMonitoringProfile::query()->where('partner_id', $partnerId)->update(['status' => 'suspended', 'health_status' => 'suspended', 'updated_at' => $now]);
            PartnerUsageMeter::query()->where('partner_id', $partnerId)->update(['status' => 'paused', 'updated_at' => $now]);
            PartnerAlertPolicy::query()->where('partner_id', $partnerId)->update(['status' => 'paused', 'updated_at' => $now]);
            PartnerHealthCheck::query()->where('partner_id', $partnerId)->update(['health_status' => 'suspended', 'updated_at' => $now]);
            PartnerBillingPlanBinding::query()->where('partner_id', $partnerId)->update(['status' => 'suspended', 'updated_at' => $now]);

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'central',
                action: 'partner.suspended',
                targetType: 'partner',
                targetId: $partnerId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'payload' => $payload,
                ],
                partnerId: $partnerId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function unsuspendPartner(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $now = now();

            Partner::query()->where('id', $partnerId)->where('status', 'suspended')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerTenant::query()->where('partner_id', $partnerId)->where('status', 'suspended')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerTenantDomain::query()->where('partner_id', $partnerId)->where('status', 'suspended')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerApiClient::query()->where('partner_id', $partnerId)->where('status', 'suspended')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerTenantDeploymentProfile::query()
                ->whereIn('tenant_id', PartnerTenant::query()->where('partner_id', $partnerId)->select('id'))
                ->where('status', 'suspended')
                ->update(['status' => 'active', 'updated_at' => $now]);
            PartnerMonitoringProfile::query()
                ->where('partner_id', $partnerId)
                ->where('status', 'suspended')
                ->update(['status' => 'active', 'health_status' => 'unknown', 'updated_at' => $now]);
            PartnerUsageMeter::query()->where('partner_id', $partnerId)->where('status', 'paused')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerAlertPolicy::query()->where('partner_id', $partnerId)->where('status', 'paused')->update(['status' => 'active', 'updated_at' => $now]);
            PartnerHealthCheck::query()->where('partner_id', $partnerId)->where('health_status', 'suspended')->update(['health_status' => 'unknown', 'updated_at' => $now]);
            PartnerBillingPlanBinding::query()->where('partner_id', $partnerId)->where('status', 'suspended')->update(['status' => 'active', 'updated_at' => $now]);

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'central',
                action: 'partner.unsuspended',
                targetType: 'partner',
                targetId: $partnerId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'payload' => $payload,
                ],
                partnerId: $partnerId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $this->findPartner($partnerId);
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listApiClients(array $queryParams): array
    {
        $query = PartnerApiClient::query()->orderBy('created_at')->orderBy('id');

        if (($queryParams['partner_id'] ?? null) !== null && trim((string) $queryParams['partner_id']) !== '') {
            $query->where('partner_id', trim((string) $queryParams['partner_id']));
        }

        $rows = $query->limit($this->limit($queryParams['limit'] ?? null))->get()->all();

        return [
            'data' => array_map(fn (object $client): array => $this->apiClientResource($client), $rows),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateApiClientPayload(array $payload, bool $creating): array
    {
        $errors = [];

        if ($creating || array_key_exists('partner_id', $payload)) {
            $partnerId = trim((string) ($payload['partner_id'] ?? ''));

            if ($partnerId === '' || ! Partner::whereKey($partnerId)->exists()) {
                $errors['partner_id'][] = 'The partner_id field must reference an existing partner.';
            }
        }

        if ($creating || array_key_exists('name', $payload)) {
            $name = trim((string) ($payload['name'] ?? ''));

            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::API_CLIENT_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('scopes', $payload)) {
            if (! is_array($payload['scopes'])) {
                $errors['scopes'][] = 'The scopes field must be an array.';
            } else {
                foreach ($payload['scopes'] as $scope) {
                    if (! is_string($scope) || trim($scope) === '') {
                        $errors['scopes'][] = 'Each scope must be a non-empty string.';
                        break;
                    }
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createApiClient(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $clientId = 'pac_'.Str::ulid()->toBase32();
            $secret = bin2hex(random_bytes(32));
            $now = now();

            PartnerApiClient::query()->insert([
                'id' => $clientId,
                'partner_id' => trim((string) $payload['partner_id']),
                'name' => trim((string) $payload['name']),
                'client_key' => 'pk_'.bin2hex(random_bytes(16)),
                'secret_hash' => hash('sha256', $secret),
                'status' => $payload['status'] ?? 'active',
                'scopes_json' => json_encode($this->normalizedStringList($payload['scopes'] ?? []), JSON_THROW_ON_ERROR),
                'last_used_at' => null,
                'revoked_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->auditApiClientChange($actor, $request, $clientId, trim((string) $payload['partner_id']), 'created', $payload);

            return $this->apiClientById($clientId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateApiClient(string $clientId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($clientId, $payload, $actor, $request): ?array {
            $client = PartnerApiClient::query()->where('id', $clientId)->lockForUpdate()->first();

            if ($client === null) {
                return null;
            }

            $updates = ['updated_at' => now()];

            if (array_key_exists('name', $payload)) {
                $updates['name'] = trim((string) $payload['name']);
            }

            if (array_key_exists('status', $payload)) {
                $updates['status'] = $payload['status'];
                $updates['revoked_at'] = $payload['status'] === 'revoked' ? now() : null;
            }

            if (array_key_exists('scopes', $payload)) {
                $updates['scopes_json'] = json_encode($this->normalizedStringList($payload['scopes']), JSON_THROW_ON_ERROR);
            }

            PartnerApiClient::query()->where('id', $clientId)->update($updates);

            $this->auditApiClientChange($actor, $request, $clientId, (string) $client->partner_id, 'updated', $payload);

            return $this->apiClientById($clientId);
        });
    }

    public function revokeApiClient(string $clientId, AdminSessionContext $actor, Request $request): bool
    {
        return DB::transaction(function () use ($clientId, $actor, $request): bool {
            $client = PartnerApiClient::query()->where('id', $clientId)->lockForUpdate()->first();

            if ($client === null) {
                return false;
            }

            PartnerApiClient::query()->where('id', $clientId)->update([
                'status' => 'revoked',
                'revoked_at' => now(),
                'updated_at' => now(),
            ]);

            $this->auditApiClientChange($actor, $request, $clientId, (string) $client->partner_id, 'revoked', []);

            return true;
        });
    }

    private function upsertDomain(string $domainId, string $partnerId, string $tenantId, string $host, array $payload, mixed $now): void
    {
        $existing = PartnerTenantDomain::where('id', $domainId)->first();
        $type = $payload['domain_type'] ?? 'subdomain';
        $customDomain = $type === 'custom_domain';
        $verifiedAt = $customDomain ? $existing?->verified_at : ($existing?->verified_at ?? $now);
        $sslReadyAt = $customDomain ? $existing?->ssl_ready_at : ($existing?->ssl_ready_at ?? $now);
        $dnsVerifiedAt = $customDomain ? $existing?->dns_verified_at : ($existing?->dns_verified_at ?? $now);
        $proxyVerifiedAt = $existing?->cloudflare_proxy_verified_at;
        $httpsEnforcedAt = $existing?->https_enforced_at;
        $values = [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'host' => $host,
            'type' => $type,
            'status' => $this->domainStatusForReadiness($type, $verifiedAt, $sslReadyAt, $dnsVerifiedAt, $proxyVerifiedAt, $httpsEnforcedAt),
            'is_primary' => true,
            'verified_at' => $verifiedAt,
            'ssl_ready_at' => $sslReadyAt,
            'dns_verified_at' => $dnsVerifiedAt,
            'cloudflare_proxy_verified_at' => $proxyVerifiedAt,
            'https_enforced_at' => $httpsEnforcedAt,
            'cloudflare_readiness_checked_at' => $existing?->cloudflare_readiness_checked_at,
            'updated_at' => $now,
        ];

        if ($existing === null) {
            $values['id'] = $domainId;
            $values['created_at'] = $now;
            PartnerTenantDomain::query()->insert($values);

            return;
        }

        PartnerTenantDomain::query()->where('id', $domainId)->update($values);
    }

    private function domainStatusForReadiness(
        string $type,
        mixed $verifiedAt,
        mixed $sslReadyAt,
        mixed $dnsVerifiedAt,
        mixed $proxyVerifiedAt,
        mixed $httpsEnforcedAt,
    ): string {
        if ($type !== 'custom_domain') {
            return 'active';
        }

        $dnsReady = $verifiedAt !== null && $dnsVerifiedAt !== null;
        $sslReady = $sslReadyAt !== null;
        $proxyReady = ! (bool) config('platform.cloudflare.proxy_required', true) || $proxyVerifiedAt !== null;
        $httpsReady = ! (bool) config('platform.cloudflare.https_required', true) || $httpsEnforcedAt !== null;

        return $dnsReady && $sslReady && $proxyReady && $httpsReady ? 'active' : 'pending_verification';
    }

    private function ensureTenantScopeAndOwner(string $partnerId, string $tenantId, string $tenantName, array $payload, mixed $now): void
    {
        $scopeId = $this->tenantScopeId($tenantId);
        $ownerRoleId = $this->stableId('rol', 'tenant:'.$tenantId.':owner');
        $ownerEmail = strtolower(trim((string) $payload['owner_email']));
        $ownerName = trim((string) ($payload['owner_name'] ?? 'Owner '.$tenantName));
        $ownerPassword = array_key_exists('owner_password', $payload) ? (string) $payload['owner_password'] : null;

        $this->updateOrInsert(
            'admin_scopes',
            ['id' => $scopeId],
            [
                'scope_type' => 'tenant',
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
            ],
            $now,
        );

        $this->ensureTenantOwnerRole($ownerRoleId, $tenantId, $now);
        $this->ensureTenantCustomerSupportRoles($tenantId, $now);

        $adminUser = AdminUser::query()->where('email', $ownerEmail)->lockForUpdate()->first();
        $adminUserId = $adminUser?->id !== null ? (string) $adminUser->id : $this->stableId('adm', $ownerEmail);

        if ($adminUser === null) {
            AdminUser::query()->insert([
                'id' => $adminUserId,
                'name' => $ownerName,
                'email' => $ownerEmail,
                'phone' => $payload['owner_phone'] ?? null,
                'password_hash' => Hash::make($ownerPassword ?? Str::random(64)),
                'status' => $ownerPassword === null ? 'invited' : 'active',
                'two_factor_enabled' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ] + $this->forcedPasswordColumns(true, null));
        } else {
            $updates = [
                'name' => $ownerName,
                'updated_at' => $now,
            ];

            if ($ownerPassword !== null) {
                $updates['password_hash'] = Hash::make($ownerPassword);
                $updates['status'] = 'active';
                $updates += $this->forcedPasswordColumns(true, null);
            }

            AdminUser::query()->where('id', $adminUserId)->update($updates);
        }

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => $adminUserId,
            'role_id' => $ownerRoleId,
            'scope_id' => $scopeId,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        $this->updateOrInsert(
            'admin_permission_cache_versions',
            ['admin_user_id' => $adminUserId, 'scope_id' => $scopeId],
            [
                'id' => $this->stableId('pcv', $adminUserId.':'.$scopeId),
                'version' => 2,
            ],
            $now,
        );
    }

    private function ensureTenantOwnerRole(string $ownerRoleId, string $tenantId, mixed $now): void
    {
        $this->updateOrInsert(
            'roles',
            ['id' => $ownerRoleId],
            [
                'scope_type' => 'tenant',
                'tenant_id' => $tenantId,
                'code' => 'owner',
                'name' => 'Tenant Owner',
                'status' => 'active',
                'version' => 1,
            ],
            $now,
        );

        $permissionIds = Permission::query()
            ->where('scope_type', 'tenant')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            RolePermission::query()->insertOrIgnore(array_map(fn (string $permissionId): array => [
                'role_id' => $ownerRoleId,
                'permission_id' => $permissionId,
                'created_at' => $now,
                'updated_at' => $now,
            ], $permissionIds));
        }

        $menuIds = AdminMenu::query()
            ->where('scope_type', 'tenant')
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        if ($menuIds !== []) {
            RoleMenu::query()->insertOrIgnore(array_map(fn (string $menuId): array => [
                'role_id' => $ownerRoleId,
                'menu_id' => $menuId,
                'created_at' => $now,
                'updated_at' => $now,
            ], $menuIds));
        }
    }

    private function ensureTenantCustomerSupportRoles(string $tenantId, mixed $now): void
    {
        $permissionIds = Permission::query()
            ->where('scope_type', 'tenant')
            ->where('status', 'active')
            ->whereIn('code', [
                'support_ticket.view_assigned',
                'support_ticket.reply_assigned',
                'support_ticket.close_assigned',
                'support_ticket.view_all',
                'support_ticket.assign',
                'support_agent.manage',
                'support_faq.view',
                'support_faq.manage',
                'support_report.view',
            ])
            ->pluck('id', 'code');
        $menuId = AdminMenu::query()
            ->where('scope_type', 'tenant')
            ->where('code', 'customer_support')
            ->where('status', 'active')
            ->value('id');
        $roles = [
            'support' => [
                'name' => 'Support',
                'permissions' => [
                    'support_ticket.view_assigned',
                    'support_ticket.reply_assigned',
                    'support_ticket.close_assigned',
                ],
            ],
            'master_support' => [
                'name' => 'Master Support',
                'permissions' => array_keys($permissionIds->all()),
            ],
        ];

        foreach ($roles as $code => $definition) {
            $roleId = $this->stableId('rol', 'tenant:'.$tenantId.':'.$code);
            $this->updateOrInsert(
                'roles',
                ['id' => $roleId],
                [
                    'scope_type' => 'tenant',
                    'tenant_id' => $tenantId,
                    'code' => $code,
                    'name' => $definition['name'],
                    'status' => 'active',
                    'version' => 1,
                ],
                $now,
            );
            foreach ($definition['permissions'] as $permissionCode) {
                $permissionId = $permissionIds[$permissionCode] ?? null;
                if ($permissionId !== null) {
                    RolePermission::query()->insertOrIgnore([[
                        'role_id' => $roleId,
                        'permission_id' => $permissionId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]]);
                }
            }
            if ($menuId !== null) {
                RoleMenu::query()->insertOrIgnore([[
                    'role_id' => $roleId,
                    'menu_id' => $menuId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]]);
            }
        }
    }

    private function ensureTenantConfig(string $tenantId, string $tenantName, string $host, array $payload, mixed $now): void
    {
        if (! PartnerTenantSetting::where('tenant_id', $tenantId)->exists()) {
            PartnerTenantSetting::query()->insert([
                'id' => $this->stableId('pts', $tenantId),
                'tenant_id' => $tenantId,
                'site_name' => trim((string) ($payload['site_name'] ?? $tenantName)),
                'display_name' => $payload['display_name'] ?? null,
                'locale' => $payload['locale'] ?? 'th-TH',
                'timezone' => $payload['timezone'] ?? 'Asia/Bangkok',
                'support_email' => $payload['support_email'] ?? null,
                'support_phone' => $payload['support_phone'] ?? null,
                'support_url' => $payload['support_url'] ?? null,
                'lottery_product_label' => $this->nullableTrimmedString($payload['lottery_product_label'] ?? null),
                'ticket_image_watermark' => $this->nullableTrimmedString($payload['ticket_image_watermark'] ?? null),
                'default_title' => $payload['default_title'] ?? trim((string) ($payload['site_name'] ?? $tenantName)),
                'title_template' => $payload['title_template'] ?? null,
                'default_description' => $payload['default_description'] ?? null,
                'default_keywords_json' => json_encode($this->normalizedStringList($payload['default_keywords'] ?? []), JSON_THROW_ON_ERROR),
                'robots_default' => $payload['robots_default'] ?? 'index,follow',
                'sitemap_enabled' => true,
                'robots_enabled' => true,
                'maintenance_active' => false,
                'maintenance_mode' => null,
                'maintenance_message' => null,
                'maintenance_expected_end_at' => null,
                'maintenance_retry_after_seconds' => null,
                'maintenance_allowed_routes_json' => json_encode([], JSON_THROW_ON_ERROR),
                'maintenance_blocked_route_patterns_json' => json_encode([], JSON_THROW_ON_ERROR),
                'api_base_url' => $payload['api_base_url'] ?? '/api/v1',
                'realtime_url' => $payload['realtime_url'] ?? null,
                'asset_cdn_base_url' => $payload['asset_cdn_base_url'] ?? 'https://'.$host,
                'terms_content' => $payload['terms_content'] ?? null,
                'config_version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        if (! PartnerTenantTheme::where('tenant_id', $tenantId)->exists()) {
            PartnerTenantTheme::query()->insert([
                'id' => $this->stableId('ptt', $tenantId),
                'tenant_id' => $tenantId,
                'logo_url' => $payload['logo_url'] ?? null,
                'favicon_url' => $payload['favicon_url'] ?? null,
                'og_image_url' => $payload['og_image_url'] ?? null,
                'primary_color' => $payload['primary_color'] ?? self::CUSTOMER_PRIMARY_COLOR,
                'secondary_color' => $payload['secondary_color'] ?? self::CUSTOMER_SECONDARY_COLOR,
                'accent_color' => $payload['accent_color'] ?? self::CUSTOMER_ACCENT_COLOR,
                'background_color' => $payload['background_color'] ?? '#FFFFFF',
                'text_color' => $payload['text_color'] ?? self::CUSTOMER_TEXT_COLOR,
                'font_family' => $payload['font_family'] ?? self::CUSTOMER_FONT_FAMILY,
                'config_version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $features = array_merge($this->defaultFeatures(), is_array($payload['features'] ?? null) ? $payload['features'] : []);

        foreach ($features as $featureKey => $enabled) {
            $this->updateOrInsert(
                'partner_tenant_feature_flags',
                ['tenant_id' => $tenantId, 'feature_key' => $featureKey],
                [
                    'id' => $this->stableId('pff', $tenantId.':'.$featureKey),
                    'enabled' => (bool) $enabled,
                ],
                $now,
            );
        }
    }

    private function ensureRuntimeDefaults(string $partnerId, string $tenantId, array $payload, mixed $now): void
    {
        $this->updateOrInsert(
            'partner_tenant_deployment_profiles',
            ['tenant_id' => $tenantId],
            [
                'id' => $this->stableId('pdp', $tenantId),
                'mode' => $payload['deployment_mode'] ?? 'shared',
                'status' => 'active',
                'runtime_region' => $payload['runtime_region'] ?? null,
                'resource_pool' => $payload['resource_pool'] ?? null,
            ],
            $now,
        );

        $this->updateOrInsert(
            'partner_monitoring_profiles',
            ['partner_id' => $partnerId],
            [
                'id' => $this->stableId('pmp', $partnerId),
                'status' => 'active',
                'health_status' => 'unknown',
            ],
            $now,
        );

        foreach ($this->defaultUsageMeters() as $meterKey) {
            $this->updateOrInsert(
                'partner_usage_meters',
                ['partner_id' => $partnerId, 'meter_key' => $meterKey],
                [
                    'id' => $this->stableId('pum', $partnerId.':'.$meterKey),
                    'value' => 0,
                    'limit_value' => null,
                    'status' => 'active',
                ],
                $now,
            );
        }

        foreach ($this->defaultAlertPolicies() as $policyKey => $policy) {
            $this->updateOrInsert(
                'partner_alert_policies',
                ['partner_id' => $partnerId, 'policy_key' => $policyKey],
                [
                    'id' => $this->stableId('pap', $partnerId.':'.$policyKey),
                    'status' => 'active',
                    'severity' => $policy['severity'],
                    'config_json' => json_encode([
                        'metric' => $policy['metric'],
                        'threshold' => $policy['threshold'],
                        'window_seconds' => $policy['window_seconds'],
                        'description' => $policy['description'],
                        'data_source' => $policy['data_source'],
                    ], JSON_THROW_ON_ERROR),
                ],
                $now,
            );
        }

        $this->updateOrInsert(
            'partner_health_checks',
            ['partner_id' => $partnerId, 'check_key' => 'site_config'],
            [
                'id' => $this->stableId('phc', $partnerId.':site_config'),
                'tenant_id' => $tenantId,
                'health_status' => 'unknown',
                'checked_at' => null,
            ],
            $now,
        );

        $this->updateOrInsert(
            'partner_billing_plan_bindings',
            ['partner_id' => $partnerId],
            [
                'id' => $this->stableId('pbb', $partnerId),
                'billing_plan_code' => $payload['billing_plan_code'] ?? 'starter',
                'status' => 'trial',
                'effective_at' => $now,
            ],
            $now,
        );

        $this->ensureStarterAffiliateDefaults($tenantId, $now);
    }

    private function ensureStarterAffiliateDefaults(string $tenantId, mixed $now): void
    {
        $tiers = [
            ['bronze', 'Bronze', 1, 100, 30000],
            ['silver', 'Silver', 2, 150, 25000],
            ['gold', 'Gold', 3, 200, 20000],
            ['platinum', 'Platinum', 4, 250, 15000],
            ['diamond', 'Diamond', 5, 300, 10000],
        ];
        foreach ($tiers as [$code, $name, $rank, $commission, $minimumPayout]) {
            $programId = $this->stableId('afp', $tenantId.':'.$code);
            DB::table('affiliate_programs')->insertOrIgnore([
                'id' => $programId,
                'tenant_id' => $tenantId,
                'code' => $code,
                'name' => $name,
                'status' => 'active',
                'tier_rank' => $rank,
                'minimum_payout_amount' => $minimumPayout,
                'commission_per_ticket_amount' => $commission,
                'starts_at' => null,
                'ends_at' => null,
                'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('commission_rules')->insertOrIgnore([
                'id' => $this->stableId('cmr', $tenantId.':'.$code.'_per_ticket'),
                'tenant_id' => $tenantId,
                'affiliate_program_id' => $programId,
                'affiliate_account_id' => null,
                'code' => $code.'_per_ticket',
                'name' => $name.' commission per ticket',
                'rule_type' => 'per_ticket',
                'amount' => $commission,
                'rate_bps' => 0,
                'currency' => 'THB',
                'status' => 'active',
                'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    /**
     * @return array<int, string>
     */
    private function defaultUsageMeters(): array
    {
        return (new ObservabilityCatalog())->defaultUsageMeters();
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function defaultAlertPolicies(): array
    {
        return (new ObservabilityCatalog())->defaultAlertPolicies();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function apiClientById(string $clientId): ?array
    {
        $client = PartnerApiClient::find($clientId);

        return $client === null ? null : $this->apiClientResource($client);
    }

    /**
     * @return array<string, mixed>
     */
    private function partnerResource(object $partner): array
    {
        $tenants = PartnerTenant::query()
            ->where('partner_id', $partner->id)
            ->orderBy('code')
            ->get()
            ->all();
        $domains = PartnerTenantDomain::query()
            ->where('partner_id', $partner->id)
            ->orderByDesc('is_primary')
            ->orderBy('host')
            ->get()
            ->all();
        $primaryTenantId = $tenants[0]->id ?? null;
        $primaryTenant = $tenants[0] ?? null;
        $settings = $primaryTenant === null
            ? null
            : PartnerTenantSetting::query()->forTenant((string) $primaryTenant->id)->first();
        $theme = $primaryTenant === null
            ? null
            : PartnerTenantTheme::query()->forTenant((string) $primaryTenant->id)->first();
        $owner = $primaryTenant === null
            ? null
            : $this->ownerResourceForTenant((string) $primaryTenant->id);

        return [
            'id' => (string) $partner->id,
            'tenant_id' => $primaryTenantId,
            'status' => (string) $partner->status,
            'created_at' => $partner->created_at,
            'updated_at' => $partner->updated_at,
            'code' => (string) $partner->code,
            'name' => (string) $partner->name,
            'type' => (string) $partner->type,
            'stock_percent' => $this->percentFromBasisPoints((int) ($partner->stock_percent_basis_points ?? 0)),
            'stock_percent_basis_points' => (int) ($partner->stock_percent_basis_points ?? 0),
            'tenants' => array_map(fn (object $tenant): array => [
                'id' => (string) $tenant->id,
                'partner_id' => (string) $tenant->partner_id,
                'code' => (string) $tenant->code,
                'name' => (string) $tenant->name,
                'status' => (string) $tenant->status,
                'created_at' => $tenant->created_at,
                'updated_at' => $tenant->updated_at,
            ], $tenants),
            'domains' => array_map(fn (object $domain): array => [
                'id' => (string) $domain->id,
                'tenant_id' => (string) $domain->tenant_id,
                'host' => (string) $domain->host,
                'type' => (string) $domain->type,
                'status' => (string) $domain->status,
                'is_primary' => (bool) $domain->is_primary,
                'created_at' => $domain->created_at,
                'updated_at' => $domain->updated_at,
            ], $domains),
            'tenant_settings' => $primaryTenant === null ? null : $this->settingsResourceForTenant($primaryTenant, $settings),
            'tenant_theme' => $primaryTenant === null ? null : $this->themeResourceForTenant($primaryTenant, $theme),
            'owner_admin' => $owner,
            'runtime' => [
                'api_clients_total' => PartnerApiClient::where('partner_id', $partner->id)->count(),
                'monitoring_status' => PartnerMonitoringProfile::where('partner_id', $partner->id)->value('status'),
                'billing_status' => PartnerBillingPlanBinding::where('partner_id', $partner->id)->value('status'),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function settingsResourceForTenant(object $tenant, ?object $settings): array
    {
        $settings ??= $this->settingsDefaultForTenant($tenant);
        $host = $this->primaryHostForTenant((string) $tenant->id);

        return [
            'id' => (string) $settings->id,
            'tenant_id' => (string) $tenant->id,
            'status' => (string) $tenant->status,
            'created_at' => $settings->created_at,
            'updated_at' => $settings->updated_at,
            'site' => $this->sitePayload($settings),
            'seo' => $this->seoPayload($settings, $host),
            'maintenance' => $this->maintenancePayload($settings, (string) $tenant->status),
            'api' => $this->apiPayload($settings),
            'legal' => $this->legalPayload($settings),
            'config_version' => (int) $settings->config_version,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function themeResourceForTenant(object $tenant, ?object $theme): array
    {
        $theme ??= $this->themeDefaultForTenant($tenant);

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

    /**
     * @return array<string, mixed>|null
     */
    private function ownerResourceForTenant(string $tenantId): ?array
    {
        $owner = AdminUser::query()
            ->join('admin_user_roles', 'admin_user_roles.admin_user_id', '=', 'admin_users.id')
            ->where('admin_user_roles.scope_id', $this->tenantScopeId($tenantId))
            ->where('admin_user_roles.role_id', $this->stableId('rol', 'tenant:'.$tenantId.':owner'))
            ->select('admin_users.*')
            ->orderBy('admin_users.email')
            ->first();

        if ($owner === null) {
            return null;
        }

        return [
            'id' => (string) $owner->id,
            'name' => $owner->name,
            'email' => (string) $owner->email,
            'phone' => $owner->phone,
            'status' => (string) $owner->status,
            'updated_at' => $owner->updated_at,
        ];
    }

    private function ensureProfileSettings(object $tenant, mixed $now): object
    {
        $settings = PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();

        if ($settings !== null) {
            return $settings;
        }

        PartnerTenantSetting::query()->create([
            'id' => $this->stableId('pts', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'site_name' => (string) $tenant->name,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'support_url' => null,
            'lottery_product_label' => null,
            'ticket_image_watermark' => null,
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
            'asset_cdn_base_url' => $this->canonicalUrl($this->primaryHostForTenant((string) $tenant->id)),
            'terms_content' => null,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();
    }

    private function ensureProfileTheme(object $tenant, mixed $now): object
    {
        $theme = PartnerTenantTheme::query()->forTenant((string) $tenant->id)->first();

        if ($theme !== null) {
            return $theme;
        }

        PartnerTenantTheme::query()->create([
            'id' => $this->stableId('ptt', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'logo_url' => null,
            'favicon_url' => null,
            'og_image_url' => null,
            'primary_color' => self::CUSTOMER_PRIMARY_COLOR,
            'secondary_color' => self::CUSTOMER_SECONDARY_COLOR,
            'accent_color' => self::CUSTOMER_ACCENT_COLOR,
            'background_color' => '#FFFFFF',
            'text_color' => self::CUSTOMER_TEXT_COLOR,
            'font_family' => self::CUSTOMER_FONT_FAMILY,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantTheme::query()->forTenant((string) $tenant->id)->first();
    }

    private function settingsDefaultForTenant(object $tenant): object
    {
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
            'support_url' => null,
            'lottery_product_label' => null,
            'ticket_image_watermark' => null,
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
            'asset_cdn_base_url' => $this->canonicalUrl($this->primaryHostForTenant((string) $tenant->id)),
            'terms_content' => null,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ];
    }

    private function themeDefaultForTenant(object $tenant): object
    {
        $now = now();

        return (object) [
            'id' => $this->stableId('ptt', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'logo_url' => null,
            'favicon_url' => null,
            'og_image_url' => null,
            'primary_color' => self::CUSTOMER_PRIMARY_COLOR,
            'secondary_color' => self::CUSTOMER_SECONDARY_COLOR,
            'accent_color' => self::CUSTOMER_ACCENT_COLOR,
            'background_color' => '#FFFFFF',
            'text_color' => self::CUSTOMER_TEXT_COLOR,
            'font_family' => self::CUSTOMER_FONT_FAMILY,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ];
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
            'support_url' => $settings->support_url,
            'lottery_product_label' => $settings->lottery_product_label,
            'ticket_image_watermark' => $settings->ticket_image_watermark,
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
        return [
            'active' => (bool) $settings->maintenance_active || $tenantStatus === 'maintenance',
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
    private function legalPayload(object $settings): array
    {
        return [
            'terms_content' => $this->termsContent($settings),
        ];
    }

    private function termsContent(object $settings): string
    {
        $custom = trim((string) ($settings->terms_content ?? ''));

        return $custom !== '' ? $custom : $this->defaultTermsContent($this->siteDisplayName($settings));
    }

    private function siteDisplayName(object $settings): string
    {
        $displayName = trim((string) ($settings->display_name ?? ''));
        $siteName = trim((string) ($settings->site_name ?? ''));

        return $displayName !== '' ? $displayName : ($siteName !== '' ? $siteName : 'เว็บไซต์นี้');
    }

    private function defaultTermsContent(string $siteName): string
    {
        return implode("\n", [
            'ข้อตกลงการใช้งาน',
            '1. '.$siteName.'เป็นระบบจำหน่ายลอตเตอรี่ออนไลน์',
            '2. บริษัทไม่สนับสนุนการจำหน่ายสลากให้กับบุคคลที่มีอายุไม่ถึง 20 ปี',
            '3. บริษัทสนับสนุนผู้ไม่มีรายได้ ผู้พิการ ในการเป็นตัวแทนจำหน่ายลอตเตอรี่ออนไลน์',
            '4. บริษัทเก็บรักษาสลากที่ลูกค้าซื้อเพื่อความปลอดภัย รวมถึงการขึ้นรางวัลให้กับลูกค้า',
            '5. หากผู้ซื้อนำรูปภาพสลากหรือสลากจริงไปขายต่อ ทางบริษัทไม่มีส่วนเกี่ยวข้องและไม่รับผิดชอบความเสียหายในทุกกรณี',
            '6. หลังจาก ทำรายการ และ กดปุ่ม " ชำระเงิน " ทางบริษัทถือว่า ผู้สั่งซื้อได้รับทราบ ข้อตกลงและเงื่อนไขต่างๆของบริษัทเป็นที่เรียบร้อย',
            '7. บริษัทขอสงวนสิทธิ์ ขึ้นเงินรางวัลให้ลูกค้าที่ซื้อกับระบบ ในกรณีลูกค้าถูกรางวัล โดยไม่มีค่าใช้จ่ายใดๆ ทั้งสิ้น',
            '8. ลูกค้าสามารถยกเลิกการสั่งซื้อสลากได้ภายใน 15 นาทีทุกกรณี หากเกินระยะเวลาที่กำหนด บริษัทขอสงวนสิทธิ์ไม่คืนเงินค่าสลากทุกกรณี',
        ]);
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
        $legal = is_array($payload['legal'] ?? null) ? $payload['legal'] : [];

        foreach ([
            'site_name',
            'display_name',
            'locale',
            'timezone',
            'support_email',
            'support_phone',
            'support_url',
            'lottery_product_label',
            'ticket_image_watermark',
        ] as $field) {
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

        if (array_key_exists('terms_content', $legal)) {
            $updates['terms_content'] = $legal['terms_content'] === null ? null : trim((string) $legal['terms_content']);
        } elseif (array_key_exists('terms_content', $payload)) {
            $updates['terms_content'] = $payload['terms_content'] === null ? null : trim((string) $payload['terms_content']);
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
        foreach (['lottery_product_label', 'ticket_image_watermark'] as $field) {
            if (array_key_exists($field, $updates)) {
                $value = $updates[$field] === null ? '' : trim((string) $updates[$field]);
                $updates[$field] = $value === '' ? null : $value;
            }
        }

        foreach (['default_keywords_json', 'maintenance_allowed_routes_json', 'maintenance_blocked_route_patterns_json'] as $jsonField) {
            if (array_key_exists($jsonField, $updates)) {
                $updates[$jsonField] = json_encode($this->normalizedStringList($updates[$jsonField]), JSON_THROW_ON_ERROR);
            }
        }

        return $updates;
    }

    private function primaryHostForTenant(string $tenantId): string
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

    private function isAllowedHttpsUrlOrEmpty(mixed $value): bool
    {
        if ($value === null) {
            return true;
        }

        $url = trim((string) $value);
        if ($url === '') {
            return true;
        }

        if (filter_var($url, FILTER_VALIDATE_URL) === false) {
            return false;
        }

        return strtolower((string) parse_url($url, PHP_URL_SCHEME)) === 'https'
            && trim((string) parse_url($url, PHP_URL_HOST)) !== ''
            && trim((string) parse_url($url, PHP_URL_USER)) === '';
    }

    private function nullableTrimmedString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = trim((string) $value);

        return $normalized === '' ? null : $normalized;
    }

    private function percentBasisPointsFrom(mixed $percent, mixed $basisPoints = null): ?int
    {
        if ($percent !== null && $percent !== '') {
            if (! is_numeric($percent)) {
                return null;
            }

            return (int) round(((float) $percent) * 100);
        }

        if ($basisPoints !== null && $basisPoints !== '') {
            if (! is_numeric($basisPoints)) {
                return null;
            }

            return (int) round((float) $basisPoints);
        }

        return null;
    }

    private function percentFromBasisPoints(int $basisPoints): float|int
    {
        $percent = $basisPoints / 100;

        return fmod($percent, 1.0) === 0.0 ? (int) $percent : $percent;
    }

    /**
     * @return array<string, mixed>
     */
    private function apiClientResource(object $client): array
    {
        return [
            'id' => (string) $client->id,
            'tenant_id' => null,
            'status' => (string) $client->status,
            'created_at' => $client->created_at,
            'updated_at' => $client->updated_at,
            'partner_id' => (string) $client->partner_id,
            'name' => (string) $client->name,
            'client_key' => (string) $client->client_key,
            'scopes' => $this->decodeJsonList($client->scopes_json),
            'last_used_at' => $client->last_used_at,
            'revoked_at' => $client->revoked_at,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditPartnerChange(AdminSessionContext $actor, Request $request, string $partnerId, string $changeType, array $payload): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'partner.changed',
            targetType: 'partner',
            targetId: $partnerId,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditApiClientChange(AdminSessionContext $actor, Request $request, string $clientId, string $partnerId, string $changeType, array $payload): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'partner_api_client.changed',
            targetType: 'partner_api_client',
            targetId: $clientId,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function tenantIdFor(string $partnerId, array $payload): string
    {
        $provided = trim((string) ($payload['tenant_id'] ?? ''));

        return $provided !== '' ? $provided : $this->stableId('ten', $partnerId);
    }

    private function tenantScopeId(string $tenantId): string
    {
        return 'scp_t_'.substr(sha1($tenantId), 0, 20);
    }

    /**
     * @param array<string, mixed> $attributes
     * @param array<string, mixed> $values
     */
    private function updateOrInsert(string $table, array $attributes, array $values, mixed $now): void
    {
        $query = $this->queryForTable($table);

        foreach ($attributes as $column => $value) {
            $query->where($column, $value);
        }

        if ($query->exists()) {
            $this->queryForTable($table)
                ->where($attributes)
                ->update(array_merge($values, ['updated_at' => $now]));

            return;
        }

        $this->queryForTable($table)->insert(array_merge($attributes, $values, [
            'created_at' => $now,
            'updated_at' => $now,
        ]));
    }

    private function queryForTable(string $table): mixed
    {
        return match ($table) {
            'admin_permission_cache_versions' => AdminPermissionCacheVersion::query(),
            'admin_scopes' => AdminScope::query(),
            'partner_alert_policies' => PartnerAlertPolicy::query(),
            'partner_billing_plan_bindings' => PartnerBillingPlanBinding::query(),
            'partner_health_checks' => PartnerHealthCheck::query(),
            'partner_monitoring_profiles' => PartnerMonitoringProfile::query(),
            'partner_tenant_deployment_profiles' => PartnerTenantDeploymentProfile::query(),
            'partner_tenant_feature_flags' => PartnerTenantFeatureFlag::query(),
            'partner_tenants' => PartnerTenant::query(),
            'partner_usage_meters' => PartnerUsageMeter::query(),
            'roles' => Role::query(),
            default => throw new \InvalidArgumentException('Unsupported model-backed table: '.$table),
        };
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @return array<string, mixed>
     */
    private function forcedPasswordColumns(bool $mustChange, mixed $changedAt): array
    {
        $columns = [];

        if (Schema::hasColumn('admin_users', 'must_change_password')) {
            $columns['must_change_password'] = $mustChange;
        }

        if (Schema::hasColumn('admin_users', 'password_changed_at')) {
            $columns['password_changed_at'] = $changedAt;
        }

        return $columns;
    }

    private function normalizeHost(string $host): string
    {
        return TenantHostNormalizer::normalize($host);
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, $limit));
    }

    /**
     * @return array<string, bool>
     */
    private function defaultFeatures(): array
    {
        return [
            'affiliate' => false,
            'agent_network' => false,
            'topup_qr' => false,
            'topup_credit' => false,
            'cashback' => false,
            'reward_check' => true,
            'custom_theme' => true,
            'custom_domain' => false,
            'customer_support' => false,
        ];
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
