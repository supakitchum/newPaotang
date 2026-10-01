<?php

namespace App\Modules\PublicSite\Services;

use App\Models\AffiliateAccount;
use App\Modules\AdminOperations\Services\TenantAnnouncementService;
use App\Modules\AdminOperations\Services\TenantSeoService;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use Illuminate\Http\Request;

class PublicContentService
{
    public function __construct(
        private readonly TenantConfigurationService $configuration,
        private readonly TenantSeoService $seo,
        private readonly TenantAnnouncementService $announcements,
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
            'resource' => $this->announcements->publicList(
                (string) $site['data']['tenant_id'],
                $this->limit($request->query('limit')),
            ),
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function newsModal(Request $request): array
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return ['error' => $site['error']];
        }

        $announcement = $this->announcements->publicModal((string) $site['data']['tenant_id']);

        return [
            'resource' => [
                'data' => $announcement,
                'content_source_status' => $announcement === null ? 'empty' : 'configured',
            ],
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: array{status: int, code: string, message: string}}
     */
    public function newsDetail(Request $request, string $slug): array
    {
        $site = $this->siteConfig($request);

        if (isset($site['error'])) {
            return ['error' => $site['error']];
        }

        $announcement = $this->announcements->publicFindBySlug((string) $site['data']['tenant_id'], $slug);

        return $announcement === null
            ? ['error' => ['status' => 404, 'code' => 'news_not_found', 'message' => 'News was not found.']]
            : ['resource' => $announcement];
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
        $query = AffiliateAccount::query()
            ->forTenant($tenantId)
            ->where('status', 'active')
            ->where('store_name_status', 'approved')
            ->whereNotNull('name')
            ->where('name', '!=', '')
            ->select(['id', 'name', 'code', 'store_name_status'])
            ->orderBy('id')
            ->limit($limit + 1);

        $q = trim((string) $request->query('q', ''));

        if ($q !== '') {
            $query->where(function ($query) use ($q): void {
                $query->where('name', 'like', '%'.$q.'%')
                    ->orWhere('code', 'like', '%'.$q.'%');
            });
        }

        $cursor = trim((string) $request->query('cursor', ''));

        if ($cursor !== '') {
            $query->where('id', '>', $cursor);
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'resource' => [
                'data' => array_map(fn (object $row): array => [
                    'id' => (string) $row->id,
                    'name' => (string) $row->name,
                    'store_name' => (string) $row->name,
                    'affiliate_id' => (string) $row->id,
                    'code' => (string) $row->code,
                    'status' => 'active',
                ], $rows),
                'meta' => [
                    'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
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
