<?php

namespace Tests\Feature;

use App\Models\PlatformAsset;
use App\Models\TenantAnnouncement;
use App\Modules\PartnerStore\Services\PublicAssetThumbnailService;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Mockery;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class PublicActivityThumbnailTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    private PlatformAsset $asset;
    private string $source;

    protected function setUp(): void
    {
        parent::setUp();
        config(['cache.default' => 'array']);
        Storage::fake('lottery_images');
        $this->insertActivePartnerTenantWithDomain('par_thumbnail', 'ten_thumbnail', 'thumbnail.test');
        $this->source = file_get_contents(database_path('fixtures/customer_content/images/activity-scan.png'));
        $path = 'tenants/ten_thumbnail/activities/source.png';
        Storage::disk('lottery_images')->put($path, $this->source);
        $this->asset = PlatformAsset::query()->create([
            'id' => 'ast_thumbnail',
            'scope_type' => 'tenant',
            'tenant_id' => 'ten_thumbnail',
            'purpose' => 'tenant_activity_image',
            'file_name' => 'source.png',
            'content_type' => 'image/png',
            'size_bytes' => strlen($this->source),
            'checksum_sha256' => hash('sha256', $this->source),
            'status' => 'committed',
            'storage_key' => $path,
            'public_url' => 'http://thumbnail.test/api/v1/public/assets/'.$path,
        ]);
    }

    public function test_activity_thumbnail_is_small_versioned_webp_and_does_not_modify_source(): void
    {
        $url = PublicAssetThumbnailService::url($this->asset, $this->asset->public_url);
        $response = $this->get($url)->assertOk()->assertHeader('Content-Type', 'image/webp');
        $size = getimagesizefromstring($response->getContent());

        $this->assertSame(480, $size[0]);
        $this->assertLessThan(strlen($this->source) / 5, strlen($response->getContent()));
        $this->assertStringContainsString('immutable', $response->headers->get('Cache-Control'));
        $this->assertStringNotContainsString('Accept-Language', (string) $response->headers->get('Vary'));
        $this->assertSame($this->source, Storage::disk('lottery_images')->get($this->asset->storage_key));
    }

    public function test_repeated_thumbnail_uses_cache_without_reading_storage_and_supports_304(): void
    {
        $url = PublicAssetThumbnailService::url($this->asset, $this->asset->public_url);
        $first = $this->get($url)->assertOk();
        $storage = Mockery::mock(RuntimeStorageService::class);
        $storage->shouldNotReceive('routeForStorageKey');
        $storage->shouldNotReceive('getUsingDriver');
        $this->assertSame($first->getContent(), (new PublicAssetThumbnailService($storage))->get($this->asset));

        $this->get($url, ['If-None-Match' => $first->headers->get('ETag')])
            ->assertStatus(304)
            ->assertContent('');
    }

    public function test_old_thumbnail_version_is_rejected_after_source_changes(): void
    {
        $url = PublicAssetThumbnailService::url($this->asset, $this->asset->public_url);
        $this->get($url)->assertOk();
        $replacement = file_get_contents(database_path('fixtures/customer_content/images/activity-cashback.png'));
        Storage::disk('lottery_images')->put($this->asset->storage_key, $replacement);
        $this->asset->update(['checksum_sha256' => hash('sha256', $replacement)]);

        $this->get($url)->assertNotFound()->assertHeader('Cache-Control', 'no-store, private');
        $newUrl = PublicAssetThumbnailService::url($this->asset, $this->asset->public_url);
        $this->assertNotSame($url, $newUrl);
        $this->get($newUrl)->assertOk()->assertHeader('Content-Type', 'image/webp');
    }

    public function test_full_activity_image_still_returns_original_bytes_and_etag(): void
    {
        $first = $this->get($this->asset->public_url)
            ->assertOk()->assertHeader('Content-Type', 'image/png')->assertContent($this->source);
        $this->get($this->asset->public_url, ['If-None-Match' => $first->headers->get('ETag')])
            ->assertStatus(304);
    }

    public function test_legacy_news_cover_uses_small_versioned_webp_without_rewriting_assets(): void
    {
        $this->asset->update(['purpose' => 'tenant_announcement_image']);
        $announcement = TenantAnnouncement::query()->create([
            'id' => 'ann_thumbnail',
            'tenant_id' => 'ten_thumbnail',
            'title' => 'Legacy news',
            'slug' => 'legacy-news',
            'status' => 'active',
            'image_full_asset_id' => $this->asset->id,
            'image_thumb_asset_id' => $this->asset->id,
        ]);
        $url = PublicAssetThumbnailService::url($this->asset, $this->asset->public_url);

        $this->getJson('http://thumbnail.test/api/v1/public/news')
            ->assertOk()
            ->assertJsonPath('data.0.image_thumb_url', $url)
            ->assertJsonPath('data.0.cover_url', $url)
            ->assertJsonPath('data.0.image_full_url', $this->asset->public_url);

        $response = $this->get($url)->assertOk()->assertHeader('Content-Type', 'image/webp');
        $this->assertSame(480, getimagesizefromstring($response->getContent())[0]);
        $this->assertLessThan(strlen($this->source) / 5, strlen($response->getContent()));
        $this->assertSame($this->source, Storage::disk('lottery_images')->get($this->asset->storage_key));
        $this->assertSame($this->asset->id, $announcement->fresh()->image_full_asset_id);
        $this->assertSame($this->asset->id, $announcement->fresh()->image_thumb_asset_id);
        $this->assertDatabaseCount('platform_assets', 1);
        $this->get($this->asset->public_url)->assertOk()->assertContent($this->source);
        $this->get($url, ['If-None-Match' => $response->headers->get('ETag')])->assertStatus(304);
    }

    public function test_news_with_dedicated_thumbnail_keeps_its_existing_url(): void
    {
        $this->asset->update(['purpose' => 'tenant_announcement_image']);
        $thumbnail = $this->asset->replicate();
        $thumbnail->id = 'ast_news_dedicated_thumb';
        $thumbnail->public_url = 'http://thumbnail.test/api/v1/public/assets/tenants/ten_thumbnail/news/thumb.webp';
        $thumbnail->storage_key = 'tenants/ten_thumbnail/news/thumb.webp';
        $thumbnail->save();
        TenantAnnouncement::query()->create([
            'id' => 'ann_dedicated_thumbnail',
            'tenant_id' => 'ten_thumbnail',
            'title' => 'News with a thumbnail',
            'slug' => 'dedicated-thumbnail',
            'status' => 'active',
            'image_full_asset_id' => $this->asset->id,
            'image_thumb_asset_id' => $thumbnail->id,
        ]);

        $this->getJson('http://thumbnail.test/api/v1/public/news')
            ->assertOk()
            ->assertJsonPath('data.0.image_thumb_url', $thumbnail->public_url)
            ->assertJsonPath('data.0.image_full_url', $this->asset->public_url);
    }
}
