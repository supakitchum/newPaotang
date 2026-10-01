<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantRedirect;
use App\Models\PartnerTenantSeoPage;
use App\Models\PartnerTenantSeoSetting;
use App\Models\PartnerTenantSetting;
use App\Models\PartnerTenantTheme;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Tenancy\TenantHostNormalizer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenantSeoService
{
    private const STATUSES = ['draft', 'active', 'inactive', 'archived'];
    private const REDIRECT_CODES = [301, 302, 307, 308];

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settings(string $tenantId): ?array
    {
        if (PartnerTenant::whereKey($tenantId)->doesntExist()) {
            return null;
        }

        return $this->seoSettingResource($this->ensureSeoSettings($tenantId));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateSettings(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->seoSettingsPayload($tenantId, $payload);
        $errors = $this->seoSettingsErrors($tenantId, $normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $settings = $this->ensureSeoSettings($tenantId);
            $updates = [];

            foreach (['status', 'default_title', 'title_template', 'default_description', 'default_keywords_json', 'robots_default', 'canonical_base_url', 'og_image_url'] as $field) {
                if (array_key_exists($field, $normalized)) {
                    $updates[$field] = $normalized[$field];
                }
            }

            if ($updates !== []) {
                $updates['config_version'] = ((int) $settings->config_version) + 1;
                $updates['updated_at'] = now();

                PartnerTenantSeoSetting::query()->forTenant($tenantId)->update($updates);
            }

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_seo_setting', (string) $settings->id, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->settings($tenantId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPages(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerTenantSeoPage::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        if (($queryParams['path'] ?? null) !== null && trim((string) $queryParams['path']) !== '') {
            $query->where('path', $this->normalizePath((string) $queryParams['path']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->pageResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createPage(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->pagePayload($tenantId, $payload, true);
        $errors = $this->pageErrors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (PartnerTenantSeoPage::query()->forTenant($tenantId)->where('path', $normalized['path'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $pageId = 'seo_'.Str::ulid()->toBase32();

            PartnerTenantSeoPage::query()->create($normalized + [
                'id' => $pageId,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_seo_page', $pageId, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->findPage($tenantId, $pageId)];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findPage(string $tenantId, string $pageId): ?array
    {
        $page = PartnerTenantSeoPage::query()->forTenant($tenantId)->where('id', $pageId)->first();

        return $page === null ? null : $this->pageResource($page);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updatePage(string $tenantId, string $pageId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $page = PartnerTenantSeoPage::query()->forTenant($tenantId)->where('id', $pageId)->first();

        if ($page === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $normalized = $this->pagePayload($tenantId, $payload, false, $page);
        $errors = $this->pageErrors($tenantId, $normalized, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('path', $normalized)
            && PartnerTenantSeoPage::query()->forTenant($tenantId)->where('path', $normalized['path'])->where('id', '!=', $pageId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $pageId, $payload, $normalized, $actor, $request, $tenant): array {
            if ($normalized !== []) {
                PartnerTenantSeoPage::query()->forTenant($tenantId)->where('id', $pageId)->update($normalized + ['updated_at' => now()]);
            }

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_seo_page', $pageId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->findPage($tenantId, $pageId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, status?: int}
     */
    public function deletePage(string $tenantId, string $pageId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $page = PartnerTenantSeoPage::query()->forTenant($tenantId)->where('id', $pageId)->first();

        if ($page === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $pageId, $payload, $actor, $request, $tenant): array {
            PartnerTenantSeoPage::query()->forTenant($tenantId)->where('id', $pageId)->delete();

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_seo_page', $pageId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listRedirects(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerTenantRedirect::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->redirectResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createRedirect(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->redirectPayload($tenantId, $payload, true);
        $errors = $this->redirectErrors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (PartnerTenantRedirect::query()->forTenant($tenantId)->where('source_path', $normalized['source_path'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $payload, $normalized, $actor, $request, $tenant): array {
            $redirectId = 'red_'.Str::ulid()->toBase32();

            PartnerTenantRedirect::query()->create($normalized + [
                'id' => $redirectId,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_redirect', $redirectId, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->findRedirect($tenantId, $redirectId)];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findRedirect(string $tenantId, string $redirectId): ?array
    {
        $redirect = PartnerTenantRedirect::query()->forTenant($tenantId)->where('id', $redirectId)->first();

        return $redirect === null ? null : $this->redirectResource($redirect);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateRedirect(string $tenantId, string $redirectId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $redirect = PartnerTenantRedirect::query()->forTenant($tenantId)->where('id', $redirectId)->first();

        if ($redirect === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $normalized = $this->redirectPayload($tenantId, $payload, false);
        $errors = $this->redirectErrors($tenantId, $normalized, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('source_path', $normalized)
            && PartnerTenantRedirect::query()->forTenant($tenantId)->where('source_path', $normalized['source_path'])->where('id', '!=', $redirectId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $redirectId, $payload, $normalized, $actor, $request, $tenant): array {
            if ($normalized !== []) {
                PartnerTenantRedirect::query()->forTenant($tenantId)->where('id', $redirectId)->update($normalized + ['updated_at' => now()]);
            }

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_redirect', $redirectId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->findRedirect($tenantId, $redirectId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, status?: int}
     */
    public function deleteRedirect(string $tenantId, string $redirectId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $redirect = PartnerTenantRedirect::query()->forTenant($tenantId)->where('id', $redirectId)->first();

        if ($redirect === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $redirectId, $payload, $actor, $request, $tenant): array {
            PartnerTenantRedirect::query()->forTenant($tenantId)->where('id', $redirectId)->delete();

            $this->audit($actor, $request, 'seo.changed', 'partner_tenant_redirect', $redirectId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function metadataForPath(string $tenantId, string $host, string $path): ?array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return null;
        }

        $settings = $this->ensureSeoSettings($tenantId);
        $page = PartnerTenantSeoPage::query()
            ->forTenant($tenantId)
            ->where('path', $this->normalizePath($path))
            ->where('status', 'active')
            ->first();
        $theme = PartnerTenantTheme::query()->forTenant($tenantId)->first();
        $baseUrl = $settings->canonical_base_url ?: 'https://'.$this->normalizeHost($host);
        $pageTitle = $page?->title ?: ($settings->default_title ?: $tenant->name);

        return [
            'title' => $this->applyTitleTemplate((string) $pageTitle, $settings->title_template),
            'description' => $page?->description ?: $settings->default_description,
            'canonical_url' => $page?->canonical_url ?: $this->canonicalUrl((string) $baseUrl, $page?->path ?: $this->normalizePath($path)),
            'robots' => $page?->robots ?: (string) $settings->robots_default,
            'og_image_url' => $page?->og_image_url ?: ($settings->og_image_url ?: $theme?->og_image_url),
        ];
    }

    private function ensureSeoSettings(string $tenantId): object
    {
        $settings = PartnerTenantSeoSetting::query()->forTenant($tenantId)->first();

        if ($settings !== null) {
            return $settings;
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $tenantSettings = PartnerTenantSetting::query()->forTenant($tenantId)->first();
        $host = PartnerTenantDomain::query()->forTenant($tenantId)->orderByDesc('is_primary')->orderBy('host')->value('host');

        PartnerTenantSeoSetting::query()->create([
            'id' => 'seo_'.substr(sha1($tenantId.':seo-settings'), 0, 20),
            'tenant_id' => $tenantId,
            'status' => 'active',
            'default_title' => $tenantSettings?->default_title ?: $tenant?->name,
            'title_template' => $tenantSettings?->title_template,
            'default_description' => $tenantSettings?->default_description,
            'default_keywords_json' => $tenantSettings?->default_keywords_json ?: [],
            'robots_default' => $tenantSettings?->robots_default ?: 'index,follow',
            'canonical_base_url' => $host === null ? null : 'https://'.$this->normalizeHost((string) $host),
            'og_image_url' => null,
            'config_version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return PartnerTenantSeoSetting::query()->forTenant($tenantId)->first();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function seoSettingsPayload(string $tenantId, array $payload): array
    {
        $seo = is_array($payload['seo'] ?? null) ? $payload['seo'] : $payload;

        return array_filter([
            'tenant_id' => $seo['tenant_id'] ?? null,
            'status' => array_key_exists('status', $seo) ? trim((string) $seo['status']) : null,
            'default_title' => array_key_exists('default_title', $seo) ? trim((string) $seo['default_title']) : null,
            'title_template' => array_key_exists('title_template', $seo) ? $this->nullableString($seo['title_template']) : null,
            'default_description' => array_key_exists('default_description', $seo) ? $this->nullableString($seo['default_description']) : null,
            'default_keywords_json' => array_key_exists('default_keywords', $seo) ? $seo['default_keywords'] : null,
            'robots_default' => array_key_exists('robots_default', $seo) ? trim((string) $seo['robots_default']) : null,
            'canonical_base_url' => array_key_exists('canonical_base_url', $seo) ? $this->nullableString($seo['canonical_base_url']) : null,
            'og_image_url' => array_key_exists('og_image_url', $seo) ? $this->nullableString($seo['og_image_url']) : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function seoSettingsErrors(string $tenantId, array $payload): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        if (array_key_exists('default_title', $payload) && trim((string) $payload['default_title']) === '') {
            $errors['default_title'][] = 'The default_title field must not be blank.';
        }

        if (array_key_exists('default_keywords_json', $payload) && ! is_array($payload['default_keywords_json'])) {
            $errors['default_keywords'][] = 'The default_keywords field must be an array.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function pagePayload(string $tenantId, array $payload, bool $creating, ?object $existing = null): array
    {
        return array_filter([
            'tenant_id' => $payload['tenant_id'] ?? null,
            'path' => array_key_exists('path', $payload) ? $this->normalizePath((string) $payload['path']) : null,
            'title' => array_key_exists('title', $payload) ? trim((string) $payload['title']) : null,
            'description' => array_key_exists('description', $payload) ? $this->nullableString($payload['description']) : null,
            'canonical_url' => array_key_exists('canonical_url', $payload) ? $this->nullableString($payload['canonical_url']) : null,
            'robots' => array_key_exists('robots', $payload) ? trim((string) $payload['robots']) : ($creating ? 'index,follow' : null),
            'og_image_url' => array_key_exists('og_image_url', $payload) ? $this->nullableString($payload['og_image_url']) : null,
            'status' => array_key_exists('status', $payload) ? trim((string) $payload['status']) : ($creating ? 'active' : null),
            'metadata_json' => array_key_exists('metadata', $payload) ? array_replace_recursive(is_array($existing?->metadata_json) ? $existing->metadata_json : [], is_array($payload['metadata']) ? $payload['metadata'] : []) : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function pageErrors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        foreach (['path', 'title'] as $field) {
            if ($creating && (! array_key_exists($field, $payload) || trim((string) $payload[$field]) === '')) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('metadata_json', $payload) && ! is_array($payload['metadata_json'])) {
            $errors['metadata'][] = 'The metadata field must be an object.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function redirectPayload(string $tenantId, array $payload, bool $creating): array
    {
        return array_filter([
            'tenant_id' => $payload['tenant_id'] ?? null,
            'source_path' => array_key_exists('source_path', $payload) ? $this->normalizePath((string) $payload['source_path']) : null,
            'target_url' => array_key_exists('target_url', $payload) ? trim((string) $payload['target_url']) : null,
            'status_code' => array_key_exists('status_code', $payload) ? filter_var($payload['status_code'], FILTER_VALIDATE_INT) : ($creating ? 301 : null),
            'status' => array_key_exists('status', $payload) ? trim((string) $payload['status']) : ($creating ? 'active' : null),
            'metadata_json' => array_key_exists('metadata', $payload) && is_array($payload['metadata']) ? $payload['metadata'] : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function redirectErrors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if (array_key_exists('tenant_id', $payload) && $payload['tenant_id'] !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the selected tenant.';
        }

        foreach (['source_path', 'target_url'] as $field) {
            if ($creating && (! array_key_exists($field, $payload) || trim((string) $payload[$field]) === '')) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('status_code', $payload) && ! in_array((int) $payload['status_code'], self::REDIRECT_CODES, true)) {
            $errors['status_code'][] = 'The status_code field is invalid.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        return $errors;
    }

    /**
     * @return array<string, mixed>
     */
    private function seoSettingResource(object $settings): array
    {
        return [
            'id' => (string) $settings->id,
            'tenant_id' => (string) $settings->tenant_id,
            'status' => (string) $settings->status,
            'created_at' => $settings->created_at?->toISOString(),
            'updated_at' => $settings->updated_at?->toISOString(),
            'default_title' => $settings->default_title,
            'title_template' => $settings->title_template,
            'default_description' => $settings->default_description,
            'default_keywords' => $settings->default_keywords_json ?? [],
            'robots_default' => (string) $settings->robots_default,
            'canonical_base_url' => $settings->canonical_base_url,
            'og_image_url' => $settings->og_image_url,
            'config_version' => (int) $settings->config_version,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function pageResource(object $page): array
    {
        return [
            'id' => (string) $page->id,
            'tenant_id' => (string) $page->tenant_id,
            'status' => (string) $page->status,
            'created_at' => $page->created_at?->toISOString(),
            'updated_at' => $page->updated_at?->toISOString(),
            'path' => (string) $page->path,
            'title' => (string) $page->title,
            'description' => $page->description,
            'canonical_url' => $page->canonical_url,
            'robots' => (string) $page->robots,
            'og_image_url' => $page->og_image_url,
            'metadata' => $page->metadata_json ?? [],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function redirectResource(object $redirect): array
    {
        return [
            'id' => (string) $redirect->id,
            'tenant_id' => (string) $redirect->tenant_id,
            'status' => (string) $redirect->status,
            'created_at' => $redirect->created_at?->toISOString(),
            'updated_at' => $redirect->updated_at?->toISOString(),
            'source_path' => (string) $redirect->source_path,
            'target_url' => (string) $redirect->target_url,
            'status_code' => (int) $redirect->status_code,
            'metadata' => $redirect->metadata_json ?? [],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetType,
        string $targetId,
        array $payload,
        string $tenantId,
        ?string $partnerId,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function whereString(mixed $query, string $field, mixed $value): void
    {
        if ($value !== null && trim((string) $value) !== '') {
            $query->where($field, trim((string) $value));
        }
    }

    private function normalizePath(string $path): string
    {
        $path = trim($path);

        if ($path === '') {
            return '/';
        }

        $path = parse_url($path, PHP_URL_PATH) ?: $path;
        $path = '/'.ltrim($path, '/');

        return $path === '//' ? '/' : $path;
    }

    private function canonicalUrl(string $baseUrl, string $path): string
    {
        return rtrim($baseUrl, '/').$this->normalizePath($path);
    }

    private function applyTitleTemplate(string $title, mixed $template): string
    {
        if (! is_string($template) || trim($template) === '') {
            return $title;
        }

        if (str_contains($template, '{{title}}')) {
            return str_replace('{{title}}', $title, $template);
        }

        if (str_contains($template, '%s')) {
            return sprintf($template, $title);
        }

        return $title;
    }

    private function nullableString(mixed $value): ?string
    {
        $string = trim((string) $value);

        return $string === '' ? null : $string;
    }

    private function normalizeHost(string $host): string
    {
        return TenantHostNormalizer::normalize($host);
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 50 : max(1, min(100, $limit));
    }
}
