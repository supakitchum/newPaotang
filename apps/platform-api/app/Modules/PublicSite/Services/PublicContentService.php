<?php

namespace App\Modules\PublicSite\Services;

use App\Models\LocalStockItem;
use App\Modules\AdminOperations\Services\TenantSeoService;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use Illuminate\Http\Request;

class PublicContentService
{
    public function __construct(
        private readonly TenantConfigurationService $configuration,
        private readonly TenantSeoService $seo,
    ) {
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function seoPage(Request $request): array
    {
        $path = trim((string) $request->query('path', ''));

        if ($path === '') {
            return ['error' => ['status' => 422, 'code' => 'validation_failed', 'message' => 'The path field is required.']];
        }

        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return ['error' => $site['error']];
        }

        $metadata = $this->seo->metadataForPath(
            (string) $site['data']['tenant_id'],
            (string) ($site['data']['domain']['host'] ?? $request->getHost()),
            $path,
        );

        if ($metadata === null) {
            return ['error' => ['status' => 404, 'code' => 'tenant_not_found', 'message' => 'Tenant domain was not found.']];
        }

        return ['resource' => $metadata];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function news(Request $request): array
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return ['error' => $site['error']];
        }

        return [
            'resource' => [
                'data' => [],
                'content_source_status' => 'not_configured',
            ],
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function stores(Request $request): array
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return ['error' => $site['error']];
        }

        $tenantId = (string) $site['data']['tenant_id'];
        $limit = $this->limit($request->query('limit'));
        $query = LocalStockItem::query()
            ->forTenant($tenantId)
            ->whereNotNull('store_id')
            ->where('store_id', '!=', '')
            ->where('status', 'available')
            ->select('store_id')
            ->distinct()
            ->orderBy('store_id')
            ->limit($limit + 1);

        $q = trim((string) $request->query('q', ''));

        if ($q !== '') {
            $query->where('store_id', 'like', '%'.$q.'%');
        }

        $cursor = trim((string) $request->query('cursor', ''));

        if ($cursor !== '') {
            $query->where('store_id', '>', $cursor);
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'resource' => [
                'data' => array_map(fn (object $row): array => [
                    'id' => (string) $row->store_id,
                    'name' => (string) $row->store_id,
                    'status' => 'active',
                ], $rows),
                'meta' => [
                    'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->store_id : null,
                    'has_more' => $hasMore,
                ],
            ],
        ];
    }

    /**
     * @return array{data?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    private function siteConfig(Request $request): array
    {
        return $this->configuration->siteConfigForRequest($request);
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 20 : max(1, min(100, $limit));
    }
}
