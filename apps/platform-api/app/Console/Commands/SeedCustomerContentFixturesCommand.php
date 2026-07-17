<?php

namespace App\Console\Commands;

use App\Models\PlatformAsset;
use App\Models\TenantActivity;
use App\Models\TenantActivityCashbackConfig;
use App\Models\TenantActivityLuckyConfig;
use App\Models\TenantAnnouncement;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use JsonException;

class SeedCustomerContentFixturesCommand extends Command
{
    protected $signature = 'customer-content:seed-test
        {--tenant= : Existing tenant id or code}
        {--game= : Existing game id or code; defaults to the current open game}
        {--allow-runtime : Allow a non-test database only with an exact database-name confirmation}
        {--confirm-database= : Exact effective database name required with --allow-runtime}
        {--validate-only : Validate fixture content and cover assets without reading or writing the database}';

    protected $description = 'Seed customer activities and news with local cover images under an explicit database guard.';

    public function __construct(private readonly RuntimeStorageService $storage)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        try {
            $fixtures = $this->fixtureData();
            $this->validateFixtureData($fixtures);
        } catch (JsonException|\RuntimeException $exception) {
            $this->error('Customer content fixture is invalid: '.$exception->getMessage());

            return self::FAILURE;
        }

        if ((bool) $this->option('validate-only')) {
            $this->info('Customer content fixture is valid: 10 activities, 10 news items, and all referenced covers are present.');

            return self::SUCCESS;
        }

        $databaseName = (string) DB::connection()->getDatabaseName();
        $isTestDatabase = str_ends_with(strtolower($databaseName), '_test');
        $runtimeConfirmed = (bool) $this->option('allow-runtime')
            && hash_equals($databaseName, trim((string) $this->option('confirm-database')));
        if (! $isTestDatabase && ! $runtimeConfirmed) {
            $this->error(
                "Refusing to seed customer content into database [{$databaseName}]. "
                .'Use a database ending in _test, or provide both --allow-runtime and an exact --confirm-database value after explicit operator approval.'
            );

            return self::FAILURE;
        }

        if (! $isTestDatabase) {
            $this->warn("Runtime database [{$databaseName}] explicitly confirmed. Fixture rows will be upserted without deleting unrelated content.");
        }

        $tenantKey = trim((string) $this->option('tenant'));
        if ($tenantKey === '') {
            $this->error('The --tenant option is required. Use an existing tenant id or code.');

            return self::FAILURE;
        }

        $tenant = DB::table('partner_tenants')
            ->where(fn ($query) => $query->where('id', $tenantKey)->orWhere('code', $tenantKey))
            ->first(['id', 'code']);
        if ($tenant === null) {
            $this->error("Tenant [{$tenantKey}] was not found.");

            return self::FAILURE;
        }

        $game = $this->resolveGame(trim((string) $this->option('game')));
        if ($game === null) {
            $this->error('No matching game was found. Create a game or provide --game.');

            return self::FAILURE;
        }

        $tenantId = (string) $tenant->id;
        $gameId = (string) $game->id;
        $activityCount = 0;
        $newsCount = 0;

        DB::transaction(function () use ($fixtures, $tenantId, $gameId, &$activityCount, &$newsCount): void {
            foreach ($fixtures['activities'] ?? [] as $fixture) {
                $this->seedActivity($tenantId, $gameId, $fixture);
                $activityCount++;
            }

            foreach ($fixtures['news'] ?? [] as $index => $fixture) {
                $this->seedAnnouncement($tenantId, $fixture, (int) $index);
                $newsCount++;
            }
        });

        $this->info("Seeded {$activityCount} activities and {$newsCount} news items into [{$databaseName}].");
        $this->line("tenant: {$tenant->code} ({$tenantId})");
        $this->line("game: {$game->code} ({$gameId})");

        return self::SUCCESS;
    }

    private function resolveGame(string $gameKey): ?object
    {
        $query = DB::table('games')->select(['id', 'code']);
        if ($gameKey !== '') {
            return $query
                ->where(fn ($builder) => $builder->where('id', $gameKey)->orWhere('code', $gameKey))
                ->first();
        }

        return (clone $query)
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at')
            ->first()
            ?? $query->orderByDesc('draw_at')->orderByDesc('created_at')->first();
    }

    /** @return array<string, array<int, array<string, mixed>>> */
    private function fixtureData(): array
    {
        $path = database_path('fixtures/customer_content/content.json');
        $contents = file_get_contents($path);
        if (! is_string($contents)) {
            throw new JsonException("Unable to read fixture file [{$path}].");
        }

        return json_decode($contents, true, flags: JSON_THROW_ON_ERROR);
    }

    /** @param array<string, array<int, array<string, mixed>>> $fixtures */
    private function validateFixtureData(array $fixtures): void
    {
        $groups = [
            'activities' => $fixtures['activities'] ?? [],
            'news' => $fixtures['news'] ?? [],
        ];

        foreach ($groups as $group => $items) {
            if (count($items) !== 10) {
                throw new \RuntimeException("Fixture group [{$group}] must contain exactly 10 items.");
            }

            $slugs = [];
            foreach ($items as $index => $item) {
                $slug = trim((string) ($item['slug'] ?? ''));
                $cover = trim((string) ($item['cover'] ?? ''));
                if ($slug === '' || $cover === '') {
                    throw new \RuntimeException("Fixture [{$group}.{$index}] requires both slug and cover.");
                }
                if (isset($slugs[$slug])) {
                    throw new \RuntimeException("Fixture group [{$group}] contains duplicate slug [{$slug}].");
                }
                $slugs[$slug] = true;

                $coverPath = database_path('fixtures/customer_content/images/'.$cover);
                if (! is_file($coverPath)) {
                    throw new \RuntimeException("Fixture cover [{$cover}] was not found.");
                }

                $imageInfo = getimagesize($coverPath);
                if (! is_array($imageInfo) || ($imageInfo[2] ?? null) !== IMAGETYPE_PNG) {
                    throw new \RuntimeException("Fixture cover [{$cover}] must be a valid PNG image.");
                }

                [$width, $height] = $imageInfo;
                if ($width < 1200 || $height < 675) {
                    throw new \RuntimeException("Fixture cover [{$cover}] must be at least 1200x675 pixels.");
                }

                if ($group === 'activities') {
                    $this->validateActivityFixture($item, $index);
                } else {
                    $this->validateNewsFixture($item, $index);
                }
            }
        }
    }

    /** @param array<string, mixed> $fixture */
    private function validateActivityFixture(array $fixture, int $index): void
    {
        $this->validateLocalizedText($fixture['name'] ?? null, "activities.{$index}.name");

        $type = trim((string) ($fixture['type'] ?? ''));
        if (! in_array($type, ['lucky_board', 'cashback'], true)) {
            throw new \RuntimeException("Fixture [activities.{$index}.type] must be lucky_board or cashback.");
        }

        $config = $fixture['config'] ?? null;
        if (! is_array($config)) {
            throw new \RuntimeException("Fixture [activities.{$index}.config] must be an object.");
        }

        if ($type === 'lucky_board') {
            $predictionType = trim((string) ($config['prediction_type'] ?? ''));
            if (! in_array($predictionType, ['first_prize_last2', 'first_prize_last3', 'last2'], true)) {
                throw new \RuntimeException("Fixture [activities.{$index}.config.prediction_type] is invalid.");
            }

            return;
        }

        $cashbackType = trim((string) ($config['cashback_type'] ?? ''));
        if (! in_array($cashbackType, ['percent', 'fixed'], true)) {
            throw new \RuntimeException("Fixture [activities.{$index}.config.cashback_type] must be percent or fixed.");
        }
    }

    /** @param array<string, mixed> $fixture */
    private function validateNewsFixture(array $fixture, int $index): void
    {
        foreach (['title', 'summary', 'body'] as $field) {
            $this->validateLocalizedText($fixture[$field] ?? null, "news.{$index}.{$field}");
        }
    }

    private function validateLocalizedText(mixed $value, string $path): void
    {
        if (! is_array($value)) {
            throw new \RuntimeException("Fixture [{$path}] must be a localized object.");
        }

        foreach (['th-TH', 'en-US'] as $locale) {
            if (trim((string) ($value[$locale] ?? '')) === '') {
                throw new \RuntimeException("Fixture [{$path}.{$locale}] is required.");
            }
        }
    }

    /** @param array<string, mixed> $fixture */
    private function seedActivity(string $tenantId, string $gameId, array $fixture): void
    {
        $slug = trim((string) ($fixture['slug'] ?? ''));
        $type = (string) ($fixture['type'] ?? 'lucky_board');
        $name = (array) ($fixture['name'] ?? []);
        $activityId = $this->stableId('act_', "{$tenantId}:activity:{$slug}");
        $assetId = $this->storeFixtureAsset(
            tenantId: $tenantId,
            ownerId: $activityId,
            slug: $slug,
            cover: (string) ($fixture['cover'] ?? ''),
            kind: 'activity',
        );

        TenantActivity::query()->updateOrCreate(
            ['id' => $activityId],
            [
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'name' => (string) ($name['th-TH'] ?? $slug),
                'name_i18n' => $name,
                'slug' => $slug,
                'type' => $type,
                'status' => 'active',
                'sort_order' => (int) ($fixture['sort_order'] ?? 0),
                'image_full_asset_id' => $assetId,
                'image_thumb_asset_id' => $assetId,
                'metadata_json' => ['fixture' => 'customer_content_v1'],
            ],
        );

        $config = (array) ($fixture['config'] ?? []);
        if ($type === 'cashback') {
            TenantActivityCashbackConfig::query()->updateOrCreate(
                ['activity_id' => $activityId],
                [
                    'cashback_type' => (string) ($config['cashback_type'] ?? 'percent'),
                    'cashback_percent_bps' => (int) ($config['cashback_percent_bps'] ?? 0),
                    'fixed_amount' => (int) ($config['fixed_amount'] ?? 0),
                    'min_ticket_count' => (int) ($config['min_ticket_count'] ?? 0),
                    'min_purchase_amount' => (int) ($config['min_purchase_amount'] ?? 0),
                    'currency' => 'THB',
                    'metadata_json' => ['fixture' => 'customer_content_v1'],
                ],
            );

            return;
        }

        $predictionType = (string) ($config['prediction_type'] ?? 'first_prize_last2');
        TenantActivityLuckyConfig::query()->updateOrCreate(
            ['activity_id' => $activityId],
            [
                'first_prize_last2_enabled' => $predictionType === 'first_prize_last2',
                'first_prize_last3_enabled' => $predictionType === 'first_prize_last3',
                'last2_enabled' => $predictionType === 'last2',
                'eligibility_rule' => 'cumulative_tickets',
                'threshold_tickets' => (int) ($config['threshold_tickets'] ?? 1),
                'first_prize_last2_amount' => (int) ($config['first_prize_last2_amount'] ?? 0),
                'first_prize_last3_amount' => (int) ($config['first_prize_last3_amount'] ?? 0),
                'last2_amount' => (int) ($config['last2_amount'] ?? 0),
                'currency' => 'THB',
                'metadata_json' => ['fixture' => 'customer_content_v1'],
            ],
        );
    }

    /** @param array<string, mixed> $fixture */
    private function seedAnnouncement(string $tenantId, array $fixture, int $index): void
    {
        $slug = trim((string) ($fixture['slug'] ?? ''));
        $title = (array) ($fixture['title'] ?? []);
        $summary = (array) ($fixture['summary'] ?? []);
        $body = (array) ($fixture['body'] ?? []);
        $announcementId = $this->stableId('ann_', "{$tenantId}:announcement:{$slug}");
        $assetId = $this->storeFixtureAsset(
            tenantId: $tenantId,
            ownerId: $announcementId,
            slug: $slug,
            cover: (string) ($fixture['cover'] ?? ''),
            kind: 'announcement',
        );

        TenantAnnouncement::query()->updateOrCreate(
            ['id' => $announcementId],
            [
                'tenant_id' => $tenantId,
                'title' => (string) ($title['th-TH'] ?? $slug),
                'title_i18n' => $title,
                'slug' => $slug,
                'summary' => (string) ($summary['th-TH'] ?? ''),
                'summary_i18n' => $summary,
                'body' => (string) ($body['th-TH'] ?? ''),
                'body_i18n' => $body,
                'status' => 'active',
                'modal_enabled' => false,
                'important' => (bool) ($fixture['important'] ?? false),
                'display_start_at' => now()->subDays($index),
                'display_end_at' => null,
                'sort_order' => (int) ($fixture['sort_order'] ?? 0),
                'image_full_asset_id' => $assetId,
                'image_thumb_asset_id' => $assetId,
                'metadata_json' => ['fixture' => 'customer_content_v1'],
            ],
        );
    }

    private function storeFixtureAsset(
        string $tenantId,
        string $ownerId,
        string $slug,
        string $cover,
        string $kind,
    ): string {
        $path = database_path('fixtures/customer_content/images/'.$cover);
        $bytes = file_get_contents($path);
        if (! is_string($bytes)) {
            throw new \RuntimeException("Unable to read fixture image [{$path}].");
        }

        $route = $kind === 'activity'
            ? RuntimeStorageService::ROUTE_ACTIVITY_IMAGES
            : RuntimeStorageService::ROUTE_ANNOUNCEMENT_IMAGES;
        $storageKey = "tenants/{$tenantId}/fixtures/customer-content/{$kind}/{$slug}.png";
        $storageKey = $this->storage->put($route, $storageKey, $bytes, ['ContentType' => 'image/png']);
        $assetId = $this->stableId('ast_', "{$tenantId}:{$kind}:{$slug}:cover");

        PlatformAsset::query()->updateOrCreate(
            ['id' => $assetId],
            [
                'scope_type' => 'tenant',
                'tenant_id' => $tenantId,
                'created_by_admin_id' => null,
                'purpose' => $kind === 'activity' ? 'tenant_activity_image' : 'tenant_announcement_image',
                'file_name' => $cover,
                'content_type' => 'image/png',
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'status' => 'committed',
                'storage_key' => $storageKey,
                'upload_url' => null,
                'public_url' => $this->storage->publicUrl($route, $storageKey),
                'metadata_json' => [
                    'fixture' => 'customer_content_v1',
                    'owner_id' => $ownerId,
                    'variant' => 'cover',
                    'storage_route' => $route,
                ],
                'expires_at' => null,
                'committed_at' => now(),
            ],
        );

        return $assetId;
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.substr(hash('sha256', $seed), 0, 30 - strlen($prefix));
    }
}
